import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";
import hre from "hardhat";

export default buildModule("RWAdeployV1", (m) => {

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

  const busd = m.contract("BUSDMock", [name, symbol, admin]);

  const campaign = m.contract("CampaignVault", [[
      admin,
      cname,
      csymbol,
      busd,
      fundingGoal,
      minContribution,
      _maxInvestment,
      _startTime,
      _endTime,
      _tokenPrice,
      _payoutType,
      maturityTime,
      interestPermile
  ]]);

  const campaignFactory = m.contract("CampaignFactory", [admin]);


  return { busd , campaign, campaignFactory};
});
