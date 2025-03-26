// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ILotteryPool {
    function depositFee(
        uint256 lotteryId,
        uint256 amount,
        address swapper
    ) external payable;
}
