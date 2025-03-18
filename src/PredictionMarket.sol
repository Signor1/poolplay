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
    event MarketUpdated(uint256 indexed marketId, bool isActive);
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
}
