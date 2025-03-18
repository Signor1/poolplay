// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PoolPlayHook} from "./PoolPlayHook.sol";

/**
 * @title PoolPlayPredictionMarket
 * @notice A prediction market for PoolPlay pools
 * @dev This contract allows users to place bets on the future TVL of a PoolPlay pool
 * @dev The contract is owned by the PoolPlay team and anyone can set bets
 * @dev The contract is also responsible for collecting fees from winning bets
 */
contract PoolPlayPredictionMarket is Ownable, ReentrancyGuard {
    // ===== Enums =====
    enum PredictionType {
        TVL,
        VOLUME_24H,
        FEES_24H,
        POSITION_VALUE,
        PRICE,
        PRICE_RATIO
    }
    enum PredictionOutcome {
        PENDING,
        WON,
        LOST,
        CANCELLED,
        DISPUTED
    }
    enum ComparisonType {
        GREATER_THAN,
        LESS_THAN,
        EQUAL_TO,
        BETWEEN
    }

    // ===== Structs =====
    struct Prediction {
        uint256 id;
        address user;
        PredictionType predictionType;
        ComparisonType comparisonType;
        uint256 targetValue;
        uint256 targetValue2; // Used for BETWEEN comparison
        uint256 betAmount;
        uint256 potentialPayout;
        uint256 deadline;
        PredictionOutcome outcome;
        bytes32 validationId;
        bool settled;
        bool withdrawn;
    }

    struct Market {
        uint256 id;
        string title;
        string description;
        PredictionType predictionType;
        uint256 validationTimestamp;
        uint256 totalBetAmount;
        uint256 minBetAmount;
        uint256 maxBetAmount;
        uint256 platformFee; // In basis points (e.g., 50 = 0.5%)
        bool isActive;
        bool isSettled;
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

    constructor() Ownable(msg.sender) {
        // Empty constructor for cloning
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
}
