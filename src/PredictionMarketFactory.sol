// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PredictionMarket} from "./PredictionMarket.sol";
import {PoolPlayHook} from "./PoolPlayHook.sol";

contract PredictionMarketFactory {
    using Clones for address;
    using PoolIdLibrary for PoolKey;

    address public immutable master;
    address public immutable poolPlayHook;
    mapping(PoolId => address) public poolToMarket;

    event MarketCreated(
        address indexed market,
        PoolId indexed poolId,
        address betToken
    );

    constructor(address _poolPlayHook, address _master) {
        poolPlayHook = _poolPlayHook;
        master = _master;
    }

    function createMarket(
        PoolKey calldata key,
        address betToken
    ) external returns (address) {
        PoolId poolId = key.toId();
        require(
            poolToMarket[poolId] == address(0),
            "Market already exists for pool"
        );
        address market = master.clone();
        PredictionMarket(market).initialize(poolPlayHook, betToken);
        poolToMarket[poolId] = market;
        emit MarketCreated(market, poolId, betToken);
        return market;
    }
}
