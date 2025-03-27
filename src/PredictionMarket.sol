// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPoolPlayHook} from "./Interfaces/IPoolPlayHook.sol";

contract PoolPlayPredictionMarket is Ownable, ReentrancyGuard {
    using PoolIdLibrary for PoolId;

    enum PredictionType {
        TVL,
        VOLUME_24H,
        FEES_24H
    }
    enum PredictionOutcome {
        PENDING,
        WON,
        LOST
    }
    enum ComparisonType {
        GREATER_THAN,
        LESS_THAN,
        BETWEEN
    }

    struct Prediction {
        address user;
        ComparisonType comparisonType;
        uint256 targetValue;
        uint256 targetValue2; // For BETWEEN comparison
        uint256 betAmount;
        uint256 potentialPayout;
        PredictionOutcome outcome;
        bool settled;
        bool withdrawn;
    }

    struct Market {
        string title;
        PoolId poolId;
        PredictionType predictionType;
        uint256 validationTimestamp;
        uint256 totalBetAmount;
        uint256 minBetAmount;
        uint256 maxBetAmount;
        uint256 platformFee; // Basis points (e.g., 50 = 0.5%)
        bool isActive;
        bool isSettled;
        uint256 totalLossBetAmount;
        uint256[] winners; // Prediction IDs of winners
    }

    IPoolPlayHook public poolPlayHook;
    IERC20 public bettingToken;

    uint256 public nextMarketId = 1;
    uint256 public nextPredictionId = 1;
    uint256 public totalPlatformFees;
    uint256 public constant MAX_PLATFORM_FEE = 1000; // 10%
    uint256 public platformFee = 50; // 0.5%

    mapping(uint256 => Market) public markets;
    mapping(uint256 => Prediction) public predictions;
    mapping(uint256 => uint256[]) public marketPredictions;
    mapping(address => uint256[]) public userPredictions;

    event MarketCreated(uint256 indexed marketId, string title, PredictionType predictionType);
    event PredictionPlaced(uint256 indexed predictionId, uint256 indexed marketId, address user, uint256 betAmount);
    event PredictionSettled(uint256 indexed predictionId, PredictionOutcome outcome, uint256 potentialPayout);
    event MarketSettled(uint256 indexed marketId, uint256 actualValue, uint256 winnerCount);

    constructor(address _poolPlayHook, address _bettingToken) Ownable(msg.sender) {
        poolPlayHook = IPoolPlayHook(_poolPlayHook);
        bettingToken = IERC20(_bettingToken);
    }

    // ===== Market Management =====
    function createMarket(
        string memory title,
        PoolId poolId,
        PredictionType predictionType,
        uint256 validationTimestamp,
        uint256 minBetAmount,
        uint256 maxBetAmount
    ) external nonReentrant {
        require(minBetAmount > 0 && maxBetAmount > minBetAmount, "Invalid bet amounts");
        require(validationTimestamp > block.timestamp + 1 hours, "Validation too soon");

        uint256 marketId = nextMarketId++;
        Market storage newMarket = markets[marketId];
        newMarket.title = title;
        newMarket.poolId = poolId;
        newMarket.predictionType = predictionType;
        newMarket.validationTimestamp = validationTimestamp;
        newMarket.minBetAmount = minBetAmount;
        newMarket.maxBetAmount = maxBetAmount;
        newMarket.platformFee = platformFee;
        newMarket.isActive = true;

        emit MarketCreated(marketId, title, predictionType);
    }

    // ===== Prediction Functions =====
    function placePrediction(
        uint256 marketId,
        ComparisonType comparisonType,
        uint256 targetValue,
        uint256 targetValue2,
        uint256 betAmount
    ) external nonReentrant {
        Market storage market = markets[marketId];
        require(market.isActive, "Market inactive");
        require(betAmount >= market.minBetAmount && betAmount <= market.maxBetAmount, "Invalid bet amount");
        require(market.validationTimestamp > block.timestamp, "Market expired");
        if (comparisonType == ComparisonType.BETWEEN) {
            require(targetValue < targetValue2, "Invalid range");
        }

        uint256 fee = (betAmount * market.platformFee) / 10000;
        uint256 potentialPayout = betAmount + ((betAmount * 9500) / 10000); // 95% payout

        require(bettingToken.transferFrom(msg.sender, address(this), betAmount), "Transfer failed");

        uint256 predictionId = nextPredictionId++;
        Prediction storage prediction = predictions[predictionId];
        prediction.user = msg.sender;
        prediction.comparisonType = comparisonType;
        prediction.targetValue = targetValue;
        prediction.targetValue2 = targetValue2;
        prediction.betAmount = betAmount;
        prediction.potentialPayout = potentialPayout;
        prediction.outcome = PredictionOutcome.PENDING;

        market.totalBetAmount += betAmount;
        marketPredictions[marketId].push(predictionId);
        userPredictions[msg.sender].push(predictionId);
        totalPlatformFees += fee;

        emit PredictionPlaced(predictionId, marketId, msg.sender, betAmount);
    }

    function settleMarket(uint256 marketId) external nonReentrant {
        Market storage market = markets[marketId];
        require(!market.isSettled, "Already settled");
        require(block.timestamp >= market.validationTimestamp, "Too early");

        uint256 actualValue = getCurrentValue(market.poolId, market.predictionType);
        uint256[] memory predictionIds = marketPredictions[marketId];
        uint256 totalLossBetAmount = 0;
        uint256 winnerCount = 0;
        uint256[] memory winners = new uint256[](predictionIds.length);

        for (uint256 i = 0; i < predictionIds.length; i++) {
            Prediction storage pred = predictions[predictionIds[i]];
            if (pred.settled) continue;

            if (isPredictionCorrect(pred, actualValue)) {
                pred.outcome = PredictionOutcome.WON;
                winners[winnerCount++] = predictionIds[i];
            } else {
                pred.outcome = PredictionOutcome.LOST;
                totalLossBetAmount += pred.betAmount;
            }
            pred.settled = true;
            emit PredictionSettled(predictionIds[i], pred.outcome, pred.potentialPayout);
        }

        market.totalLossBetAmount = totalLossBetAmount;
        if (winnerCount > 0) {
            uint256 winningsPerWinner = totalLossBetAmount / winnerCount;
            market.winners = new uint256[](winnerCount);
            for (uint256 i = 0; i < winnerCount; i++) {
                market.winners[i] = winners[i];
                predictions[winners[i]].potentialPayout = predictions[winners[i]].betAmount + winningsPerWinner;
            }
        }
        market.isSettled = true;

        emit MarketSettled(marketId, actualValue, winnerCount);
    }

    function withdrawWinnings(uint256 predictionId) external nonReentrant {
        Prediction storage prediction = predictions[predictionId];
        require(prediction.settled && !prediction.withdrawn, "Not withdrawable");
        require(prediction.outcome == PredictionOutcome.WON, "Not a winner");

        prediction.withdrawn = true;
        require(bettingToken.transfer(prediction.user, prediction.potentialPayout), "Transfer failed");
    }

    function getMarket(uint256 marketId) external view returns (Market memory) {
        return markets[marketId];
    }

    function getPrediction(uint256 predictionId) external view returns (Prediction memory) {
        return predictions[predictionId];
    }

    // ===== Helper Functions =====
    function isPredictionCorrect(Prediction storage pred, uint256 actualValue) private view returns (bool) {
        if (pred.comparisonType == ComparisonType.GREATER_THAN) {
            return actualValue > pred.targetValue;
        } else if (pred.comparisonType == ComparisonType.LESS_THAN) {
            return actualValue < pred.targetValue;
        } else if (pred.comparisonType == ComparisonType.BETWEEN) {
            return actualValue >= pred.targetValue && actualValue <= pred.targetValue2;
        }
        return false;
    }

    function getCurrentValue(PoolId poolId, PredictionType predictionType) public view returns (uint256) {
        if (predictionType == PredictionType.TVL) {
            return poolPlayHook.getPoolTVL(poolId);
        } else if (predictionType == PredictionType.VOLUME_24H) {
            return poolPlayHook.getPoolVolume24h(poolId);
        } else if (predictionType == PredictionType.FEES_24H) {
            return poolPlayHook.getPoolFees24h(poolId);
        }
        revert("Unsupported prediction type");
    }

    // ===== Admin Functions =====
    function withdrawPlatformFees(uint256 amount) external onlyOwner {
        require(amount <= totalPlatformFees, "Insufficient fees");
        totalPlatformFees -= amount;
        require(bettingToken.transfer(owner(), amount), "Transfer failed");
    }
}
