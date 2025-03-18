// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolPlayHook} from "./PoolPlayHook.sol";
import {LotteryPool} from "./LotteryPool.sol";

contract LotteryPoolFactory {
    using Clones for address;
    using CurrencyLibrary for Currency;

    struct PoolConfig {
        uint24 defaultFeeBps;
        uint48 defaultInterval;
    }

    address public immutable hookMaster;
    address public immutable lotteryMaster;
    PoolConfig public config;

    event PoolCreated(
        address indexed hook,
        address indexed lotteryPool,
        PoolKey key
    );

    constructor(IPoolManager manager, address _lotteryMaster) {
        hookMaster = address(new PoolPlayHook(manager, address(this)));
        lotteryMaster = _lotteryMaster;
        config = PoolConfig(50, 1 days); // 0.5% fee, 1-day interval per mentor feedback
    }

    function createPool(
        PoolKey calldata key,
        uint24 customFeeBps,
        uint48 customInterval
    ) external returns (address) {
        uint24 fee = customFeeBps > 0 ? customFeeBps : config.defaultFeeBps;
        uint48 interval = customInterval > 0
            ? customInterval
            : config.defaultInterval;

        address hook = hookMaster.clone();
        address lottery = lotteryMaster.clone();

        LotteryPool(lottery).initialize(
            address(hook),
            interval,
            Currency.unwrap(key.currency0)
        );
        PoolPlayHook(hook).initializePool(key.toId(), fee, interval, lottery);

        emit PoolCreated(hook, lottery, key);
        return hook;
    }
}
