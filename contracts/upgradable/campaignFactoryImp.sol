// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/ISenderCreator.sol";
import "./campaignVaultImp.sol";

contract CampaignFactory is 
    PausableUpgradeable, 
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    using Create2 for bytes32;

    event NewCampaignCreated(bytes32 indexed id, address indexed campaign, address indexed owner);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(bytes32 => address) internal campaigns;

    address public ADMIN;           
    address public Implementation;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address implementation) public initializer {
        __ReentrancyGuard_init();  
        __AccessControl_init();    
        __Pausable_init(); 
        
        require(admin != address(0), "Invalid admin");
        require(implementation != address(0), "Invalid implementation");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        ADMIN = admin;
        Implementation = implementation;
    }

    /**
     * @notice Generate unique user ID based on caller and blockchain context.
     */
    function generateUserID(address account) public view returns (bytes32 ID) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                msg.sender,
                address(this),
                account,
                block.chainid,
                block.prevrandao,
                block.number
            )
        );
        assembly ("memory-safe") {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, hash)
            ID := keccak256(0x00, 0x3c)
        }
    }
/**
     * @notice Deploy a new ERC-4337 SimpleAccount deterministically using CREATE2.
     */
    function createCampaign(Structs.deployParams calldata params, uint256 salt)
        external
        nonReentrant
        whenNotPaused
        onlyRole(ADMIN_ROLE)
        returns (address newCampaign)
    {
        address predicted = getAddress(params, salt);
        if (predicted.code.length > 0) {
            return address(CampaignVault(payable(predicted)));
        }

        newCampaign = deployProxy(getData(params), salt);

        bytes32 userId = generateUserID(address(newCampaign));
        campaigns[userId] = address(newCampaign);

        emit NewCampaignCreated(userId, address(newCampaign), params.admin);
    }

    //deploying BeaconProxy contract with create2
    function deployProxy(bytes memory data, uint salt) internal returns(address proxy){
        bytes memory bytecode = getCreationBytecode(data);
        assembly {
            proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(proxy)) {
                revert(0, 0)
            }
        }
    }

    //adding constructor arguments to BeaconProxy bytecode
    function getCreationBytecode(bytes memory _data) internal view returns (bytes memory) {
        return abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(Implementation, _data));
    }

    //returns address that contract with such arguments will be deployed on
    function getAddress(Structs.deployParams calldata params,uint _salt)
        public
        view
        returns (address)
    {   
        bytes memory bytecode = getCreationBytecode(getData(params));

        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode))
        );

        return address(uint160(uint(hash)));
    }

    function getData(Structs.deployParams calldata params) internal pure returns(bytes memory){
        return abi.encodeWithSelector(CampaignVault.initialize.selector, params);
    }

    /**
     * @notice Get deployed account by user ID.
     */
    function getAccount(bytes32 userId) external view returns (address) {
        return campaigns[userId];
    }

    function getImplementation() external view returns (address) {
        return Implementation;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;

    receive() external payable {}
    fallback() external payable {}
}