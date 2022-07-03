const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NameRegistry", function () {

  describe("#registerName()", function () {
    it("Should register name for the caller", async function () {
      const [owner, addr1, addr2] = await ethers.getSigners();

      const copperTokenFactory = await ethers.getContractFactory("CopperToken");
      const copperToken = await copperTokenFactory.deploy(1000);

      const copperExchageFactory = await ethers.getContractFactory("CopperExchange");
      const copperExchange = await copperExchageFactory.deploy(copperToken.address);

      const nmeRegistryFactory = await ethers.getContractFactory("NameRegistry");
      const sut = await nmeRegistryFactory.deploy(copperToken.address);

      await copperToken.transfer(copperExchange.address, 500);
      await copperToken.transfer(sut.address, 500);

      const etherToPay = ethers.utils.parseEther("1");
      await copperExchange.connect(addr1).buy({ value: etherToPay });

      const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice("myName");
      await copperToken.connect(addr1).approve(sut.address, namePrice);

      await sut.connect(addr1).registerName('myName');

      const names = await sut.getAddressNames(addr1.address);

      expect(names).to.eql(["myName"]);
    });
  });
});
