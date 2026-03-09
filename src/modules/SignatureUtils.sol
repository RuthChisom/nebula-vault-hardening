// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title SignatureUtils
 * @notice Reusable signature verification logic using OpenZeppelin standards.
 */
library SignatureUtils {
    using MessageHashUtils for bytes32;

    function verify(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (bool) {
        if (signer == address(0)) return false;
        return ECDSA.recover(hash.toEthSignedMessageHash(), signature) == signer;
    }
}
