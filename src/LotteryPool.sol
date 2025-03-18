// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VRFConsumerBaseV2} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract LotteryPool is VRFConsumerBaseV2 {
    using PoolIdLibrary for PoolKey;

    struct Epoch {
        uint40 startTime;
        uint40 endTime;
        uint256 totalFees;
        mapping(address => uint256) liquidity;
        address[] participants;
    }

    address public hook;
    address public token; // Fee and prize token
    uint48 public distributionInterval;
    uint256 public currentEpoch;

    VRFCoordinatorV2Interface public immutable vrfCoordinator;
    bytes32 public keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c; // Example for Sepoia
    uint64 public subscriptionId;

    mapping(uint256 => Epoch) public epochs;
    mapping(uint256 => uint256) public epochToRequestID; // Changed to uint256 requestId

    event WinnerSelected(
        uint256 indexed epoch,
        address indexed winner,
        uint256 prize
    );

    modifier onlyHook() {
        require(msg.sender == hook, "Unauthorized");
        _;
    }

    address private constant LINK_TOKEN =
        0x779877A7B0D9E8603169DdbD7836e478b4624789; // Sepoia LINK

    constructor(address _vrfCoordinator) VRFConsumerBaseV2(_vrfCoordinator) {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
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
            keyHash,
            subscriptionId,
            3, // Request confirmations
            100000, // Gas limit
            1 // Number of random words
        );
        epochToRequestID[currentEpoch - 1] = requestId;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 epochNumber = 0;
        for (uint256 i = 0; i < currentEpoch; i++) {
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
            uint256 prize = (epoch.totalFees * 90) / 100; // 90% to winner, 10% to operator
            IERC20(token).transfer(winner, prize);
            emit WinnerSelected(epochNumber, winner, prize);
        }
    }

    // Admin function to set VRF subscription ID after deployment
    function setSubscriptionId(uint64 _subscriptionId) external {
        require(subscriptionId == 0, "Already set");
        subscriptionId = _subscriptionId;
    }
}
