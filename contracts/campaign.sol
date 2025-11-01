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

    uint256 public fundingCap;       
    uint256 public minDeposit;              
    uint16 private feedCount = 0;
    enum PayoutType { CapitalAppreciation, Dividends, Both }
    PayoutType public payoutType;
    uint256 public tokenPrice;
    address public admin;

    mapping(uint16 => sharePrice) internal sharePriceHistory;
    mapping(address => userDetail) internal userDetails;
    mapping(address => bool) public isKycVerified;

    
    event FUNDSAdded(uint256 amount, uint256 index, uint256 time);
    event OwnerChanged(address prevAdmin, address newUser);


    constructor(
        address admin,
        string memory _name,
        string memory _symbol,
        uint256 _goal,
        uint256 _minInvestment,
        uint256 _maxInvestment,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _tokenPrice,
        PayoutType _payoutType,
        Milestone[] memory _milestones,
        uint16 _investmentFeeBps,
        uint16 _payoutFeeBps
        
    ) ERC20(name_, symbol_) ERC4626(asset_) {
        require(admin_ != address(0), "zero admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        fundingCap = fundingCap_;
        minDeposit = minDeposit_;
        
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

    function _feedFunds(uint256 _amount, address _from) internal returns(bool){
        require(_amount > 0, "ROI: invalid amount");
        SafeERC20.safeTransferFrom(IERC20(asset()), _from, address(this), _amount);
        feedCount = feedCount + 1;
        (,uint256 price) = Math.tryDiv(totalAssets(), _amount);
        sharePriceHistory[feedCount] = sharePrice(
            price,
            block.timestamp
        );
        emit FUNDSAdded(_amount, feedCount, block.timestamp);
        return true;
    }

    function _ROIclaim(address _to) internal {
        // require(block.timestamp > _lastclaim + 30 days, "ROI: no dues are pending");

        uint16 Index = userDetails[_to].lastclaimedIndex + uint16(1);
        uint256 _claimableAmount  = _calculateROI(Index, _to);
        SafeERC20.safeTransfer(IERC20(asset()), _to, _claimableAmount);
    }


    function _calculateROI(uint16 Index, address _to) internal view returns(uint256 claimable){

        for (uint16 i = Index; i <= feedCount; i++) 
        {
            uint256 shares = userDetails[_to].investments[i].allocatedShares;
            uint256 price = sharePriceHistory[i].pricePerShare;

            (uint256 ROI) = Math.tryMul(shares, price);

            claimable = claimable + ROI;

        }
        
    }
}


