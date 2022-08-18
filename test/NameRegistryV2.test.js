const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NameRegistryV2", function () {

    let copperToken;
    let sut;

    beforeEach(async function () {
        const [_owner, addr1, addr2] = await ethers.getSigners();

        const copperTokenFactory = await ethers.getContractFactory("CopperToken");
        copperToken = await copperTokenFactory.deploy(1000);

        const nmeRegistryFactory = await ethers.getContractFactory("NameRegistryV2");
        sut = await nmeRegistryFactory.deploy(copperToken.address);

        await copperToken.transfer(addr1.address, 250);
        await copperToken.transfer(addr2.address, 250);
        await copperToken.transfer(sut.address, 500);
    });

    describe("#registerName()", function () {

        it("Front running case 1. Should assign the name registered by front runner to the earlier committer", async function () {
            // Arrange
            const [owner, addr1, frontRunner] = await ethers.getSigners();
            const name = "myName";
            const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);

            await copperToken.connect(addr1).approve(sut.address, namePrice);
            const nameHash = await sut.connect(addr1).getNameHash(name);
            await sut.connect(addr1).commitNameHash(nameHash);

            await copperToken.connect(frontRunner).approve(sut.address, namePrice);
            const frontRunnerNameHash = await sut.connect(frontRunner).getNameHash(name);
            await sut.connect(frontRunner).commitNameHash(frontRunnerNameHash);
            await sut.connect(frontRunner).registerName(name);

            // Act & Assert
            expect(await sut.connect(addr1).registerName(name))
                .to.emit(sut, "nameRegistered")
                .withArgs(name, addr1.address, namePrice);
        });

        it("Front running case 2. Should not register the name of the frontrunner if the frontrunner front run commit operation with the same name hash as the regular user", async function () {
            // Arrange
            const [owner, addr1, frontRunner] = await ethers.getSigners();
            const name = "myName";

            const nameHash = await sut.connect(addr1).getNameHash(name);

            await sut.connect(frontRunner).commitNameHash(nameHash);
            await sut.connect(addr1).commitNameHash(nameHash);

            // Act & Assert
            await expect(sut.connect(frontRunner).registerName(name)).to.be.revertedWith("Name not committed");
        });

        it("Should transfer copper from the caller to the contract", async function () {
            // Arrange
            const [owner, addr1] = await ethers.getSigners();
            const name = "myName";
            const intialBalanceOfContract = await copperToken.balanceOf(sut.address);
            const intialBalanceOfCaller = await copperToken.balanceOf(addr1.address);

            const nameHash = await sut.connect(addr1).getNameHash(name);
            await sut.connect(addr1).commitNameHash(nameHash);

            const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);
            await copperToken.connect(addr1).approve(sut.address, namePrice);

            // Act
            await sut.connect(addr1).registerName(name);

            // Assert
            expect(await copperToken.balanceOf(sut.address)).to.equal(intialBalanceOfContract.toNumber() + namePrice.toNumber());
            expect(await copperToken.balanceOf(addr1.address)).to.equal(intialBalanceOfCaller.toNumber() - namePrice.toNumber());
        });

        it("Should not register uncommited name", async function () {
            // Arrange
            const [owner, addr1] = await ethers.getSigners();
            const name = "myName";

            await approveCopperForName(name, addr1);

            // Act & Assert
            await expect(sut.connect(addr1).registerName(name)).to.be.revertedWith("Name not committed");
        });

        it("Should not register an already registered not expired name", async function () {
            // Arrange
            const [owner, addr1, addr2] = await ethers.getSigners();
            const name = "myName";

            await approveCopperForName(name, addr1);
            const nameHash = await sut.connect(addr1).getNameHash(name);
            await sut.connect(addr1).commitNameHash(nameHash);
            await sut.connect(addr1).registerName(name);

            await approveCopperForName(name, addr2);
            const nameHash2 = await sut.connect(addr2).getNameHash(name);
            await sut.connect(addr2).commitNameHash(nameHash2);

            // Act & Assert
            await expect(sut.connect(addr2).registerName(name)).to.not.emit(sut, "nameRegistered");
        });

        it("Should register an already registered expired name", async function () {
            // Arrange
            const [owner, addr1, addr2] = await ethers.getSigners();
            const name = "myName";
            const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);

            await copperToken.connect(addr1).approve(sut.address, namePrice);
            const nameHash = await sut.connect(addr1).getNameHash(name);
            await sut.connect(addr1).commitNameHash(nameHash);
            await sut.connect(addr1).registerName(name);
            await increaseBlockTimestamp(60 * 60 * 6);

            await copperToken.connect(addr2).approve(sut.address, namePrice);
            const nameHash2 = await sut.connect(addr2).getNameHash(name);
            await sut.connect(addr2).commitNameHash(nameHash2);

            // Act & Assert
            expect(await sut.connect(addr2).registerName(name))
                .to.emit(sut, "nameRegistered")
                .withArgs(name, addr2.address, namePrice);
        });

        it("Should not register a name if allowance of copper is not enough to pay for it", async function () {
            // Arrange
            const [owner, addr1] = await ethers.getSigners();
            const name = "myName";

            const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);
            await copperToken.connect(addr1).approve(sut.address, namePrice - 1);

            const nameHash = await sut.connect(addr1).getNameHash(name);
            await sut.connect(addr1).commitNameHash(nameHash);

            // Act & Assert
            await expect(sut.connect(addr1).registerName(name)).to.be.revertedWith("ERC20: insufficient allowance");
        });

    });

    describe("#commitNameHash()", function () {

        it("Should allow committing the same name hash for different addresses", async function () {
            // Arrange
            const [owner, addr1, frontRunner] = await ethers.getSigners();
            const name = "myName";

            const nameHash = await sut.connect(addr1).getNameHash(name);

            // Act & Assert
            await sut.connect(frontRunner).commitNameHash(nameHash);
            await sut.connect(addr1).commitNameHash(nameHash);
        });

        it("Should not allow committing the same name hash for the same address twice", async function () {
            // Arrange
            const [owner, addr1] = await ethers.getSigners();
            const name = "myName";

            const nameHash = await sut.connect(addr1).getNameHash(name);

            await sut.connect(addr1).commitNameHash(nameHash);

            // Act & Assert
            await expect(sut.connect(addr1).commitNameHash(nameHash)).to.be.revertedWith("Name already committed");
        });

    });

    describe("#releaseAvailableFunds()", function () {

        it("Should release copper token after name registration expires", async function () {
            // Arrange
            const [owner, addr1, addr2] = await ethers.getSigners();
            const name = "myName";
            const intitialBalance = await copperToken.balanceOf(addr1.address);
            const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);

            await copperToken.connect(addr1).approve(sut.address, namePrice);
            const nameHash = await sut.connect(addr1).getNameHash(name);
            await sut.connect(addr1).commitNameHash(nameHash);
            await sut.connect(addr1).registerName(name);
            await increaseBlockTimestamp(60 * 60 * 6);

            // Acts
            await sut.connect(addr1).releaseAvailableFunds([name]);

            // Assert
            expect((await copperToken.balanceOf(addr1.address)).toNumber())
                .to.eql(intitialBalance - (namePrice - await sut.getFixedCopperPerNameFee()));
        });

        it("Should release copper token only for expired names", async function () {
            // Arrange
            const [owner, addr1] = await ethers.getSigners();
            const name1 = "myName1", name2 = "myName2", name3 = "myName3";
            const intitialBalance = await copperToken.balanceOf(addr1.address);
            const namePrice1 = (await sut.connect(addr1).calculateNameRegistrationPrice(name1)).toNumber();
            const namePrice2 = (await sut.connect(addr1).calculateNameRegistrationPrice(name2)).toNumber();
            const namePrice3 = (await sut.connect(addr1).calculateNameRegistrationPrice(name3)).toNumber();
            const fixedCopperPerNameFee = await sut.getFixedCopperPerNameFee();

            await copperToken.connect(addr1).approve(sut.address, namePrice1);
            const nameHash1 = await sut.connect(addr1).getNameHash(name1);
            await sut.connect(addr1).commitNameHash(nameHash1);
            await sut.connect(addr1).registerName(name1);

            await copperToken.connect(addr1).approve(sut.address, namePrice2);
            const nameHash2 = await sut.connect(addr1).getNameHash(name2);
            await sut.connect(addr1).commitNameHash(nameHash2);
            await sut.connect(addr1).registerName(name2);

            await increaseBlockTimestamp(60 * 60 * 6);

            await copperToken.connect(addr1).approve(sut.address, namePrice3);
            const nameHash3 = await sut.connect(addr1).getNameHash(name3);
            await sut.connect(addr1).commitNameHash(nameHash3);
            await sut.connect(addr1).registerName(name3);

            // Act
            await sut.connect(addr1).releaseAvailableFunds([name1, name2, name3]);

            // Assert
            expect((await copperToken.balanceOf(addr1.address)).toNumber())
                .to.eql((intitialBalance - (namePrice1 + namePrice2 + namePrice3)) + fixedCopperPerNameFee * 2);
        });

        it("Should not release copper token second time for the same expired name (double spend)", async function () {
            // Arrange
            const [owner, addr1] = await ethers.getSigners();
            const name = "myName";
            const intitialBalance = await copperToken.balanceOf(addr1.address);
            const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);

            await copperToken.connect(addr1).approve(sut.address, namePrice);
            const nameHash = await sut.connect(addr1).getNameHash(name);
            await sut.connect(addr1).commitNameHash(nameHash);
            await sut.connect(addr1).registerName(name);
            await increaseBlockTimestamp(60 * 60 * 6);

            // Act
            await sut.connect(addr1).releaseAvailableFunds([name]);
            await sut.connect(addr1).releaseAvailableFunds([name]);

            // Assert
            expect((await copperToken.balanceOf(addr1.address)).toNumber())
                .to.eql(intitialBalance - (namePrice - await sut.getFixedCopperPerNameFee()));
        });

        it("Should not release copper token for not expired name", async function () {
            // Arrange
            const [owner, addr1] = await ethers.getSigners();
            const name = "myName";
            const intitialBalance = await copperToken.balanceOf(addr1.address);
            const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);

            await copperToken.connect(addr1).approve(sut.address, namePrice);
            const nameHash = await sut.connect(addr1).getNameHash(name);
            await sut.connect(addr1).commitNameHash(nameHash);
            await sut.connect(addr1).registerName(name);
            await increaseBlockTimestamp(60 * 60 * 4);

            // Act
            await sut.connect(addr1).releaseAvailableFunds([name]);

            // Assert
            expect((await copperToken.balanceOf(addr1.address)).toNumber())
                .to.eql(intitialBalance - namePrice);
        });

    });

    describe("#calculateNameRegistrationPrice()", function () {

        it("Should add the fee based on the name length to the fixed name price", async function () {
            // Arrange
            const [owner, addr1] = await ethers.getSigners();
            const name = "myName";
            const fixedNamePrice = await sut.getFixedCopperPerNameFee();

            // Act
            const namePrice = await sut.connect(addr1).calculateNameRegistrationPrice(name);

            // Assert
            expect(namePrice).to.equal(fixedNamePrice.toNumber() + name.length);
        });

    });

    async function approveCopperForName(name, address) {
        const namePrice = await sut.connect(address).calculateNameRegistrationPrice(name);
        await copperToken.connect(address).approve(sut.address, namePrice);
    }

    async function increaseBlockTimestamp(increaseValueInSecods) {
        await ethers.provider.send('evm_increaseTime', [increaseValueInSecods]);
        await ethers.provider.send('evm_mine');
    }

});