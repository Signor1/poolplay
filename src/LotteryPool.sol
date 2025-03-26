// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVRFCoordinatorV2Plus} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {LinkTokenInterface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {LotteryPoolLib} from "./library/LotteryPoolLib.sol";

contract LotteryPool is VRFConsumerBaseV2Plus {
    using PoolIdLibrary for PoolId;
    using LotteryPoolLib for LotteryPoolLib.Lottery;

    mapping(uint256 => LotteryPoolLib.Lottery) public lotteries;
    uint256 public nextLotteryId = 1;
    IVRFCoordinatorV2Plus public immutable vrfCoordinator;
    bytes32 public immutable keyHash =
        0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be;
    uint256 public subscriptionId;
    mapping(uint256 => uint256) public requestIdToLotteryId;
    mapping(uint256 => uint256) public requestIdToEpoch;
    address public linkToken; // Made public and mutable for test flexibility

    event LotteryCreated(
        uint256 indexed lotteryId,
        PoolId poolId,
        address token
    );
    event FeeDeposited(
        uint256 indexed lotteryId,
        uint256 epoch,
        uint256 amount,
        address swapper
    );
    event WinnerSelected(
        uint256 indexed lotteryId,
        uint256 indexed epoch,
        address indexed winner,
        uint256 prize
    );
    event EpochStarted(
        uint256 indexed lotteryId,
        uint256 epoch,
        uint40 startTime,
        uint40 endTime
    );

    constructor(
        address _vrfCoordinator
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator);
        _createNewSubscription();
    }

    function setLinkToken(address _linkToken) external {
        // For testing; in production, set in constructor or make immutable
        require(linkToken == address(0), "LINK token already set");
        linkToken = _linkToken;
    }

    function createLottery(
        PoolId poolId,
        address token,
        uint48 distributionInterval,
        uint24 lotteryFeeBps
    ) external returns (uint256) {
        require(
            lotteryFeeBps > 0 && lotteryFeeBps <= 1000,
            "Invalid fee: 0 < feeBps <= 10%"
        );
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

    function depositFee(
        uint256 lotteryId,
        uint256 amount,
        address swapper
    ) external payable {
        LotteryPoolLib.Lottery storage lottery = lotteries[lotteryId];
        require(lottery.lotteryFeeBps > 0, "Lottery not initialized");
        LotteryPoolLib.Epoch storage epoch = lottery.epochs[
            lottery.currentEpoch
        ];
        require(block.timestamp <= epoch.endTime, "Epoch ended");
        require(amount > 0, "Invalid amount");

        if (lottery.token == address(0)) {
            require(msg.value >= amount, "Insufficient ETH");
        } else {
            require(
                IERC20(lottery.token).transferFrom(
                    msg.sender,
                    address(this),
                    amount
                ),
                "Token transfer failed"
            );
        }

        epoch.totalFees += amount;
        lottery.addParticipant(swapper);
        emit FeeDeposited(lotteryId, lottery.currentEpoch, amount, swapper);
    }

    function updateLottery(uint256 lotteryId) external {
        LotteryPoolLib.Lottery storage lottery = lotteries[lotteryId];
        require(lottery.lotteryFeeBps > 0, "Lottery not initialized");
        LotteryPoolLib.Epoch storage epoch = lottery.epochs[
            lottery.currentEpoch
        ];
        if (block.timestamp >= epoch.endTime) {
            _requestNewWinner(lotteryId);
            lottery.startNewEpoch();
            emit EpochStarted(
                lotteryId,
                lottery.currentEpoch,
                epoch.startTime,
                epoch.endTime
            );
        }
    }

    function _requestNewWinner(uint256 lotteryId) internal {
        require(subscriptionId != 0, "Subscription ID not set");
        require(
            linkToken != address(0) &&
                IERC20(linkToken).balanceOf(address(this)) >= 1 ether,
            "Insufficient LINK"
        );

        uint256 requestId = vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: 3,
                callbackGasLimit: 100000,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        requestIdToLotteryId[requestId] = lotteryId;
        requestIdToEpoch[requestId] = lotteries[lotteryId].currentEpoch;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 lotteryId = requestIdToLotteryId[requestId];
        uint256 epochNumber = requestIdToEpoch[requestId];
        require(lotteryId > 0, "Invalid request ID");

        LotteryPoolLib.Lottery storage lottery = lotteries[lotteryId];
        LotteryPoolLib.Epoch storage epoch = lottery.epochs[epochNumber];
        if (epoch.participants.length > 0) {
            address winner = epoch.participants[
                randomWords[0] % epoch.participants.length
            ];
            epoch.winner = winner;
            uint256 prize = (epoch.totalFees * 90) / 100;

            if (lottery.token == address(0)) {
                (bool success, ) = winner.call{value: prize}("");
                require(success, "ETH transfer failed");
            } else {
                require(
                    IERC20(lottery.token).transfer(winner, prize),
                    "Token transfer failed"
                );
            }
            emit WinnerSelected(lotteryId, epochNumber, winner, prize);
        }
    }

    function _createNewSubscription() private {
        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.addConsumer(subscriptionId, address(this));
    }

    function topUpSubscription(uint256 amount) external {
        require(
            LinkTokenInterface(linkToken).transferAndCall(
                address(vrfCoordinator),
                amount,
                abi.encode(subscriptionId)
            ),
            "LINK transfer failed"
        );
    }

    function withdrawOperatorFee(
        uint256 lotteryId,
        uint256 epoch,
        address recipient
    ) external {
        LotteryPoolLib.Lottery storage lottery = lotteries[lotteryId];
        LotteryPoolLib.Epoch storage epochData = lottery.epochs[epoch];
        require(epochData.winner != address(0), "Epoch not settled");
        uint256 operatorFee = (epochData.totalFees * 10) / 100;
        if (lottery.token == address(0)) {
            (bool success, ) = recipient.call{value: operatorFee}("");
            require(success, "ETH withdrawal failed");
        } else {
            require(
                IERC20(lottery.token).transfer(recipient, operatorFee),
                "Token withdrawal failed"
            );
        }
    }

    function getLottery(
        uint256 lotteryId
    )
        external
        view
        returns (
            PoolId poolId,
            address token,
            uint48 distributionInterval,
            uint24 lotteryFeeBps,
            uint256 currentEpoch
        )
    {
        LotteryPoolLib.Lottery storage lottery = lotteries[lotteryId];
        return (
            lottery.poolId,
            lottery.token,
            lottery.distributionInterval,
            lottery.lotteryFeeBps,
            lottery.currentEpoch
        );
    }

    function getEpoch(
        uint256 lotteryId,
        uint256 epochId
    )
        external
        view
        returns (uint256 totalFees, uint40 startTime, uint40 endTime)
    {
        LotteryPoolLib.Epoch storage epoch = lotteries[lotteryId].epochs[
            epochId
        ];
        return (epoch.totalFees, epoch.startTime, epoch.endTime);
    }

    function getEpochParticipants(
        uint256 lotteryId,
        uint256 epochId
    ) external view returns (address[] memory) {
        return lotteries[lotteryId].epochs[epochId].participants;
    }

    receive() external payable {}
}
