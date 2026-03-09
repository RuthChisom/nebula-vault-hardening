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
 */
contract HardenedEvictionVault is 
    IVault, 
    MultisigCore, 
    MerkleAirdrop, 
    PauseModule 
{
    mapping(address => uint256) public balances;
    uint256 public totalVaultValue;

    constructor(address[] memory owners, uint256 _threshold) 
        MultisigCore(owners, _threshold) 
    {
        _grantRole(PAUSER_ROLE, address(this));
        _grantRole(UNPAUSER_ROLE, address(this));
        _grantRole(AIRDROP_MANAGER_ROLE, address(this));
        
        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(UNPAUSER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(AIRDROP_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function deposit() external payable override whenNotPaused {
        _deposit(msg.sender, msg.value);
    }

    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    function _deposit(address user, uint256 amount) internal {
        balances[user] += amount;
        totalVaultValue += amount;
        emit Deposit(user, amount);
    }

    function withdraw(uint256 amount) external override whenNotPaused nonReentrant {
        require(balances[msg.sender] >= amount, "Vault: insufficient balance");
        
        balances[msg.sender] -= amount;
        totalVaultValue -= amount;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Vault: transfer failed");
        
        emit Withdrawal(msg.sender, amount);
    }

    function claim(bytes32[] calldata proof, uint256 amount) 
        public 
        override 
        whenNotPaused 
    {
        totalVaultValue -= amount; 
        super.claim(proof, amount);
    }

    function executeTransaction(uint256 txId) 
        public 
        payable 
        override 
    {
        uint256 value = transactions[txId].value;
        super.executeTransaction(txId);
        totalVaultValue -= value;
    }

    function emergencyWithdrawAll(address recipient) external {
        require(msg.sender == address(this), "Vault: only multisig self-call authorized");
        require(recipient != address(0), "Vault: zero address recipient");
        
        uint256 balance = address(this).balance;
        totalVaultValue = 0;
        
        (bool success, ) = recipient.call{value: balance}("");
        require(success, "Vault: emergency transfer failed");
    }

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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
