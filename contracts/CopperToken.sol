//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CopperToken is ERC20 {
    constructor(uint256 _initialSupply) ERC20("Copper", "CPR") {
        _mint(msg.sender, _initialSupply);
    }
}