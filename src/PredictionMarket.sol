// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPoolPlayHook} from "./Interfaces/IPoolPlayHook.sol";

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
        address creator;
        string title;
        string description;
        PoolId poolId;
        PredictionType predictionType;
        uint256 validationTimestamp;
        uint256 totalBetAmount;
        uint256 minBetAmount;
        uint256 maxBetAmount;
        uint256 platformFee; // In basis points (e.g., 50 = 0.5%)
        bool isActive;
        bool isSettled;
        uint256 totalLossBetAmount;
        uint256 winnerCount;
        uint256[] winners;
    }

    // ===== State Variables =====
    IPoolPlayHook public poolPlayHook;
    IERC20 public bettingToken;

    uint256 public nextMarketId = 1;
    uint256 public nextPredictionId = 1;
    uint256 public totalPlatformFees = 0;
    uint256 public minOperatorValidations = 3; // Minimum validations required from EigenLayer operators

    // Fee settings
    uint256 public constant MAX_PLATFORM_FEE = 1000; // 10% in basis points
    uint256 public platformFee = 50; // 0.5% in basis points

    // Timeframe settings
    uint256 public minValidationDelay = 1 hours;
    uint256 public maxValidationDelay = 90 days;

    // Mappings
    mapping(uint256 => Market) public markets;
    mapping(uint256 => Prediction) public predictions;
    mapping(uint256 => uint256[]) public marketPredictions;
    mapping(address => uint256[]) public userPredictions;
    mapping(bytes32 => uint256) public validationIdToPredictionId;
    mapping(bytes32 => uint256) public disputeResolutions;

    // Events
    event MarketCreated(
        uint256 indexed marketId,
        string title,
        PredictionType predictionType
    );
    event PredictionPlaced(
        uint256 indexed predictionId,
        uint256 indexed marketId,
        address user,
        uint256 betAmount
    );
    event PredictionSettled(
        uint256 indexed predictionId,
        PredictionOutcome outcome,
        uint256 potentialPayout
    );
    event MarketSettled(
        uint256 indexed marketId,
        uint256 actualValue,
        uint256 winnerCount
    );
    event PredictionWithdrawn(
        uint256 indexed predictionId,
        address user,
        uint256 amount
    );
    event ValidationRequested(
        bytes32 indexed validationId,
        uint256 predictionId
    );
    event ValidationCompleted(
        bytes32 indexed validationId,
        uint256 actualValue,
        PredictionOutcome outcome
    );
    event DisputeFiled(bytes32 indexed validationId, address user);
    event DisputeResolved(bytes32 indexed validationId, bool upheld);
    event MarketUpdated(uint256 indexed marketId, bool isActive);

    // ===== Constructor =====
    constructor(
        address _poolPlayHook,
        address _bettingToken
    ) Ownable(msg.sender) {
        poolPlayHook = IPoolPlayHook(_poolPlayHook);
        bettingToken = IERC20(_bettingToken);
    }

    // ===== Modifiers =====
    modifier onlyValidMarket(uint256 marketId) {
        require(marketId > 0 && marketId < nextMarketId, "Invalid market ID");
        _;
    }

    modifier onlyValidPrediction(uint256 predictionId) {
        require(
            predictionId > 0 && predictionId < nextPredictionId,
            "Invalid prediction ID"
        );
        _;
    }

    // ===== Market Management Functions =====

    /**
     * @notice Creates a new market for a prediction
     * @param title The title of the market
     * @param description The description of the market
     * @param predictionType The type of prediction
     * @param validationTimestamp The timestamp of the validation
     * @param minBetAmount The minimum bet amount
     * @param maxBetAmount The maximum bet amount
     * @param marketFee The market fee in basis points (e.g., 50 = 0.5%)
     */
    function createMarket(
        string memory title,
        string memory description,
        PredictionType predictionType,
        PoolId poolId,
        uint256 validationTimestamp,
        uint256 minBetAmount,
        uint256 maxBetAmount,
        uint256 marketFee
    ) external nonReentrant {
        require(marketFee <= MAX_PLATFORM_FEE, "Market fee exceeds max");
        require(minBetAmount > 0, "Min bet amount must be greater than 0");
        require(
            maxBetAmount > minBetAmount,
            "Max bet amount must be greater than min bet amount"
        );
        require(
            validationTimestamp > block.timestamp + minValidationDelay,
            "Validation timestamp too soon"
        );
        require(
            validationTimestamp < block.timestamp + maxValidationDelay,
            "Validation timestamp too far"
        );

        Market storage newMarket = markets[nextMarketId];
        newMarket.id = nextMarketId;
        newMarket.creator = msg.sender;
        newMarket.title = title;
        newMarket.description = description;
        newMarket.poolId = poolId;
        newMarket.predictionType = predictionType;
        newMarket.validationTimestamp = validationTimestamp;
        newMarket.minBetAmount = minBetAmount;
        newMarket.maxBetAmount = maxBetAmount;
        newMarket.platformFee = marketFee;
        newMarket.isActive = true;
        newMarket.isSettled = false;
        newMarket.winnerCount = 0;

        emit MarketCreated(nextMarketId, title, predictionType);

        nextMarketId++;
    }

    /**
     * @notice Updates a market
     * @param marketId The ID of the market to update
     * @param isActive Whether the market is active
     */
    function updateMarket(
        uint256 marketId,
        bool isActive
    ) external nonReentrant onlyValidMarket(marketId) onlyOwner {
        Market storage market = markets[marketId];
        require(market.isActive != isActive, "No change in market status");

        market.isActive = isActive;
        emit MarketUpdated(marketId, isActive);
    }

    // ===== Prediction Functions =====

    /**
     * @notice Places a prediction on a market
     * @param marketId The ID of the market
     * @param comparisonType The type of comparison
     * @param targetValue The target value
     * @param targetValue2 The target value for BETWEEN comparison
     * @param betAmount The amount to bet
     */
    function placePrediction(
        uint256 marketId,
        ComparisonType comparisonType,
        uint256 targetValue,
        uint256 targetValue2,
        uint256 betAmount
    ) external nonReentrant onlyValidMarket(marketId) {
        Market storage market = markets[marketId];
        require(market.isActive, "Market is not active");
        require(betAmount > 0, "Bet amount must be greater than 0");
        require(betAmount >= market.minBetAmount, "Bet amount too low");
        require(betAmount <= market.maxBetAmount, "Bet amount too high");
        require(
            market.validationTimestamp > block.timestamp,
            "Market validation timestamp has passed"
        );

        if (comparisonType == ComparisonType.BETWEEN) {
            require(
                targetValue < targetValue2,
                "For this comparison type target values must not be the same."
            );
        }

        uint256 fee = (betAmount * market.platformFee) / 10000;
        uint256 potentialPayout = betAmount + ((betAmount * 9500) / 10000); // Example: 95% ROI

        // Transfer tokens from user
        require(
            bettingToken.transferFrom(msg.sender, address(this), betAmount),
            "Token transfer failed"
        );

        // Create prediction
        Prediction storage prediction = predictions[nextPredictionId];
        prediction.id = nextPredictionId;
        prediction.user = msg.sender;
        prediction.predictionType = market.predictionType;
        prediction.comparisonType = comparisonType;
        prediction.targetValue = targetValue;
        prediction.targetValue2 = targetValue2;
        prediction.betAmount = betAmount;
        prediction.potentialPayout = potentialPayout;
        prediction.deadline = market.validationTimestamp;
        prediction.outcome = PredictionOutcome.PENDING;
        prediction.settled = false;
        prediction.withdrawn = false;

        // Update market stats
        market.totalBetAmount += betAmount;
        marketPredictions[marketId].push(nextPredictionId);
        userPredictions[msg.sender].push(nextPredictionId);

        // Update platform fees
        totalPlatformFees += fee;

        emit PredictionPlaced(
            nextPredictionId,
            marketId,
            msg.sender,
            betAmount
        );
        nextPredictionId++;
    }

    /**
     * @notice Settles a market by checking actual values from the hook
     * @param marketId The ID of the market to settle
     */
    function settleMarket(
        uint256 marketId
    ) external nonReentrant onlyValidMarket(marketId) {
        Market storage market = markets[marketId];

        require(!market.isSettled, "Market already settled");
        require(
            block.timestamp >= market.validationTimestamp,
            "Too early to settle"
        );

        // Get actual value from hook
        uint256 actualValue;
        if (market.predictionType == PredictionType.TVL) {
            actualValue = poolPlayHook.getPoolTVL(market.poolId);
        } else if (market.predictionType == PredictionType.VOLUME_24H) {
            actualValue = poolPlayHook.getPoolVolume24h(market.poolId);
        } else if (market.predictionType == PredictionType.FEES_24H) {
            actualValue = poolPlayHook.getPoolFees24h(market.poolId);
        } else {
            revert("Unsupported prediction type");
        }

        // Process all predictions in this market
        uint256[] memory preds = marketPredictions[marketId];
        uint256 totalLossBetAmount = 0;
        uint256 winnerCount = 0;

        // First pass: determine winners and losers
        for (uint256 i = 0; i < preds.length; i++) {
            Prediction storage pred = predictions[preds[i]];
            if (pred.settled) continue;

            // Determine if prediction was correct
            bool isCorrect;
            if (pred.comparisonType == ComparisonType.GREATER_THAN) {
                isCorrect = actualValue > pred.targetValue;
            } else if (pred.comparisonType == ComparisonType.LESS_THAN) {
                isCorrect = actualValue < pred.targetValue;
            } else if (pred.comparisonType == ComparisonType.EQUAL_TO) {
                isCorrect = actualValue == pred.targetValue;
            } else if (pred.comparisonType == ComparisonType.BETWEEN) {
                isCorrect = (actualValue >= pred.targetValue &&
                    actualValue <= pred.targetValue2);
            } else {
                revert("Invalid comparison type");
            }

            // Mark as won or lost
            if (isCorrect) {
                pred.outcome = PredictionOutcome.WON;
                market.winners.push(pred.id);
                winnerCount++;
            } else {
                pred.outcome = PredictionOutcome.LOST;
                totalLossBetAmount += pred.betAmount;
            }

            pred.settled = true;
        }

        // Store total loss amount and winner count
        market.totalLossBetAmount = totalLossBetAmount;
        market.winnerCount = winnerCount;

        // Second pass: calculate winnings for each winner
        if (winnerCount > 0) {
            uint256 winningsPerWinner = totalLossBetAmount / winnerCount;

            for (uint256 i = 0; i < market.winners.length; i++) {
                uint256 predId = market.winners[i];
                Prediction storage pred = predictions[predId];

                // Winner gets their bet back plus share of losses
                pred.potentialPayout = pred.betAmount + winningsPerWinner;

                emit PredictionSettled(
                    predId,
                    PredictionOutcome.WON,
                    pred.potentialPayout
                );
            }
        }

        // Mark market as settled
        market.isSettled = true;

        emit MarketSettled(marketId, actualValue, winnerCount);
    }

    /**
     * @notice Withdraws winnings for a settled prediction
     * @param predictionId The ID of the prediction
     */
    function withdrawWinnings(uint256 predictionId) external nonReentrant {
        Prediction storage prediction = predictions[predictionId];

        require(prediction.settled, "Not yet settled");
        require(!prediction.withdrawn, "Already withdrawn");
        require(prediction.outcome == PredictionOutcome.WON, "Did not win");

        prediction.withdrawn = true;

        // Transfer winnings to user
        require(
            bettingToken.transfer(prediction.user, prediction.potentialPayout),
            "Transfer failed"
        );

        emit PredictionWithdrawn(
            predictionId,
            msg.sender,
            prediction.potentialPayout
        );
    }

    /**
     * @notice Refunds a bet if the prediction is cancelled
     * @param predictionId The ID of the prediction
     */
    function refundBet(uint256 predictionId) external nonReentrant {
        Prediction storage prediction = predictions[predictionId];

        require(prediction.user == msg.sender, "Not prediction owner");
        require(
            prediction.outcome == PredictionOutcome.CANCELLED,
            "Not cancelled"
        );
        require(!prediction.withdrawn, "Already withdrawn");

        prediction.withdrawn = true;

        // Return only the original bet amount
        require(
            bettingToken.transfer(prediction.user, prediction.betAmount),
            "Transfer failed"
        );

        emit PredictionWithdrawn(
            predictionId,
            prediction.user,
            prediction.betAmount
        );
    }

    /**
     * @notice Admin function to cancel a market
     * @param marketId The ID of the market to cancel
     */
    function cancelMarket(uint256 marketId) external onlyOwner {
        Market storage market = markets[marketId];
        require(market.id == marketId, "Market does not exist");
        require(!market.isSettled, "Market already settled");

        // Mark market as settled
        market.isSettled = true;

        // Mark all predictions as cancelled
        uint256[] memory preds = marketPredictions[marketId];
        for (uint256 i = 0; i < preds.length; i++) {
            Prediction storage pred = predictions[preds[i]];
            if (!pred.settled) {
                pred.outcome = PredictionOutcome.CANCELLED;
                pred.settled = true;

                emit PredictionSettled(
                    pred.id,
                    PredictionOutcome.CANCELLED,
                    pred.betAmount
                );
            }
        }

        emit MarketSettled(marketId, 0, 0);
    }

    // ===== View Functions =====
    /**
     * @notice Gets all predictions for a user
     * @param user The address of the user
     * @return predictionIds The IDs of the user's predictions
     */
    function getUserPredictions(
        address user
    ) external view returns (uint256[] memory) {
        return userPredictions[user];
    }

    /**
     * @notice Gets all predictions for a market
     * @param marketId The ID of the market
     * @return predictionIds The IDs of the predictions in the market
     */
    function getMarketPredictions(
        uint256 marketId
    ) external view returns (uint256[] memory) {
        return marketPredictions[marketId];
    }

    /**
     * @notice Gets a market
     * @param marketId The ID of the market
     * @return market The market
     */
    function getMarket(uint256 marketId) external view returns (Market memory) {
        return markets[marketId];
    }

    /**
     * @notice Gets the current value from the hook based on prediction type
     * @param predictionType The type of prediction
     * @return value The current value
     */
    function getCurrentValue(
        PoolId poolId,
        PredictionType predictionType
    ) public view returns (uint256) {
        if (predictionType == PredictionType.TVL) {
            return poolPlayHook.getPoolTVL(poolId);
        } else if (predictionType == PredictionType.VOLUME_24H) {
            return poolPlayHook.getPoolVolume24h(poolId);
        } else if (predictionType == PredictionType.FEES_24H) {
            return poolPlayHook.getPoolFees24h(poolId);
        } else if (predictionType == PredictionType.POSITION_VALUE) {
            return poolPlayHook.getPositionValue(poolId, msg.sender);
        } else {
            revert("Unsupported prediction type");
        }
    }

    /**
     * @notice Gets the value of a market
     * @param marketId The ID of the market
     * @return value The value of the market
     */
    function getMarketPoolValue(
        uint256 marketId
    ) external view returns (uint256) {
        Market storage market = markets[marketId];
        return getCurrentValue(market.poolId, market.predictionType);
    }

    /**
     * @notice Gets the winners of a market
     * @param marketId The ID of the market
     * @return winners The winners of the market
     */
    function getWinners(
        uint256 marketId
    ) external view returns (uint256[] memory) {
        Market storage market = markets[marketId];
        return market.winners;
    }

    // ===== Admin Functions =====
    /**
     * @notice Withdraws accumulated platform fees
     * @param amount The amount to withdraw
     */
    function withdrawPlatformFees(uint256 amount) external onlyOwner {
        require(amount <= totalPlatformFees, "Amount exceeds available fees");
        totalPlatformFees -= amount;
        require(bettingToken.transfer(owner(), amount), "Transfer failed");
    }

    /**
     * @notice Updates the PoolPlay hook
     * @param _poolPlayHook The address of the new PoolPlay hook
     */
    function updatePoolPlayHook(address _poolPlayHook) external onlyOwner {
        poolPlayHook = IPoolPlayHook(_poolPlayHook);
    }
}
