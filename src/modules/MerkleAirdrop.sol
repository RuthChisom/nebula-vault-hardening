// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IAirdrop.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Logic for Merkle-based airdrop claims with administrative controls.
abstract contract MerkleAirdrop is IAirdrop, AccessControl, ReentrancyGuard {
    bytes32 public constant AIRDROP_MANAGER_ROLE = keccak256("AIRDROP_MANAGER_ROLE");
    
    bytes32 public override merkleRoot;
    mapping(address => bool) public override claimed;

    // Sets the Merkle root for claims - Restricted to addresses with the AIRDROP_MANAGER_ROLE.
    function setMerkleRoot(bytes32 root) external override onlyRole(AIRDROP_MANAGER_ROLE) {
        merkleRoot = root;
        emit MerkleRootSet(root);
    }

    /**
     * @dev Allows a user to claim their allocated amount by providing a Merkle proof.
     */
    function claim(bytes32[] calldata proof, uint256 amount) external override nonReentrant {
        require(merkleRoot != bytes32(0), "Airdrop: root not set");
        require(!claimed[msg.sender], "Airdrop: already claimed");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Airdrop: invalid proof");

        claimed[msg.sender] = true;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Airdrop: transfer failed");

        emit Claim(msg.sender, amount);
    }

    function isClaimed(address account) external view override returns (bool) {
        return claimed[account];
    }
}
