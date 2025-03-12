// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolPlayHook} from "./PoolPlayHook.sol";

contract PredictionMarket {
    using PoolIdLibrary for PoolKey;

    struct Bet {
        address user;
        PoolId poolId;
        uint256 targetTVL;
        uint40 lockTime;
        uint40 settleTime;
        bool resolved;
    }

    mapping(PoolId => uint256[]) public tvlHistory;
    Bet[] public bets;
    PoolPlayHook public immutable hook;

    constructor(address _hook) {
        hook = PoolPlayHook(_hook);
    }

    function placeBet(
        PoolKey calldata key,
        uint256 targetTVL,
        uint40 duration
    ) external payable {
        PoolId poolId = key.toId();
        bets.push(
            Bet({
                user: msg.sender,
                poolId: poolId,
                targetTVL: targetTVL,
                lockTime: uint40(block.timestamp),
                settleTime: uint40(block.timestamp) + duration,
                resolved: false
            })
        );
        tvlHistory[poolId].push(hook.getTVL(poolId));
    }

    function settleBet(uint256 betId) external {
        Bet storage bet = bets[betId];
        require(block.timestamp >= bet.settleTime, "Too early");
        require(!bet.resolved, "Already resolved");

        uint256 finalTVL = hook.getTVL(bet.poolId);
        bool won = finalTVL >= bet.targetTVL;

        if (won) {
            // Distribute rewards
            uint256 reward = calculateReward(betId);
            ERC20(token).transfer(bet.user, reward);
        }

        bet.resolved = true;
    }
}
