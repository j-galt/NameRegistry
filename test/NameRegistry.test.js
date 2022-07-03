const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NameRegistry", function () {

  let copperToken;
  let copperExchange;
  let sut;

  beforeEach(async function () {
    const copperTokenFactory = await ethers.getContractFactory("CopperToken");
    copperToken = await copperTokenFactory.deploy(1000);

    const copperExchageFactory = await ethers.getContractFactory("CopperExchange");
    copperExchange = await copperExchageFactory.deploy(copperToken.address);

    const nmeRegistryFactory = await ethers.getContractFactory("NameRegistry");
    sut = await nmeRegistryFactory.deploy(copperToken.address);

    await copperToken.transfer(copperExchange.address, 500);
    await copperToken.transfer(sut.address, 500);
  });


  describe("#registerName()", function () {

    it("Should register name for the caller", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")

      // Act
      const nameHash = await sut.connect(addr1).encryptName(name);
      await sut.connect(addr1).commitName(nameHash);

      const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);
      await copperToken.connect(addr1).approve(sut.address, namePrice);

      await sut.connect(addr1).registerName(name);

      // Assert
      expect(await sut.getAddressNames(addr1.address)).to.eql([name]);
    });

  });

  describe("#releaseAvailableFunds()", function () {

    it("Should allow to release copper token after name registration expires", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")

      const nameHash = await sut.connect(addr1).encryptName(name);
      await sut.connect(addr1).commitName(nameHash);

      const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);
      await copperToken.connect(addr1).approve(sut.address, namePrice);

      await sut.connect(addr1).registerName(name);
      await increaseBlockTimestamp(60 * 60 * 6);

      // Act
      await sut.connect(addr1).releaseAvailableFunds();

      // Assert
      expect(await copperToken.allowance(sut.address, addr1.address)).to.eql(await sut.getFixedCopperPerNameFee());
    });

    // fix this
    it("Should clean expired names", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name1 = "myName1", name2 = "myName2", name3 = "myName3";
      await buyCopperForEther(addr1, "1")

      await registerName(name1);
      await increaseBlockTimestamp(60 * 60 * 6);
      await registerName(name2);
      await registerName(name3);

      // Act
      await sut.connect(addr1).releaseAvailableFunds();

      // Assert
      expect(await sut.getAddressNames(addr1.address)).to.eql([ name2, name3 ]);
    });
  });

  async function buyCopperForEther(address, etherAmount) {
    const etherToPay = ethers.utils.parseEther(etherAmount);
    await copperExchange.connect(address).buy({ value: etherToPay });
  }

  async function increaseBlockTimestamp(increaseValueInSecods) {
    await ethers.provider.send('evm_increaseTime', [increaseValueInSecods]);
    await ethers.provider.send('evm_mine');
  }

  async function registerName(address, name) {
    const nameHash = await sut.connect(address).encryptName(name);
    await sut.connect(address).commitName(nameHash);

    const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name1);
    await copperToken.connect(address).approve(sut.address, namePrice);
  
    await sut.connect(address).registerName(name);
  }

});
