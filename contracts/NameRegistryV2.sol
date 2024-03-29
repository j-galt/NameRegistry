//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./INameRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

/// @title Name Registry with front-running protection.
/// @dev If a name is front run and the actual owner attempts to register the name, the ownership will be transfered
/// to the actual owner.
contract NameRegistryV2 is INameRegistry {
    ERC20 private _erc20Token;

    uint96 private _sequenceNumber;
    uint256 private _fixedTokenPerNamePrice;
    uint256 private _fixedTokenPerSymbolPrice;
    uint16 private constant _defaultNameOwnershipPeriodInSeconds = 60 * 60 * 5;

    mapping(bytes32 => Committer) private _committers;
    mapping(bytes32 => Name) private _registeredNames;

    constructor(address erc20Token) {
        _erc20Token = ERC20(erc20Token);
        _fixedTokenPerNamePrice = 5 * 10**_erc20Token.decimals();
        _fixedTokenPerSymbolPrice = 10**_erc20Token.decimals();
    }

    /// @notice Commits name hash got from getNameHash function.
    /// @param nameHash Hash of the name.
    function commitNameHash(bytes32 nameHash) external override {
        bytes32 committerIndex = _getCommitterIndex(nameHash, msg.sender);

        require(_committers[committerIndex].addr == address(0), "Name already committed");

        _committers[committerIndex] = Committer({
            addr: msg.sender,
            _sequenceNumber: _sequenceNumber++
        });

        emit nameHashCommitted(msg.sender, nameHash);
    }

    /// @notice Registers the name. The name should be committed beforehand as well as the required amount of tokens
    /// should be allowed to be taken by this contract.
    /// Front-running protection. If the name is submitted by a front runner,
    /// it will give it back to the earlier committer once the leter calls the function. Name expires in some time.
    /// @param name Name to be registered.
    function registerName(string memory name) external override {
        bytes32 committerIndex = _getCommitterIndex(getNameHash(name, msg.sender), msg.sender);

        Committer memory ownerCandidate = _committers[committerIndex];
        require(ownerCandidate.addr == msg.sender, "Name not committed");

        address newNameOwnerAddress = ownerCandidate.addr;
        Name memory registeredName = _registeredNames[_getNameIndex(name)];

        if (registeredName.owner != address(0)) {
            bytes32 committerIndexOfNameOwner = _getCommitterIndex(
                getNameHash(name, registeredName.owner),
                registeredName.owner
            );

            Committer memory currentNameOwner = _committers[committerIndexOfNameOwner];

            if (ownerCandidate._sequenceNumber > currentNameOwner._sequenceNumber 
                && !_nameExpired(registeredName.ownershipExpirationTimestamp)
            ) {
                newNameOwnerAddress = currentNameOwner.addr;
            }
        }

        if (msg.sender == newNameOwnerAddress) {
            _registerName(newNameOwnerAddress, name);
        }
    }

    /// @notice Releases the fixed portion of the price of names that expired.
    /// @param namesToBeReleased Collection of expired names to release the funds for.
    /// @dev namesToBeReleased Collection can be obtained by client code filtering nameRegistered events.
    function releaseAvailableFunds(string[] memory namesToBeReleased) external override {
        uint256 totalFundsToReturn;

        for (uint256 i = 0; i < namesToBeReleased.length;) {
            bytes32 nameIndex = _getNameIndex(namesToBeReleased[i]);
            Name memory name = _registeredNames[nameIndex];

            if (name.owner != address(0) && _nameExpired(name.ownershipExpirationTimestamp)) {
                totalFundsToReturn += _fixedTokenPerNamePrice;
                delete _registeredNames[nameIndex];
            }

            unchecked { i++; }
        }

        if (totalFundsToReturn > 0) {
            _erc20Token.transfer(msg.sender, totalFundsToReturn);
            emit fundsReleased(msg.sender, totalFundsToReturn);
        }
    }

    /// @notice Gets the fixed portion of the price per name in ERC20 token.
    /// @return price The price per name in ERC20 token.
    function getFixedNamePrice() external view override returns (uint256 price) {
        return _fixedTokenPerNamePrice;
    }

    /// @notice Checks if the addr is the owner of the name.
    /// @param addr Address to check.
    /// @param name Name to check.
    /// @return isOwner True if the addr is the owner of the name, false otherwise.
    function isNameOwner(address addr, string memory name) external view override returns (bool isOwner) {
        return _registeredNames[_getNameIndex(name)].owner == addr;
    }

    /// @notice Gets hash of the name.
    /// @param name Name to be registered.
    /// @return nameHash Hash of the name.
    function getNameHash(string memory name, address sender) public pure returns (bytes32 nameHash) {
        return keccak256(abi.encodePacked(name, sender));
    }

    /// @notice Calculates name registration price in ERC20 token based on the name length.
    /// @param name Name to be evaluated.
    /// @return price Name registration price in ERC20 token.
    function calculateNameRegistrationPrice(string memory name) public view returns (uint256 price) {
        uint256 nameRegistrationFee = bytes(name).length * _fixedTokenPerSymbolPrice;
        return _fixedTokenPerNamePrice + nameRegistrationFee;
    }

    /// @notice Transfers tokens from nameOwner and registers the name by writing to _registeredNames mapping.
    /// @param nameOwner Owner of the name.
    /// @param name Name to be registered.
    function _registerName(address nameOwner, string memory name) private {
        uint256 nameRegistrationPrice = calculateNameRegistrationPrice(name);

        _registeredNames[_getNameIndex(name)] = Name({
            owner: nameOwner,
            ownershipExpirationTimestamp: uint64(block.timestamp) + _defaultNameOwnershipPeriodInSeconds
        });

        _erc20Token.transferFrom(msg.sender, address(this), nameRegistrationPrice);

        emit nameRegistered(nameOwner, name, nameRegistrationPrice);
    }

    /// @notice Calculates the index for _committers mapping based on name hash and address.
    /// @param nameHash Hash of the name got from getNameHash() function.
    /// @param addr Address that calculated nameHash.
    /// @return index Index intended to be used in _committers mapping.
    function _getCommitterIndex(bytes32 nameHash, address addr) private pure returns (bytes32 index) {
        return keccak256(abi.encodePacked(nameHash, addr));
    }

    /// @notice Vhecks if the name is expired at the moment of a call.
    /// @param ownershipExpirationTimestamp Timestamp at which the name is considered expired, 
    /// calculated in _registerName() function.
    /// @return nameExpired True if name is expired, otherwise false.
    function _nameExpired(uint256 ownershipExpirationTimestamp) private view returns (bool nameExpired) {
        return ownershipExpirationTimestamp > 0 && ownershipExpirationTimestamp < block.timestamp;
    }

    /// @notice Calculates the index for _registeredNames mapping.
    /// @param name The name that the index is calculated from.
    /// @return nameIndex Index intended to be used in _registeredNames mapping.
    function _getNameIndex(string memory name) private pure returns (bytes32 nameIndex) {
        return keccak256(abi.encodePacked(name));
    }
}
