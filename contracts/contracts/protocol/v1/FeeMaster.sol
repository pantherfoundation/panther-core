// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable max-line-length
pragma solidity ^0.8.19;

import "./interfaces/IFeeMaster.sol";

import "./feeMaster/PoolKey.sol";
import "./feeMaster/FeeAccountant.sol";
import "./feeMaster/ProtocolFeeSwapper.sol";
import "./feeMaster/TotalDebtHandler.sol";
import "./feeMaster/ProtocolFeeDistributor.sol";
import { Pool, ChargedFeesPerTx, FeeData, AssetData } from "./feeMaster/Types.sol";

import "./core/utils/Types.sol";

import "./core/libraries/TransactionTypes.sol";
import "../../common/UtilsLib.sol";
import "../../common/TransferHelper.sol";
import "../../common/ImmutableOwnable.sol";
import { GT_ZKP_DISTRIBUTE, GT_FEE_EXCHANGE, DEFAULT_GRANT_TYPE_PRP_REWARDS } from "../../common/Constants.sol";

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
    ProtocolFeeSwapper,
    FeeAccountant,
    ProtocolFeeDistributor,
    IFeeMaster
{
    using TransferHelper for address;
    using TotalDebtHandler for address;
    using TransactionTypes for uint16;
    using UtilsLib for uint256;
    using UtilsLib for uint40;
    using UtilsLib for uint32;

    // panther VaultV1 contract address
    address public immutable VAULT;
    // prpVoucherGrantor contract address
    address public immutable PRP_VOUCHER_GRANTOR;

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

    uint96 public minRewardableZkpAmount;

    // transaction types => donation amount
    mapping(uint16 => uint256) public donations;

    /**
     * @notice Initializes the FeeMaster contract with necessary addresses.
     * @param owner The address of the contract owner.
     * @param providers The Providers struct containing essential provider addresses.
     * @param zkpToken The address of the ZKP token contract.
     * @param wethToken The address of the WETH token contract.
     * @param vault The address of the vault contract.
     * @param treasury The address of the treasury contract.
     */
    constructor(
        address owner,
        Providers memory providers,
        address zkpToken,
        address wethToken,
        address vault,
        address treasury
    )
        ImmutableOwnable(owner)
        UniswapV3Handler(wethToken)
        FeeAccountant(providers, zkpToken)
        ProtocolFeeDistributor(
            treasury,
            providers.pantherTrees,
            providers.pantherPool
        )
    {
        require(vault != address(0), "init: zero address");

        VAULT = vault;
        PRP_VOUCHER_GRANTOR = providers.pantherPool;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function getNativeRateInZkp(
        uint256 nativeAmount
    ) public view returns (uint256) {
        Pool memory pool = getEnabledPoolOrRevert(WETH, ZKP_TOKEN);
        return getTrustedPoolQuoteAmount(pool, WETH, ZKP_TOKEN, nativeAmount);
    }

    function getZkpRateInNative(
        uint256 zkpAmount
    ) public view returns (uint256) {
        Pool memory pool = getEnabledPoolOrRevert(WETH, ZKP_TOKEN);
        return getTrustedPoolQuoteAmount(pool, ZKP_TOKEN, WETH, zkpAmount);
    }

    /* ========== ONLY FOR OWNER AND CONFIGURATION FUNCTIONS ========== */

    function updateFeeParams(
        uint96 perUtxoReward,
        uint96 perKytFee,
        uint96 kycFee,
        uint16 protocolFeePercentage
    ) external onlyOwner {
        FeeParams memory feeParams = _updateFeeParams(
            perUtxoReward,
            perKytFee,
            kycFee,
            protocolFeePercentage
        );

        emit FeeParamsUpdated(feeParams);
    }

    function updateProtocolZkpFeeDistributionParams(
        uint16 _treasuryLockPercentage,
        uint96 _minRewardableZkpAmount
    ) external onlyOwner {
        require(
            _treasuryLockPercentage <= HUNDRED_PERCENT,
            "too high treasury lock percentage"
        );
        require(_minRewardableZkpAmount > 0, "zero min rewardable amount");

        treasuryLockPercentage = _treasuryLockPercentage;
        minRewardableZkpAmount = _minRewardableZkpAmount;

        emit ProtocolZkpFeeDistributionParamsUpdated(
            _treasuryLockPercentage,
            _minRewardableZkpAmount
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

    function increaseNativeTokenReserves() external payable onlyOwner {
        require(msg.value > 0, "invalid amount");

        nativeTokenReserve += msg.value.safe128();
        PANTHER_POOL.adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            NATIVE_TOKEN,
            int256(msg.value),
            address(this)
        );
        emit NativeTokenReserveUpdated(msg.value);
    }

    function increaseZkpTokenDonations(
        uint256 _zkpTokenDonation
    ) external onlyOwner {
        zkpTokenDonationReserve += _zkpTokenDonation.safe128();

        PANTHER_POOL.adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            ZKP_TOKEN,
            int256(_zkpTokenDonation),
            address(this)
        );

        emit ZkpTokenDonationsUpdated(_zkpTokenDonation);
    }

    function updateTwapPeriod(uint32 _twapPeriod) external onlyOwner {
        _updateTwapPeriod(_twapPeriod);

        emit TwapPeriodUpdated(twapPeriod);
    }

    function updatePool(
        address _pool,
        address _token0,
        address _token1,
        bool _enabled
    ) external onlyOwner {
        bytes32 _key = _updatePool(_pool, _token0, _token1, _enabled);

        emit PoolUpdated(_pool, _key, _enabled);
    }

    function approveVaultToTransferZkp() external {
        TransferHelper.safeApprove(ZKP_TOKEN, VAULT, type(uint256).max);
    }

    function cacheNativeToZkpRate() public {
        cachedNativeRateInZkp = getNativeRateInZkp(1 ether);
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function rebalanceDebt(bytes32 secretHash, address sellToken) external {
        // NOTE: This method converts ERC20 tokens to native tokens and/or ZKP.
        // NFTs will remain in the contract. This issue will be addressed later.

        require(
            sellToken != ZKP_TOKEN && sellToken != NATIVE_TOKEN,
            "invalid sell token"
        );

        // getting sell amount: total protocol fee in sell token
        uint256 sellTokenAmount = getDebtForProtocol(sellToken);

        // Updating the speciefic debt that FeeMaster owes to
        // the Provider (i.e protocol) in sellToken
        _updateDebtForProtocol(sellToken, -int256(sellTokenAmount));

        // Receiving sell token from Vault and decreasing the
        // total debt that PantherPool owes to FeeMaster in sellToken
        PANTHER_POOL.adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            sellToken,
            -int256(sellTokenAmount),
            address(this)
        );

        (
            uint256 newNativeTokenReserves,
            uint256 outputWNative,
            uint256 newProtocolFeeInZkp
        ) = _trySwapProtoclFeesToNativeAndZkp(
                ZKP_TOKEN,
                sellToken,
                sellTokenAmount,
                nativeTokenReserve,
                nativeTokenReserveTarget
            );

        nativeTokenReserve = newNativeTokenReserves.safe128();

        // Sending Natives to Vault and increasing the
        // total debt that PantherPool owes to FeeMaster in Native
        PANTHER_POOL.adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            NATIVE_TOKEN,
            int256(address(this).balance),
            address(this)
        );

        if (newProtocolFeeInZkp > 0) {
            // Updating the speciefic debt that FeeMaster owes to
            // the Provider (i.e protocol) in ZKP
            _updateDebtForProtocol(ZKP_TOKEN, int256(newProtocolFeeInZkp));

            // Asking Vault to transfer ZKPs from this contract and
            // increasing the total debt that PantherPool owes to FeeMaster in ZKP
            PANTHER_POOL.adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
                ZKP_TOKEN,
                int256(newProtocolFeeInZkp),
                address(this)
            );
        }

        uint256 minRewardableNativeAmount = minRewardableZkpAmount /
            cachedNativeRateInZkp;

        if (outputWNative >= minRewardableNativeAmount)
            _grantPrpRewardsToUser(secretHash, GT_FEE_EXCHANGE);
    }

    function distributeProtocolZkpFees(bytes32 secretHash) external {
        uint256 zkpAmount = getDebtForProtocol(ZKP_TOKEN);

        // Receiving sell token from Vault and decreasing the
        // total debt that PantherPool owes to FeeMaster in sellToken
        PANTHER_POOL.adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            ZKP_TOKEN,
            -int256(zkpAmount),
            address(this)
        );

        _distributeProtocolZkpFees(ZKP_TOKEN, zkpAmount);

        if (zkpAmount > minRewardableZkpAmount) {
            _grantPrpRewardsToUser(secretHash, GT_ZKP_DISTRIBUTE);
        }

        _updateDebtForProtocol(ZKP_TOKEN, -int256(zkpAmount));

        emit ZkpsDistributed(zkpAmount);
    }

    function accountFees(
        FeeData calldata feeData
    )
        external
        onlyPantherPool
        checkChargedZkpAmount(feeData)
        checkAvailableDonation(feeData)
        returns (ChargedFeesPerTx memory chargedFeesPerTx)
    {
        _decreaseAvailableDonation(feeData);
        cacheNativeToZkpRate();

        if (feeData.txType.isActivationOrReactivationOrRenewal()) {
            return chargedFeesPerTx = _accountActivationFees(feeData);
        }
        if (feeData.txType == TT_PRP_ACCOUNTING) {
            return chargedFeesPerTx = _accountPrpConversionOrClaimFees(feeData);
        }
        if (feeData.txType == TT_PRP_CONVERSION) {
            return chargedFeesPerTx = _accountPrpConversionOrClaimFees(feeData);
        }
        if (feeData.txType == TT_ZSWAP) {
            return chargedFeesPerTx = _accountZSwap(feeData);
        }
    }

    function accountFees(
        FeeData calldata feeData,
        AssetData calldata assetData
    )
        external
        onlyPantherPool
        checkChargedZkpAmount(feeData)
        checkAvailableDonation(feeData)
        returns (ChargedFeesPerTx memory chargedFeesPerTx)
    {
        _decreaseAvailableDonation(feeData);
        cacheNativeToZkpRate();

        if (feeData.txType.isMain()) {
            return chargedFeesPerTx = _accountMainFees(feeData, assetData);
        }
    }

    function payOff(address receiver) external returns (uint256 debt) {
        debt = debts[msg.sender][NATIVE_TOKEN];
        require(debt > 0, "zero debt");

        _updateDebts(msg.sender, NATIVE_TOKEN, -int256(debt));

        PANTHER_POOL.adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            NATIVE_TOKEN,
            -int256(debt),
            receiver
        );

        emit PayOff(receiver, NATIVE_TOKEN, debt);
    }

    function payOff(
        address tokenAddress,
        address receiver,
        uint256 amount
    ) external returns (uint256 debt) {
        debt = debts[msg.sender][tokenAddress];
        require(amount > 0, "zero amount");
        require(debt >= amount, "zero debt");

        _updateDebts(msg.sender, tokenAddress, -int256(amount));

        PANTHER_POOL.adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
            tokenAddress,
            -int256(amount),
            receiver
        );

        emit PayOff(receiver, tokenAddress, debt);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _decreaseAvailableDonation(FeeData calldata feeData) private {
        if (feeData.scAddedZkpAmount > 0) {
            zkpTokenDonationReserve -= feeData
                .scAddedZkpAmount
                .scaleUpBy1e12()
                .safe128();
        }
    }

    /**
     * @notice Attempts to convert a specified amount of ZKP tokens into native tokens to compensate the paymaster.
     *         This function utilizes the contract's native token reserves and protocol debts to fulfill the compensation.
     * @dev This internal function performs the following steps:
     *      1. **Calculate Equivalent Native Tokens:**
     *         Determines the amount of native tokens (`outputNative`) equivalent to the provided ZKP tokens (`paymasterCompensationInZkp`)
     *         using the current cached TWAP obtained from `getZkpRateInNative`.
     *
     *      2. **Utilize Native Reserves:**
     *         Attempts to fulfill the `outputNative` requirement by utilizing the contract's native token reserves via
     *         `_utilizeNativeReservesForInternalZkpConversion`. If reserves are sufficient, the required amount is deducted from the reserves.
     *
     *      3. **Utilize Protocol Debts:**
     *         If native reserves are insufficient (`unconvertedNativeAmount > 0`), the function attempts to cover the remaining
     *         native token requirement by reducing the protocol's existing native token debts through
     *         `_utilizeProtocolNativeDebtForInternalZkpConversion`.
     *
     *      4. **Debt Accounting:**
     *         - **Full Conversion:** If the entire `outputNative` is covered by reserves and debts (`unconvertedNativeAmount == 0`),
     *           the paymaster's debt is fully accounted in native tokens (`paymasterDebtInNative = outputNative`), and no debt remains in ZKP tokens.
     *
     *         - **Partial Conversion:** If there's a portion of `outputNative` that couldn't be covered (`unconvertedNativeAmount > 0`),
     *           the function accounts for the covered portion in native tokens and the remaining debt in ZKP tokens. Specifically:
     *           - `paymasterDebtInNative = outputNative - unconvertedNativeAmount`
     *           - `paymasterDebtInZkp = (unconvertedNativeAmount * paymasterCompensationInZkp) / outputNative`
     *
     *      5. **Event Emission:**
     *         Emits a `PaymasterCompensationAccounted` event with the updated debts in ZKP and native tokens.
     *
     * @param paymasterCompensationInZkp The amount of ZKP tokens intended to compensate the paymaster.
     * @return paymasterDebtInZkp The portion of the compensation that remains as debt in ZKP tokens after attempting the conversion.
     * @return paymasterDebtInNative The portion of the compensation successfully converted to native tokens.
     */
    function _tryInternalZkpToNativeConversion(
        uint256 paymasterCompensationInZkp
    )
        internal
        override
        returns (uint256 paymasterDebtInZkp, uint256 paymasterDebtInNative)
    {
        uint256 outputNative = getZkpRateInNative(paymasterCompensationInZkp);

        uint256 unconvertedNativeAmount = _utilizeNativeReservesForInternalZkpConversion(
                outputNative
            );

        if (unconvertedNativeAmount > 0) {
            unconvertedNativeAmount = _utilizeProtocolNativeDebtForInternalZkpConversion(
                unconvertedNativeAmount
            );
        }

        if (unconvertedNativeAmount == 0) {
            paymasterDebtInNative = outputNative;
            paymasterDebtInZkp = 0;
        } else {
            paymasterDebtInNative = outputNative - unconvertedNativeAmount;
            paymasterDebtInZkp =
                (unconvertedNativeAmount * paymasterCompensationInZkp) /
                outputNative;
        }

        emit PaymasterCompensationConverted(
            paymasterDebtInZkp,
            paymasterDebtInNative
        );
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

    function _grantPrpRewardsToUser(
        bytes32 secretHash,
        bytes4 grantType
    ) private {
        try
            IPrpVoucherController(PRP_VOUCHER_GRANTOR).generateRewards(
                secretHash,
                DEFAULT_GRANT_TYPE_PRP_REWARDS,
                grantType
            )
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    /* ========== MODIFIERS ========== */

    /**
     * @dev Checks if the donation amount is available and correctly configured for the transaction type.
     * @param feeData The FeeData struct containing fee-related information.
     * @notice Ensures that if a donation is included, it matches the configured amount and the reserve is sufficient.
     */
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

    /**
     * @dev Ensures that the charged ZKP amount is greater than zero.
     * @param feeData The FeeData struct containing fee-related information.
     * @notice Prevents processing transactions with zero charged ZKP amounts.
     */
    modifier checkChargedZkpAmount(FeeData calldata feeData) {
        require(feeData.scChargedZkpAmount > 0, "zero charged zkp");
        _;
    }

    modifier onlyPantherPool() {
        require(msg.sender == PANTHER_POOL, "only panther pool");
        _;
    }
}
