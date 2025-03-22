// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVRFCoordinatorV2Plus} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {LinkTokenInterface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract LotteryPool is VRFConsumerBaseV2Plus {
    using PoolIdLibrary for PoolKey;

    struct Epoch {
        uint40 startTime;
        uint40 endTime;
        uint256 totalFees;
        mapping(address => uint256) liquidity;
        address[] participants;
        address winner;
    }

    event WinnerSelected(
        uint256 indexed epoch,
        address indexed winner,
        uint256 prize
    );

    address public hook;
    address public token; // Fee and prize token
    uint48 public distributionInterval;
    uint256 public currentEpoch;

    IVRFCoordinatorV2Plus public immutable vrfCoordinator;
    bytes32 public keyHash =
        0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be; // Keyhash for Arbitrum Arbitrum
    // 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c; // Example for Sepoia
    uint256 public subscriptionId;

    mapping(uint256 => Epoch) public epochs;
    mapping(uint256 => uint256) public epochToRequestID; // Changed to uint256 requestId

    modifier onlyHook() {
        require(msg.sender == hook, "Unauthorized");
        _;
    }

    address private LINK_TOKEN;
    // 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E; // LINK TOKEN Arbitrum
    // 0x779877A7B0D9E8603169DdbD7836e478b4624789; // Sepoia LINK

    constructor(
        address _vrfCoordinator,
        address _link
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator);
        LINK_TOKEN = _link;
    }

    function initialize(
        address _hook,
        uint48 _interval,
        address _token
    ) external {
        require(hook == address(0), "Already initialized");
        hook = _hook;
        distributionInterval = _interval;
        token = _token;
        _startNewEpoch();
        _createNewSubscription();
    }

    function updateLiquidity() external onlyHook {
        Epoch storage epoch = epochs[currentEpoch];
        if (block.timestamp >= epoch.endTime) {
            _requestNewWinner();
            _startNewEpoch();
        }
    }

    function depositFee(uint256 amount) external onlyHook {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        epochs[currentEpoch].totalFees += amount;
    }

    function recordLiquidity(
        address provider,
        uint256 liquidity
    ) external onlyHook {
        Epoch storage epoch = epochs[currentEpoch];
        if (block.timestamp >= epoch.endTime) {
            _requestNewWinner();
            _startNewEpoch();

            Epoch storage newEpoch = epochs[currentEpoch];
            newEpoch.liquidity[provider] = liquidity;
            newEpoch.participants.push(provider);
            return;
        }

        if (epoch.liquidity[provider] == 0) {
            epoch.participants.push(provider);
        }
        epoch.liquidity[provider] += liquidity;
    }

    function _startNewEpoch() internal {
        currentEpoch++;
        Epoch storage newEpoch = epochs[currentEpoch];
        newEpoch.startTime = uint40(block.timestamp);
        newEpoch.endTime = uint40(block.timestamp + distributionInterval);
        newEpoch.totalFees = 0;
        newEpoch.participants = new address[](0);
    }

    function _requestNewWinner() internal {
        require(subscriptionId != 0, "Subscription ID not set");
        require(
            IERC20(LINK_TOKEN).balanceOf(address(this)) >= 1000000000000000000,
            "Insufficient LINK"
        ); // 1 LINK as placeholder
        uint256 requestId = vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: 3, // Request confirmations
                callbackGasLimit: 100000, // Gas limit
                numWords: 1, // Number of random words
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        epochToRequestID[currentEpoch] = requestId;
    }

    function getEpochDetails(
        uint256 epoch
    )
        public
        view
        returns (
            uint40 startTime,
            uint40 endTime,
            uint256 totalFees,
            address winner,
            address[] memory participants
        )
    {
        Epoch storage e = epochs[epoch];
        return (e.startTime, e.endTime, e.totalFees, e.winner, e.participants);
    }

    function getCurrentEpochDetails()
        external
        view
        returns (
            uint40 startTime,
            uint40 endTime,
            uint256 totalFees,
            address winner,
            address[] memory participants
        )
    {
        return getEpochDetails(currentEpoch);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 epochNumber = 0;
        for (uint256 i = 1; i < currentEpoch; i++) {
            if (epochToRequestID[i] == requestId) {
                epochNumber = i;
                break;
            }
        }
        require(epochNumber > 0, "Invalid request ID");
        Epoch storage epoch = epochs[epochNumber];
        if (epoch.participants.length > 0) {
            address winner = epoch.participants[
                randomWords[0] % epoch.participants.length
            ];
            epoch.winner = winner;
            uint256 prize = (epoch.totalFees * 90) / 100; // 90% to winner, 10% to operator
            IERC20(token).transfer(winner, prize);
            emit WinnerSelected(epochNumber, winner, prize);
        }
    }

    // Create a new subscription when the contract is initially deployed.
    function _createNewSubscription() private onlyOwner {
        subscriptionId = s_vrfCoordinator.createSubscription();
        // Add this contract as a consumer of its own subscription.
        vrfCoordinator.addConsumer(subscriptionId, address(this));
    }

    // Assumes this contract owns link.
    // 1000000000000000000 = 1 LINK
    function topUpSubscription(uint256 amount) external onlyOwner {
        LinkTokenInterface(LINK_TOKEN).transferAndCall(
            address(s_vrfCoordinator),
            amount,
            abi.encode(subscriptionId)
        );
    }

    function addConsumer(address consumerAddress) external onlyOwner {
        // Add a consumer contract to the subscription.
        vrfCoordinator.addConsumer(subscriptionId, consumerAddress);
    }

    function removeConsumer(address consumerAddress) external onlyOwner {
        // Remove a consumer contract from the subscription.
        vrfCoordinator.removeConsumer(subscriptionId, consumerAddress);
    }

    function cancelSubscription(address receivingWallet) external onlyOwner {
        // Cancel the subscription and send the remaining LINK to a wallet address.
        vrfCoordinator.cancelSubscription(subscriptionId, receivingWallet);
        subscriptionId = 0;
    }

    // Transfer this contract's funds to an address.
    // 1000000000000000000 = 1 LINK
    function withdraw(uint256 amount, address to) external onlyOwner {
        LinkTokenInterface(LINK_TOKEN).transfer(to, amount);
    }
}
