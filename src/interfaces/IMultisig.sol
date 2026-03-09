// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMultisig
 * @notice Interface for Multisig operations, transaction submission, and confirmation.
 */
interface IMultisig {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 submissionTime;
        uint256 executionTime;
    }

    event Submission(uint256 indexed txId, address indexed proposer);
    event Confirmation(uint256 indexed txId, address indexed owner);
    event Execution(uint256 indexed txId);
    event ExecutionFailure(uint256 indexed txId);

    function submitTransaction(address to, uint256 value, bytes calldata data) external returns (uint256 txId);
    function confirmTransaction(uint256 txId) external;
    function executeTransaction(uint256 txId) external payable;
    function isOwner(address account) external view returns (bool);
    function getThreshold() external view returns (uint256);
}
