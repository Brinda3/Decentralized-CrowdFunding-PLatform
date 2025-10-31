import { expect } from "chai";
import hre from "hardhat";
import { network } from "hardhat";
const { ethers } = await network.connect();

describe("Purchase Contract", function () {
  let owner: any;
  let admin: any;
  let addr1: any;
  let addr2: any;
  let campaign: any;
  let token: any;

  const name = "AumFin-test";
  const symbol = "AUMFINT";
  const fundingGoal = ethers.parseEther("1000");
  const minContribution = ethers.parseEther("1");
  const unlockTime = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30; // 30 days

  before(async () => {
    owner = await ethers.provider.getSigner(0);
    admin = await ethers.provider.getSigner(1);
    addr1 = await ethers.provider.getSigner(2);
    addr2 = await ethers.provider.getSigner(3);
    // --- Deploy Token ---
    // pass constructor arguments as an array to deployContract
  // token constructor: (string name_, string symbol_, address admin)
  token = await ethers.deployContract("AumFinBEPToken", [name, symbol, await admin.getAddress()]);
    // --- Deploy Campaign ---
    // pass all constructor args as an array
    campaign = await ethers.deployContract("CampaignVault", [
      token.target,
      name,
      symbol,
      await admin.getAddress(),
      fundingGoal,
      minContribution,
      unlockTime,
    ]);

    // --- Assign Roles ---
    const MINTER_ROLE = await token.MINTER_ROLE();
    await token.connect(admin).grantRole(MINTER_ROLE, await admin.getAddress());

    console.log("Token Address:", token.target);
    console.log("Campaign Address:",  campaign.target);
  });

  it("should deploy contracts successfully", async () => {
    expect(await token.getAddress()).to.be.properAddress;
    expect(await campaign.getAddress()).to.be.properAddress;
  });

  describe("Campaign Contributions", function () {
    it("should accept contributions", async () => {
      const contributionAmount = ethers.parseEther("10");

      //transfer tokens to addr1
      let mint_tx = await token.connect(admin).transfer(await addr1.getAddress(), contributionAmount);
      await mint_tx.wait();

      expect(await token.balanceOf(await addr1.getAddress())).to.equal(contributionAmount);

      //token approval
      let approve_tx = await token.connect(addr1).approve(campaign.target, contributionAmount);
      await approve_tx.wait();

      let allowance = await token.allowance(await addr1.getAddress(), campaign.target);

      expect(allowance).to.equal(contributionAmount);


      //make contribution
      let contribute_tx = await campaign.connect(addr1).deposit(contributionAmount, await addr1.getAddress());
      await contribute_tx.wait();
    });
  });
  
});
