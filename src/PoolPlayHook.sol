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
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {PoolPlayLib} from "./library/PoolPlayLib.sol";
import {AggregatorV3Interface} from
    "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ILotteryPool} from "./interfaces/ILotteryPool.sol";
import {IERC20Metadata} from "./interfaces/IERC20.sol";

contract PoolPlayHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;
    using PoolPlayLib for uint256;
    using StateLibrary for IPoolManager;

    struct PoolConfig {
        uint48 lastDistribution;
        uint48 distributionInterval;
        uint24 lotteryFeeBps;
        uint256 lotteryId;
        uint256 totalVolume;
        uint256 totalFees;
        uint48 volumeTimestamp;
    }

    mapping(PoolId => PoolConfig) public poolConfigs;
    mapping(PoolId => PoolKey) public poolKeys;
    mapping(address => address) public tokenToUsdFeed;

    address public immutable allowedRouter;
    address public immutable lotteryPool;

    event PoolInitialized(PoolId indexed poolId, uint256 lotteryId, uint24 lotteryFeeBps, uint48 distributionInterval);
    event LotteryEntered(PoolId indexed poolId, address indexed swapper, uint256 feeAmount, address feeCurrency);
    event FeeTransferred(PoolId indexed poolId, uint256 lotteryId, uint256 amount, address feeCurrency);

    constructor(IPoolManager manager, address _allowedRouter, address _lotteryPool) BaseHook(manager) {
        allowedRouter = _allowedRouter;
        lotteryPool = _lotteryPool;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false, // No delta adjustment
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeInitialize(address, PoolKey calldata key, uint160) internal override returns (bytes4) {
        poolKeys[key.toId()] = key;
        return this.beforeInitialize.selector;
    }

    function initializePool(PoolId poolId, uint24 lotteryFeeBps, uint48 distributionInterval, uint256 lotteryId)
        external
    {
        require(poolConfigs[poolId].lotteryFeeBps == 0, "Pool already initialized");
        require(lotteryFeeBps > 0 && lotteryFeeBps <= 1000, "Invalid fee: 0 < feeBps <= 10%");
        require(distributionInterval > 0, "Invalid interval");

        poolConfigs[poolId] = PoolConfig({
            lastDistribution: uint48(block.timestamp),
            distributionInterval: distributionInterval,
            lotteryFeeBps: lotteryFeeBps,
            lotteryId: lotteryId,
            totalVolume: 0,
            totalFees: 0,
            volumeTimestamp: uint48(block.timestamp)
        });

        emit PoolInitialized(poolId, lotteryId, lotteryFeeBps, distributionInterval);
    }

    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) internal view override returns (bytes4, BeforeSwapDelta, uint24) {
        if (sender != allowedRouter || hookData.length == 0) {
            return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        PoolId poolId = key.toId();
        PoolConfig memory config = poolConfigs[poolId];
        if (config.lotteryFeeBps == 0) {
            return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        // Validate input amount
        uint256 inputAmount = params.amountSpecified < 0 ? uint256(-params.amountSpecified) : 0;
        require(inputAmount > 0, "Invalid swap amount");

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function _afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        if (!_isValidSenderAndData(sender, hookData)) {
            return (this.afterSwap.selector, 0);
        }

        PoolId poolId = key.toId();
        PoolConfig storage config = poolConfigs[poolId];
        if (config.lotteryFeeBps == 0) {
            return (this.afterSwap.selector, 0);
        }

        address swapper = _decodeSwapper(hookData);
        if (swapper == address(0)) {
            return (this.afterSwap.selector, 0);
        }

        (uint256 feeAmount, Currency feeCurrency) = _calculateFee(params, delta, config.lotteryFeeBps, key);
        _transferFee(feeCurrency, feeAmount);

        ILotteryPool(lotteryPool).depositFee(config.lotteryId, feeAmount, swapper);
        _emitEvents(poolId, config.lotteryId, feeAmount, feeCurrency);

        // _updatePoolMetrics(poolId, inputAmount, feeAmount); // Uncomment if needed
        return (this.afterSwap.selector, 0);
    }

    // Helper: Validate sender and hook data
    function _isValidSenderAndData(address sender, bytes calldata hookData) private view returns (bool) {
        return sender == allowedRouter && hookData.length > 0;
    }

    // Helper: Decode swapper from hook data
    function _decodeSwapper(bytes calldata hookData) private pure returns (address) {
        return abi.decode(hookData, (address));
    }

    // Helper: Calculate fee amount and currency
    function _calculateFee(
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        uint24 lotteryFeeBps,
        PoolKey calldata key
    ) private pure returns (uint256 feeAmount, Currency feeCurrency) {
        uint256 inputAmount = params.zeroForOne ? uint256(int256(-delta.amount0())) : uint256(int256(-delta.amount1()));
        feeAmount = _calculateFeeAmount(inputAmount, lotteryFeeBps);
        feeCurrency = params.zeroForOne ? key.currency0 : key.currency1;
    }

    // Helper: Calculate fee from input amount
    function _calculateFeeAmount(uint256 amount, uint24 feeBps) private pure returns (uint256) {
        return (amount * feeBps) / 10_000; // Assuming BPS (basis points), 10000 = 100%
    }

    // Helper: Transfer fee to LotteryPool
    function _transferFee(Currency feeCurrency, uint256 feeAmount) private {
        if (feeCurrency.isAddressZero()) {
            require(address(allowedRouter).balance >= feeAmount, "Router lacks ETH");
            (bool success,) = allowedRouter.call{value: 0}(
                abi.encodeWithSignature("transferFee(address,uint256)", lotteryPool, feeAmount)
            );
            require(success, "ETH fee transfer failed");
        } else {
            IERC20 token = IERC20(Currency.unwrap(feeCurrency));
            require(token.allowance(allowedRouter, address(this)) >= feeAmount, "Insufficient allowance");
            require(token.transferFrom(allowedRouter, lotteryPool, feeAmount), "Token transfer failed");
        }
    }

    // Helper: Emit events
    function _emitEvents(PoolId poolId, uint256 lotteryId, uint256 feeAmount, Currency feeCurrency) private {
        emit LotteryEntered(poolId, msg.sender, feeAmount, Currency.unwrap(feeCurrency));
        emit FeeTransferred(poolId, lotteryId, feeAmount, Currency.unwrap(feeCurrency));
    }

    /**
     * @notice Sets the Chainlink price feed for a token.
     * @param token The token address.
     * @param usdFeed The Chainlink price feed address (e.g., ETH/USD).
     */
    function setTokenFeed(address token, address usdFeed) external {
        // Add access control (e.g., onlyOwner) as needed
        tokenToUsdFeed[token] = usdFeed;
    }

    /**
     * @notice Gets the USD value of a token balance using Chainlink price feed.
     * @param tokenAddress The token address.
     * @param balance The token balance (in token decimals).
     * @return value The USD value with 18 decimals.
     */
    function getTokenValue(address tokenAddress, uint256 balance) internal view returns (uint256) {
        if (balance == 0) return 0;
        address feedAddress = tokenToUsdFeed[tokenAddress];
        require(feedAddress != address(0), "No price feed for token");

        AggregatorV3Interface feed = AggregatorV3Interface(feedAddress);
        (, int256 price,,,) = feed.latestRoundData();
        require(price > 0, "Invalid price from Chainlink");

        uint8 tokenDecimals = IERC20Metadata(tokenAddress).decimals();
        uint8 feedDecimals = feed.decimals(); // Typically 8 for USD feeds

        // Normalize to 18 decimals for consistency
        uint256 value = (balance * uint256(price) * 1e18) / (10 ** (tokenDecimals + feedDecimals));
        return value;
    }

    /**
     * @notice Updates pool volume and fee metrics for 24h tracking.
     * @param poolId The pool ID.
     * @param volume The swap volume (in token0 terms).
     * @param fee The lottery fee collected (in token0 terms).
     */
    function _updatePoolMetrics(PoolId poolId, uint256 volume, uint256 fee) internal {
        PoolConfig storage config = poolConfigs[poolId];
        if (block.timestamp >= config.volumeTimestamp + 24 hours) {
            config.totalVolume = volume;
            config.totalFees = fee;
            config.volumeTimestamp = uint48(block.timestamp);
        } else {
            config.totalVolume += volume;
            config.totalFees += fee;
        }
    }

    /**
     * @notice Gets the Total Value Locked (TVL) for a pool in USD (18 decimals).
     * @param poolId The pool ID.
     * @return tvl The total value locked in USD.
     */
    function getPoolTVL(PoolId poolId) external view returns (uint256) {
        PoolKey memory key = poolKeys[poolId];
        require(Currency.unwrap(key.currency0) != address(0), "Pool not initialized");

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        uint128 liquidity = poolManager.getLiquidity(poolId);

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        // Calculate token amounts from liquidity and sqrtPrice
        uint256 amount0 = (uint256(liquidity) * 1e18) / ((sqrtPriceX96 * sqrtPriceX96) / 2 ** 96);
        uint256 amount1 = (uint256(liquidity) * sqrtPriceX96 * sqrtPriceX96) / (2 ** 96 * 1e18);

        uint256 value0 = getTokenValue(token0, amount0);
        uint256 value1 = getTokenValue(token1, amount1);

        return value0 + value1; // Total TVL in USD (18 decimals)
    }

    /**
     * @notice Gets the 24-hour trading volume for a pool in USD (18 decimals).
     * @param poolId The pool ID.
     * @return volume The total volume in the last 24 hours.
     */
    function getPoolVolume24h(PoolId poolId) external view returns (uint256) {
        PoolConfig memory config = poolConfigs[poolId];
        if (block.timestamp >= config.volumeTimestamp + 24 hours) {
            return 0;
        }
        PoolKey memory key = poolKeys[poolId];
        address token0 = Currency.unwrap(key.currency0);
        // Convert stored volume (in token0 terms) to USD
        return getTokenValue(token0, config.totalVolume);
    }

    /**
     * @notice Gets the 24-hour fees collected for a pool in USD (18 decimals).
     * @param poolId The pool ID.
     * @return fees The total fees in the last 24 hours.
     */
    function getPoolFees24h(PoolId poolId) external view returns (uint256) {
        PoolConfig memory config = poolConfigs[poolId];
        if (block.timestamp >= config.volumeTimestamp + 24 hours) {
            return 0;
        }
        PoolKey memory key = poolKeys[poolId];
        address token0 = Currency.unwrap(key.currency0);
        // Convert stored fees (in token0 terms) to USD
        return getTokenValue(token0, config.totalFees);
    }

    /**
     * @notice Gets the value of a user’s position in a pool in USD (18 decimals).
     * @param poolId The pool ID.
     * @param user The user’s address.
     * @return value The position value.
     */
    function getPositionValue(PoolId poolId, address user) external view returns (uint256) {
        PoolKey memory key = poolKeys[poolId];
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        bytes32 positionId = keccak256(abi.encodePacked(user, poolId, int24(0), int24(0))); // Simplified position ID
        (uint128 liquidity,,) = poolManager.getPositionInfo(poolId, user, 0, 0, positionId);

        if (liquidity == 0) return 0;

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        uint256 amount0 = (uint256(liquidity) * 1e18) / ((sqrtPriceX96 * sqrtPriceX96) / 2 ** 96);
        uint256 amount1 = (uint256(liquidity) * sqrtPriceX96 * sqrtPriceX96) / (2 ** 96 * 1e18);

        uint256 value0 = getTokenValue(token0, amount0);
        uint256 value1 = getTokenValue(token1, amount1);

        return value0 + value1; // Position value in USD (18 decimals)
    }

    // Receives ETH for fee deposits and winner payouts.
    receive() external payable {}
}
