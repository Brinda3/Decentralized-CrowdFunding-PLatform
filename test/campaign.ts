import { expect } from "chai";
import { Block } from "ethers";
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
  const _maxInvestment = ethers.parseEther("1000");
  const _startTime =  Math.floor(Date.now() / 1000);
  const _endTime =  Math.floor(Date.now() / 1000) + 1 * 60 * 60;;
  const _tokenPrice = ethers.parseEther("0.1");
  const _payoutType = 0;
  const maturityTime =  Math.floor(Date.now() / 1000) + 2 * 60 * 60;;
  const interestPermile = 500;

  before(async () => {
    owner = await ethers.provider.getSigner(0);
    admin = await ethers.provider.getSigner(1);
    addr1 = await ethers.provider.getSigner(2);
    addr2 = await ethers.provider.getSigner(3);

    const ownerAddress = await owner.getAddress();
    console.log(ownerAddress)

    // --- Deploy Token ---
    // pass constructor arguments as an array to deployContract
  // token constructor: (string name_, string symbol_, address admin)
  token = await ethers.deployContract("BUSDMock", [name, symbol, await admin.getAddress()]);
    // --- Deploy Campaign ---
    // pass all constructor args as an array

        //     address admin;
        // string  _name;
        // string _symbol;
        // IERC20 asset;
        // uint256 goal;
        // uint256 _minInvestment;
        // uint256 _maxInvestment;
        // uint256 _startTime;
        // uint256 _endTime;
        // uint256 _tokenPrice;
        // PayoutType _payoutType;
        // uint256 maturityTime;
        // uint256 interestPermile;
    console.log(_tokenPrice);
    campaign = await ethers.deployContract("CampaignVault", [
      [
      await owner.getAddress(),
      await owner.getAddress(),
      name,
      symbol,
      token.target,
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

  describe("Campaign Contributions - crypto", function () {
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
      let balance = await campaign.balanceOf(await addr1.getAddress());
      console.log(balance);
      await contribute_tx.wait();
    });
  });

    describe("Campaign Contributions - fiat", function () {
    it("should accept contributions", async () => {
      const contributionAmount = ethers.parseEther("10");
      const fee = (contributionAmount * 25n) / 1000n; // 25% fee


      const getSign = async () => {
        let nonce = 1;
        let deadline = Math.floor(Date.now() / 1000) + 5 * 60; // 1 hour from now
        const messageHash = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(
            [
              "address",
              "address",
              "address",
              "uint256",
              "uint256",
              "uint256",
              "uint256"
            ],
            [
              campaign.target,
              await addr2.getAddress(),
              token.target,
              contributionAmount,
              fee,
              await ethers.provider.getNetwork().then(n => n.chainId),
              nonce
            ]
          )
        );

        const ethSignedMessageHash = ethers.hashMessage(ethers.getBytes(messageHash));

        const signature = await owner.signMessage(ethers.getBytes(messageHash));
        let signArry =  [
          ethers.Signature.from(signature).v,
          ethers.Signature.from(signature).r,
          ethers.Signature.from(signature).s,
          nonce,
          deadline
        ]
        return signArry;
      }
      const sign =  await getSign();
      console.log(sign);

      //transfer tokens to addr1
      let mint_tx = await token.connect(admin).transfer(await addr2.getAddress(), contributionAmount);
      await mint_tx.wait();

      expect(await token.balanceOf(await addr2.getAddress())).to.equal(contributionAmount);

      //token approval
      let approve_tx = await token.connect(addr2).approve(campaign.target, contributionAmount);
      await approve_tx.wait();

      let allowance = await token.allowance(await addr2.getAddress(), campaign.target);

      expect(allowance).to.equal(contributionAmount);


      // //make contribution
      let contribute_tx = await campaign.connect(addr2).depositWithSign(contributionAmount, sign);
      await contribute_tx.wait();
      let balance = await campaign.balanceOf(await addr2.getAddress());
      console.log(balance);
    });
  });
  
});
