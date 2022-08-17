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

/** @title Name Registry */
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

    /**
    @notice Gets hash of the name.
    @param name Name to be registered.
    @return hash Hash of the name.
    */
    function getNameHash(string memory name) public view returns (bytes32) {
        return getNameHash(name, msg.sender);
    }

    /**
    @notice Commits name hash got from getNameHash function.
    @param nameHash Hash of the name.
    */
    function commitNameHash(bytes32 nameHash) external {
        bytes32 hashOfNameHash = getHashOfNameHash(nameHash, msg.sender);

        require(committedNameHashes[hashOfNameHash].addr == address(0), "Name already committed");

        committedNameHashes[hashOfNameHash] = Committer({ addr: msg.sender, sequenceNumber: sequenceNumber++ });
        committers.push(msg.sender);
    }

    /**
    @notice Registers the name. The name should be committed beforehand as well as the required amount of tokens should be allowed to be taken by this contract.
    @notice Front-running protection. If the name is submitted by a front runner, it will give it back to the earlier committer once the leter calls the function.
    @notice Name expires in some time.
    @param name Name to be registered.
    */
    function registerName(string memory name) external {
        bytes32 hashOfNameHash = getHashOfNameHash(getNameHash(name), msg.sender);

        Committer memory ownerCandidate = committedNameHashes[hashOfNameHash];
        require(ownerCandidate.addr == msg.sender, "Name not committed");
        
        address newNameOwnerAddress = ownerCandidate.addr;
        Name memory registeredName = _registeredNames[name];

        if (registeredName.owner != address(0)) {
            bytes32 hashOfNameHashOfNameOwner = getHashOfNameHash(
                getNameHash(name, registeredName.owner),
                registeredName.owner
            );

            Committer memory currentNameOwner = committedNameHashes[hashOfNameHashOfNameOwner];

            if (ownerCandidate.sequenceNumber > currentNameOwner.sequenceNumber
                && !nameExpired(registeredName.ownershipExpirationTimestamp)) {
                newNameOwnerAddress = currentNameOwner.addr;
            }
        }
        
        if (msg.sender == newNameOwnerAddress) {
            registerName(newNameOwnerAddress, name);
        }
    }

    /**
    @notice Gets the registered names of the address.
    @param addr Owner of names.
    @return names Registered names.
    */
    function getAddressNames(address addr) external view returns(string[] memory names) {
        return _addressNames[addr];
    }

    /**
    @notice Releases the fixed portion of the price of names that expired.
    */
    function releaseAvailableFunds() external {
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

    /**
    @notice Gets the fixed portion of the price per name in Copper Token.
    @return price The price per name in Copper Token.
    */
    function getFixedCopperPerNameFee() external view returns(uint price) {
        return _copperPerNamePrice;
    }

    /**
    @notice Calculates name registration price in Copper Token based on the name length.
    @param name Name to be evaluated.
    @return price Name registration price in Copper Token.
    */
    function calculateNameRegistrationPrice(string memory name) public view returns(uint) {
        uint nameRegistrationFee = bytes(name).length;
        return _copperPerNamePrice + nameRegistrationFee;
    }

    function getNameHash(string memory name, address sender) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(name, sender));
    }

    function getHashOfNameHash(bytes32 nameHash, address addr) private pure returns (bytes32) {
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

    function stringsEqual(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function nameExpired(uint ownershipExpirationTimestamp) private view returns(bool) {
        return ownershipExpirationTimestamp > 0 && ownershipExpirationTimestamp < block.timestamp;
    }
}
