// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITimelock
 * @notice Interface for timelock-related logic and constraints.
 */
interface ITimelock {
    event TimelockDurationUpdated(uint256 newDuration);

    function TIMELOCK_DURATION() external view returns (uint256);
    function getMinExecutionTime(uint256 submissionTime) external view returns (uint256);
}
