const hre = require("hardhat");

async function main() {
  const copperToken = await hre.ethers.getContractAt("CopperToken", "0xdcb6FcbDeC68FD2860daEd1ca900f2537e930049");

  const balance = await copperToken.balanceOf("0x1EC1676aAfb4F308110495c300f5369156F5Bf7a");

  console.log("Balance: ", balance.toNumber());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
