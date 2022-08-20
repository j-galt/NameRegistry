//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface INameRegistry {
    struct Committer {
        address addr;
        uint96 _sequenceNumber;
    }

    struct Name {
        address owner;
        uint64 ownershipExpirationTimestamp;
    }

    event nameRegistered(address indexed owner, string name, uint256 priceInCopper);
    event fundsReleased(address indexed receiver, uint256 releasedCopper);
}
