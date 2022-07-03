//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CopperToken.sol";

contract CopperExchange is Ownable {
    CopperToken private _copperToken;
    uint private _tokenPriceInWei = 1 ether / 50;

    constructor(address _copperTokenAddress) {
        _copperToken = CopperToken(_copperTokenAddress);
    }

    function buy() public payable returns(uint tokensBought) {
        require(msg.value >= _tokenPriceInWei, "No ether is sent");

        uint tokenAmount = msg.value / _tokenPriceInWei;
        require(_copperToken.balanceOf(address(this)) >= tokenAmount, "Exchange does't have enough copper to send");

        _copperToken.transfer(msg.sender, tokenAmount);

        return tokenAmount;
    }
}