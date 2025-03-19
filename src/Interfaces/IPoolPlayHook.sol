// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPoolPlayHook
 * @dev Interface for the PoolPlay Uniswap V4 hook
 */
interface IPoolPlayHook {
    function getPoolTVL() external view returns (uint256);
    function getPoolVolume24h() external view returns (uint256);
    function getPoolFees24h() external view returns (uint256);
    function getPositionValue(address user) external view returns (uint256);
}
