//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./CopperToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NameRegistry is Ownable {
    CopperToken private _copperToken;
    uint256 private _copperPerNamePrice = 5;
    uint256 private _defaultNameOwnershipPeriodInSeconds = 60 * 60 * 5;

    mapping(address => string[]) private _addressNames;
    mapping(string => uint) private _nameOwnershipExpirationTimestamp;

    constructor(address copperToken_) {
        _copperToken = CopperToken(copperToken_);
    }

    function registerName(string calldata _name) onlyFreeNames(_name) public {
        uint nameRegistrationPriceInCopper = calculateNameRegistrationPrice(_name);

        require(_copperToken.allowance(msg.sender, address(this)) >= nameRegistrationPriceInCopper, 
            "The client hasn't set enough allowance for the owner to pay for the name.");

        _addressNames[msg.sender].push(_name);
        _nameOwnershipExpirationTimestamp[_name] = _defaultNameOwnershipPeriodInSeconds;

        _copperToken.transferFrom(msg.sender, address(this), nameRegistrationPriceInCopper);

        // rainse en event NameBooked(name, msg.sender, nameRegistrationPriceInCopper);    
    }

    function calculateNameRegistrationPrice(string calldata _name) onlyFreeNames(_name) public view returns(uint) {
        uint nameRegistrationFee = 0;
        return _copperPerNamePrice + nameRegistrationFee;
    }

    function releaseAvailableFunds() public {
        string[] memory registeredNames = _addressNames[msg.sender];

        uint expiredNamesCount = 0;
        for (uint i = 0; i < registeredNames.length; i++) {
            if (_nameOwnershipExpirationTimestamp[registeredNames[i]] < block.timestamp) {
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

    modifier onlyFreeNames(string calldata name) {
        require(_nameOwnershipExpirationTimestamp[name] < block.timestamp, "The name is already booked by someone.");
        _;
    }
}