// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title PauseModule
 * @notice Implements a secure pausing mechanism.
 * pause() is restricted to the multisig (PAUSER_ROLE).
 * unpause() requires a 24-hour timelock after being requested.
 */
abstract contract PauseModule is Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    uint256 public constant UNPAUSE_DELAY = 24 hours;
    uint256 public unpauseTimestamp;

    event UnpauseRequested(address indexed requester, uint256 eligibleAt);
    event UnpauseCancelled(address indexed canceller);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Immediately pauses the contract.
     * Restricted to PAUSER_ROLE (intended for the Multisig).
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
        unpauseTimestamp = 0; // Reset any pending unpause
    }

    /**
     * @dev Initiates the 24-hour timelock for unpausing.
     */
    function requestUnpause() external onlyRole(UNPAUSER_ROLE) whenPaused {
        unpauseTimestamp = block.timestamp + UNPAUSE_DELAY;
        emit UnpauseRequested(msg.sender, unpauseTimestamp);
    }

    /**
     * @dev Executes the unpause after the 24-hour delay has passed.
     */
    function unpause() external onlyRole(UNPAUSER_ROLE) whenPaused {
        require(unpauseTimestamp != 0, "PauseModule: unpause not requested");
        require(block.timestamp >= unpauseTimestamp, "PauseModule: timelock not expired");
        
        unpauseTimestamp = 0;
        _unpause();
    }

    /**
     * @dev Allows cancelling a pending unpause request.
     */
    function cancelUnpause() external onlyRole(PAUSER_ROLE) {
        unpauseTimestamp = 0;
        emit UnpauseCancelled(msg.sender);
    }
}
