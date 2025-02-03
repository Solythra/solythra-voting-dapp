require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");

module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000, // 🔥 Maximized optimization for lower gas fees
      },
      viaIR: true, // 🔥 Solidity Intermediate Representation enabled for better efficiency
    },
  },

  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
    },

    base_sepolia: {
      url: process.env.BASE_SEPOLIA_RPC || "https://sepolia.base.org",
      chainId: 84532,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: "auto",
    },

    base_mainnet: {
      url: process.env.BASE_MAINNET_RPC || "https://mainnet.base.org",
      chainId: 8453,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: "auto",
    },

    gnosis_safe: {
      url: process.env.GNOSIS_SAFE_RPC || "https://rpc.gnosischain.com",
      chainId: 100,
      accounts: process.env.MULTISIG_WALLET ? [process.env.MULTISIG_WALLET] : [],
    },
  },

  etherscan: {
    apiKey: process.env.BASESCAN_API_KEY || "",
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org",
        },
      },
    ],
  },

  gasReporter: {
    enabled: true,
    currency: "USD",
    gasPrice: 20,
    showTimeSpent: true,
    showMethodSig: true, // 🔥 Analyzes most expensive contract functions
    outputFile: "gas-report.txt",
    noColors: true, // Clean output for logging
  },

  paths: {
    sources: "./contracts",
    cache: "./cache",
    artifacts: "./artifacts",
  },

  mocha: {
    timeout: 30000, // 🔥 Extended timeout for complex contract tests
  },
};

// ✅ Strict Environment Variable Validation
const requiredEnvVars = [
  "PRIVATE_KEY",
  "BASESCAN_API_KEY",
  "BASE_SEPOLIA_RPC",
  "BASE_MAINNET_RPC",
];

requiredEnvVars.forEach((key) => {
  if (!process.env[key]) {
    console.error(`❌ ERROR: Missing ${key} in .env file! Deployment halted.`);
    process.exit(1);
  }
});
