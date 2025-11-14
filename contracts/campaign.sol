// SPDX-License-Identifier: MIT
/**
 * @title CampaignVault
 * @author AumFin
 * @notice This contract is a campaign vault that allows users to deposit and withdraw funds.
 * @dev This contract is a campaign vault that allows users to deposit and withdraw funds.
 */
pragma solidity 0.8.30;

/**
 * @notice Import necessary contracts from OpenZeppelin.
 */
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./utils/struct.sol";

/**
 * @title CampaignVault
 * @author AumFin
 * @notice This contract is a campaign vault that allows users to deposit and withdraw funds.
 * @dev This contract is a campaign vault that allows users to deposit and withdraw funds.
 */
contract CampaignVault is ERC4626, AccessControl, ReentrancyGuard, Pausable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SafeERC20 for IERC20;

    error INVALIDSIGNATURE();
    error EXPIRED(uint256 time);
    error INVWINDOWNOTCLOSED();
    error INVWINDOWNOTOPEN();
    error ZEROADDRESS();
    error ZEROAMOUNT();
    error INVALIDTIMERANGE();
    error MATURITYBEFOREEND();
    error ZEROMININVESTMENT();
    error MAXLESSTHANMIN();
    error ZEROGOAL();
    error ZEROTOKENPRICE();
    error INVALIDRECEIVER();
    error MINIMUMDEPOSITREQUIRED();
    error CAPEXCEEDED();
    error INSUFFICIENTSHARES();
    error INSUFFICIENTFUNDS();
    error NOCLAIMABLEAMOUNT();
    error INSUFFICIENTDIVIDENDFUNDS();
    error NOROIDEPOSITAVAILABLE();
    error CLAIMNOTAVAILABLE();
    error NOROIAVAILABLE();
    error NOSHARESMINTED();
    error FEEDCOUNTOVERFLOW();
    error CANNOTRESCUEUNDERLYING();
    error ALREADYADMIN();
    error NONCEALREADYUSED();

    address public signAuthority;

    /**
     * @notice Struct to store share price information.
     * @param pricePerShare The price per share.
     * @param date The date of the share price.
     */
    struct sharePrice {
        uint256 pricePerShare;
        uint256 date;
    }

    /**
     * @notice Struct to store investment details.
     * @param amount The amount of the investment.
     * @param allocatedShares The allocated shares.
     * @param timeStamp The timestamp of the investment.
     */
    struct investmentDetail {
        uint256 amount;
        uint256 allocatedShares;
        uint256 timeStamp;
    }

    /**
     * @notice Struct to store user details.
     * @param investments The investments of the user.
     * @param totalAllocatedShares The total allocated shares.
     * @param lastclaimedIndex The last claimed index.
     * @param lastclaimTimestamp The timestamp of the last claim.
     */
    struct userDetail {
        investmentDetail[] investments;
        uint256 totalAllocatedShares;
        uint32 lastclaimedIndex; // Changed from uint16 to uint32
        uint256 lastclaimTimestamp;
    }

    /**
     * @notice Struct to store signature information.
     * @param v The v value of the signature.
     * @param r The r value of the signature.
     * @param s The s value of the signature.
     * @param nonce The nonce of the signature.
     * @param deadline The deadline of the signature.
     */
    struct Sign {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 nonce;
        uint256 deadline;
    }

    /**
     * @notice Modifier to check if the time is expired.
     * @param time The time to check.
     * @dev Reverts if the time is expired.
     */
    modifier isExpired(uint256 time) {
        if (block.timestamp > time) {
            revert EXPIRED(time);
        }
        _;
    }

    /**
     * @notice Funding cap.
     * @dev The maximum amount of assets that can be invested.
     */
    uint256 public FUNDING_CAP;
    /**
     * @notice Minimum deposit.
     * @dev The minimum amount of assets that can be invested.
     */
    uint256 public MIN_DEPOSIT;
    /**
     * @notice Maximum deposit.
     * @dev The maximum amount of assets that can be invested.
     */
    uint256 public MAX_DEPOSIT;
    /**
     * @notice Feed count.
     * @dev The number of feed periods.
     */
    uint32 private feedCount = 0; // Changed from uint16 to uint32
    Structs.PayoutType public PAYOUT_TYPE;
    /**
     * @notice Token price.
     * @dev The price per share.
     */
    uint256 public TOKEN_PRICE;
    /**
     * @notice Admin address.
     * @dev The address of the admin.
     */
    address public admin;
    /**
     * @notice Start time.
     * @dev The timestamp when the investment window opens.
     */
    uint256 public STARTTIME;
    /**
     * @notice End time.
     * @dev The timestamp when the investment window closes.
     */
    uint256 public ENDTIME;
    /**
     * @notice Maturity time.
     * @dev The timestamp when the campaign reaches maturity.
     */
    uint256 public MATURITY_TIME;
    /**
     * @notice Maturity interest per mille.
     * @dev The interest rate per mille for maturity payout.
     */
    uint256 public MATURITY_INTEREST_PERMILE;
    /**
     * @notice Deposit fee per mille.
     * @dev The deposit fee per mille.
     */
    uint256 public DEPOSIT_FEE_PERMILE = 250;
    /**
     * @notice Withdraw fee per mille.
     * @dev The withdrawal fee per mille.
    */
    uint256 public WITHDRAW_FEE_PERMILE = 250;

    /**
     * @notice Total investments.
     * @dev The total amount of investments.
     */
    uint256 public TOTAL_INVESTMENTS = 0;

    /**
     * @notice Scale.
     * @dev The scale of the contract.
     */
    uint256 constant SCALE = 1e18;

    /**
     * @notice Funds allocated for dividend.
     * @dev The amount of funds allocated for dividend.
     */
    uint256 private FUNDS_ALLOCATED_FOR_DIVIDEND;

    /**
     * @notice Share price history.
     * @dev The history of share prices.
     */
    mapping(uint32 => sharePrice) internal sharePriceHistory;
    /**
     * @notice User details.
     * @dev The details of the users.
     */
    mapping(address => userDetail) internal userDetails;

    /**
     * @notice Used nonces.
     * @dev The used nonces.
     */
    mapping(uint256 => bool) internal usedNonces;

    /**
     * @notice Funds added event.
     * @dev The event when funds are added.
     */
    event FUNDSAdded(uint256 amount, uint256 index, uint256 time);
    /**
     * @notice Owner changed event.
     * @dev The event when the owner is changed.
     */
    event OwnerChanged(address prevAdmin, address newUser);
    /**
     * @notice Withdrawn funds event.
     * @dev The event when funds are withdrawn.
     */
    event withdrawnFunds(uint256 indexed amount);

    /**
     * @notice Modifier to check if the investment window is closed.
     * @dev Reverts if the investment window is not closed.
     */
    modifier onlyInvClosed() {
        // Fixed logic: window closed if time passed OR cap reached
        if (block.timestamp < ENDTIME && TOTAL_INVESTMENTS < FUNDING_CAP) {
            revert INVWINDOWNOTCLOSED();
        }
        _;
    }

    /**
     * @notice Modifier to check if the investment window is open.
     * @dev Reverts if the investment window is not open.
     */
    modifier onlyInvOpen() {
        // Fixed logic: window open if time not passed AND cap not reached
        if (block.timestamp < STARTTIME || block.timestamp > ENDTIME || TOTAL_INVESTMENTS >= FUNDING_CAP) {
            revert INVWINDOWNOTOPEN();
        }
        _;
    }

    /**
     * @notice Initializes a new CampaignVault with the provided parameters.
     * @param params Struct containing all deployment parameters:
     *   - admin: Address that will receive DEFAULT_ADMIN_ROLE and be set as admin variable
     *   - signer: Address authorized to sign deposit transactions
     *   - _name: Name of the ERC20 share token
     *   - _symbol: Symbol of the ERC20 share token
     *   - asset: Address of the underlying ERC20 asset token
     *   - goal: Maximum funding cap for the campaign
     *   - _minInvestment: Minimum amount that can be deposited
     *   - _maxInvestment: Maximum amount per deposit
     *   - _startTime: Unix timestamp when investment window opens
     *   - _endTime: Unix timestamp when investment window closes
     *   - _tokenPrice: Price per share token in asset units
     *   - _payoutType: Type of payout (CapitalAppreciation, Dividends, or Both)
     *   - maturityTime: Unix timestamp when campaign reaches maturity
     *   - interestPermile: Interest rate per mille (parts per 1000) for maturity payout
     * @dev Validates all parameters and initializes the contract state.
     * @dev Grants DEFAULT_ADMIN_ROLE to admin and sets admin variable to keep them in sync.
     * @dev Validates all parameters and initializes the contract state.
    */
    constructor(Structs.deployParams memory params)
        ERC20(params._name, params._symbol)
        ERC4626(IERC20(params.asset))
    {
        if (params.admin == address(0)) revert ZEROADDRESS();
        if (params.signer == address(0)) revert ZEROADDRESS();
        if (params._startTime >= params._endTime) revert INVALIDTIMERANGE();
        if (params._endTime >= params.maturityTime) revert MATURITYBEFOREEND();
        if (params._minInvestment == 0) revert ZEROMININVESTMENT();
        if (params._maxInvestment < params._minInvestment) revert MAXLESSTHANMIN();
        if (params.goal == 0) revert ZEROGOAL();
        if (params._tokenPrice == 0) revert ZEROTOKENPRICE();

        // Grant DEFAULT_ADMIN_ROLE and set admin variable
        _grantRole(DEFAULT_ADMIN_ROLE, params.admin);
        admin = params.admin;
        signAuthority = params.signer;
        FUNDING_CAP = params.goal;
        MIN_DEPOSIT = params._minInvestment;
        MAX_DEPOSIT = params._maxInvestment;
        TOKEN_PRICE = params._tokenPrice;
        STARTTIME = params._startTime;
        ENDTIME = params._endTime;
        MATURITY_TIME = params.maturityTime;
        MATURITY_INTEREST_PERMILE = params.interestPermile;
        PAYOUT_TYPE = params._payoutType;
    }

    /**
     * @notice Retrieves all details for a specific user.
     * @param user The address of the user to query.
     * @return userDetail struct containing:
     *   - investments: Array of all investment records
     *   - totalAllocatedShares: Total shares currently allocated to the user
     *   - lastclaimedIndex: Index of the last feed period from which ROI was claimed
     *   - lastclaimTimestamp: Timestamp of the last ROI claim
     * @dev Returns the details of the user.
    */
    function getUserDetails(address user) public view returns (userDetail memory) {
        return userDetails[user];
    }

    /**
     * @notice Calculates the total unclaimed ROI for a user based on all feed periods.
     * @param user The address of the user to calculate ROI for.
     * @return The total unclaimed ROI amount in asset tokens.
     * @dev Calculates ROI from the last claimed index to the current feed count.
     */
    function getROI(address user) public view returns (uint256) {
        uint32 startIndex = userDetails[user].lastclaimedIndex + 1;
        return _calculateROI(user, startIndex);
    }

    /**
     * @notice Calculates the maturity interest ROI for a user.
     * @param user The address of the user to calculate maturity ROI for.
     * @return The maturity interest amount in asset tokens.
     * @dev Calculates based on total allocated shares and MATURITY_INTEREST_PERMILE.
     */
    function getmaturityROI(address user) public view returns (uint256) {
        return _calculateMaturityROI(user);
    }

    /**
     * @notice Returns the maximum amount of assets that can be deposited.
     * @param receiver The address that would receive the shares (unused but required by ERC4626).
     * @return The maximum deposit amount, considering:
     *   - Investment window must be open (between STARTTIME and ENDTIME)
     *   - Funding cap must not be reached
     *   - Returns the minimum of remaining cap space and MAX_DEPOSIT
     * @dev Returns 0 if investment window is closed or cap is reached.
     */
    /// @inheritdoc IERC4626
    function maxDeposit(address) public view virtual override returns (uint256) {
        if (block.timestamp < STARTTIME || block.timestamp > ENDTIME) {
            return 0;
        }
        if (TOTAL_INVESTMENTS >= FUNDING_CAP) {
            return 0;
        }
        uint256 remaining = FUNDING_CAP - TOTAL_INVESTMENTS;
        return remaining < MAX_DEPOSIT ? remaining : MAX_DEPOSIT;
    }

    /**
     * @notice Deposits assets into the vault and mints shares to the receiver.
     * @param assets The amount of assets to deposit (before fee deduction).
     * @param receiver The address that will receive the minted shares (must be msg.sender).
     * @return shares The amount of shares minted to the receiver.
     * @dev Applies deposit fee (DEPOSIT_FEE_PERMILE) which is sent to admin.
     * @dev Only callable when investment window is open and contract is not paused.
     * @dev Updates user investment tracking and total investments.
     * @custom:security Uses nonReentrant and whenNotPaused modifiers.
     */
    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        onlyInvOpen
        returns (uint256 shares)
    {
        if (assets == 0) revert ZEROAMOUNT();
        if (receiver != msg.sender) revert INVALIDRECEIVER();

        uint256 _fee = Math.mulDiv(assets, DEPOSIT_FEE_PERMILE, 1e4, Math.Rounding.Floor);
        uint256 assetsAfterFee = assets - _fee;

        if (assetsAfterFee < MIN_DEPOSIT) {
            // Only allow a small deposit if it perfectly fills the fund
            if (TOTAL_INVESTMENTS + assetsAfterFee != FUNDING_CAP) {
                revert MINIMUMDEPOSITREQUIRED();
            }
        }        
        if (TOTAL_INVESTMENTS + assetsAfterFee > FUNDING_CAP) revert CAPEXCEEDED();

        // Transfer fee to admin using SafeERC20 (only if fee > 0 and admin is valid)
        if (_fee > 0 && admin != address(0)) {
            IERC20(asset()).safeTransferFrom(msg.sender, admin, _fee);
        }

        // Call parent deposit
        shares = super.deposit(assetsAfterFee, receiver);

        // Update user tracking with actual minted shares
        userDetails[receiver].investments.push(
            investmentDetail(assetsAfterFee, shares, block.timestamp)
        );

        userDetails[receiver].totalAllocatedShares += shares;
        TOTAL_INVESTMENTS += assetsAfterFee;

        emit Deposit(receiver, receiver, assetsAfterFee, shares);

        return shares;
    }

    /**
     * @notice Deposits assets with a signature-based authorization.
     * @param assets The amount of assets to deposit (before fee deduction).
     * @param sign The signature struct containing v, r, s, nonce, and deadline.
     * @return shares The amount of shares minted to msg.sender.
     * @dev Requires a valid signature from signAuthority authorizing the deposit.
     * @dev Signature must not be expired and nonce must not be reused.
     * @dev Only callable when investment window is open and contract is not paused.
     * @custom:security Uses signature verification to prevent unauthorized deposits.
     */
    function depositWithSign(
        uint256 assets,
        Sign calldata sign
    ) external nonReentrant whenNotPaused onlyInvOpen returns (uint256 shares) {
        if (assets == 0) revert ZEROAMOUNT();
        address receiver = msg.sender;

        uint256 _fee = Math.mulDiv(assets, DEPOSIT_FEE_PERMILE, 1e4, Math.Rounding.Floor);
        uint256 assetsAfterFee = assets - _fee;

        // Verify signature first before any state changes
        verifySign(asset(), _fee, assets, receiver, sign);
        if (usedNonces[sign.nonce]) revert NONCEALREADYUSED();
        if (assetsAfterFee < MIN_DEPOSIT) revert MINIMUMDEPOSITREQUIRED();
        if (TOTAL_INVESTMENTS + assetsAfterFee > FUNDING_CAP) revert CAPEXCEEDED();

        uint256 maxAssets = maxDeposit(receiver);
        if (assetsAfterFee > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assetsAfterFee, maxAssets);
        }

        uint256 _allocShares = _convertToShares(assetsAfterFee, Math.Rounding.Floor);

        // Update state after successful transfers and minting
        _mint(receiver, _allocShares);
        usedNonces[sign.nonce] = true;
        TOTAL_INVESTMENTS += assetsAfterFee;

        userDetails[receiver].investments.push(
            investmentDetail(assetsAfterFee, _allocShares, block.timestamp)
        );

        userDetails[receiver].totalAllocatedShares += _allocShares;

        emit Deposit(receiver, receiver, assetsAfterFee, _allocShares);

        return _allocShares;
    }

    /**
     * @notice Withdraws assets from the vault by burning shares.
     * @param assets The net amount of assets the user wants to receive (after fee).
     * @param receiver The address that will receive the assets.
     * @param owner The address that owns the shares (must have allowance if caller != owner).
     * @return shares The amount of shares burned.
     * @dev Calculates total assets needed including withdrawal fee.
     * @dev Withdrawal fee (WITHDRAW_FEE_PERMILE) is sent to admin.
     * @dev Only callable when contract is not paused.
     * @custom:security Uses nonReentrant and whenNotPaused modifiers.
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override nonReentrant whenNotPaused returns (uint256 shares) {
        if (assets == 0) revert ZEROAMOUNT();

        // Calculate total assets needed from vault (user receives 'assets', fee goes to admin)
        // If user wants to receive 'assets' net, we need to withdraw more to cover the fee
        // totalAssetsToWithdraw * (1e4 - WITHDRAW_FEE_PERMILE) / 1e4 = assets
        // Therefore: totalAssetsToWithdraw = assets * 1e4 / (1e4 - WITHDRAW_FEE_PERMILE)
        uint256 totalAssetsToWithdraw = Math.mulDiv(assets, 1e4, 1e4 - WITHDRAW_FEE_PERMILE, Math.Rounding.Ceil);

        // Calculate shares needed for total assets to withdraw from vault
        shares = previewWithdraw(totalAssetsToWithdraw);

        // Validate shares before proceeding
        if (userDetails[owner].totalAllocatedShares < shares) revert INSUFFICIENTSHARES();

        userDetails[owner].totalAllocatedShares -= shares;

        // Call parent withdraw with total assets (fee handled in _withdraw)
        return super.withdraw(totalAssetsToWithdraw, receiver, owner);
    }

    /**
     * @notice Redeems shares for assets.
     * @param shares The amount of shares to redeem.
     * @param receiver The address that will receive the assets.
     * @param owner The address that owns the shares (must have allowance if caller != owner).
     * @return assets The net amount of assets received (after withdrawal fee).
     * @dev Withdrawal fee (WITHDRAW_FEE_PERMILE) is deducted and sent to admin.
     * @dev Only callable when contract is not paused.
     * @custom:security Uses nonReentrant and whenNotPaused modifiers.
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override nonReentrant whenNotPaused returns (uint256 assets) {
        if (shares == 0) revert ZEROAMOUNT();

        // Validate shares before proceeding
        if (userDetails[owner].totalAllocatedShares < shares) revert INSUFFICIENTSHARES();

        userDetails[owner].totalAllocatedShares -= shares;

        // Call parent redeem (state update happens in _withdraw hook)
        return super.redeem(shares, receiver, owner);
    }

    /**
     * @notice Allows admin to rescue tokens accidentally sent to the contract.
     * @param token The address of the token to rescue.
     * @param amount The amount of tokens to rescue.
     * @dev Cannot rescue the underlying asset token.
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE.
     * @custom:security Prevents rescue of underlying asset to maintain vault integrity.
     */
    function rescueTokens(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZEROADDRESS();
        if (token == address(asset())) revert CANNOTRESCUEUNDERLYING();
        if (amount == 0) revert ZEROAMOUNT();
        if (IERC20(token).balanceOf(address(this)) < amount) revert INSUFFICIENTFUNDS();
        // Use SafeERC20 instead of plain transfer
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Transfers ownership of the contract to a new admin address.
     * @dev Only callable by the current admin. Updates both the admin variable and DEFAULT_ADMIN_ROLE.
     * @param newUser The address of the new admin. Must not be zero address or current admin.
     * @custom:security Ensures admin variable and role are always in sync.
     */
    function transferOwnership(address newUser)
        public
        nonReentrant
        whenNotPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newUser == address(0)) revert ZEROADDRESS();
        if (newUser == admin) revert ALREADYADMIN();
        // Ensure new admin doesn't already have the role (defense in depth)
        if (hasRole(DEFAULT_ADMIN_ROLE, newUser)) revert ALREADYADMIN();

        address prevAdmin = admin;

        // Revoke role from previous admin
        _revokeRole(DEFAULT_ADMIN_ROLE, prevAdmin);

        // Update admin variable and grant role to new admin (keep in sync)
        admin = newUser;
        _grantRole(DEFAULT_ADMIN_ROLE, newUser);

        emit OwnerChanged(prevAdmin, newUser);
    }

    /**
     * @notice Pauses all state-changing functions in the contract.
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE.
     * @dev Prevents deposits, withdrawals, claims, and other state changes.
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the contract, allowing normal operations to resume.
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Returns the total amount of assets managed by the vault.
     * @return The total assets available, excluding funds allocated for dividends.
     * @dev Calculated as contract balance minus FUNDS_ALLOCATED_FOR_DIVIDEND.
     * @dev Returns 0 if balance is less than or equal to allocated dividend funds.
     */
    /// @inheritdoc IERC4626
    function totalAssets() public view virtual override returns (uint256) {
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        if (balance <= FUNDS_ALLOCATED_FOR_DIVIDEND) {
            return 0;
        }
        return balance - FUNDS_ALLOCATED_FOR_DIVIDEND;
    }

    /**
     * @notice Allows admin to withdraw funds from the vault after investment window closes.
     * @param amount The amount of assets to withdraw.
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE.
     * @dev Only callable when investment window is closed (onlyInvClosed modifier).
     * @dev Funds are transferred to the admin address.
     * @dev Cannot withdraw more than totalAssets().
     * @custom:security Requires investment window to be closed before allowing fund withdrawal.
     */
    function withdrawFunds(uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyInvClosed
    {
        if (amount == 0) revert ZEROAMOUNT();
        if (amount > totalAssets()) revert INSUFFICIENTFUNDS();
        IERC20(asset()).safeTransfer(admin, amount);
        emit withdrawnFunds(amount);
    }

    /**
     * @notice Feeds funds into the vault for dividend distribution.
     * @param _amount The amount of assets to feed into the vault.
     * @param _from The address from which to transfer the assets.
     * @return true if the operation succeeds.
     * @dev Only callable by addresses with DEFAULT_ADMIN_ROLE.
     * @dev Calculates price per share based on total supply and adds to share price history.
     * @dev Allocates funds to FUNDS_ALLOCATED_FOR_DIVIDEND for ROI claims.
     * @dev Requires at least one share to be minted before feeding funds.
     * @custom:security Prevents division by zero by requiring shares to exist.
     */
    function feedFunds(uint256 _amount, address _from)
        external
        nonReentrant
        whenNotPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        if (_amount == 0) revert ZEROAMOUNT();
        if (_from == address(0)) revert ZEROADDRESS();

        uint256 supply = totalSupply();
        if (supply == 0) revert NOSHARESMINTED();
        if (feedCount >= type(uint32).max) revert FEEDCOUNTOVERFLOW();

        IERC20(asset()).safeTransferFrom(_from, address(this), _amount);

        feedCount = feedCount + 1;
        uint256 price = Math.mulDiv(_amount, SCALE, supply, Math.Rounding.Floor);

        sharePriceHistory[feedCount] = sharePrice(price, block.timestamp);

        FUNDS_ALLOCATED_FOR_DIVIDEND += _amount;
        emit FUNDSAdded(_amount, feedCount, block.timestamp);
        return true;
    }

    /**
     * @notice Allows users to claim their ROI or maturity payout.
     * @dev Routes to appropriate claim function based on PAYOUT_TYPE:
     *   - CapitalAppreciation: Claims maturity payout if maturity time reached
     *   - Dividends: Claims ROI from feed periods
     *   - Both: Claims maturity if reached, otherwise claims ROI
     * @dev Only callable when investment window is closed.
     * @custom:security Uses nonReentrant and whenNotPaused modifiers.
     */
    function claim() external nonReentrant whenNotPaused onlyInvClosed {
        if (
            PAYOUT_TYPE == Structs.PayoutType.CapitalAppreciation &&
            block.timestamp >= MATURITY_TIME
        ) {
            maturityClaim();
        } else if (PAYOUT_TYPE == Structs.PayoutType.Dividends) {
            ROIclaim();
        } else if (PAYOUT_TYPE == Structs.PayoutType.Both) {
            if (block.timestamp >= MATURITY_TIME) {
                maturityClaim();
            } else {
                ROIclaim();
            }
        }
    }

    /**
     * @notice Internal function to handle maturity claims.
     * @dev Claims both principal (with withdrawal fee) and maturity interest.
     * @dev Burns all user shares and transfers principal after fee deduction.
     * @dev Transfers maturity interest from allocated dividend funds.
     * @dev Updates user state before external transfers (checks-effects-interactions pattern).
     */
    function maturityClaim() internal {
        address userAddr = msg.sender;
        uint256 interest = _calculateMaturityROI(userAddr);
        uint256 shares = userDetails[userAddr].totalAllocatedShares;

        if (interest == 0 && shares == 0) revert NOCLAIMABLEAMOUNT();

        uint256 principal = _convertToAssets(shares, Math.Rounding.Floor);

        // Update state before transfers
        userDetails[userAddr].totalAllocatedShares = 0;

        if (shares > 0) {
            _burn(userAddr, shares);

            uint256 fee = Math.mulDiv(principal, WITHDRAW_FEE_PERMILE, 1e4, Math.Rounding.Floor);
            uint256 principalAfterFee = principal - fee;

            // Transfer fee to admin (only if fee > 0 and admin is valid)
            if (fee > 0 && admin != address(0)) {
                IERC20(asset()).safeTransfer(admin, fee);
            }
            // Transfer principal to user (only if amount > 0)
            if (principalAfterFee > 0) {
                IERC20(asset()).safeTransfer(userAddr, principalAfterFee);
            }
        }

        if (interest > 0) {
            if (FUNDS_ALLOCATED_FOR_DIVIDEND < interest) revert INSUFFICIENTDIVIDENDFUNDS();
            FUNDS_ALLOCATED_FOR_DIVIDEND -= interest;
            IERC20(asset()).safeTransfer(userAddr, interest);
        }
    }

    /**
     * @notice Calculates the maturity interest ROI for a user.
     * @param userAddr The address of the user.
     * @return The maturity interest amount based on total allocated shares and interest rate.
     * @dev Returns 0 if user has no allocated shares.
     */
    function _calculateMaturityROI(address userAddr) internal view returns (uint256) {
        userDetail storage user = userDetails[userAddr];
        if (user.totalAllocatedShares == 0) {
            return 0;
        }
        return Math.mulDiv(
            user.totalAllocatedShares,
            MATURITY_INTEREST_PERMILE,
            1e4,
            Math.Rounding.Floor
        );
    }

    /**
     * @notice Internal function to handle ROI claims from feed periods.
     * @dev Calculates claimable ROI from last claimed index to current feed count.
     * @dev Updates user's last claimed index and timestamp.
     * @dev Transfers claimable amount from allocated dividend funds.
     * @dev Updates state before external transfers (checks-effects-interactions pattern).
     */
    function ROIclaim() internal {
        if (feedCount == 0) revert NOROIDEPOSITAVAILABLE();
        address userAddr = msg.sender;
        uint32 startIndex = userDetails[userAddr].lastclaimedIndex + 1;
        if (startIndex > feedCount) revert CLAIMNOTAVAILABLE();
        uint256 claimable = _calculateROI(userAddr, startIndex);
        if (claimable == 0) revert NOROIAVAILABLE();

        // Update state before transfer
        userDetails[userAddr].lastclaimedIndex = feedCount;
        userDetails[userAddr].lastclaimTimestamp = block.timestamp;

        if (FUNDS_ALLOCATED_FOR_DIVIDEND < claimable) revert INSUFFICIENTDIVIDENDFUNDS();
        FUNDS_ALLOCATED_FOR_DIVIDEND -= claimable;

        // Transfer claimable amount (only if > 0)
        if (claimable > 0) {
            IERC20(asset()).safeTransfer(userAddr, claimable);
        }
    }

    /**
     * @notice Calculates ROI for a user across multiple feed periods.
     * @param userAddr The address of the user.
     * @param startIndex The starting feed period index (inclusive).
     * @return The total claimable ROI amount across all feed periods from startIndex to feedCount.
     * @dev Returns 0 if user has no allocated shares.
     * @dev Uses current totalAllocatedShares for all periods (note: this may not reflect historical balances).
     */
    function _calculateROI(address userAddr, uint32 startIndex) internal view returns (uint256) {
        userDetail storage user = userDetails[userAddr];
        if (user.totalAllocatedShares == 0) {
            return 0;
        }

        uint256 totalClaimable = 0;

        for (uint32 i = startIndex; i <= feedCount; i++) {
            sharePrice storage sp = sharePriceHistory[i];
            totalClaimable += Math.mulDiv(
                user.totalAllocatedShares,
                sp.pricePerShare,
                SCALE,
                Math.Rounding.Floor
            );
        }

        return totalClaimable;
    }

    /**
     * @notice Converts assets to shares using the fixed TOKEN_PRICE.
     * @param assets The amount of assets to convert.
     * @param rounding The rounding direction (Floor, Ceil, or Trunc).
     * @return The equivalent amount of shares.
     * @dev Uses formula: shares = assets * SCALE / TOKEN_PRICE.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return Math.mulDiv(assets, SCALE, TOKEN_PRICE, rounding);
    }

    /**
     * @notice Converts shares to assets using the fixed TOKEN_PRICE.
     * @param shares The amount of shares to convert.
     * @param rounding The rounding direction (Floor, Ceil, or Trunc).
     * @return The equivalent amount of assets.
     * @dev Uses formula: assets = shares * TOKEN_PRICE / SCALE.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return Math.mulDiv(shares, TOKEN_PRICE, SCALE, rounding);
    }

    /**
     * @notice Internal function that handles the actual withdrawal logic.
     * @param caller The address initiating the withdrawal.
     * @param receiver The address that will receive the assets.
     * @param owner The address that owns the shares.
     * @param assets The total amount of assets to withdraw (before fee).
     * @param shares The amount of shares to burn.
     * @dev Handles allowance checking if caller is not the owner.
     * @dev Deducts withdrawal fee and transfers to admin and receiver.
     * @dev Updates user tracking state before external calls.
     * @custom:security Uses assert for invariant check (shares should always be validated).
     */
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

        // Update user tracking state before external calls
        // This is an invariant check - shares should always be validated before reaching here
        assert(userDetails[owner].totalAllocatedShares >= shares);
        userDetails[owner].totalAllocatedShares -= shares;

        _burn(owner, shares);

        uint256 _fee = Math.mulDiv(assets, WITHDRAW_FEE_PERMILE, 1e4, Math.Rounding.Floor);
        uint256 assetsAfterFee = assets - _fee;

        // Use SafeERC20 for transfers (only if amounts > 0 and admin is valid)
        if (_fee > 0 && admin != address(0)) {
            IERC20(asset()).safeTransfer(admin, _fee);
        }
        if (assetsAfterFee > 0) {
            IERC20(asset()).safeTransfer(receiver, assetsAfterFee);
        }

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /**
     * @notice Verifies that a signature is valid and not expired.
     * @param token The token address included in the signature.
     * @param fee The fee amount included in the signature.
     * @param caller The caller address included in the signature.
     * @param sign The signature struct containing v, r, s, nonce, and deadline.
     * @dev Reverts if signature is expired, invalid, or not from signAuthority.
     * @dev Uses EIP-191 message signing with chainid to prevent cross-chain replay.
     */
    function verifySign(
        address token,
        uint256 fee,
        uint256 amount,
        address caller,
        Sign calldata sign
    ) internal view isExpired(sign.deadline) {
        bytes32 messageHash = keccak256(
            abi.encode(this, caller, token, amount, fee, block.chainid, sign.nonce)
        );

        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        address recovered = ethSignedMessageHash.recover(sign.v, sign.r, sign.s);

        if (recovered != signAuthority) {
            revert INVALIDSIGNATURE();
        }
    }
}