import type { HardhatUserConfig } from "hardhat/config";
import hardhatVerify from "@nomicfoundation/hardhat-verify";

import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import { configVariable } from "hardhat/config";

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxMochaEthersPlugin,    hardhatVerify,
],
    verify: {
          blockscout: {
      enabled: false,
    },
    etherscan: {
      apiKey: "Q6VCHDYPPATQHPS4CR3AUUQ41ARAMSXZA4",
    },
  },
  solidity: {
    profiles: {
      default: {
        version: "0.8.30",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: "prague",
        },
      },
      production: {
        version: "0.8.30",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: "prague",
        },
      },
    },
  },
      chainDescriptors: 
    {
      97:{
      name: "Bsctestnet",
blockExplorers: {
        etherscan: {
          name: "etherscan",
          "url": "https://testnet.bscscan.com/",
          "apiUrl": "https://api.etherscan.io/v2/api",
        },
    }}
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    BscTestnet: {
      type: "http",
      chainType: "l1",
      url: "https://bnb-testnet.g.alchemy.com/v2/3BH10F7T5x3xp5eOUF9vhTnu7MIv7yz_",
      accounts: ["59a11c1e0a6920454ead747645b571eb8caefda94c2eeecec92922b3cd79002b"],
    },
  },
};

export default config;
