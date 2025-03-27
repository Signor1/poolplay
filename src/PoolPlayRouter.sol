// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {CurrencySettler} from "@v4-core/test/utils/CurrencySettler.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PoolPlayRouter is Ownable {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using TransientStateLibrary for IPoolManager;

    IPoolManager public immutable manager;
    address public immutable hook;

    struct CallbackData {
        address swapper;
        address recipientAddress;
        PoolKey key;
        IPoolManager.SwapParams swapParams;
        bytes hookData;
        uint256 lotteryFee; // Fee amount for lottery entry
        Currency feeCurrency; // Currency of the lottery fee
    }

    error CallerNotManager();
    error InsufficientFee();

    constructor(address _manager, address _hook) Ownable(msg.sender) {
        manager = IPoolManager(_manager);
        hook = _hook;
    }

    function swap(
        PoolKey memory key,
        IPoolManager.SwapParams memory swapParams,
        address recipientAddress,
        uint24 lotteryFeeBps // Provided by hook or frontend
    ) external payable returns (BalanceDelta) {
        uint256 inputAmount = swapParams.amountSpecified < 0 ? uint256(-swapParams.amountSpecified) : 0;
        uint256 lotteryFee = (inputAmount * lotteryFeeBps) / 10_000;

        Currency feeCurrency = swapParams.zeroForOne ? key.currency0 : key.currency1;

        // Deduct fee from swap amount
        swapParams.amountSpecified = -int256(inputAmount - lotteryFee);

        // Collect only the inputAmount (swap + fee)
        if (feeCurrency.isAddressZero()) {
            require(msg.value >= inputAmount, "Insufficient ETH");
            (bool success,) = hook.call{value: lotteryFee}("");
            require(success, "ETH fee transfer to hook failed");
        } else {
            require(
                IERC20(Currency.unwrap(feeCurrency)).transferFrom(msg.sender, address(this), inputAmount),
                "Token transfer failed"
            );
            IERC20(Currency.unwrap(feeCurrency)).transfer(hook, lotteryFee);
        }

        // Pass fee info in hookData
        bytes memory hookData = abi.encode(msg.sender, lotteryFee, feeCurrency);
        BalanceDelta delta = abi.decode(
            manager.unlock(
                abi.encode(
                    CallbackData(msg.sender, recipientAddress, key, swapParams, hookData, lotteryFee, feeCurrency)
                )
            ),
            (BalanceDelta)
        );

        // Refund excess ETH if any
        if (address(this).balance > 0 && feeCurrency.isAddressZero()) {
            CurrencyLibrary.ADDRESS_ZERO.transfer(msg.sender, address(this).balance);
        }
        return delta;
    }

    function unlockCallback(bytes calldata _rawdata) external returns (bytes memory) {
        if (msg.sender != address(manager)) revert CallerNotManager();
        CallbackData memory data = abi.decode(_rawdata, (CallbackData));

        BalanceDelta delta = manager.swap(data.key, data.swapParams, data.hookData);

        int256 deltaAfter0 = manager.currencyDelta(address(this), data.key.currency0);
        int256 deltaAfter1 = manager.currencyDelta(address(this), data.key.currency1);

        if (deltaAfter0 < 0) {
            data.key.currency0.settle(manager, data.swapper, uint256(-deltaAfter0), false);
        }
        if (deltaAfter1 < 0) {
            data.key.currency1.settle(manager, data.swapper, uint256(-deltaAfter1), false);
        }
        if (deltaAfter0 > 0) {
            data.key.currency0.take(manager, data.recipientAddress, uint256(deltaAfter0), false);
        }
        if (deltaAfter1 > 0) {
            data.key.currency1.take(manager, data.recipientAddress, uint256(deltaAfter1), false);
        }

        return abi.encode(delta);
    }

    receive() external payable {}
}
