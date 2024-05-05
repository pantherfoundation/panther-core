// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
// solhint-disable max-line-length
pragma solidity ^0.8.19;

import "./interfaces/IFeeMaster.sol";
import "./interfaces/ITransactionChargesHandler.sol";

import "./feeMaster/PoolKey.sol";
import "./feeMaster/UniswapV3Handler.sol";
import "./feeMaster/UniswapPoolsList.sol";
import "./feeMaster/FeeAccountant.sol";
import { ChargedFeesPerTx, FeeData, AssetData } from "./feeMaster/Types.sol";

import "../../common/UtilsLib.sol";
import "../../common/TransferHelper.sol";
import "../../common/ImmutableOwnable.sol";
import { NATIVE_TOKEN } from "../../common/Constants.sol";
import { TT_ZACCOUNT_ACTIVATION, TT_PRP_CLAIM, TT_PRP_CONVERSION, TT_MAIN_TRANSACTION } from "./pantherPool/Types.sol";

/**
 * @title FeeMaster
 * @author Pantherprotocol Contributors
 * @notice This contract governs fee-related activities and reserve management.
 * @dev The FeeMaster contract serves as a hub for managing fees and reserves within the protocol.
 * It incorporates functionalities for handling native tokens, zkp tokens, donations, and fee
 * accounting. FeeMaster is equipped with capabilities such as updating reserves, rebalancing debt,
 * distributing protocol fees, and accounting for various transaction types. It interfaces with
 * UniswapV3Handler, UniswapPoolsList, and FeeAccountant contracts to facilitate interactions
 * with external systems and manage fee-related operations efficiently.
 */
contract FeeMaster is
    ImmutableOwnable,
    UniswapV3Handler,
    UniswapPoolsList,
    FeeAccountant,
    IFeeMaster
{
    using TransferHelper for address;
    using UtilsLib for uint256;
    using UtilsLib for uint40;
    using UtilsLib for uint32;

    // panther VaultV1 contract address
    address public immutable VAULT;

    // the cached ratio between native token and zkp token
    uint256 public cachedNativeRateInZkp;

    // The amount of reserved native token that FeeMaster desires to have
    uint256 public nativeTokenReserveTarget;

    // The native token (Eth, Matic, etc) reserved in Vault, owned by the FeeMaster
    // to be used to update paymaster debt in native
    uint128 public nativeTokenReserve;

    // The zkp token reserved in Vault, owned by the FeeMaster
    // to be used as donation to user to cover fees
    uint128 public zkpTokenDonationReserve;

    // transaction types => donation amount
    mapping(uint16 => uint256) public donations;

    constructor(
        address owner,
        address pantherPool,
        address pantherBusTree,
        address paymaster,
        address zkpToken,
        address wethToken,
        address vault
    )
        ImmutableOwnable(owner)
        UniswapV3Handler(wethToken)
        FeeAccountant(pantherPool, pantherBusTree, paymaster, zkpToken)
    {
        require(vault != address(0), "init: zero address");

        VAULT = vault;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function getNativeRateInZkp(
        uint256 nativeAmount
    ) public view returns (uint256) {
        address pool = getEnabledPoolAddress(NATIVE_TOKEN, ZKP_TOKEN);
        return getQuoteAmount(pool, NATIVE_TOKEN, ZKP_TOKEN, nativeAmount);
    }

    function getZkpRateInNative(
        uint256 zkpAmount
    ) public view returns (uint256) {
        address pool = getEnabledPoolAddress(NATIVE_TOKEN, ZKP_TOKEN);
        return getQuoteAmount(pool, ZKP_TOKEN, NATIVE_TOKEN, zkpAmount);
    }

    /* ========== ONLY FOR OWNER FUNCTIONS ========== */

    function updateFeeParams(
        uint256 perUtxoReward,
        uint256 perKytFee,
        uint256 kycFee,
        uint16 protocolFeePercentage
    ) external onlyOwner {
        _updateFeeParams(
            perUtxoReward,
            perKytFee,
            kycFee,
            protocolFeePercentage
        );
    }

    function updateDonations(
        uint16[] calldata txTypes,
        uint256[] calldata donateAmounts
    ) external onlyOwner {
        require(txTypes.length == donateAmounts.length, "mismatch length");

        for (uint256 i = 0; i < txTypes.length; ) {
            uint16 txType = txTypes[i];
            uint256 donateAmount = donateAmounts[i];

            donations[txType] = donateAmount;

            unchecked {
                ++i;
            }

            emit DonationsUpdated(txType, donateAmount);
        }
    }

    function updateNativeTokenReserveTarget(
        uint256 _nativeTokenReserveTarget
    ) external onlyOwner {
        nativeTokenReserveTarget = _nativeTokenReserveTarget;

        emit NativeTokenReserveTargetUpdated(nativeTokenReserveTarget);
    }

    function increaseZkpTokenDonations(
        uint256 _zkpTokenDonation
    ) external onlyOwner {
        zkpTokenDonationReserve += _zkpTokenDonation.safe128();

        _adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            ZKP_TOKEN,
            int256(_zkpTokenDonation),
            address(this)
        );
        emit ZkpTokenDonationsUpdated(_zkpTokenDonation);
    }

    function increaseNativeTokenReserves() external payable onlyOwner {
        require(msg.value > 0, "invalid amount");

        nativeTokenReserve += msg.value.safe128();
        _adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            NATIVE_TOKEN,
            int256(msg.value),
            address(this)
        );
        emit NativeTokenReserveUpdated(msg.value);
    }

    function updateTwapPeriod(uint256 _twapPeriod) external onlyOwner {
        _updateTwapPeriod(_twapPeriod);
    }

    function addPool(
        address _pool,
        address _tokenA,
        address _tokenB
    ) external onlyOwner {
        _addPool(_pool, _tokenA, _tokenB);
    }

    function updatePool(
        address _pool,
        address _tokenA,
        address _tokenB,
        bool _enabled
    ) external onlyOwner {
        _updatePool(_pool, _tokenA, _tokenB, _enabled);
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function rebalanceDebt(address sellToken) external {
        // getting sell amount: total protocol fee in sell token
        uint256 sellTokenAmount = getDebtForProtocol(sellToken);

        // Receiving sell token from Vault and decreasing the
        // total debt that PantherPool owes to FeeMaster in sellToken
        _adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            sellToken,
            -int256(sellTokenAmount),
            address(this)
        );

        // Updating the speciefic debt that FeeMaster owes to
        // the Provider (i.e protocol) in sellToken
        _updateDebtForProtocol(sellToken, -int256(sellTokenAmount));

        // Converting sellToken for Native
        uint256 receivedNative = _convertTokenToNative(
            sellToken,
            sellTokenAmount
        );
        uint256 nativeBalance = address(this).balance;
        assert(nativeBalance >= receivedNative);

        // 1.6 Calculate the total native reserves
        uint128 _nativeTokenReserve = nativeTokenReserve;
        _nativeTokenReserve += nativeBalance.safe128();

        if (_nativeTokenReserve > nativeTokenReserveTarget) {
            // Getting the excess amount of Native tokens
            uint256 excessNative = uint256(_nativeTokenReserve) -
                nativeTokenReserveTarget;

            // Converting Native for ZKP
            uint256 receivedZkpAmount = _convertNativeToZkp(excessNative);

            // Asking Vault to transfer ZKPs from this contract and
            // increasing the total debt that PantherPool owes to FeeMaster in ZKP
            _adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
                ZKP_TOKEN,
                int256(receivedZkpAmount),
                address(this)
            );

            // Updating the speciefic debt that FeeMaster owes to
            // the Provider (i.e protocol) in ZKP
            _updateDebtForProtocol(ZKP_TOKEN, int256(receivedZkpAmount));

            // set _nativeTokenReserve to be equal to nativeTokenReserveTarget
            _nativeTokenReserve -= excessNative.safe128();
        }

        // Sending Natives to Vault and increasing the
        // total debt that PantherPool owes to FeeMaster in Native
        _adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            NATIVE_TOKEN,
            int256(address(this).balance),
            address(this)
        );

        // Updating the Native reserves
        nativeTokenReserve = _nativeTokenReserve;

        // issue prp to msg sender

        // emit
    }

    // solhint-disable-next-line no-empty-blocks
    function distributeZkpProtocolFees() external {
        // distribute part of them to prp converter
        // distribute part of them to panther fundation
        // issue prp to msg sender
        // emit
    }

    function accountFees(
        FeeData calldata feeData
    )
        external
        checkChargedZkpAmount(feeData)
        checkAvailableDonation(feeData)
        returns (ChargedFeesPerTx memory chargedFeesPerTx)
    {
        _decreaseAvailableDonation(feeData);
        cacheNativeToZkpRate();

        if (feeData.txType == TT_ZACCOUNT_ACTIVATION) {
            return chargedFeesPerTx = _accountActivationFees(feeData);
        }
        if (feeData.txType == TT_PRP_CLAIM) {
            return chargedFeesPerTx = _accountPrpConversionOrClaimFees(feeData);
        }
        if (feeData.txType == TT_PRP_CONVERSION) {
            return chargedFeesPerTx = _accountPrpConversionOrClaimFees(feeData);
        }
    }

    function accountFees(
        FeeData calldata feeData,
        AssetData calldata assetData
    )
        external
        checkChargedZkpAmount(feeData)
        checkAvailableDonation(feeData)
        returns (ChargedFeesPerTx memory chargedFeesPerTx)
    {
        require(feeData.txType == TT_MAIN_TRANSACTION, "only main tx type");
        _decreaseAvailableDonation(feeData);
        cacheNativeToZkpRate();

        chargedFeesPerTx = _accountMainFees(feeData, assetData);
    }

    // ?? having a special function to payoff paymaster and try to
    // convert the remaining paymaster zkp debts if there are any
    function payOff(address receiver) external returns (uint256 debt) {
        debt = debts[msg.sender][NATIVE_TOKEN];
        require(debt > 0, "zero debt");

        _updateDebts(msg.sender, NATIVE_TOKEN, -int256(debt));

        _adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            NATIVE_TOKEN,
            -int256(debt),
            receiver
        );
    }

    function payOff(
        address tokenAddress,
        address receiver
    ) external returns (uint256 debt) {
        debt = debts[msg.sender][tokenAddress];
        require(debt > 0, "zero debt");

        _updateDebts(msg.sender, tokenAddress, -int256(debt));

        _adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            tokenAddress,
            -int256(debt),
            receiver
        );
    }

    function cacheNativeToZkpRate() public {
        cachedNativeRateInZkp = getNativeRateInZkp(1 ether);
    }

    function approveVaultToTransferZkp() external {
        TransferHelper.safeApprove(ZKP_TOKEN, VAULT, type(uint256).max);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
        address token,
        int256 netAmount,
        address extAccount
    ) private {
        uint256 msgValue = token == NATIVE_TOKEN ? msg.value : 0;

        try
            ITransactionChargesHandler(PANTHER_POOL)
                .adjustVaultAssetsAndUpdateTotalFeeMasterDebt{
                value: msgValue
            }(token, netAmount, extAccount)
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    function _decreaseAvailableDonation(FeeData calldata feeData) private {
        if (feeData.scAddedZkpAmount > 0) {
            zkpTokenDonationReserve -= feeData
                .scAddedZkpAmount
                .scaleUpBy1e12()
                .safe128();
        }
    }

    function _convertTokenToNative(
        address _token,
        uint256 _amount
    ) private returns (uint256 receivedNative) {
        // getting pool address
        address pool = getEnabledPoolAddress(NATIVE_TOKEN, _token);

        // Executing the flash swap and receive Natives
        receivedNative = _flashSwap(pool, _token, NATIVE_TOKEN, _amount);
    }

    function _convertNativeToZkp(
        uint256 _amount
    ) private returns (uint256 receivedZkp) {
        // getting pool address
        address pool = getEnabledPoolAddress(NATIVE_TOKEN, ZKP_TOKEN);

        // Executing the flash swap and receive ZKPs
        receivedZkp = _flashSwap(pool, NATIVE_TOKEN, ZKP_TOKEN, _amount);
    }

    function _tryInternalZkpToNativeConversion(
        uint256 paymasterCompensationInZkp
    )
        internal
        override
        returns (uint256 paymasterDebtInZkp, uint256 paymasterDebtInNative)
    {
        uint256 outputNative = getZkpRateInNative(paymasterCompensationInZkp);

        uint256 unconvertedAmount = _utilizeNativeReservesForInternalZkpConversion(
                outputNative
            );

        if (unconvertedAmount > 0) {
            unconvertedAmount = _utilizeProtocolNativeDebtForInternalZkpConversion(
                unconvertedAmount
            );
        }

        if (unconvertedAmount == 0) {
            paymasterDebtInNative = outputNative;
            paymasterDebtInZkp = 0;
        } else {
            paymasterDebtInNative = outputNative - unconvertedAmount;
            paymasterDebtInZkp =
                (paymasterDebtInNative * paymasterCompensationInZkp) /
                outputNative;
        }
    }

    function _utilizeNativeReservesForInternalZkpConversion(
        uint256 convertibleNativeAmount
    ) private returns (uint256 unconvertedAmount) {
        uint256 _nativeTokenReserve = nativeTokenReserve;

        if (_nativeTokenReserve == 0)
            return unconvertedAmount = convertibleNativeAmount;

        if (_nativeTokenReserve >= convertibleNativeAmount) {
            _nativeTokenReserve -= convertibleNativeAmount;

            nativeTokenReserve = _nativeTokenReserve.safe128();

            unconvertedAmount = 0;
        } else {
            unconvertedAmount = convertibleNativeAmount - _nativeTokenReserve;
            nativeTokenReserve = 0;
        }
    }

    function _utilizeProtocolNativeDebtForInternalZkpConversion(
        uint256 convertibleNativeAmount
    ) private returns (uint256 unconvertedAmount) {
        uint256 protocolNativeDebt = getDebtForProtocol(NATIVE_TOKEN);

        if (protocolNativeDebt == 0)
            return unconvertedAmount = convertibleNativeAmount;

        if (protocolNativeDebt >= convertibleNativeAmount) {
            unconvertedAmount = 0;

            _updateDebtForProtocol(
                NATIVE_TOKEN,
                -int256(convertibleNativeAmount)
            );
        } else {
            unconvertedAmount = convertibleNativeAmount - protocolNativeDebt;

            _updateDebtForProtocol(NATIVE_TOKEN, -int256(protocolNativeDebt));
        }
    }

    /* ========== MODIFIERS ========== */

    modifier checkAvailableDonation(FeeData calldata feeData) {
        if (feeData.scAddedZkpAmount > 0) {
            uint256 addedZkpAmount = feeData.scAddedZkpAmount.scaleUpBy1e12();

            require(
                donations[feeData.txType] == addedZkpAmount,
                "invalid donation amount"
            );
            require(
                zkpTokenDonationReserve >= addedZkpAmount,
                "not enough donation reserve"
            );
        }
        _;
    }
    modifier checkChargedZkpAmount(FeeData calldata feeData) {
        require(feeData.scChargedZkpAmount > 0, "zero charged zkp");
        _;
    }
}
