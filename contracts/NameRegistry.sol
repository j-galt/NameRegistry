//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./CopperToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract NameRegistry is Ownable {
    CopperToken private _copperToken;
    uint private _copperPerNamePrice = 5;
    uint private _defaultNameOwnershipPeriodInSeconds = 60 * 60 * 5;

    mapping(address => string[]) private _addressNames;
    mapping(string => uint) private _nameOwnershipExpirationTimestamp;
    mapping(bytes32 => bool) private _nameHashes;

    NameRegistrationStage private _stage;

    event nameRegistered(string name, address owner, uint priceInCopper);
    event fundsReleased(uint releasedCopper, uint expiredNamesCount, address owner);

    constructor(address copperToken_) {
        _copperToken = CopperToken(copperToken_);
        _stage = NameRegistrationStage.Commit;
    }

    function commitName(bytes32 _nameHash) public {
        require(_stage == NameRegistrationStage.Commit, "Commiting a name is allowed only at commit stage.");
        require(!_nameHashes[_nameHash], "The name is already commited.");
        _nameHashes[_nameHash] = true;
    }

    function registerName(string calldata _name) onlyFreeNames(_name) public {
        require(_stage == NameRegistrationStage.Register, "Registering a name is allowed only at register stage.");

        verifyNameCommitedBySender(_name);

        uint nameRegistrationPriceInCopper = calculateNameRegistrationPrice(_name);

        require(_copperToken.allowance(msg.sender, address(this)) >= nameRegistrationPriceInCopper, 
            "The client hasn't set enough allowance for NameRegistry contract to pay for the name.");

        _addressNames[msg.sender].push(_name);
        _nameOwnershipExpirationTimestamp[_name] = block.timestamp + _defaultNameOwnershipPeriodInSeconds;

        _copperToken.transferFrom(msg.sender, address(this), nameRegistrationPriceInCopper);

        emit nameRegistered(_name, msg.sender, nameRegistrationPriceInCopper);
    }

    function releaseAvailableFunds() public {
        string[] storage registeredNames = _addressNames[msg.sender];

        uint expiredNamesCount = 0;
        for (uint i = 0; i < registeredNames.length; i++) {
            if (_nameOwnershipExpirationTimestamp[registeredNames[i]] < block.timestamp) {
                registeredNames[i] = registeredNames[registeredNames.length - 1];
                registeredNames.pop();
                expiredNamesCount++;
            }
        }

        uint releasedCopper = expiredNamesCount * _copperPerNamePrice;
        if (releasedCopper > 0) {
            _copperToken.approve(msg.sender, releasedCopper);
        }

        emit fundsReleased(releasedCopper, expiredNamesCount, msg.sender);
    }

    function changeNameRegistrationStage(NameRegistrationStage stage_) public onlyOwner {
        _stage = stage_;
    }

    function calculateNameRegistrationPrice(string calldata _name) onlyFreeNames(_name) public view returns(uint) {
        uint nameRegistrationFee = bytes(_name).length;
        return _copperPerNamePrice + nameRegistrationFee;
    }

    function getAddressNames(address _addr) public view returns(string[] memory names) {
        return _addressNames[_addr];
    }

    function encryptName(string calldata name) public view returns(bytes32 encrypted) {
        return keccak256(abi.encodePacked(msg.sender, name));
    }

    function getFixedCopperPerNameFee() public view returns(uint price) {
        return _copperPerNamePrice;
    }

    modifier onlyFreeNames(string calldata name) {
        require(_nameOwnershipExpirationTimestamp[name] < block.timestamp, "The name is already registered by someone.");
        _;
    }

    function verifyNameCommitedBySender(string calldata _name) private {
        bytes32 nameHash = encryptName(_name);
        require(_nameHashes[nameHash], "The name is not commited.");
        delete _nameHashes[nameHash];
    }
}

enum NameRegistrationStage {
    Commit,
    Register
}