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
}
