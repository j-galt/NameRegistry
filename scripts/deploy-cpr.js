const hre = require("hardhat");

async function main() {
  const copperTokenFactory = await hre.ethers.getContractFactory("CopperToken");
  const copperToken = await copperTokenFactory.deploy('100000000000000000000000');

  await copperToken.deployed();

  console.log("CopperToken deployed to:", copperToken.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
