import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";

export default buildModule("CampaignVaultDeploy", (m) => {
  
  // Admin & Signer addresses
  const admin = m.getAccount(0);
  const signer = admin; // Can be different address if needed
  
  // Campaign token details
  const name = "AumFin-test";
  const symbol = "AUMFINT";
  
  // Investment parameters
  const fundingGoal = ethers.parseEther("1000");
  const minInvestment = ethers.parseEther("1");
  const maxInvestment = ethers.parseEther("1000");
  
  // Timing parameters (in seconds)
  const startTime = Math.floor(Date.now() / 1000);
  const endTime = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30; // 30 days
  const maturityTime = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 60; // 60 days
  
  // Economic parameters
  const tokenPrice = ethers.parseEther("0.1"); // Price per share
  const interestPermile = 500; // 50% (500/1000)
  
  // Payout type: 0 = CapitalAppreciation, 1 = Dividends, 2 = Both
  const payoutType = 0;

  // Deploy BUSD Mock
  const busd = m.contract("BUSDMock", ["BUSD", "BUSD", admin]);

  // Deploy both implementation versions
  const campaignVaultImpl = m.contract("CampaignVault", []);
  const campaignVaultFactoryImpl = m.contract("CampaignFactory", []);

  // Deploy proxy pointing to first implementation
  const campaignProxy = m.contract("campaignProxy", [
    campaignVaultImpl,
    admin
  ]);


  const campaignFactoryProxy = m.contract("campaignFactoryProxy", [
    campaignVaultFactoryImpl,
    admin
  ], {
    id: "campaignFactoryProxyDeploy"
  });

  
  // Get the proxy as a CampaignVault interface to call initialize
  const campaignVault = m.contractAt("CampaignVault", campaignProxy, { 
    id: "campaignVault" 
  });

  const campaignFactory = m.contractAt("CampaignFactory", campaignFactoryProxy, { 
    id: "campaignFactoryDeploy" 
  });

  
  // Create the deployParams struct
  const deployParams = {
    admin: admin,
    signer: signer,
    _name: name,
    _symbol: symbol,
    asset: busd,
    goal: fundingGoal,
    _minInvestment: minInvestment,
    _maxInvestment: maxInvestment,
    _startTime: startTime,
    _endTime: endTime,
    _tokenPrice: tokenPrice,
    _payoutType: payoutType,
    maturityTime: maturityTime,
    capitalAppreciationPermile: interestPermile,
    maxDividendsCount: 10    
  };
  
  // Initialize the proxy (delegated to implementation)
  m.call(campaignVault, "initialize", [deployParams], {
    id: "initialize_campaign"
  });

  m.call(campaignFactory, "initialize", [admin, campaignProxy], {
    id: "initialize_campaign_factory"
  });
  
  return {
    busd,
    campaignVaultImpl,
    campaignProxy,
    campaignVault
  };
});