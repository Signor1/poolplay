// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LotteryPool} from "./LotteryPool.sol";

contract PoolPlayHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    struct PoolConfig {
        address lotteryPool;
        uint48 lastDistribution;
        uint48 distributionInterval;
        uint24 lotteryFeeBps;
    }

    mapping(PoolId => PoolConfig) public poolConfigs;
    mapping(PoolId => PoolKey) public poolKeys; // Track PoolKey for TVL calculation

    address public immutable factory;

    constructor(IPoolManager manager, address _factory) BaseHook(manager) {
        factory = _factory;
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true, // Enabled for TVL tracking
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: true,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // Store PoolKey when pool is initialized
    function _beforeInitialize(
        address,
        PoolKey calldata key,
        uint160
    ) internal override returns (bytes4) {
        PoolId poolId = key.toId();
        poolKeys[poolId] = key;
        return this.beforeInitialize.selector;
    }

    function _beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        PoolConfig memory config = poolConfigs[poolId];

        if (config.lotteryPool == address(0)) {
            return (
                BaseHook.beforeSwap.selector,
                BalanceDeltaLibrary.ZERO_DELTA
            );
        }

        int256 feeAmount = (params.amountSpecified *
            int256(uint256(config.lotteryFeeBps))) / 10_000;
        int256 newAmount = params.amountSpecified - feeAmount;

        Currency feeCurrency = params.zeroForOne
            ? key.currency0
            : key.currency1;

        manager.take(
            feeCurrency,
            msg.sender,
            uint256(feeAmount),
            config.lotteryPool
        );

        return (BaseHook.beforeSwap.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    // Implement TVL calculation
    function getPoolTVL(PoolId poolId) external view returns (uint256) {
        PoolKey memory key = poolKeys[poolId];
        require(address(key.currency0) != address(0), "Pool not initialized");

        uint256 balance0 = manager.getCurrencyBalance(key.currency0);
        uint256 balance1 = manager.getCurrencyBalance(key.currency1);

        // simple sum of balances
        // But need to be adjusted with price oracle if needed
        return balance0 + balance1;
    }

    // Rest of the contract remains the same...
    function _afterAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        _updateLiquidity(key.toId());
        return (
            BaseHook.afterAddLiquidity.selector,
            BalanceDeltaLibrary.ZERO_DELTA
        );
    }

    function _afterRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        _updateLiquidity(key.toId());
        return (
            BaseHook.afterRemoveLiquidity.selector,
            BalanceDeltaLibrary.ZERO_DELTA
        );
    }

    function _updateLiquidity(PoolId poolId) internal {
        PoolConfig storage config = poolConfigs[poolId];
        if (config.lotteryPool != address(0)) {
            LotteryPool(config.lotteryPool).updateLiquidity();
        }
    }
}
