// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract campaignFactoryProxy is TransparentUpgradeableProxy, AccessControl, ReentrancyGuard {

    address public Admin;


    event Ownerchanged(address prevAdmin, address newAdmin);
    event AdminAdded(address admin);
    event AdminRemoved(address admin);


    bytes32 private constant ADMIN_ROLE = keccak256(abi.encode("ADMIN_ROLE"));

    constructor(address impl, address admin)
        TransparentUpgradeableProxy(impl, admin, "")
    {
        Admin = admin;
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, Admin);
    }

    /**
     * @notice Transfer ownership of the contract to a new user
     * @param newUser The new admin address
     * @dev This function is used to transfer ownership of the contract to a new user
     */
    function transferOwnership(address newUser) public onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(newUser != address(0), "Invalid admin address");
        require(newUser != Admin, "Already the admin");
        
        address prevAdmin = Admin;
        _revokeRole(DEFAULT_ADMIN_ROLE, prevAdmin);
        _revokeRole(ADMIN_ROLE, prevAdmin);
        
        Admin = newUser;
        _grantRole(DEFAULT_ADMIN_ROLE, newUser);
        _grantRole(ADMIN_ROLE, newUser);
        
        emit Ownerchanged(prevAdmin, newUser);
    }

    /**
     * @notice Add a new admin to the contract
     * @param newAdmin The new admin address to add
     * @dev Only existing admins can call this function
     * @dev New admin address cannot be zero address
     * @dev Address cannot already be an admin
     * @dev Emits AdminAdded event when admin is successfully added
     */
    function addAdmin(address newAdmin) public onlyRole(ADMIN_ROLE) nonReentrant {
        require(newAdmin != address(0), "Invalid admin address");
        require(!hasRole(ADMIN_ROLE, newAdmin), "Already an admin");
        
        _grantRole(ADMIN_ROLE, newAdmin);
        emit AdminAdded(newAdmin);
    }

    /**
     * @notice Remove an admin from the contract
     * @param admin The admin address to remove
     * @dev Only existing admins can call this function
     * @dev Cannot remove the primary admin (ADMIN)
     * @dev Address must be a current admin to be removed
     * @dev Emits AdminRemoved event when admin is successfully removed
     */
    function removeAdmin(address admin) public onlyRole(ADMIN_ROLE) nonReentrant {
        require(admin != address(0), "Invalid admin address");
        require(admin != Admin, "Cannot remove primary admin");
        require(hasRole(ADMIN_ROLE, admin), "Not an admin");
        
        _revokeRole(ADMIN_ROLE, admin);
        emit AdminRemoved(admin);
    }

    /// @notice Return the current implementation address
    function getImplementation() public view returns (address) {
        return _implementation();
    }

    /// @notice Upgrade to a new implementation
    function upgrade(address newImpl) external  nonReentrant onlyRole(ADMIN_ROLE)  {
        ERC1967Utils.upgradeToAndCall(newImpl, "");    
    }

    receive() external payable {}
}
