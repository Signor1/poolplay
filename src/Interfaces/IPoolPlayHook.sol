// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";

/**
 * @title IPoolPlayHook
 * @dev Interface for the PoolPlay Uniswap V4 hook
 */
interface IPoolPlayHook {
    function getPoolTVL(PoolId poolId) external view returns (uint256);
    function getPoolVolume24h(PoolId poolId) external view returns (uint256);
    function getPoolFees24h(PoolId poolId) external view returns (uint256);
    function getPositionValue(
        PoolId poolId,
        address user
    ) external view returns (uint256);
}
