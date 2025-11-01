// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract CampaignVault is ERC4626, AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct sharePrice {
        uint256 pricePerShare;
        uint256 date;
    }


    struct investmentDetail {
        uint256 amount;
        uint256 allocatedShares;
        uint256 timeStamp;
    }

    struct userDetail {
        investmentDetail[] investments;
        uint256 totalAllocatedShares;
        uint16 lastclaimedIndex;
        uint256 lastclaimTimestamp;
    }

    enum PayoutType { CapitalAppreciation, Dividends, Both }

    struct deployParams {
        address admin;
        string  _name;
        string _symbol;
        IERC20 asset;
        uint256 goal;
        uint256 _minInvestment;
        uint256 _maxInvestment;
        uint256 _startTime;
        uint256 _endTime;
        uint256 _tokenPrice;
        PayoutType _payoutType;
        uint16 _investmentFeeBps;
        uint16 _payoutFeeBps;
    }

    uint256 public fundingCap;       
    uint256 public minDeposit;              
    uint16 private feedCount = 0;
    PayoutType public payoutType;
    uint256 public tokenPrice;
    address public admin;

    uint256 constant SCALE = 1e18;

    uint256 private FUNDS_ALLOCATED_FOR_DIVIDEND;

    mapping(uint32 => sharePrice) internal sharePriceHistory;
    mapping(address => userDetail) internal userDetails;
    mapping(address => bool) public isKycVerified;
    
    event FUNDSAdded(uint256 amount, uint256 index, uint256 time);
    event OwnerChanged(address prevAdmin, address newUser);


    constructor(
        deployParams memory params
    ) ERC20(params._name, params._symbol) ERC4626(IERC20(params.asset)) {
        require(admin != address(0), "zero admin");
        _grantRole(DEFAULT_ADMIN_ROLE, params.admin);
        _grantRole(ADMIN_ROLE, params.admin);
        fundingCap = params.goal;
        minDeposit = params._minInvestment;
        
    }

    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        require(assets >= minDeposit, "below min");
        require(totalAssets() + assets <= fundingCap, "cap exceeded");
        return super.deposit(assets, receiver);
    }
 
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        
        return super.redeem(shares, receiver, owner);
    }

    function rescueTokens(address token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(token != address(asset()), "no rescue underlying");
        IERC20(token).transfer(msg.sender, amount);
    }

    function transferOwnership(address newUser) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newUser != address(0), "Invalid admin address");
        require(newUser != admin, "Already the admin");
        
        address prevAdmin = admin;
        _revokeRole(DEFAULT_ADMIN_ROLE, prevAdmin);
        _revokeRole(ADMIN_ROLE, prevAdmin);
        
        admin = newUser;
        _grantRole(DEFAULT_ADMIN_ROLE, newUser);
        _grantRole(ADMIN_ROLE, newUser);
        
        emit OwnerChanged(prevAdmin, newUser);
    }

        /// @inheritdoc IERC4626
    function totalAssets() public view virtual override  returns (uint256) {
        return (IERC20(asset()).balanceOf(address(this)) - FUNDS_ALLOCATED_FOR_DIVIDEND);
    }

    function feedFunds(uint256 _amount, address _from) external onlyRole(ADMIN_ROLE) returns(bool){
        require(_amount > 0, "ROI: invalid amount");
        SafeERC20.safeTransferFrom(IERC20(asset()), _from, address(this), _amount);
        feedCount = feedCount + 1;
        uint256 price =(_amount * SCALE) / totalSupply();
        sharePriceHistory[feedCount] = sharePrice(
            price,
            block.timestamp
        );
        FUNDS_ALLOCATED_FOR_DIVIDEND = FUNDS_ALLOCATED_FOR_DIVIDEND + _amount;
        emit FUNDSAdded(_amount, feedCount, block.timestamp);
        return true;
    }


    function claim() internal {
        if (payoutType == PayoutType.CapitalAppreciation) {
            //send the investment amount + dividend
        }

        if(payoutType == PayoutType.Dividends) {
            ROIclaim();
        }
        if (payoutType == PayoutType.Both) {
            //check the campaign whether matured or not
            // if(){
            // if yes send the investment amount + dividend
            // }else {
            //     ROIclaim()
            // }
        }

    }


    function ROIclaim() internal {
        address userAddr = msg.sender;
        uint32 startIndex = userDetails[userAddr].lastclaimedIndex + 1;
        uint256 claimable = _calculateROI(userAddr, startIndex);
        require(claimable > 0, "No ROI available");
        SafeERC20.safeTransfer(IERC20(asset()), userAddr, claimable);
        userDetails[userAddr].lastclaimedIndex = feedCount;
        userDetails[userAddr].lastclaimTimestamp = block.timestamp;
    }

    function _calculateROI(address userAddr, uint32 startIndex) internal view returns (uint256) {
        userDetail storage user = userDetails[userAddr];
        uint256 totalClaimable = 0;

        for (uint32 i = startIndex; i <= feedCount; i++) {
            sharePrice storage sp = sharePriceHistory[i];
            totalClaimable += _calculateForEachInvestment(user, sp.pricePerShare, sp.date);
        }

        return totalClaimable;
    }

    function _calculateForEachInvestment(
        userDetail storage user,
        uint256 price,
        uint256 timestamp
    ) internal view returns (uint256) {
        uint256 claimable = 0;
        uint256 len = user.investments.length;

        for (uint256 j = 0; j < len; j++) {
            investmentDetail storage inv = user.investments[j];
            if (inv.timeStamp < timestamp) {
                unchecked {
                    claimable += (inv.allocatedShares * price) / 1e18;
                }
            }
        }
        return claimable;
    }
}





