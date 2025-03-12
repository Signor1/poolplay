// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {VRFConsumerBase} from "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract LotteryPool is VRFConsumerBase {
    using PoolIdLibrary for PoolKey;

    struct Epoch {
        uint40 startTime;
        uint40 endTime;
        uint256 totalFees;
        mapping(address => uint256) liquidity;
        address[] participants;
    }

    address public immutable hook;
    uint48 public distributionInterval;
    uint256 public currentEpoch;
    bytes32 public keyHash;
    uint256 public vrfFee;

    mapping(uint256 => Epoch) public epochs;
    mapping(bytes32 => uint256) public vrfRequests;

    modifier onlyHook() {
        require(msg.sender == hook, "Unauthorized");
        _;
    }

    constructor(address _vrfCoordinator) VRFConsumerBase(_vrfCoordinator) {}

    function initialize(address _hook, uint48 _interval) external {
        require(hook == address(0), "Already initialized");
        hook = _hook;
        distributionInterval = _interval;
        _startNewEpoch();
    }

    function updateLiquidity() external onlyHook {
        Epoch storage epoch = epochs[currentEpoch];
        if (block.timestamp >= epoch.endTime) {
            _requestNewWinner();
            _startNewEpoch();
        }
    }

    function _startNewEpoch() internal {
        currentEpoch++;
        epochs[currentEpoch] = Epoch({
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + distributionInterval),
            totalFees: 0,
            participants: new address[](0)
        });
    }

    function _requestNewWinner() internal {
        require(LINK.balanceOf(address(this)) >= vrfFee, "Insufficient LINK");
        bytes32 requestId = requestRandomness(keyHash, vrfFee);
        vrfRequests[requestId] = currentEpoch - 1;
    }

    function fulfillRandomness(
        bytes32 requestId,
        uint256 randomness
    ) internal override {
        uint256 epochNumber = vrfRequests[requestId];
        Epoch storage epoch = epochs[epochNumber];

        if (epoch.participants.length > 0) {
            address winner = epoch.participants[
                randomness % epoch.participants.length
            ];
            uint256 prize = (epoch.totalFees * 90) / 100;
            ERC20(token).transfer(winner, prize);
        }
    }

    function depositFee(uint256 amount) external onlyHook {
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
}
