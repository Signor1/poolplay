// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import {PoolKey} from "v4-core/types/PoolKey.sol";
// import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import {IPoolPlayHook} from "./Interfaces/IPoolPlayHook.sol";

// contract PoolPlayPredictionMarket is Ownable, ReentrancyGuard {
//     using PoolIdLibrary for PoolId;

//     enum PredictionType {
//         TVL,
//         VOLUME_24H,
//         FEES_24H,
//         POSITION_VALUE,
//         PRICE,
//         PRICE_RATIO
//     }
//     enum PredictionOutcome {
//         PENDING,
//         WON,
//         LOST,
//         CANCELLED,
//         DISPUTED
//     }
//     enum ComparisonType {
//         GREATER_THAN,
//         LESS_THAN,
//         EQUAL_TO,
//         BETWEEN
//     }

//     struct Prediction {
//         uint256 id;
//         address user;
//         PredictionType predictionType;
//         ComparisonType comparisonType;
//         uint256 targetValue;
//         uint256 targetValue2;
//         uint256 betAmount;
//         uint256 potentialPayout;
//         uint256 deadline;
//         PredictionOutcome outcome;
//         bytes32 validationId;
//         bool settled;
//         bool withdrawn;
//     }

//     struct Market {
//         uint256 id;
//         address creator;
//         string title;
//         string description;
//         PoolId poolId;
//         PredictionType predictionType;
//         uint256 validationTimestamp;
//         uint256 totalBetAmount;
//         uint256 minBetAmount;
//         uint256 maxBetAmount;
//         uint256 platformFee;
//         bool isActive;
//         bool isSettled;
//         uint256 totalLossBetAmount;
//         uint256 winnerCount;
//         uint256[] winners;
//     }

//     IPoolPlayHook public poolPlayHook;
//     IERC20 public bettingToken;

//     uint256 public nextMarketId = 1;
//     uint256 public nextPredictionId = 1;
//     uint256 public totalPlatformFees = 0;
//     uint256 public minOperatorValidations = 3;
//     uint256 public constant MAX_PLATFORM_FEE = 1000;
//     uint256 public platformFee = 50;
//     uint256 public minValidationDelay = 1 hours;
//     uint256 public maxValidationDelay = 90 days;

//     mapping(uint256 => Market) public markets;
//     mapping(uint256 => Prediction) public predictions;
//     mapping(uint256 => uint256[]) public marketPredictions;
//     mapping(address => uint256[]) public userPredictions;
//     mapping(bytes32 => uint256) public validationIdToPredictionId;
//     mapping(bytes32 => uint256) public disputeResolutions;

//     event MarketCreated(
//         uint256 indexed marketId,
//         string title,
//         PredictionType predictionType
//     );
//     event PredictionPlaced(
//         uint256 indexed predictionId,
//         uint256 indexed marketId,
//         address user,
//         uint256 betAmount
//     );
//     event PredictionSettled(
//         uint256 indexed predictionId,
//         PredictionOutcome outcome,
//         uint256 potentialPayout
//     );
//     event MarketSettled(
//         uint256 indexed marketId,
//         uint256 actualValue,
//         uint256 winnerCount
//     );
//     event PredictionWithdrawn(
//         uint256 indexed predictionId,
//         address user,
//         uint256 amount
//     );
//     event ValidationRequested(
//         bytes32 indexed validationId,
//         uint256 predictionId
//     );
//     event ValidationCompleted(
//         bytes32 indexed validationId,
//         uint256 actualValue,
//         PredictionOutcome outcome
//     );
//     event DisputeFiled(bytes32 indexed validationId, address user);
//     event DisputeResolved(bytes32 indexed validationId, bool upheld);
//     event MarketUpdated(uint256 indexed marketId, bool isActive);

//     constructor(
//         address _poolPlayHook,
//         address _bettingToken
//     ) Ownable(msg.sender) {
//         poolPlayHook = IPoolPlayHook(_poolPlayHook);
//         bettingToken = IERC20(_bettingToken);
//     }

//     modifier onlyValidMarket(uint256 marketId) {
//         require(marketId > 0 && marketId < nextMarketId, "Invalid market ID");
//         _;
//     }

//     modifier onlyValidPrediction(uint256 predictionId) {
//         require(
//             predictionId > 0 && predictionId < nextPredictionId,
//             "Invalid prediction ID"
//         );
//         _;
//     }

//     // ===== Market Management Functions =====
//     function createMarket(
//         string memory title,
//         string memory description,
//         PredictionType predictionType,
//         PoolId poolId,
//         uint256 validationTimestamp,
//         uint256 minBetAmount,
//         uint256 maxBetAmount,
//         uint256 marketFee
//     ) external nonReentrant {
//         require(marketFee <= MAX_PLATFORM_FEE, "Market fee exceeds max");
//         require(minBetAmount > 0, "Min bet amount must be greater than 0");
//         require(
//             maxBetAmount > minBetAmount,
//             "Max bet amount must be greater than min bet amount"
//         );
//         require(
//             validationTimestamp > block.timestamp + minValidationDelay,
//             "Validation timestamp too soon"
//         );
//         require(
//             validationTimestamp < block.timestamp + maxValidationDelay,
//             "Validation timestamp too far"
//         );

//         Market storage newMarket = markets[nextMarketId];
//         newMarket.id = nextMarketId;
//         newMarket.creator = msg.sender;
//         newMarket.title = title;
//         newMarket.description = description;
//         newMarket.poolId = poolId;
//         newMarket.predictionType = predictionType;
//         newMarket.validationTimestamp = validationTimestamp;
//         newMarket.minBetAmount = minBetAmount;
//         newMarket.maxBetAmount = maxBetAmount;
//         newMarket.platformFee = marketFee;
//         newMarket.isActive = true;
//         newMarket.isSettled = false;
//         newMarket.winnerCount = 0;

//         emit MarketCreated(nextMarketId, title, predictionType);
//         nextMarketId++;
//     }

//     function updateMarket(
//         uint256 marketId,
//         bool isActive
//     ) external nonReentrant onlyValidMarket(marketId) onlyOwner {
//         Market storage market = markets[marketId];
//         require(market.isActive != isActive, "No change in market status");
//         market.isActive = isActive;
//         emit MarketUpdated(marketId, isActive);
//     }

//     // ===== Prediction Functions =====
//     function placePrediction(
//         uint256 marketId,
//         ComparisonType comparisonType,
//         uint256 targetValue,
//         uint256 targetValue2,
//         uint256 betAmount
//     ) external nonReentrant onlyValidMarket(marketId) {
//         Market storage market = markets[marketId];
//         require(market.isActive, "Market is not active");
//         require(betAmount > 0, "Bet amount must be greater than 0");
//         require(betAmount >= market.minBetAmount, "Bet amount too low");
//         require(betAmount <= market.maxBetAmount, "Bet amount too high");
//         require(
//             market.validationTimestamp > block.timestamp,
//             "Market validation timestamp has passed"
//         );

//         if (comparisonType == ComparisonType.BETWEEN) {
//             require(
//                 targetValue < targetValue2,
//                 "For this comparison type target values must not be the same."
//             );
//         }

//         uint256 fee = (betAmount * market.platformFee) / 10000;
//         uint256 potentialPayout = betAmount + ((betAmount * 9500) / 10000);

//         require(
//             bettingToken.transferFrom(msg.sender, address(this), betAmount),
//             "Token transfer failed"
//         );

//         Prediction storage prediction = predictions[nextPredictionId];
//         prediction.id = nextPredictionId;
//         prediction.user = msg.sender;
//         prediction.predictionType = market.predictionType;
//         prediction.comparisonType = comparisonType;
//         prediction.targetValue = targetValue;
//         prediction.targetValue2 = targetValue2;
//         prediction.betAmount = betAmount;
//         prediction.potentialPayout = potentialPayout;
//         prediction.deadline = market.validationTimestamp;
//         prediction.outcome = PredictionOutcome.PENDING;
//         prediction.settled = false;
//         prediction.withdrawn = false;

//         market.totalBetAmount += betAmount;
//         marketPredictions[marketId].push(nextPredictionId);
//         userPredictions[msg.sender].push(nextPredictionId);
//         totalPlatformFees += fee;

//         emit PredictionPlaced(
//             nextPredictionId,
//             marketId,
//             msg.sender,
//             betAmount
//         );
//         nextPredictionId++;
//     }

//     function settleMarket(
//         uint256 marketId
//     ) external nonReentrant onlyValidMarket(marketId) {
//         Market storage market = markets[marketId];
//         require(!market.isSettled, "Market already settled");
//         require(
//             block.timestamp >= market.validationTimestamp,
//             "Too early to settle"
//         );

//         uint256 actualValue = _getActualValue(market);
//         _evaluatePredictions(marketId, actualValue);
//         market.isSettled = true;

//         emit MarketSettled(marketId, actualValue, market.winnerCount);
//     }

//     function _getActualValue(
//         Market storage market
//     ) private view returns (uint256) {
//         if (market.predictionType == PredictionType.TVL) {
//             return poolPlayHook.getPoolTVL(market.poolId);
//         } else if (market.predictionType == PredictionType.VOLUME_24H) {
//             return poolPlayHook.getPoolVolume24h(market.poolId);
//         } else if (market.predictionType == PredictionType.FEES_24H) {
//             return poolPlayHook.getPoolFees24h(market.poolId);
//         } else {
//             revert("Unsupported prediction type");
//         }
//     }

//     function _evaluatePredictions(
//         uint256 marketId,
//         uint256 actualValue
//     ) private {
//         Market storage market = markets[marketId];
//         uint256 predictionCount = marketPredictions[marketId].length;
//         uint256[] memory tempWinners = new uint256[](predictionCount);
//         uint256 winnerCount = 0;
//         uint256 totalLossBetAmount = 0;

//         for (uint256 i = 0; i < predictionCount; i++) {
//             uint256 predId = marketPredictions[marketId][i];
//             Prediction storage pred = predictions[predId];
//             if (pred.settled) continue;

//             if (_isPredictionCorrect(pred, actualValue)) {
//                 pred.outcome = PredictionOutcome.WON;
//                 tempWinners[winnerCount] = predId;
//                 winnerCount++;
//             } else {
//                 pred.outcome = PredictionOutcome.LOST;
//                 totalLossBetAmount += pred.betAmount;
//             }
//             pred.settled = true;
//         }

//         market.totalLossBetAmount = totalLossBetAmount;
//         market.winnerCount = winnerCount;
//         if (winnerCount > 0) {
//             _assignWinners(market, tempWinners, winnerCount);
//             _distributeWinnings(marketId, totalLossBetAmount, winnerCount);
//         }
//     }

//     function _isPredictionCorrect(
//         Prediction storage pred,
//         uint256 actualValue
//     ) private view returns (bool) {
//         if (pred.comparisonType == ComparisonType.GREATER_THAN) {
//             return actualValue > pred.targetValue;
//         } else if (pred.comparisonType == ComparisonType.LESS_THAN) {
//             return actualValue < pred.targetValue;
//         } else if (pred.comparisonType == ComparisonType.EQUAL_TO) {
//             return actualValue == pred.targetValue;
//         } else if (pred.comparisonType == ComparisonType.BETWEEN) {
//             return (actualValue >= pred.targetValue &&
//                 actualValue <= pred.targetValue2);
//         } else {
//             revert("Invalid comparison type");
//         }
//     }

//     function _assignWinners(
//         Market storage market,
//         uint256[] memory tempWinners,
//         uint256 winnerCount
//     ) private {
//         uint256[] storage winners = market.winners;
//         assembly {
//             sstore(winners.slot, winnerCount)
//         }
//         for (uint256 i = 0; i < winnerCount; i++) {
//             winners[i] = tempWinners[i];
//         }
//     }

//     function _distributeWinnings(
//         uint256 marketId,
//         uint256 totalLossBetAmount,
//         uint256 winnerCount
//     ) private {
//         uint256 winningsPerWinner = totalLossBetAmount / winnerCount;
//         uint256[] storage winners = markets[marketId].winners;

//         for (uint256 i = 0; i < winnerCount; i++) {
//             Prediction storage pred = predictions[winners[i]];
//             pred.potentialPayout = pred.betAmount + winningsPerWinner;
//             emit PredictionSettled(
//                 pred.id,
//                 PredictionOutcome.WON,
//                 pred.potentialPayout
//             );
//         }
//     }

//     function withdrawWinnings(uint256 predictionId) external nonReentrant {
//         Prediction storage prediction = predictions[predictionId];
//         require(prediction.settled, "Not yet settled");
//         require(!prediction.withdrawn, "Already withdrawn");
//         require(prediction.outcome == PredictionOutcome.WON, "Did not win");

//         prediction.withdrawn = true;
//         require(
//             bettingToken.transfer(prediction.user, prediction.potentialPayout),
//             "Transfer failed"
//         );
//         emit PredictionWithdrawn(
//             predictionId,
//             msg.sender,
//             prediction.potentialPayout
//         );
//     }

//     function refundBet(uint256 predictionId) external nonReentrant {
//         Prediction storage prediction = predictions[predictionId];
//         require(prediction.user == msg.sender, "Not prediction owner");
//         require(
//             prediction.outcome == PredictionOutcome.CANCELLED,
//             "Not cancelled"
//         );
//         require(!prediction.withdrawn, "Already withdrawn");

//         prediction.withdrawn = true;
//         require(
//             bettingToken.transfer(prediction.user, prediction.betAmount),
//             "Transfer failed"
//         );
//         emit PredictionWithdrawn(
//             predictionId,
//             prediction.user,
//             prediction.betAmount
//         );
//     }

//     function cancelMarket(uint256 marketId) external onlyOwner {
//         Market storage market = markets[marketId];
//         require(market.id == marketId, "Market does not exist");
//         require(!market.isSettled, "Market already settled");

//         market.isSettled = true;
//         uint256 predictionCount = marketPredictions[marketId].length;
//         for (uint256 i = 0; i < predictionCount; i++) {
//             Prediction storage pred = predictions[
//                 marketPredictions[marketId][i]
//             ];
//             if (!pred.settled) {
//                 pred.outcome = PredictionOutcome.CANCELLED;
//                 pred.settled = true;
//                 emit PredictionSettled(
//                     pred.id,
//                     PredictionOutcome.CANCELLED,
//                     pred.betAmount
//                 );
//             }
//         }
//         emit MarketSettled(marketId, 0, 0);
//     }

//     // ===== View Functions =====
//     function getUserPredictions(
//         address user
//     ) external view returns (uint256[] memory) {
//         return userPredictions[user];
//     }

//     function getMarketPredictions(
//         uint256 marketId
//     ) external view returns (uint256[] memory) {
//         return marketPredictions[marketId];
//     }

//     function getMarket(uint256 marketId) external view returns (Market memory) {
//         return markets[marketId];
//     }

//     function getMarketWinners(
//         uint256 marketId
//     ) external view returns (uint256[] memory) {
//         return markets[marketId].winners;
//     }

//     function getCurrentValue(
//         PoolId poolId,
//         PredictionType predictionType
//     ) public view returns (uint256) {
//         if (predictionType == PredictionType.TVL) {
//             return poolPlayHook.getPoolTVL(poolId);
//         } else if (predictionType == PredictionType.VOLUME_24H) {
//             return poolPlayHook.getPoolVolume24h(poolId);
//         } else if (predictionType == PredictionType.FEES_24H) {
//             return poolPlayHook.getPoolFees24h(poolId);
//         } else if (predictionType == PredictionType.POSITION_VALUE) {
//             return poolPlayHook.getPositionValue(poolId, msg.sender);
//         } else {
//             revert("Unsupported prediction type");
//         }
//     }

//     function getMarketPoolValue(
//         uint256 marketId
//     ) external view returns (uint256) {
//         Market storage market = markets[marketId];
//         return getCurrentValue(market.poolId, market.predictionType);
//     }

//     // function getWinners(
//     //     uint256 marketId
//     // ) external view returns (uint256[] memory) {
//     //     return markets[marketId].winners;
//     // }

//     // ===== Admin Functions =====
//     function withdrawPlatformFees(uint256 amount) external onlyOwner {
//         require(amount <= totalPlatformFees, "Amount exceeds available fees");
//         totalPlatformFees -= amount;
//         require(bettingToken.transfer(owner(), amount), "Transfer failed");
//     }

//     function updatePoolPlayHook(address _poolPlayHook) external onlyOwner {
//         poolPlayHook = IPoolPlayHook(_poolPlayHook);
//     }
// }
