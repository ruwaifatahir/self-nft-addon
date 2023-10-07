import hre, { ethers } from "hardhat";

const { parseUnits } = ethers.utils;

async function main() {
  const addon = await ethers.getContractAt(
    "SelfNftAddon",
    "0x2cf5097D3Bb4bCC4F42F4B08AfD9cF22DF4dBaB5"
  );

  const trx = await addon.registerNameSelf(
    "khubaibass",
    "0x0000000000000000000000000000000000000000"
  );

  console.log(trx.data);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
