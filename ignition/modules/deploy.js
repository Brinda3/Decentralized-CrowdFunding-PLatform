import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AumFin = buildModule("AumFin", (m) => {
 
  const fundingCap_ = m.getParameter("fundingCap", 100000n * 10n ** 18n); 
  const minDeposit_ = m.getParameter("minDeposit", 10n * 10n ** 18n);      
  const unlockTime_ = m.getParameter(
    "unlockTime",
    BigInt(Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60) 
  );


  const projectToken = m.contract("ProjectToken", [
    "AumFinToken",
    "AUM",
    m.getAccount(0), 
  ]);

  
  const campaignVault = m.contract("CampaignVault", [
    projectToken,     
    "VaultShare",
    "vAUM",
    m.getAccount(0),  
    fundingCap_,
    minDeposit_,
    unlockTime_,
  ]);

  return { projectToken, campaignVault };
});

export default AumFin;
