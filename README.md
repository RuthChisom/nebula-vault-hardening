# Nebula Vault Hardening Protocol

A professional, modular, and security-hardened Solidity vault architecture designed to mitigate the vulnerabilities of traditional multi-signature vaults. This protocol integrates advanced governance features, including timelocked executions, Merkle-based airdrops, and role-based emergency controls.

## Architecture Overview

The protocol is built on a modular "plug-and-play" architecture, where core logic is decoupled into specialized abstract contracts and interfaces. This design minimizes the attack surface and ensures that each component can be audited and upgraded independently.

### Core Components
- **HardenedEvictionVault.sol**: The central orchestrator that integrates all modules and handles primary accounting.
- **Interfaces (`src/interfaces/`)**: Defines strict API boundaries for Vault, Multisig, Timelock, and Airdrop components.
- **Modules (`src/modules/`)**: Stateless and stateful logic blocks for specific protocol features.

---

## Module Breakdown

### 1. MultisigCore
A robust multi-signature implementation that manages owner roles and dynamic thresholds.
- **Security**: Prevents duplicate owners, zero-address assignments, and unauthorized threshold changes.
- **Governance**: All administrative actions must pass through a proposal and confirmation lifecycle.

### 2. TimelockExecutor
Ensures a mandatory **1-hour execution delay** for all multisig transactions.
- **Protection**: Mitigates "panic-execution" and provides a window for stakeholders to review or exit before changes take effect.
- **Grace Period**: Transactions expire if not executed within a specific window, preventing the execution of stale proposals.

### 3. MerkleAirdrop
A gas-efficient mechanism for reward distribution.
- **Efficiency**: Uses Merkle Proofs to offload state storage off-chain while maintaining on-chain integrity.
- **Integrity**: Integrated directly with vault accounting to prevent `totalVaultValue` underflows and double-claiming.

### 4. PauseModule
An advanced emergency circuit breaker.
- **Immediate Pause**: Can be triggered instantly by the Multisig in case of a detected exploit.
- **Timelocked Unpause**: Enforces a **24-hour delay** to unpause, ensuring users have time to react before the vault resume operations.

---

## Security Hardening (Vs. Original)

| Feature | Original Vault | Hardened Protocol |
| :--- | :--- | :--- |
| **Access Control** | Open `emergencyWithdrawAll` | Restricted to Multisig self-calls only |
| **Reentrancy** | Vulnerable (no guard) | Global `nonReentrant` modifiers |
| **Accounting** | Inconsistent `totalVaultValue` | Atomic updates on every ETH exit point |
| **Timelock** | Bypassed for threshold = 1 | Mandatory delays regardless of threshold |
| **Pause Logic** | Immediate unpause (dangerous) | 24-hour cooling-off period for unpausing |
| **Signatures** | Broken custom logic | OpenZeppelin `ECDSA` / EIP-191 Standard |
| **Ether Transfers** | Deprecated `transfer()` (gas issues) | Secure low-level `call` with success checks |

---

## Getting Started

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Solc 0.8.20](https://github.com/ethereum/solidity/releases/tag/v0.8.20) (Patched for OpenZeppelin 5.x compatibility)

### Installation
```bash
git clone https://github.com/nebula/vault-hardening.git
cd vault-hardening
forge install
```

### Build
```bash
forge build
```

### Run Security Tests
The protocol includes a specialized security suite covering reentrancy, replay attacks, and timelock bypasses.
```bash
forge test --match-path test/security/Security.t.sol -vvv
```

### Deployment
Update the `owners` array in `script/Deploy.s.sol` and run:
```bash
source .env
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

---

## License
This project is licensed under the **MIT License**.

## Security Analysis

A detailed security review and threat model can be found in:

[SECURITY_REPORT.md](https://github.com/RuthChisom/nebula-vault-hardening/blob/master/SECURITY_REPORT.md)
