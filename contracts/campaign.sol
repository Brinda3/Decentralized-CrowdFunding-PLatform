// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

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
        uint256 lastclaimedIndex;
        uint256 lastclaimTimestamp;
    }

    uint256 public fundingCap;       
    uint256 public minDeposit;       
    uint256 public unlockTime;       
    address public escrowaddress;
    uint16 private feedCount = 0;

    mapping(uint16 => uint256) internal sharePriceHistory;
    mapping(address => bool) public isKycVerified;

    
    event FUNDSAdded(uint256 amount, uint256 index, uint256 time);


    constructor(
        IERC20 asset_,               
        string memory name_,
        string memory symbol_,
        address admin_,
        uint256 fundingCap_,
        uint256 minDeposit_,
        uint256 unlockTime_
    ) ERC20(name_, symbol_) ERC4626(asset_) {
        require(admin_ != address(0), "zero admin");
        require(unlockTime_ > block.timestamp, "invalid unlock");
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        fundingCap = fundingCap_;
        minDeposit = minDeposit_;
        unlockTime = unlockTime_;
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
        require(block.timestamp >= unlockTime, "locked");
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
        require(block.timestamp >= unlockTime, "locked");
        return super.redeem(shares, receiver, owner);
    }


    function timeLeftToUnlock() external view returns (uint256) {
        return block.timestamp >= unlockTime ? 0 : unlockTime - block.timestamp;
    }

    
    function rescueTokens(address token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(token != address(asset()), "no rescue underlying");
        IERC20(token).transfer(msg.sender, amount);
    }

    function _feedFunds(uint256 _amount, address _from, IERC20 _token) internal pure returns(bool){
        // require(_amount > 0, "ROI: invalid amount");
        // require(address(_token) != address(0), "ROI: invalid address");
        // SafeERC20.safeTransferFrom(_token, _from, address(this), _amount);
        // uint256 pricePerShare = numberOfsharesAllocated / 
        // feedCount = feedCount + 1;
        // feedhistory[feedCount] = _amount;
        // emit FUNDSAdded(_amount, feedCount, block.timestamp);
        return true;
    }

    function _ROIclaim(address _to) internal {
        // require(block.timestamp > _lastclaim + 30 days, "ROI: no dues are pending");

        // uint256 _pendingclaimCount = block.timestamp - (_lastclaim) / 30 days;
        // uint256 _claimableAmount  = _calculateROI(_pendingclaimCount, _holdingshares);
    }


    function _calculateROI(uint256 _claimCount, uint256 _holdingshares) internal returns(uint256 claimable){
        
    }
}


