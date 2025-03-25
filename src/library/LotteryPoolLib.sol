// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolPlayLib} from "./PoolPlayLib.sol";

/**
 * @title LotteryPoolLib
 * @notice Library for managing lottery pool state and logic.
 */
library LotteryPoolLib {
    struct Epoch {
        uint40 startTime; // Start timestamp of the epoch
        uint40 endTime; // End timestamp of the epoch
        uint256 totalFees; // Total fees collected in this epoch
        address[] participants; // List of unique swappers
        address winner; // Winner of the epoch (set after VRF)
    }

    struct Lottery {
        PoolId poolId; // Associated Uniswap V4 pool ID
        address token; // Token used for fees (address(0) for ETH)
        uint48 distributionInterval; // Time between epochs (e.g., 1 day)
        uint24 lotteryFeeBps; // Fee in basis points (e.g., 100 = 1%)
        uint256 currentEpoch; // Current epoch number
        mapping(uint256 => Epoch) epochs; // Epoch data per epoch number
    }

    /**
     * @notice Starts a new epoch for the lottery.
     * @param lottery The lottery storage reference.
     */
    function startNewEpoch(Lottery storage lottery) internal {
        lottery.currentEpoch++;
        Epoch storage newEpoch = lottery.epochs[lottery.currentEpoch];
        newEpoch.startTime = uint40(block.timestamp);
        newEpoch.endTime = uint40(block.timestamp + lottery.distributionInterval);
        newEpoch.totalFees = 0;
        delete newEpoch.participants; // Reset participants
    }

    /**
     * @notice Adds a participant to the current epoch if not already present.
     * @param lottery The lottery storage reference.
     * @param swapper The address of the swapper to add.
     */
    function addParticipant(Lottery storage lottery, address swapper) internal {
        Epoch storage epoch = lottery.epochs[lottery.currentEpoch];
        if (!PoolPlayLib.contains(epoch.participants, swapper)) {
            epoch.participants.push(swapper);
        }
    }
}
