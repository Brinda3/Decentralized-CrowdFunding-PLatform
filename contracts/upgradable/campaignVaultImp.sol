// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./struct.sol";

contract CampaignVault is 
    ERC4626Upgradeable, 
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable 
{
    error INVALIDSIGNATURE();
    error EXPIRED(uint256 time); 

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

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

    struct Sign {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 nonce;
        uint256 deadline;
    }

    modifier isExpired(uint256 time) {
        if(block.timestamp > time) {
            revert EXPIRED(time);
        }
        _;
    }

    uint256 public FUNDING_CAP;       
    uint256 public MIN_DEPOSIT;
    uint256 public MAX_DEPOSIT;            
    uint16 private feedCount;  
    Structs.PayoutType public PAYOUT_TYPE;
    uint256 public TOKEN_PRICE;
    uint256 public STARTTIME;
    uint256 public ENDTIME;
    uint256 public MATURITY_TIME;
    uint256 public MATURITY_INTREST_PERMILE;
    uint256 public DEPOSIT_FEE_PERMILE;  
    uint256 public WITHDRAW_FEE_PERMILE; 
    uint256 private FUNDS_ALLOCATED_FOR_DIVIDEND;
    uint256 private TOTAL_INVESTMENTS;

    uint256 constant SCALE = 1e18;

    address public admin;
    address public signAuthority;

    mapping(uint32 => sharePrice) internal sharePriceHistory;
    mapping(address => userDetail) internal userDetails;
    mapping(uint256 => bool) internal usedNonces;
    
    event FUNDSAdded(uint256 amount, uint256 index, uint256 time);
    event OwnerChanged(address prevAdmin, address newUser);
    event withdrawnFunds(uint256 indexed amount);

    error INVWINDOWNOTCLOSED();

    modifier onlyInvClosed() {
        if(block.timestamp < ENDTIME || TOTAL_INVESTMENTS == FUNDING_CAP) {
            revert INVWINDOWNOTCLOSED();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Structs.deployParams memory params) initializer public {
        __ERC4626_init(IERC20(params.asset));
        __ERC20_init(params._name, params._symbol);
        __ReentrancyGuard_init();  
        __AccessControl_init();    
        __Pausable_init();     
        
        require(params.admin != address(0), "zero admin");
        _grantRole(DEFAULT_ADMIN_ROLE, params.admin);
        _grantRole(ADMIN_ROLE, params.admin);
        admin = params.admin;
        
        feedCount = 0;
        DEPOSIT_FEE_PERMILE = 250;
        WITHDRAW_FEE_PERMILE = 250;
        TOTAL_INVESTMENTS = 0;
        
        FUNDING_CAP = params.goal;
        MIN_DEPOSIT = params._minInvestment;
        MAX_DEPOSIT = params._maxInvestment;
        TOKEN_PRICE = params._tokenPrice;
        STARTTIME = params._startTime;
        ENDTIME = params._endTime;
        MATURITY_TIME = params.maturityTime;
        MATURITY_INTREST_PERMILE = params.interestPermile;
        PAYOUT_TYPE = params._payoutType;
        signAuthority = params.signer;
    }
    
    function getUserDetails(address user) public view returns(userDetail memory) {
        return userDetails[user];
    }
   
    function getROI(address user) public view returns(uint256) {
        uint32 startIndex = userDetails[user].lastclaimedIndex + 1;
        return _calculateROI(user, startIndex);
    }

    function getmaturityROI(address user) public view returns(uint256){
        return _calculateMaturityROI(user);
    } 

    /// @inheritdoc IERC4626
    function maxDeposit(address) public view virtual override returns (uint256) {
        return MAX_DEPOSIT;
    }

    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        uint256 _fee = Math.mulDiv(assets, DEPOSIT_FEE_PERMILE, 1e4, Math.Rounding.Floor);
        assets = assets - _fee;
        require(assets > MIN_DEPOSIT, "minimum deposit required");
        require(TOTAL_INVESTMENTS + assets <= FUNDING_CAP, "cap exceeded");
        TOTAL_INVESTMENTS = TOTAL_INVESTMENTS + assets;
        uint256 _alllocShares = _convertToShares(assets, Math.Rounding.Floor);
        userDetails[msg.sender].investments.push(investmentDetail(
            assets,
            _alllocShares,
            block.timestamp
        ));

        userDetails[msg.sender].totalAllocatedShares = userDetails[msg.sender].totalAllocatedShares + _alllocShares;
        SafeERC20.safeTransferFrom(IERC20(asset()), msg.sender, admin, _fee);
        return super.deposit(assets, receiver);
    }

    function depositWithSign(
        uint256 assets,
        address receiver,
        Sign calldata sign
    ) external returns (uint256 shares) {
        require(!usedNonces[sign.nonce], "Nonce already used");
        receiver = msg.sender;
        usedNonces[sign.nonce] = true;
        uint256 _fee = Math.mulDiv(assets, DEPOSIT_FEE_PERMILE, 1e4, Math.Rounding.Floor);
        verifySign(asset(), _fee, receiver, sign);
        assets = assets - _fee;
        require(assets > MIN_DEPOSIT, "minimum deposit required");
        require(TOTAL_INVESTMENTS + assets <= FUNDING_CAP, "cap exceeded");
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }
        TOTAL_INVESTMENTS = TOTAL_INVESTMENTS + assets;
        uint256 _alllocShares = _convertToShares(assets, Math.Rounding.Floor);
        userDetails[receiver].investments.push(investmentDetail(
            assets,
            _alllocShares,
            block.timestamp
        ));
        userDetails[receiver].totalAllocatedShares = userDetails[receiver].totalAllocatedShares + _alllocShares;
        _mint(receiver, _alllocShares);
        emit Deposit(receiver, receiver, assets, _alllocShares);
        return _alllocShares;
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
        uint256 _fee = Math.mulDiv(assets, WITHDRAW_FEE_PERMILE, 1e4, Math.Rounding.Floor);
        assets = assets - _fee;
        uint256 _shares = _convertToShares(assets, Math.Rounding.Floor);
        userDetails[msg.sender].totalAllocatedShares = userDetails[msg.sender].totalAllocatedShares - _shares;
        SafeERC20.safeTransfer(IERC20(asset()), admin, _fee);
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
        userDetails[msg.sender].totalAllocatedShares = userDetails[msg.sender].totalAllocatedShares - shares;
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
    function totalAssets() public view virtual override returns (uint256) {
        return (IERC20(asset()).balanceOf(address(this)) - FUNDS_ALLOCATED_FOR_DIVIDEND);
    }

    function withdrawFunds(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) onlyInvClosed() {
        require(amount > 0, "Withdraw:amount should be greater than zero");
        SafeERC20.safeTransfer(IERC20(asset()), admin, amount);
    }

    function feedFunds(uint256 _amount, address _from) external onlyRole(ADMIN_ROLE) returns(bool) {
        require(_amount > 0, "ROI: invalid amount");
        SafeERC20.safeTransferFrom(IERC20(asset()), _from, address(this), _amount);
        feedCount = feedCount + 1;
        uint256 price = (_amount * SCALE) / totalSupply();
        sharePriceHistory[feedCount] = sharePrice(
            price,
            block.timestamp
        );
        FUNDS_ALLOCATED_FOR_DIVIDEND = FUNDS_ALLOCATED_FOR_DIVIDEND + _amount;
        emit FUNDSAdded(_amount, feedCount, block.timestamp);
        return true;
    }

    function claim() external onlyInvClosed() {
        if (PAYOUT_TYPE == Structs.PayoutType.CapitalAppreciation && block.timestamp > MATURITY_TIME) {
            maturityClaim();
        }

        if(PAYOUT_TYPE == Structs.PayoutType.Dividends) {
            ROIclaim();
        }
        if (PAYOUT_TYPE == Structs.PayoutType.Both) {
            if(block.timestamp > MATURITY_TIME) {
                maturityClaim();
            } else {
                ROIclaim();
            }
        }
    }

    function maturityClaim() internal {
        address userAddr = msg.sender;
        uint256 claimable = _calculateMaturityROI(userAddr);
        require(claimable > 0, "No ROI available");
        withdraw(userDetails[userAddr].totalAllocatedShares, userAddr, userAddr);
        userDetails[userAddr].totalAllocatedShares = 0;
        SafeERC20.safeTransfer(IERC20(asset()), userAddr, claimable);
    }

    function _calculateMaturityROI(address userAddr) internal view returns (uint256) {
        userDetail storage user = userDetails[userAddr];
        uint256 totalClaimable = 0;
        unchecked {
            totalClaimable += (user.totalAllocatedShares * MATURITY_INTREST_PERMILE) / 1e4;
        }
        return totalClaimable;
    }

    function ROIclaim() internal {
        require(feedCount > 0, "No ROI deposit available");
        address userAddr = msg.sender;
        uint32 startIndex = userDetails[userAddr].lastclaimedIndex + 1;
        require(startIndex <= feedCount, "Claim not available");
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
            unchecked {
                totalClaimable += (user.totalAllocatedShares * sp.pricePerShare) / 1e18;
            }
        }

        return totalClaimable;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual override returns (uint256) {
        return Math.mulDiv(assets, 1e18, TOKEN_PRICE, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual override returns (uint256) {
        return Math.mulDiv(shares, TOKEN_PRICE, 1e18, rounding); 
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        uint256 _fee = Math.mulDiv(assets, WITHDRAW_FEE_PERMILE, 1e4, Math.Rounding.Floor);
        assets = assets - _fee;
        SafeERC20.safeTransfer(IERC20(asset()), admin, _fee);
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function verifySign(
        address token,
        uint256 fee,
        address caller,
        Sign calldata sign
    ) internal view isExpired(sign.deadline) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(this, caller, token, fee, block.chainid, sign.nonce)
        );
        
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address recovered = ethSignedMessageHash.recover(sign.v, sign.r, sign.s);
        
        if (recovered != signAuthority) {
            revert INVALIDSIGNATURE();
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}