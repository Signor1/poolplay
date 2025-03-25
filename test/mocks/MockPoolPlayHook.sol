// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PoolId} from "v4-core/types/PoolId.sol";
import {IPoolPlayHook} from "../../src/Interfaces/IPoolPlayHook.sol";

contract MockPoolPlayHook is IPoolPlayHook {
    mapping(PoolId => uint256) private poolTVL;
    mapping(PoolId => uint256) private poolVolume24h;
    mapping(PoolId => uint256) private poolFees24h;
    mapping(PoolId => mapping(address => uint256)) private positionValues;

    function setPoolTVL(PoolId poolId, uint256 value) external {
        poolTVL[poolId] = value;
    }

    function setPoolVolume24h(PoolId poolId, uint256 value) external {
        poolVolume24h[poolId] = value;
    }

    function setPoolFees24h(PoolId poolId, uint256 value) external {
        poolFees24h[poolId] = value;
    }

    function setPositionValue(PoolId poolId, address user, uint256 value) external {
        positionValues[poolId][user] = value;
    }

    function getPoolTVL(PoolId poolId) external view returns (uint256) {
        return poolTVL[poolId];
    }

    function getPoolVolume24h(PoolId poolId) external view returns (uint256) {
        return poolVolume24h[poolId];
    }

    function getPoolFees24h(PoolId poolId) external view returns (uint256) {
        return poolFees24h[poolId];
    }

    function getPositionValue(PoolId poolId, address user) external view returns (uint256) {
        return positionValues[poolId][user];
    }
}
