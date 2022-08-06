//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./CopperToken.sol";
import "hardhat/console.sol";

struct Committer {
    address addr;
    uint256 sequenceNumber;
}

struct Name {
    address owner;
    uint ownershipExpirationTimestamp;
}

contract NameRegistryV2 {
    CopperToken private _copperToken;
    uint private _copperPerNamePrice = 5;

    uint256 private sequenceNumber;
    mapping(bytes32 => Committer) private committedNameHashes;
    address[] private committers;

    mapping(string => Name) private _registeredNames;
    mapping(address => string[]) private _addressNames;
    uint private _defaultNameOwnershipPeriodInSeconds = 60 * 60 * 5;

    event nameRegistered(string name, address owner, uint priceInCopper);
    event fundsReleased(uint releasedCopper, uint expiredNamesCount, address owner);

    constructor(address copperToken) {
        _copperToken = CopperToken(copperToken);
    }

    function getNameHash(string memory name) public view returns (bytes32) {
        return getNameHash(name, msg.sender);
    }

    function commitNameHash(bytes32 nameHash) external {
        bytes32 hashOfNameHash = getHashOfNameHash(nameHash, msg.sender);

        require(committedNameHashes[hashOfNameHash].addr == address(0), "Name already committed");

        committedNameHashes[hashOfNameHash] = Committer({ addr: msg.sender, sequenceNumber: sequenceNumber++ });
        committers.push(msg.sender);
    }

    function registerName(string memory name) external {
        bytes32 hashOfNameHash = getHashOfNameHash(getNameHash(name), msg.sender);

        Committer memory ownerCandidate = committedNameHashes[hashOfNameHash];
        require(ownerCandidate.addr == msg.sender, "Name not committed");

        if (nameExpired(name)) {
            unregisterName(_registeredNames[name].owner, name);
            registerName(ownerCandidate.addr, name);
        } 
        else if (_registeredNames[name].owner != address(0)) {
            bytes32 hashOfNameHashOfNameOwner = getHashOfNameHash(
                getNameHash(name, _registeredNames[name].owner),
                _registeredNames[name].owner
            );

            Committer memory nameOwner = committedNameHashes[hashOfNameHashOfNameOwner];

            if (ownerCandidate.sequenceNumber < nameOwner.sequenceNumber) {
                unregisterName(nameOwner.addr, name);
                registerName(ownerCandidate.addr, name);
            }
            else {
                revert("Name already registered by someone"); 
            }
        }
        else {
            registerName(ownerCandidate.addr, name);
        }
    }

    function getAddressNames(address addr) public view returns(string[] memory names) {
        return _addressNames[addr];
    }

    function releaseAvailableFunds() public {
        string[] memory names = _addressNames[msg.sender];

        uint expiredNamesCount = 0;
        for (uint i = 0; i < names.length; i++) {
            Name memory name = _registeredNames[names[i]];

            if (name.ownershipExpirationTimestamp < block.timestamp) {
                unregisterName(msg.sender, names[i]);
                expiredNamesCount++;
            }
        }

        uint releasedCopper = expiredNamesCount * _copperPerNamePrice;
        if (releasedCopper > 0) {
            _copperToken.approve(msg.sender, releasedCopper);
        }

        emit fundsReleased(releasedCopper, expiredNamesCount, msg.sender);
    }

    function getFixedCopperPerNameFee() public view returns(uint price) {
        return _copperPerNamePrice;
    }

    function getNameHash(string memory name, address sender)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(name, sender));
    }

    function getHashOfNameHash(bytes32 nameHash, address addr)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(nameHash, addr));
    }

    function unregisterName(address nameOwner, string memory name) private {
        string[] storage ownerNames = _addressNames[nameOwner];

        for (uint i = 0; i < ownerNames.length; i++) {
            if (stringsEqual(ownerNames[i], name)) {
                ownerNames[i] = ownerNames[ownerNames.length - 1];
                ownerNames.pop();
                delete _registeredNames[name];
            }
        }
    }

    function registerName(address nameOwner, string memory name) private {
        uint nameRegistrationPriceInCopper = calculateNameRegistrationPrice(name);

        require(_copperToken.allowance(msg.sender, address(this)) >= nameRegistrationPriceInCopper, 
            "The client hasn't set enough allowance for NameRegistry contract to pay for the name.");

        _registeredNames[name] = Name({ owner : nameOwner, ownershipExpirationTimestamp : block.timestamp + _defaultNameOwnershipPeriodInSeconds });
        _addressNames[nameOwner].push(name);

        _copperToken.transferFrom(msg.sender, address(this), nameRegistrationPriceInCopper);

        emit nameRegistered(name, nameOwner, nameRegistrationPriceInCopper);
    }

    function calculateNameRegistrationPrice(string memory _name) public view returns(uint) {
        uint nameRegistrationFee = bytes(_name).length;
        return _copperPerNamePrice + nameRegistrationFee;
    }

    function stringsEqual(string memory a, string memory b) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function nameExpired(string memory name) private view returns(bool) {
        Name memory registeredName = _registeredNames[name];
        return registeredName.ownershipExpirationTimestamp > 0 && registeredName.ownershipExpirationTimestamp < block.timestamp;
    }
}
