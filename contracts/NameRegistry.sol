//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./CopperToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract NameRegistry is Ownable {
    CopperToken private _copperToken;
    uint256 private _copperPerNamePrice = 5;
    uint256 private _defaultNameOwnershipPeriodInSeconds = 60 * 60 * 5;

    mapping(address => string[]) private _addressNames;
    mapping(string => uint) private _nameOwnershipExpirationTimestamp;

    mapping(bytes32 => address) _nameHashes;

    constructor(address copperToken_) {
        _copperToken = CopperToken(copperToken_);
    }

    function commitName(bytes32 _nameHash) public {
        require(_nameHashes[_nameHash] == address(0), "The name is already commited.");
        _nameHashes[_nameHash] = msg.sender;
    }

    function registerName(string calldata _name) onlyFreeNames(_name) public {
        verifyNameCommitedBySender(_name);

        uint nameRegistrationPriceInCopper = calculateNameRegistrationPrice(_name);

        require(_copperToken.allowance(msg.sender, address(this)) >= nameRegistrationPriceInCopper, 
            "The client hasn't set enough allowance for NameRegistry contract to pay for the name.");

        _addressNames[msg.sender].push(_name);
        _nameOwnershipExpirationTimestamp[_name] = block.timestamp + _defaultNameOwnershipPeriodInSeconds;

        _copperToken.transferFrom(msg.sender, address(this), nameRegistrationPriceInCopper);

        // rainse en event NameBooked(name, msg.sender, nameRegistrationPriceInCopper);    
    }

    function calculateNameRegistrationPrice(string calldata _name) onlyFreeNames(_name) public view returns(uint) {
        uint nameRegistrationFee = 0;
        return _copperPerNamePrice + nameRegistrationFee;
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

        // raise an event {releasedCopper, expiredNamesCount, address}
    }

    function getAddressNames(address _addr) public view returns(string[] memory names) {
        return _addressNames[_addr];
    }

    function encryptName(string calldata name) public view returns(bytes32 encrypted) {
        return keccak256(abi.encodePacked(msg.sender, name));
    }

    modifier onlyFreeNames(string calldata name) {
        require(_nameOwnershipExpirationTimestamp[name] < block.timestamp, "The name is already booked by someone.");
        _;
    }

    function verifyNameCommitedBySender(string calldata _name) private {
        bytes32 nameHash = encryptName(_name);
        require(_nameHashes[nameHash] == msg.sender, "The name is already booked by someone or not commited at all.");
        _nameHashes[nameHash] = address(0);
    }

    function getFixedCopperPerNameFee() public view returns(uint price) {
        return _copperPerNamePrice;
    }
}