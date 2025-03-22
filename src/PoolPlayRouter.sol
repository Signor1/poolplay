// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {CurrencySettler} from "@v4-core/test/utils/CurrencySettler.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";

contract PoolPlayRouter is Ownable {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using TransientStateLibrary for IPoolManager;

    IPoolManager public immutable manager;
    address public immutable hook;

    struct CallbackData {
        address sender;
        address recipientAddress;
        PoolKey key;
        IPoolManager.SwapParams swapParams;
        bytes hookData;
    }

    error CallerNotManager();
    error CallerNotHook();

    constructor(address _manager, address _hook) Ownable(msg.sender) {
        manager = IPoolManager(_manager);
        hook = _hook;
    }

    /**
     * @notice Swap against the given pool
     * @param key The pool to swap in
     * @param sender The address of the sender
     * @param swapParams The parameters for swapping
     * @param recipientAddress The address of the recipient
     * @param hookData The data to pass through to the swap hooks
     */
    function swap(
        PoolKey memory key,
        address sender,
        IPoolManager.SwapParams memory swapParams,
        address recipientAddress,
        bytes memory hookData
    ) external payable returns (BalanceDelta delta) {
        if (msg.sender != hook) revert CallerNotHook();

        delta = abi.decode(
            manager.unlock(
                CallbackData(
                    sender,
                    recipientAddress,
                    key,
                    swapParams,
                    hookData
                )
            ),
            (BalanceDelta)
        );

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0)
            CurrencyLibrary.NATIVE.transfer(msg.sender, ethBalance);
    }

    /**
     * @notice Unlock callback
     * @param _rawdata The raw data to unlock
     * @return The data to return to the manager
     */
    function unlockCallback(
        bytes calldata _rawdata
    ) external returns (bytes memory) {
        if (msg.sender != address(manager)) revert CallerNotManager();

        CallbackData memory data = abi.decode(_rawdata, (CallbackData));

        BalanceDelta delta = manager.swap(
            data.key,
            data.swapParams,
            data.hookData
        );

        int256 deltaAfter0 = manager.currencyDelta(
            address(this),
            data.key.currency0
        );
        int256 deltaAfter1 = manager.currencyDelta(
            address(this),
            data.key.currency1
        );

        if (deltaAfter0 < 0) {
            data.key.currency0.settle(
                manager,
                data.sender,
                uint256(-deltaAfter0),
                false
            );
        }

        if (deltaAfter1 < 0) {
            data.key.currency1.settle(
                manager,
                data.sender,
                uint256(-deltaAfter1),
                false
            );
        }

        return abi.encode(delta);
    }
}
