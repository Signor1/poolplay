// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPoolPlayHook} from "./Interfaces/IPoolPlayHook.sol";
import {IEigenLayerServiceManager} from "./Interfaces/IEigenLayerServiceManager.sol";

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
        PredictionType predictionType;
        uint256 validationTimestamp;
        uint256 totalBetAmount;
        uint256 minBetAmount;
        uint256 maxBetAmount;
        uint256 platformFee; // In basis points (e.g., 50 = 0.5%)
        bool isActive;
        bool isSettled;
    }

    // ===== State Variables =====
    IEigenLayerServiceManager public eigenLayerManager;
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
        PredictionOutcome outcome
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
        address _eigenLayerManager,
        address _poolPlayHook,
        address _bettingToken
    ) Ownable(msg.sender) {
        eigenLayerManager = IEigenLayerServiceManager(_eigenLayerManager);
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
        newMarket.predictionType = predictionType;
        newMarket.validationTimestamp = validationTimestamp;
        newMarket.minBetAmount = minBetAmount;
        newMarket.maxBetAmount = maxBetAmount;
        newMarket.platformFee = marketFee;
        newMarket.isActive = true;
        newMarket.isSettled = false;

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
    ) external nonReentrant onlyValidMarket(marketId) {
        Market storage market = markets[marketId];
        require(market.creator == msg.sender, "Only creator can update market");
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
     * @notice Initiates the settlement of a prediction
     * @param predictionId The ID of the prediction to settle
     */
    function initiatePredictionSettlement(
        uint256 predictionId
    ) external nonReentrant onlyValidPrediction(predictionId) {
        Prediction storage prediction = predictions[predictionId];
        require(
            prediction.deadline > block.timestamp,
            "Prediction deadline has passed"
        );
        require(prediction.settled == false, "Prediction already settled");
        require(
            prediction.outcome == PredictionOutcome.PENDING,
            "Prediction outcome is not pending"
        );

        // Request validation from EigenLayer
        bytes32 validationId = keccak256(
            abi.encode(
                "POOLPLAY_VALIDATION",
                predictionId,
                block.timestamp,
                msg.sender
            )
        );

        prediction.validationId = validationId;
        validationIdToPredictionId[validationId] = predictionId;

        // Request validation from EigenLayer operators
        emit ValidationRequested(validationId, predictionId);
    }

    /**
     * @notice Submits a validation for a prediction outcome (called by EigenLayer operators)
     * @param validationId The ID of the validation
     * @param actualValue The actual value of the metric being predicted
     */
    function submitValidation(
        bytes32 validationId,
        uint256 actualValue
    ) external {
        require(
            eigenLayerManager.isActiveOperator(msg.sender),
            "Only active EigenLayer operators can submit validations"
        );

        eigenLayerManager.submitDataValidation(
            validationId,
            abi.encode(actualValue),
            actualValue
        );

        (bytes memory aggregatedData, bool isComplete) = eigenLayerManager
            .aggregateValidations(validationId);

        if (isComplete) {
            // Decode the aggregated value (assuming EigenLayer returns the median value)
            uint256 finalValue = abi.decode(aggregatedData, (uint256));

            // Settle the prediction with the validated value
            _settlePredictionWithValue(validationId, finalValue);
        }
    }

    /**
     * @notice Settles a prediction based on the validated value
     * @param validationId The ID of the validation
     * @param actualValue The actual value of the metric
     */
    function _settlePredictionWithValue(
        bytes32 validationId,
        uint256 actualValue
    ) internal {
        uint256 predictionId = validationIdToPredictionId[validationId];
        Prediction storage prediction = predictions[predictionId];

        require(prediction.outcome == PredictionOutcome.PENDING, "Not pending");
        require(!prediction.settled, "Already settled");

        // Determine outcome based on comparison type
        PredictionOutcome outcome;
        if (prediction.comparisonType == ComparisonType.GREATER_THAN) {
            outcome = actualValue > prediction.targetValue
                ? PredictionOutcome.WON
                : PredictionOutcome.LOST;
        } else if (prediction.comparisonType == ComparisonType.LESS_THAN) {
            outcome = actualValue < prediction.targetValue
                ? PredictionOutcome.WON
                : PredictionOutcome.LOST;
        } else if (prediction.comparisonType == ComparisonType.EQUAL_TO) {
            outcome = actualValue == prediction.targetValue
                ? PredictionOutcome.WON
                : PredictionOutcome.LOST;
        } else if (prediction.comparisonType == ComparisonType.BETWEEN) {
            outcome = (actualValue >= prediction.targetValue &&
                actualValue <= prediction.targetValue2)
                ? PredictionOutcome.WON
                : PredictionOutcome.LOST;
        } else {
            revert("Invalid comparison type");
        }

        prediction.outcome = outcome;
        prediction.settled = true;

        emit PredictionSettled(predictionId, outcome);
        emit ValidationCompleted(validationId, actualValue, outcome);
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

    // ===== Dispute Resolution Functions =====

    /**
     * @notice Files a dispute for a prediction
     * @param validationId The ID of the validation
     */
    function fileDispute(bytes32 validationId) external {
        uint256 predictionId = validationIdToPredictionId[validationId];
        Prediction storage prediction = predictions[predictionId];

        require(prediction.user == msg.sender, "Not prediction owner");
        require(prediction.settled, "Prediction not settled");
        require(!prediction.withdrawn, "Already withdrawn");

        // Require some stake to prevent frivolous disputes
        require(
            bettingToken.transferFrom(
                msg.sender,
                address(this),
                prediction.betAmount / 10
            ),
            "Dispute stake failed"
        );

        emit DisputeFiled(validationId, msg.sender);
    }

    /**
     * @notice Resolves a dispute for a prediction
     * @param validationId The ID of the validation
     * @param actualValue The actual value of the metric
     * @param upholdDispute Whether the dispute is upheld
     */
    function resolveDispute(
        bytes32 validationId,
        uint256 actualValue,
        bool upholdDispute
    ) external onlyOwner {
        uint256 predictionId = validationIdToPredictionId[validationId];
        Prediction storage prediction = predictions[predictionId];

        require(prediction.settled, "Not yet settled");

        if (upholdDispute) {
            // Recalculate the outcome with the corrected value
            _settlePredictionWithValue(validationId, actualValue);
        }

        emit DisputeResolved(validationId, upholdDispute);
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
     * @notice Gets the current value from the hook based on prediction type
     * @param predictionType The type of prediction
     * @return value The current value
     */
    function getCurrentValue(
        PredictionType predictionType
    ) public view returns (uint256) {
        if (predictionType == PredictionType.TVL) {
            return poolPlayHook.getPoolTVL();
        } else if (predictionType == PredictionType.VOLUME_24H) {
            return poolPlayHook.getPoolVolume24h();
        } else if (predictionType == PredictionType.FEES_24H) {
            return poolPlayHook.getPoolFees24h();
        } else if (predictionType == PredictionType.POSITION_VALUE) {
            return poolPlayHook.getPositionValue(msg.sender);
        } else {
            revert("Unsupported prediction type");
        }
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
}
