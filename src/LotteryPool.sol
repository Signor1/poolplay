// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVRFCoordinatorV2Plus} from
    "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {LinkTokenInterface} from
    "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {LotteryPoolLib} from "./library/LotteryPoolLib.sol";

/**
 * @title LotteryPool
 * @notice Manages permissionless lottery pools with Chainlink VRF for winner selection.
 * @dev Each lottery is tied to a Uniswap V4 pool and handles fee deposits and winner payouts.
 */
contract LotteryPool is VRFConsumerBaseV2Plus {
    using PoolIdLibrary for PoolId;
    using LotteryPoolLib for LotteryPoolLib.Lottery;

    // Mapping of lottery ID to its configuration and state.
    mapping(uint256 => LotteryPoolLib.Lottery) public lotteries;
    // Next available lottery ID.
    uint256 public nextLotteryId = 1;
    // Chainlink VRF coordinator for randomness.
    IVRFCoordinatorV2Plus public immutable vrfCoordinator;
    // VRF key hash for Arbitrum.
    bytes32 public immutable keyHash = 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be;
    // VRF subscription ID.
    uint256 public subscriptionId;
    // Mapping of VRF request ID to lottery ID.
    mapping(uint256 => uint256) public requestIdToLotteryId;
    // Mapping of VRF request ID to epoch number.
    mapping(uint256 => uint256) public requestIdToEpoch;
    // LINK token address on Arbitrum.
    address private constant LINK_TOKEN = 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E;

    // Emitted when a new lottery is created.
    event LotteryCreated(uint256 indexed lotteryId, PoolId poolId, address token);
    // Emitted when fees are deposited into an epoch.
    event FeeDeposited(uint256 indexed lotteryId, uint256 epoch, uint256 amount, address swapper);
    // Emitted when a winner is selected for an epoch.
    event WinnerSelected(uint256 indexed lotteryId, uint256 indexed epoch, address indexed winner, uint256 prize);
    // Emitted when a new epoch starts.
    event EpochStarted(uint256 indexed lotteryId, uint256 epoch, uint40 startTime, uint40 endTime);

    /**
     * @notice Constructor to initialize VRF and subscription.
     * @param _vrfCoordinator Address of the Chainlink VRF Coordinator.
     */
    constructor(address _vrfCoordinator) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator);
        _createNewSubscription();
    }

    /**
     * @notice Creates a new lottery linked to a Uniswap V4 pool.
     * @dev Permissionless; anyone can create a lottery.
     * @param poolId The Uniswap V4 pool ID.
     * @param token The token for fees (address(0) for ETH).
     * @param distributionInterval Time between epochs.
     * @param lotteryFeeBps Fee in basis points.
     * @return lotteryId The ID of the created lottery.
     */
    function createLottery(PoolId poolId, address token, uint48 distributionInterval, uint24 lotteryFeeBps)
        external
        returns (uint256)
    {
        require(lotteryFeeBps > 0 && lotteryFeeBps <= 1000, "Invalid fee: 0 < feeBps <= 10%");
        require(distributionInterval > 0, "Invalid interval");

        uint256 lotteryId = nextLotteryId++;
        LotteryPoolLib.Lottery storage lottery = lotteries[lotteryId];
        lottery.poolId = poolId;
        lottery.token = token;
        lottery.distributionInterval = distributionInterval;
        lottery.lotteryFeeBps = lotteryFeeBps;
        lottery.currentEpoch = 0;
        lottery.startNewEpoch();

        emit LotteryCreated(lotteryId, poolId, token);
        emit EpochStarted(
            lotteryId,
            lottery.currentEpoch,
            lottery.epochs[lottery.currentEpoch].startTime,
            lottery.epochs[lottery.currentEpoch].endTime
        );
        return lotteryId;
    }

    /**
     * @notice Deposits a fee from a swap into the current epoch.
     * @param lotteryId The lottery ID.
     * @param amount The fee amount.
     * @param swapper The swapper’s address.
     */
    function depositFee(uint256 lotteryId, uint256 amount, address swapper) external payable {
        LotteryPoolLib.Lottery storage lottery = lotteries[lotteryId];
        require(lottery.lotteryFeeBps > 0, "Lottery not initialized");
        LotteryPoolLib.Epoch storage epoch = lottery.epochs[lottery.currentEpoch];
        require(block.timestamp <= epoch.endTime, "Epoch ended");
        require(amount > 0, "Invalid amount");

        if (lottery.token == address(0)) {
            require(msg.value >= amount, "Insufficient ETH");
        } else {
            require(IERC20(lottery.token).transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        }

        epoch.totalFees += amount;
        lottery.addParticipant(swapper);
        emit FeeDeposited(lotteryId, lottery.currentEpoch, amount, swapper);
    }

    /**
     * @notice Updates the lottery state, triggering a new epoch if needed.
     * @param lotteryId The lottery ID.
     */
    function updateLottery(uint256 lotteryId) external {
        LotteryPoolLib.Lottery storage lottery = lotteries[lotteryId];
        require(lottery.lotteryFeeBps > 0, "Lottery not initialized");
        LotteryPoolLib.Epoch storage epoch = lottery.epochs[lottery.currentEpoch];
        if (block.timestamp >= epoch.endTime) {
            _requestNewWinner(lotteryId);
            lottery.startNewEpoch();
            emit EpochStarted(lotteryId, lottery.currentEpoch, epoch.startTime, epoch.endTime);
        }
    }

    /**
     * @notice Requests a random winner from Chainlink VRF.
     * @param lotteryId The lottery ID.
     */
    function _requestNewWinner(uint256 lotteryId) internal {
        require(subscriptionId != 0, "Subscription ID not set");
        require(IERC20(LINK_TOKEN).balanceOf(address(this)) >= 1 ether, "Insufficient LINK");

        uint256 requestId = vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: 3,
                callbackGasLimit: 100000,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        requestIdToLotteryId[requestId] = lotteryId;
        requestIdToEpoch[requestId] = lotteries[lotteryId].currentEpoch;
    }

    /**
     * @notice Callback function to receive VRF random words and select a winner.
     * @param requestId The VRF request ID.
     * @param randomWords The random numbers provided by VRF.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 lotteryId = requestIdToLotteryId[requestId];
        uint256 epochNumber = requestIdToEpoch[requestId];
        require(lotteryId > 0, "Invalid request ID");

        LotteryPoolLib.Lottery storage lottery = lotteries[lotteryId];
        LotteryPoolLib.Epoch storage epoch = lottery.epochs[epochNumber];
        if (epoch.participants.length > 0) {
            address winner = epoch.participants[randomWords[0] % epoch.participants.length];
            epoch.winner = winner;
            uint256 prize = (epoch.totalFees * 90) / 100; // 90% to winner
            // uint256 operatorFee = epoch.totalFees - prize; // 10% to operator (remains in contract)

            if (lottery.token == address(0)) {
                (bool success,) = winner.call{value: prize}("");
                require(success, "ETH transfer failed");
            } else {
                require(IERC20(lottery.token).transfer(winner, prize), "Token transfer failed");
            }
            emit WinnerSelected(lotteryId, epochNumber, winner, prize);
        }
    }

    /**
     * @notice Creates a new Chainlink VRF subscription.
     */
    function _createNewSubscription() private {
        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.addConsumer(subscriptionId, address(this));
    }

    /**
     * @notice Tops up the VRF subscription with LINK tokens.
     * @param amount The amount of LINK to transfer.
     */
    function topUpSubscription(uint256 amount) external {
        require(
            LinkTokenInterface(LINK_TOKEN).transferAndCall(address(vrfCoordinator), amount, abi.encode(subscriptionId)),
            "LINK transfer failed"
        );
    }

    /**
     * @notice Withdraws operator fees (10% of each epoch).
     * @param lotteryId The lottery ID.
     * @param epoch The epoch number.
     * @param recipient The address to receive the fees.
     */
    function withdrawOperatorFee(uint256 lotteryId, uint256 epoch, address recipient) external {
        LotteryPoolLib.Lottery storage lottery = lotteries[lotteryId];
        LotteryPoolLib.Epoch storage epochData = lottery.epochs[epoch];
        require(epochData.winner != address(0), "Epoch not settled");
        uint256 operatorFee = (epochData.totalFees * 10) / 100;
        if (lottery.token == address(0)) {
            (bool success,) = recipient.call{value: operatorFee}("");
            require(success, "ETH withdrawal failed");
        } else {
            require(IERC20(lottery.token).transfer(recipient, operatorFee), "Token withdrawal failed");
        }
    }

    function getLottery(uint256 lotteryId)
        external
        view
        returns (PoolId poolId, address token, uint48 distributionInterval, uint24 lotteryFeeBps, uint256 currentEpoch)
    {
        LotteryPoolLib.Lottery storage lottery = lotteries[lotteryId];
        return
            (lottery.poolId, lottery.token, lottery.distributionInterval, lottery.lotteryFeeBps, lottery.currentEpoch);
    }

    function getEpoch(uint256 lotteryId, uint256 epochId)
        external
        view
        returns (uint256 totalFees, uint40 startTime, uint40 endTime)
    {
        LotteryPoolLib.Epoch storage epoch = lotteries[lotteryId].epochs[epochId];
        return (epoch.totalFees, epoch.startTime, epoch.endTime);
    }

    function getEpochParticipants(uint256 lotteryId, uint256 epochId) external view returns (address[] memory) {
        return lotteries[lotteryId].epochs[epochId].participants;
    }

    // Receives ETH for fee deposits and winner payouts.
    receive() external payable {}
}
