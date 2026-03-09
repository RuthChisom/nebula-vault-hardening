// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAirdrop
 * @notice Interface for Merkle-based airdrop claims.
 */
interface IAirdrop {
    event MerkleRootSet(bytes32 indexed newRoot);
    event Claim(address indexed claimant, uint256 amount);

    function setMerkleRoot(bytes32 root) external;
    function claim(bytes32[] calldata proof, uint256 amount) external;
    function isClaimed(address account) external view returns (bool);
}
