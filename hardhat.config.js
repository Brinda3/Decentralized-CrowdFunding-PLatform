require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
const config = {
  etherscan: {
    apiKey: {
      polygonAmoy: "GAZQWXTARSMNCW1M9JTPQEBTXGXS7HNNJ1",
      bscTestnet: "1R7195NCZQ1ZCZHQZPUDQJUSZWZNJ27MPV",
      sepolia: "AZY45KT8HEDKIDFUD2SDTYVF4XI1TSUVVY"
    },
  },
  networks: {
    AmoyTestnet: {
      url: "https://polygon-amoy.g.alchemy.com/v2/3BH10F7T5x3xp5eOUF9vhTnu7MIv7yz_",
      accounts: ['a0f0005b015f1f394b0b496b32cec7be9ca2d63bd60a56b8ca13cab1f1a92597'],
    },
    BscTestnet: {
      url: "https://data-seed-prebsc-2-s1.binance.org:8545/",
      accounts: ['a0f0005b015f1f394b0b496b32cec7be9ca2d63bd60a56b8ca13cab1f1a92597']
    },
    SepoliaTestnet: {
      url: "https://sepolia.infura.io/v3/645e75ac77564d179ed43f6a536cf97b",
      accounts: ['a0f0005b015f1f394b0b496b32cec7be9ca2d63bd60a56b8ca13cab1f1a92597']
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.8.29",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
};

module.exports = config;
