// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import "@openzeppelin/contracts/access/AccessControl.sol";
import "./campaign.sol";

contract CampaignFactory is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("FACTORY_ADMIN");

    uint256 public nextCampaignId;
    
    mapping(uint256 => address) public campaigns;

    
    address[] public allCampaigns;
    address public Admin;

    event CampaignCreated(uint256 indexed campaignId, address indexed campaignAddress, address indexed creator, uint256 createdAt);
    event OwnerChanged(address prevAdmin,address newUser);

    constructor(address admin) {
        require(admin != address(0), "zero admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        nextCampaignId = 1;
        Admin = admin;
    }


    function createCampaign(
        Structs.deployParams memory params
    ) external onlyRole(ADMIN_ROLE) returns (uint256 campaignId, address campaignAddr) {
        require(address(params.asset) != address(0), "zero asset");
    
        CampaignVault campaign = new CampaignVault(params);

        campaignAddr = address(campaign);
        campaignId = nextCampaignId++;

        campaigns[campaignId] = campaignAddr;

        allCampaigns.push(campaignAddr);

        emit CampaignCreated(campaignId, campaignAddr, msg.sender, block.timestamp);
    }



    function totalCampaigns() external view returns (uint256) {
        return allCampaigns.length;
    }

    function transferOwnership(address newUser) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newUser != address(0), "Invalid admin address");
        require(newUser != Admin, "Already the admin");
        
        address prevAdmin = Admin;
        _revokeRole(DEFAULT_ADMIN_ROLE, prevAdmin);
        _revokeRole(ADMIN_ROLE, prevAdmin);
        
        Admin = newUser;
        _grantRole(DEFAULT_ADMIN_ROLE, newUser);
        _grantRole(ADMIN_ROLE, newUser);
        
        emit OwnerChanged(prevAdmin, newUser);
    }

    

    function getCampaignAddress(uint256 id) external view returns (address) {
        return campaigns[id];
    }

}


