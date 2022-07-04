const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NameRegistry", function () {

  let copperToken;
  let copperExchange;
  let sut;
  let owner;

  beforeEach(async function () {
    const [_owner] = await ethers.getSigners();
    owner = _owner;

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

      const nameHash = await sut.connect(addr1).encryptName(name);
      await sut.connect(addr1).commitName(nameHash);

      const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);
      await copperToken.connect(addr1).approve(sut.address, namePrice);

      await sut.connect(owner).changeNameRegistrationStage(NameRegistrationStage.Register);

      // Act
      await sut.connect(addr1).registerName(name);

      // Assert
      expect(await sut.getAddressNames(addr1.address)).to.eql([name]);
    });

    it("Should transfer copper from the caller to the contract", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")
      const intialBalanceOfContract = await copperToken.balanceOf(sut.address);
      const intialBalanceOfCaller = await copperToken.balanceOf(addr1.address);

      const nameHash = await sut.connect(addr1).encryptName(name);
      await sut.connect(addr1).commitName(nameHash);

      const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);
      await copperToken.connect(addr1).approve(sut.address, namePrice);

      await sut.connect(owner).changeNameRegistrationStage(NameRegistrationStage.Register);

      // Act
      await sut.connect(addr1).registerName(name);

      // Assert
      expect(await copperToken.balanceOf(sut.address)).to.equal(intialBalanceOfContract.toNumber() + namePrice.toNumber());
      expect(await copperToken.balanceOf(addr1.address)).to.equal(intialBalanceOfCaller.toNumber() - namePrice.toNumber());
    });

    it("Should not register name at commit stage", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")

      const nameHash = await sut.connect(addr1).encryptName(name);
      await sut.connect(addr1).commitName(nameHash);

      const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);
      await copperToken.connect(addr1).approve(sut.address, namePrice);

      // Act & Assert
      await expect(sut.connect(addr1).registerName(name)).to.be.revertedWith("Registering a name is allowed only at register stage.");
    });

    it("Should not register uncommited name", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")

      const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);
      await copperToken.connect(addr1).approve(sut.address, namePrice);

      await sut.connect(owner).changeNameRegistrationStage(NameRegistrationStage.Register);

      // Act & Assert
      await expect(sut.connect(addr1).registerName(name)).to.be.revertedWith("The name is not commited.");
    });

    it("Should not register an already registered not expired name", async function () {
      // Arrange
      const [owner, addr1, addr2] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")
      await buyCopperForEther(addr2, "1")

      await registerName(addr1, name);

      await sut.connect(owner).changeNameRegistrationStage(NameRegistrationStage.Commit);

      await copperToken.connect(addr2).approve(sut.address, 20);
      const nameHash = await sut.connect(addr2).encryptName(name);
      await sut.connect(addr2).commitName(nameHash);

      await sut.connect(owner).changeNameRegistrationStage(NameRegistrationStage.Register);

      // Act & Assert
      await expect(sut.connect(addr2).registerName(name)).to.be.revertedWith("The name is already registered by someone.");
    });

    it("Should register an already registered expired name", async function () {
      // Arrange
      const [owner, addr1, addr2] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")
      await buyCopperForEther(addr2, "1")

      await registerName(addr1, name);
      await increaseBlockTimestamp(60 * 60 * 6);

      await sut.connect(owner).changeNameRegistrationStage(NameRegistrationStage.Commit);

      await copperToken.connect(addr2).approve(sut.address, 20);
      const nameHash = await sut.connect(addr2).encryptName(name);
      await sut.connect(addr2).commitName(nameHash);

      await sut.connect(owner).changeNameRegistrationStage(NameRegistrationStage.Register);

      // Act 
      await sut.connect(addr2).registerName(name);

      // Assert
      expect(await sut.getAddressNames(addr2.address)).to.eql([name]);
    });

    it("Should not register a name if allowance of copper is not enough to pay for it", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")

      const nameHash = await sut.connect(addr1).encryptName(name);
      await sut.connect(addr1).commitName(nameHash);

      const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);
      await copperToken.connect(addr1).approve(sut.address, namePrice - 1);

      await sut.connect(owner).changeNameRegistrationStage(NameRegistrationStage.Register);

      // Act & Assert
      await expect(sut.connect(addr1).registerName(name))
        .to.be.revertedWith("The client hasn't set enough allowance for NameRegistry contract to pay for the name.");
    });

  });

  describe("#commitName()", function () {
    it("Should not commit a name at register stage", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")

      const nameHash = await sut.connect(addr1).encryptName(name);

      await sut.connect(owner).changeNameRegistrationStage(NameRegistrationStage.Register);

      // Act & Assert
      await expect(sut.connect(addr1).commitName(nameHash)).to.be.revertedWith("Commiting a name is allowed only at commit stage.");
    });

    it("Should not commit a duplicate name", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")

      const nameHash = await sut.connect(addr1).encryptName(name);
      await sut.connect(addr1).commitName(nameHash)

      // Act & Assert
      await expect(sut.connect(addr1).commitName(nameHash)).to.be.revertedWith("The name is already commited.");
    });

  });

  describe("#releaseAvailableFunds()", function () {

    it("Should release copper token after name registration expires", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")

      await registerName(addr1, name);
      await increaseBlockTimestamp(60 * 60 * 6);

      // Act
      await sut.connect(addr1).releaseAvailableFunds();

      // Assert
      expect(await copperToken.allowance(sut.address, addr1.address)).to.eql(await sut.getFixedCopperPerNameFee());
    });

    it("Should release copper token only for expired names", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name1 = "myName1", name2 = "myName2", name3 = "myName3";
      await buyCopperForEther(addr1, "1")

      await registerName(addr1, name1);
      await registerName(addr1, name2);
      await increaseBlockTimestamp(60 * 60 * 6);
      await registerName(addr1, name3);

      // Act
      await sut.connect(addr1).releaseAvailableFunds();

      // Assert
      expect(await copperToken.allowance(sut.address, addr1.address)).to.equal(await sut.getFixedCopperPerNameFee() * 2);
    });

    it("Should not release copper token second time for the same expired name (double spend)", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")

      await registerName(addr1, name);
      await increaseBlockTimestamp(60 * 60 * 6);

      // Act
      await sut.connect(addr1).releaseAvailableFunds();
      await sut.connect(addr1).releaseAvailableFunds();

      // Assert
      expect(await copperToken.allowance(sut.address, addr1.address)).to.eql(await sut.getFixedCopperPerNameFee());
    });

    it("Should not release copper token for not expired name", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name = "myName";
      await buyCopperForEther(addr1, "1")

      await registerName(addr1, name);
      await increaseBlockTimestamp(60 * 60 * 4);

      // Act
      await sut.connect(addr1).releaseAvailableFunds();

      // Assert
      expect(await copperToken.allowance(sut.address, addr1.address)).to.equal(0);
    });

    it("Should clean expired names", async function () {
      // Arrange
      const [owner, addr1] = await ethers.getSigners();
      const name1 = "myName1", name2 = "myName2", name3 = "myName3";
      await buyCopperForEther(addr1, "1")

      await registerName(addr1, name1);
      await increaseBlockTimestamp(60 * 60 * 6);
      await registerName(addr1, name2);
      await registerName(addr1, name3);

      // Act
      await sut.connect(addr1).releaseAvailableFunds();

      // Assert
      expect(await sut.getAddressNames(addr1.address)).to.eql([name3, name2]);
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
    await sut.connect(owner).changeNameRegistrationStage(NameRegistrationStage.Commit);

    const nameHash = await sut.connect(address).encryptName(name);
    await sut.connect(address).commitName(nameHash);

    await sut.connect(owner).changeNameRegistrationStage(NameRegistrationStage.Register);

    const namePrice = await sut.connect(address).calculateNameRegistrationPrice(name);
    await copperToken.connect(address).approve(sut.address, namePrice);

    await sut.connect(address).registerName(name);
  }

});

const NameRegistrationStage = {
  Commit: 0,
  Register: 1
}