//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface INameRegistry {
    struct Committer {
        address addr;
        uint256 _sequenceNumber;
    }

    struct Name {
        address owner;
        uint256 ownershipExpirationTimestamp;
    }

    event nameRegistered(string name, address owner, uint256 priceInCopper);
    event fundsReleased(uint256 releasedCopper, address owner);
}
