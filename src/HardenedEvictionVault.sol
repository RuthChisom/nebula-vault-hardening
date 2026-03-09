// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IVault.sol";
import "./modules/MultisigCore.sol";
import "./modules/MerkleAirdrop.sol";
import "./modules/PauseModule.sol";
import "./modules/SignatureUtils.sol";

/**
 * @title HardenedEvictionVault
 * @notice A professional, modular vault architecture that hardens the original EvictionVault.
 * Combines multisig governance, timelock delays, Merkle airdrops, and role-based access control.
 */
contract HardenedEvictionVault is 
    IVault, 
    MultisigCore, 
    MerkleAirdrop, 
    PauseModule 
{
    mapping(address => uint256) public balances;
    uint256 public override totalVaultValue;

    constructor(address[] memory owners, uint256 _threshold) 
        MultisigCore(owners, _threshold) 
    {
        // Grant roles to the Multisig (this contract itself)
        _grantRole(PAUSER_ROLE, address(this));
        _grantRole(UNPAUSER_ROLE, address(this));
        _grantRole(AIRDROP_MANAGER_ROLE, address(this));
        
        // Ensure the Multisig is the admin of its own roles
        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(UNPAUSER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(AIRDROP_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev Handles ETH deposits and updates user accounting.
     */
    function deposit() external payable override whenNotPaused {
        _deposit(msg.sender, msg.value);
    }

    /**
     * @dev Fallback to handle direct ETH transfers.
     */
    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    function _deposit(address user, uint256 amount) internal {
        balances[user] += amount;
        totalVaultValue += amount;
        emit Deposit(user, amount);
    }

    /**
     * @dev Allows users to withdraw their deposited ETH.
     * Implements reentrancy protection and state-first updates.
     */
    function withdraw(uint256 amount) external override whenNotPaused nonReentrant {
        require(balances[msg.sender] >= amount, "Vault: insufficient balance");
        
        balances[msg.sender] -= amount;
        totalVaultValue -= amount;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Vault: transfer failed");
        
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev Claim rewards from the Merkle Airdrop.
     * Overrides and updates vault accounting.
     */
    function claim(bytes32[] calldata proof, uint256 amount) 
        external 
        override(IAirdrop, MerkleAirdrop) 
        whenNotPaused 
    {
        // Update vault accounting before proceeding with the claim transfer in MerkleAirdrop
        totalVaultValue -= amount; 
        super.claim(proof, amount);
    }

    /**
     * @dev Executes a multisig transaction after the timelock expires.
     * Updates totalVaultValue to maintain accounting integrity.
     */
    function executeTransaction(uint256 txId) 
        external 
        payable 
        override(IMultisig, MultisigCore) 
    {
        uint256 value = transactions[txId].value;
        super.executeTransaction(txId);
        
        // If execution succeeded, decrement totalVaultValue
        totalVaultValue -= value;
    }

    /**
     * @dev Secure emergency withdrawal. 
     * Restricted to a self-call from the Multisig itself, ensuring governance consensus.
     */
    function emergencyWithdrawAll(address recipient) external {
        require(msg.sender == address(this), "Vault: only multisig self-call authorized");
        require(recipient != address(0), "Vault: zero address recipient");
        
        uint256 balance = address(this).balance;
        totalVaultValue = 0;
        
        (bool success, ) = recipient.call{value: balance}("");
        require(success, "Vault: emergency transfer failed");
    }

    /**
     * @dev Verifies an Ethereum signed message signature using SignatureUtils.
     */
    function verifySignature(
        address signer,
        bytes32 messageHash,
        bytes memory signature
    ) external pure returns (bool) {
        return SignatureUtils.verify(signer, messageHash, signature);
    }

    function getBalance(address user) external view override returns (uint256) {
        return balances[user];
    }

    /**
     * @dev Required override for AccessControl and MultisigCore.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, MultisigCore)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
