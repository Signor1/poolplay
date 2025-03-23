// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IEigenLayerServiceManager
 * @dev Interface for interacting with EigenLayer AVS service manager
 */
interface IEigenLayerServiceManager {
    function registerOperator(address operator) external;
    function isActiveOperator(address operator) external view returns (bool);
    function getQuorum(bytes32 operationId) external view returns (uint256);
    function submitDataValidation(
        bytes32 operationId,
        bytes calldata data,
        uint256 value
    ) external;
    function aggregateValidations(
        bytes32 operationId
    ) external view returns (bytes memory, bool);
}
