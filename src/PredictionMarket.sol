// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolPlayHook} from "./PoolPlayHook.sol";

contract PredictionMarket {
    using PoolIdLibrary for PoolKey;

    struct Bet {
        address user;
        PoolId poolId;
        uint256 targetTVL;
        uint256 betAmount;
        uint40 lockTime;
        uint40 settleTime;
        bool resolved;
        bool won;
    }

    PoolPlayHook public hook;
    IERC20 public betToken;
    Bet[] public bets;
    uint24 public feeBps = 5; // 0.05% fee per bet

    event BetPlaced(
        uint256 indexed betId,
        address indexed user,
        PoolId poolId,
        uint256 targetTVL
    );
    event BetSettled(uint256 indexed betId, bool won, uint256 reward);

    constructor() {
        // Empty constructor for cloning
    }

    function initialize(address _hook, address _betToken) external {
        require(address(hook) == address(0), "Already initialized");
        hook = PoolPlayHook(_hook);
        betToken = IERC20(_betToken);
    }

    function placeBet(
        PoolKey calldata key,
        uint256 targetTVL,
        uint256 betAmount,
        uint40 duration
    ) external {
        PoolId poolId = key.toId();
        uint256 fee = (betAmount * feeBps) / 10_000;
        uint256 netBet = betAmount - fee;

        betToken.transferFrom(msg.sender, address(this), betAmount);
        bets.push(
            Bet({
                user: msg.sender,
                poolId: poolId,
                targetTVL: targetTVL,
                betAmount: netBet,
                lockTime: uint40(block.timestamp),
                settleTime: uint40(block.timestamp + duration),
                resolved: false,
                won: false
            })
        );

        emit BetPlaced(bets.length - 1, msg.sender, poolId, targetTVL);
    }

    function settleBet(uint256 betId) external {
        Bet storage bet = bets[betId];
        require(block.timestamp >= bet.settleTime, "Too early");
        require(!bet.resolved, "Already resolved");

        uint256 finalTVL = hook.getPoolTVL(bet.poolId);
        bet.won = finalTVL >= bet.targetTVL;
        bet.resolved = true;

        if (bet.won) {
            uint256 reward = bet.betAmount * 2; // Simplified; adjust with losing bets pool
            betToken.transfer(bet.user, reward);
            emit BetSettled(betId, true, reward);
        } else {
            emit BetSettled(betId, false, 0);
        }
    }

    function getBet(uint256 betId) external view returns (Bet memory) {
        return bets[betId];
    }

    function getBets() external view returns (Bet[] memory) {
        return bets;
    }
}
