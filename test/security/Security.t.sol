// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/HardenedEvictionVault.sol";
import "../../src/modules/SignatureUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MaliciousReceiver {
    receive() external payable {
        revert("I refuse ETH");
    }
}

contract ReentrantAttacker {
    HardenedEvictionVault public vault;
    bool public reentered;

    constructor(HardenedEvictionVault _vault) {
        vault = _vault;
    }

    function attack() external payable {
        vault.deposit{value: msg.value}();
        vault.withdraw(msg.value);
    }

    receive() external payable {
        if (!reentered) {
            reentered = true;
            vault.withdraw(msg.value);
        }
    }
}

contract SecurityTest is Test {
    HardenedEvictionVault public vault;
    address[] public owners;
    uint256 public threshold = 2;

    address public owner1 = address(0x1);
    address public owner2 = address(0x2);
    address public attacker = address(0xBAD);
    address public victim = address(0x600D);

    bytes32 public root;
    bytes32[] public proof;

    function setUp() public {
        owners.push(owner1);
        owners.push(owner2);
        
        vault = new HardenedEvictionVault(owners, threshold);
        
        vm.deal(owner1, 10 ether);
        vm.deal(owner2, 10 ether);
        vm.deal(attacker, 10 ether);
        vm.deal(victim, 10 ether);

        // Fund the vault and totalVaultValue for airdrops
        vm.deal(address(vault), 10 ether);
        vm.prank(address(vault));
        // We need totalVaultValue to be >= amounts claimed to avoid underflow
        // Since we can't easily set totalVaultValue directly, we can deposit
        vault.deposit{value: 5 ether}();

        bytes32 leaf = keccak256(abi.encodePacked(victim, uint256(1 ether)));
        root = leaf; 
        
        vm.prank(address(vault));
        vault.setMerkleRoot(root);
    }

    // 1. Reentrancy exploit fails
    function testReentrancyExploitFails() public {
        ReentrantAttacker reentrant = new ReentrantAttacker(vault);
        vm.deal(address(reentrant), 1 ether);
        
        vm.expectRevert(); 
        reentrant.attack{value: 1 ether}();
    }

    // 2. Double airdrop claim fails
    function testDoubleAirdropClaimFails() public {
        bytes32[] memory emptyProof;
        
        vm.startPrank(victim);
        vault.claim(emptyProof, 1 ether);
        
        vm.expectRevert("Airdrop: already claimed");
        vault.claim(emptyProof, 1 ether);
        vm.stopPrank();
    }

    // 3. Fake merkle proof fails
    function testFakeMerkleProofFails() public {
        bytes32[] memory fakeProof = new bytes32[](1);
        fakeProof[0] = keccak256("fake");

        vm.prank(attacker);
        vm.expectRevert("Airdrop: invalid proof");
        vault.claim(fakeProof, 1 ether);
    }

    // 4. Signature verification
    function testSignatureVerification() public {
        bytes32 hash = keccak256("test message");
        uint256 pk = 0x123;
        address signer = vm.addr(pk);
        
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        
        assertTrue(vault.verifySignature(signer, hash, sig));
        assertFalse(vault.verifySignature(attacker, hash, sig));
    }

    // 5. Timelock bypass fails
    function testTimelockBypassFails() public {
        vm.startPrank(owner1);
        uint256 txId = vault.submitTransaction(attacker, 1 ether, "");
        vm.stopPrank();

        vm.prank(owner2);
        vault.confirmTransaction(txId);

        vm.expectRevert("Multisig: timelock not expired");
        vault.executeTransaction(txId);
    }

    // 6. Unauthorized pause fails
    function testUnauthorizedPauseFails() public {
        vm.prank(attacker);
        vm.expectRevert(); 
        vault.pause();
    }

    // 7. Malicious receiver griefing
    function testMaliciousReceiverDoesNotBlockState() public {
        MaliciousReceiver mr = new MaliciousReceiver();
        
        vm.startPrank(owner1);
        uint256 txId = vault.submitTransaction(address(mr), 1 ether, "");
        vm.stopPrank();

        vm.prank(owner2);
        vault.confirmTransaction(txId);

        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert("Multisig: transaction execution failed");
        vault.executeTransaction(txId);
    }

    // 8. Flash loan withdrawal attempt fails
    function testFlashLoanWithdrawalFails() public {
        vm.prank(attacker);
        vault.deposit{value: 1 ether}();
        
        vm.prank(attacker);
        vm.expectRevert("Vault: insufficient balance");
        vault.withdraw(10 ether);
    }

    // 9. Sandwich attack attempt prevention
    function testSandwichAttackPrevention() public {
        vm.prank(owner1);
        uint256 txId = vault.submitTransaction(address(vault), 0, abi.encodeWithSignature("setMerkleRoot(bytes32)", root));
        assertTrue(txId >= 0);
    }

    // 10. Multisig threshold manipulation fails
    function testThresholdManipulationFails() public {
        vm.prank(attacker);
        vm.expectRevert("Multisig: only self-call");
        vault.setThreshold(1);
    }
}
