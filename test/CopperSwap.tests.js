const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CopperSwap", function () {
  
  let sut;
  let wethToken;
  let copperToken;

  const wethOwner = "0x4bfeb3440b35051BB2ba0c1226bbdcB54d3f5D1B"; // 1.4 weth

  beforeEach(async function () {
    const routerAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
    const wethAddress = "0xc778417E063141139Fce010982780140Aa0cD5Ab";
    const cprTokenAddress = "0x318177EFd4756f374802f21Cbcd3f05936eA3756";

    wethToken = await ethers.getContractAt('IERC20', wethAddress);
    copperToken = await ethers.getContractAt('CopperToken', cprTokenAddress);

    const copperSwapFactory = await ethers.getContractFactory("CopperSwap");
    sut = await copperSwapFactory.deploy(cprTokenAddress, wethAddress, routerAddress);
  });

  describe("#swapExactInputSingle()", function () {

    it("Should swap CPR for WETH", async function () {
      // Arrange
      const impersonatedWethOwner = await impersonateAddress(wethOwner);

      const copperInitial = await copperToken.balanceOf(wethOwner);
      expect(copperInitial).to.equal(0);

      await wethToken.connect(impersonatedWethOwner).approve(sut.address, 1000);

      // Act
      await sut.connect(impersonatedWethOwner).swapExactInputSingle(1000);

      // Assert
      const copperBought = await copperToken.balanceOf(wethOwner);
      expect(copperBought).to.equal(9970988);    
    });

  });

});

const impersonateAddress = async (address) => {
  const hre = require('hardhat');
  await hre.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [address],
  });
  const signer = await ethers.provider.getSigner(address);
  signer.address = signer._address;
  return signer;
};