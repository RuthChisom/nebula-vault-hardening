// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IMultisig.sol";
import "../interfaces/ITimelock.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MultisigCore
 * @notice Core multisig logic with integrated timelock and role-based access control.
 */
abstract contract MultisigCore is IMultisig, ITimelock, AccessControl, ReentrancyGuard {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    
    uint256 public threshold;
    uint256 public txCount;
    uint256 public constant TIMELOCK_DURATION = 1 hours;
    
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmed;

    modifier onlyOwner() {
        require(hasRole(OWNER_ROLE, msg.sender), "Multisig: caller is not an owner");
        _;
    }

    constructor(address[] memory owners, uint256 _threshold) {
        require(owners.length > 0, "Multisig: no owners provided");
        require(_threshold > 0 && _threshold <= owners.length, "Multisig: invalid threshold");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        for (uint256 i = 0; i < owners.length; i++) {
            require(owners[i] != address(0), "Multisig: zero address owner");
            require(!hasRole(OWNER_ROLE, owners[i]), "Multisig: duplicate owner");
            _grantRole(OWNER_ROLE, owners[i]);
        }
        threshold = _threshold;
    }

    function setThreshold(uint256 _threshold) external {
        require(msg.sender == address(this), "Multisig: only self-call");
        require(_threshold > 0, "Multisig: invalid threshold");
        threshold = _threshold;
    }

    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data
    ) external virtual override onlyOwner returns (uint256 txId) {
        require(to != address(0), "Multisig: zero address recipient");
        
        txId = txCount++;
        transactions[txId] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 0,
            submissionTime: block.timestamp,
            executionTime: 0
        });

        emit Submission(txId, msg.sender);
        _confirmTransaction(txId, msg.sender);
    }

    function confirmTransaction(uint256 txId) external virtual override onlyOwner {
        _confirmTransaction(txId, msg.sender);
    }

    function _confirmTransaction(uint256 txId, address owner) internal {
        Transaction storage txn = transactions[txId];
        require(txn.submissionTime > 0, "Multisig: tx does not exist");
        require(!txn.executed, "Multisig: tx already executed");
        require(!confirmed[txId][owner], "Multisig: tx already confirmed");

        confirmed[txId][owner] = true;
        txn.confirmations++;

        emit Confirmation(txId, owner);

        if (txn.confirmations == threshold && txn.executionTime == 0) {
            txn.executionTime = block.timestamp + TIMELOCK_DURATION;
        }
    }

    function executeTransaction(uint256 txId) public payable virtual override nonReentrant {
        Transaction storage txn = transactions[txId];
        require(txn.confirmations >= threshold, "Multisig: threshold not met");
        require(!txn.executed, "Multisig: tx already executed");
        require(block.timestamp >= txn.executionTime && txn.executionTime != 0, "Multisig: timelock not expired");

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        if (success) {
            emit Execution(txId);
        } else {
            txn.executed = false; 
            emit ExecutionFailure(txId);
            revert("Multisig: transaction execution failed");
        }
    }

    function isOwner(address account) public view virtual override returns (bool) {
        return hasRole(OWNER_ROLE, account);
    }

    function getThreshold() public view virtual override returns (uint256) {
        return threshold;
    }

    function getMinExecutionTime(uint256 submissionTime) external pure virtual override returns (uint256) {
        return submissionTime + TIMELOCK_DURATION;
    }
}
