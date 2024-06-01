// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.16;

import "../../../common/NonReentrant.sol";
import "../../../common/Claimable.sol";
import "../../../common/ImmutableOwnable.sol";
import "../../../common/interfaces/IFeeMaster.sol";
import { NATIVE_TOKEN } from "../../../common/Constants.sol";

contract MockFeeMaster is
    IFeeMaster,
    ImmutableOwnable,
    NonReentrant,
    Claimable
{
    // provider => token => amounts
    mapping(address => mapping(address => uint256)) public debts;

    address public immutable UNISWAPV3_PAIR_ADDR;

    uint32 public twapInterval;

    uint256 public minimumToRefund;

    mapping(address => bool) public claimants;

    constructor(
        address _uniswapV3Pool,
        address _owner
    ) ImmutableOwnable(_owner) {
        UNISWAPV3_PAIR_ADDR = _uniswapV3Pool;
    }

    function getPriceQ96() public view returns (uint256 priceQ96) {
        return 333333333333333333333333333333;
    }

    function cachedNativeRateInZkp() public view returns (uint256 priceQ96) {
        return 48178181756247775294;
    }

    function updateClaimant(
        address _unlocker,
        bool _status
    ) external onlyOwner {
        claimants[_unlocker] = _status;
    }

    function setTwapInterval(uint32 interval) public onlyOwner {
        twapInterval = interval;
    }

    modifier onlyClaimant() {
        require(claimants[msg.sender], "ERR_UNAUTHORIZED");
        _;
    }

    function getQuoteAmount(
        address baseToken,
        address quoteToken,
        uint256 baseAmount
    ) public returns (uint256 quoteAmount) {
        (baseAmount);
        quoteAmount = baseToken < quoteToken
            ? 1 // MATIC Amount
            : 1000; // ZKP Amount
    }

    function getNativeRateInZkp(
        uint256 inAmount
    ) public returns (uint256 outAmount) {
        (inAmount);
        return 1000;
    }

    function payOff(address receiver) external {
        uint256 balance = address(this).balance;
        require(balance > minimumToRefund, "not enough balance");
        debts[NATIVE_TOKEN][NATIVE_TOKEN] -= balance;
        _claimEthOrErc20(address(0), receiver, balance);
    }

    function getPaymasterDebt() public returns (uint256) {
        require(address(this).balance > minimumToRefund, "not enough balance");
        return address(this).balance;
    }

    receive() external payable {
        require(msg.value > 0, "No Ether sent");
        debts[NATIVE_TOKEN][NATIVE_TOKEN] += msg.value;
    }

    fallback() external payable {}
}
