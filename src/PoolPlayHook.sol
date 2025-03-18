// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LotteryPool} from "./LotteryPool.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}

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
    mapping(PoolId => PoolKey) public poolKeys;
    mapping(address => address) public tokenToUsdFeed;

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
                beforeInitialize: true,
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
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId poolId = key.toId();
        PoolConfig memory config = poolConfigs[poolId];

        if (config.lotteryPool == address(0)) {
            return (
                this.beforeSwap.selector,
                BeforeSwapDeltaLibrary.ZERO_DELTA,
                0
            );
        }

        int256 amount = params.amountSpecified < 0
            ? -params.amountSpecified
            : params.amountSpecified;
        uint256 feeAmount = (uint256(amount) * config.lotteryFeeBps) / 10_000;

        Currency feeCurrency = params.zeroForOne
            ? key.currency0
            : key.currency1;
        IERC20(Currency.unwrap(feeCurrency)).transferFrom(
            msg.sender,
            config.lotteryPool,
            feeAmount
        );
        LotteryPool(config.lotteryPool).depositFee(feeAmount);

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function setTokenFeed(address token, address usdFeed) external {
        tokenToUsdFeed[token] = usdFeed;
    }

    function getTokenValue(
        address tokenAddress,
        uint256 balance
    ) internal view returns (uint256) {
        uint8 tokenDecimals = IERC20Metadata(tokenAddress).decimals();
        address feedAddress = tokenToUsdFeed[tokenAddress];
        require(feedAddress != address(0), "No price feed for token");
        AggregatorV3Interface feed = AggregatorV3Interface(feedAddress);
        (, int256 price, , , ) = feed.latestRoundData();
        require(price > 0, "Price not available");
        uint8 priceFeedDecimals = feed.decimals(); // Typically 8 for USD feeds
        uint256 value_usd = (balance * uint256(price)) /
            (10 ** (tokenDecimals + priceFeedDecimals));
        return value_usd;
    }

    function getPoolTVL(PoolId poolId) external view returns (uint256) {
        PoolKey memory key = poolKeys[poolId];
        require(
            Currency.unwrap(key.currency0) != address(0),
            "Pool not initialized"
        );

        address currencyAddress0 = Currency.unwrap(key.currency0);
        address currencyAddress1 = Currency.unwrap(key.currency1);

        uint256 balanceCurrency0 = key.currency0.balanceOf(
            address(poolManager)
        );
        uint256 balanceCurrency1 = key.currency1.balanceOf(
            address(poolManager)
        );

        uint256 valueCurrency0 = getTokenValue(
            currencyAddress0,
            balanceCurrency0
        );
        uint256 valueCurrency1 = getTokenValue(
            currencyAddress1,
            balanceCurrency1
        );

        return valueCurrency0 + valueCurrency1;
    }

    function initializePool(
        PoolId poolId,
        uint24 lotteryFeeBps,
        uint48 distributionInterval,
        address lotteryPool
    ) external {
        require(msg.sender == factory, "Only factory can initialize");
        require(
            poolConfigs[poolId].lotteryPool == address(0),
            "Already initialized"
        );
        poolConfigs[poolId] = PoolConfig({
            lotteryPool: lotteryPool,
            lastDistribution: uint48(block.timestamp),
            distributionInterval: distributionInterval,
            lotteryFeeBps: lotteryFeeBps
        });
    }

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
            this.afterAddLiquidity.selector,
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
            this.afterRemoveLiquidity.selector,
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
