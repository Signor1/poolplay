// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title PoolPlayLib
 * @notice Library for common PoolPlay utility functions to optimize gas and code reuse.
 */
library PoolPlayLib {
    /**
     * @notice Calculates the lottery fee based on input amount and fee basis points.
     * @param inputAmount The amount of tokens spent in the swap.
     * @param feeBps Fee in basis points (e.g., 100 = 1%).
     * @return feeAmount The calculated fee amount.
     */
    function calculateFee(uint256 inputAmount, uint24 feeBps) internal pure returns (uint256) {
        return (inputAmount * feeBps) / 10_000;
    }

    /**
     * @notice Checks if an address is in an array.
     * @param array The array to search.
     * @param target The address to find.
     * @return exists True if the address is found.
     */
    function contains(address[] storage array, address target) internal view returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == target) return true;
        }
        return false;
    }
}
