// This is a script for deploying your contracts. You can adapt it to deploy
const hre = require("hardhat");
// yours, or create new ones.
async function main() {
  // ethers is avaialble in the global scope
  const [deployer] = await hre.ethers.getSigners();
  const owner = await deployer.getAddress();
  console.log("Deploying the contracts with owner account:", owner);

  const initialBalance = await deployer.getBalance();
  console.log("Account balance:", initialBalance.toString());

  const HopeVik = await hre.ethers.getContractFactory("BetFactory");
  const hopeVik = await HopeVik.deploy(1000);
  await hopeVik.deployed();

  const finalBalance = await deployer.getBalance();
  console.log("Account balance after deployment", finalBalance.toString());

  const deploymentCost = hre.ethers.utils.formatEther(
    initialBalance.sub(finalBalance)
  );
  console.log("Contract Deployment Cost", `${deploymentCost.toString()} ETH`);

  console.log("HopeVik address:", hopeVik.address);

  // We also save the contract's artifacts and address in the frontend directory
  saveFrontendFiles(HopeVik);
}

function saveFrontendFiles(hopeVik) {
  const fs = require("fs");
  const contractsDir = __dirname + "/../deployed";
  const artifactsDir = __dirname + "/../artifacts/contracts";

  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir);
  }

  fs.writeFileSync(
    contractsDir + "/HopeVik-contract-address.json",
    JSON.stringify({ HopeVik: hopeVik.address }, undefined, 2)
  );
  fs.copyFileSync(
    artifactsDir + "/HopeVik.sol/HopeVik.json",
    contractsDir + "/HopeVik.json"
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
