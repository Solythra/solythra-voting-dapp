const hre = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("\n🚀 Starting Deployment on Base...");

  // ✅ Validate required environment variables
  const requiredEnvVars = [
    "PRIVATE_KEY",
    "BASESCAN_API_KEY",
    "MULTISIG_TREASURY",
    "LIQUIDITY_POOL",
    "BASE_SEPOLIA_RPC"
  ];

  requiredEnvVars.forEach((key) => {
    if (!process.env[key]) {
      throw new Error(`❌ ERROR: ${key} is missing in .env file! Deployment halted.`);
    }
  });

  console.log("\n📦 Fetching contract factories...");
  const [deployer] = await hre.ethers.getSigners();
  console.log(`🔹 Deploying from: ${deployer.address}`);

  const initialOwner = deployer.address;
  const treasury = process.env.MULTISIG_TREASURY;

  // 🚀 Deploy Multi-Sig Governance Contract
  console.log("\n🚀 Deploying Governance...");
  const Governance = await hre.ethers.getContractFactory("Governance");
  const governance = await Governance.deploy(initialOwner, treasury);
  await governance.waitForDeployment();
  const governanceAddress = await governance.getAddress();
  console.log(`✅ Governance deployed at: ${governanceAddress}`);

  // 🚀 Deploy NFT Marketplace
  console.log("\n🚀 Deploying NFT Marketplace...");
  const NFTMarketplace = await hre.ethers.getContractFactory("NFTMarketplace");
  const nftMarketplace = await NFTMarketplace.deploy(initialOwner, process.env.MINTIUM_TOKEN, treasury);
  await nftMarketplace.waitForDeployment();
  const nftMarketplaceAddress = await nftMarketplace.getAddress();
  console.log(`✅ NFT Marketplace deployed at: ${nftMarketplaceAddress}`);

  // 🚀 Deploy Mintium (MNTM)
  console.log("\n🚀 Deploying Mintium...");
  const Mintium = await hre.ethers.getContractFactory("Mintium");
  const mintium = await Mintium.deploy(initialOwner, treasury);
  await mintium.waitForDeployment();
  const mintiumAddress = await mintium.getAddress();
  console.log(`✅ Mintium deployed at: ${mintiumAddress}`);

  // 🚀 Deploy Solythis (LYTH)
  console.log("\n🚀 Deploying Solythis...");
  const Solythis = await hre.ethers.getContractFactory("Solythis");
  const solythis = await Solythis.deploy(initialOwner, treasury);
  await solythis.waitForDeployment();
  const solythisAddress = await solythis.getAddress();
  console.log(`✅ Solythis deployed at: ${solythisAddress}`);

  // 🔹 Configure Mintium for NFT Minting & Liquidity
  console.log("\n🛠 Configuring Mintium...");
  if (nftMarketplaceAddress !== ethers.ZeroAddress) {
    await mintium.setNFTMarketplace(nftMarketplaceAddress);
    console.log("✅ Mintium marketplace set.");
  }
  if (process.env.LIQUIDITY_POOL !== ethers.ZeroAddress) {
    await mintium.setLiquidityPool(process.env.LIQUIDITY_POOL);
    console.log("✅ Mintium liquidity pool set.");
  }

  // 🔹 Configure Solythis Governance & Treasury
  console.log("\n🛠 Configuring Solythis Governance & Treasury...");
  await solythis.setGovernanceContract(governanceAddress);
  await solythis.setTreasury(treasury);
  console.log("✅ Solythis governance & treasury set.");

  // 🚀 Verify Contracts on BaseScan
  console.log("\n🔍 Waiting before verifying contracts on BaseScan...");
  await new Promise((resolve) => setTimeout(resolve, 10000));

  console.log("\n🔍 Verifying contracts on BaseScan...");
  await hre.run("verify:verify", {
    address: mintiumAddress,
    constructorArguments: [initialOwner, treasury],
  });
  await hre.run("verify:verify", {
    address: solythisAddress,
    constructorArguments: [initialOwner, treasury],
  });
  await hre.run("verify:verify", {
    address: governanceAddress,
    constructorArguments: [initialOwner, treasury],
  });
  await hre.run("verify:verify", {
    address: nftMarketplaceAddress,
    constructorArguments: [initialOwner, process.env.MINTIUM_TOKEN, treasury],
  });

  console.log("✅ Contract verification complete.");
  console.log("\n🎉 Deployment successful! 🎉");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
