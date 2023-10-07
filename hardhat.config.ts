import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        // runs: 100,
      },
    },
  },
  gasReporter: {
    enabled: true,
  },

  networks: {
    bsctestnet: {
      url: process.env.BSC_TESTNET_URL,
      chainId: 97,
      accounts: { mnemonic: process.env.MNEMONIC },
    },
    bsc: {
      url: process.env.BSC_URL,
      chainId: 56,
      accounts: { mnemonic: process.env.MNEMONIC },
    },
    sepolia: {
      url: process.env.SEPOLIA_URL,
      chainId: 11155111,
      accounts: { mnemonic: process.env.MNEMONIC },
    },
  },

  etherscan: {
    apiKey: {
      bscTestnet: process.env.BSC_TESTNET_API_KEY!,
      bsc: process.env.BSC_API_KEY!,
      sepolia: process.env.SEPOLIA_API_KEY!,
    },
  },
};

export default config;
