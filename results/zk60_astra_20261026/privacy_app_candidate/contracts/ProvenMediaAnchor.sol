// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// Testnet publication only. This contract records digests; it does not verify proofs.
contract ProvenMediaAnchor {
    address public immutable publisher;
    event Anchored(bytes32 indexed root, uint256 count, bytes32 batchFileHash);

    constructor() {
        require(block.chainid == 84532, "Base Sepolia only");
        publisher = msg.sender;
    }

    function anchor(bytes32 root, uint256 count, bytes32 batchFileHash) external {
        require(block.chainid == 84532, "Base Sepolia only");
        require(msg.sender == publisher, "publisher only");
        require(count > 0 && count <= 1000, "batch count");
        require(root != bytes32(0) && batchFileHash != bytes32(0), "empty digest");
        emit Anchored(root, count, batchFileHash);
    }
}
