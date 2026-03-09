// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TimelockExecutor
 * @notice Implements a secure timelock for transaction execution with a 1-hour delay.
 * Designed to be used as a modular component in the vault architecture.
 */
contract TimelockExecutor is AccessControl, ReentrancyGuard {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    uint256 public constant DELAY = 1 hours;
    uint256 public constant GRACE_PERIOD = 14 days;

    mapping(bytes32 => bool) public queuedTransactions;

    event TransactionQueued(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
    event TransactionExecuted(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data);
    event TransactionCancelled(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data);

    constructor(address admin) {
        require(admin != address(0), "Timelock: zero address admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PROPOSER_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, admin);
        _grantRole(CANCELLER_ROLE, admin);
    }

    /**
     * @dev Queues a transaction for future execution.
     * @param target The address of the contract to call.
     * @param value The amount of ETH to send.
     * @param signature The function signature (e.g., "transfer(address,uint256)").
     * @param data The encoded arguments for the function.
     * @param eta The timestamp at which the transaction can be executed.
     */
    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external onlyRole(PROPOSER_ROLE) returns (bytes32) {
        require(eta >= block.timestamp + DELAY, "Timelock: ETA below minimum delay");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(!queuedTransactions[txHash], "Timelock: transaction already queued");

        queuedTransactions[txHash] = true;

        emit TransactionQueued(txHash, target, value, signature, data, eta);
        return txHash;
    }

    /**
     * @dev Cancels a previously queued transaction.
     */
    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external onlyRole(CANCELLER_ROLE) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock: transaction not queued");

        queuedTransactions[txHash] = false;

        emit TransactionCancelled(txHash, target, value, signature, data);
    }

    /**
     * @dev Executes a queued transaction whose timelock has expired.
     */
    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable onlyRole(EXECUTOR_ROLE) nonReentrant returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock: transaction not queued");
        require(block.timestamp >= eta, "Timelock: transaction hasn't surpassed ETA");
        require(block.timestamp <= eta + GRACE_PERIOD, "Timelock: transaction is stale");

        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // Perform the external call
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock: transaction execution reverted");

        emit TransactionExecuted(txHash, target, value, signature, data);

        return returnData;
    }

    /**
     * @dev Allows the contract to receive ETH.
     */
    receive() external payable {}
}
