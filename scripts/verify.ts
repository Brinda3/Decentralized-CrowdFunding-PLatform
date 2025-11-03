import { ethers } from "ethers";
import hre from "hardhat";
import { verifyContract } from "@nomicfoundation/hardhat-verify/verify";
async function main() {
  try {
      //BUSD Mock
      const name = "BSUD";
      const symbol = "BUSD";
    
      //Campaign
    
      const admin = "0x5886b456782534bfa0ad2523724daa06436ef49a";
      const cname = "AumFin-test";
      const csymbol = "AUMFINT";
      const fundingGoal = ethers.parseEther("1000");
      const minContribution = ethers.parseEther("1");
      const _maxInvestment = ethers.parseEther("1000");
      const _startTime =  Date.now();
      const _endTime =Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30;
      const _tokenPrice = ethers.parseEther("0.1");
      const _payoutType = 0;
      const maturityTime = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30;
      const interestPermile = 500;

  const BUSD = "0x021e725F7457391f62cB0c04E5F939F27B086eB9";
  const campaign = "0x3966033fc6403711828196a9414E15246b871F7b";
  const campaignFactory = "0x127dfC1A499379981D65466fF3B7bd7AB5Edd120";



    // MOCK BUSD
    await verifyContract({
      address: BUSD,
      constructorArgs: [name, symbol, admin],
      provider: "etherscan"
    },hre);

    // GORA LP
    await verifyContract({
      address: campaign,
      constructorArgs: [
        [
      admin,
      cname,
      csymbol,
      BUSD,
      fundingGoal,
      minContribution,
      _maxInvestment,
      _startTime,
      _endTime,
      _tokenPrice,
      _payoutType,
      maturityTime,
      interestPermile
        ]
      ],
      provider: "etherscan"
    },hre);

    // GORA purchase
    await verifyContract({
      address: campaignFactory,
      constructorArgs: [admin],
      provider:"etherscan"
    },hre);


    console.log("Contract successfully verified on Etherscan!");
  } catch (error) {
    console.error(" Verification failed:", error);
    process.exit(1);
  }
}

main();
