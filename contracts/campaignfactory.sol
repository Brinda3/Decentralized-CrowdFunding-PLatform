// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import "@openzeppelin/contracts/access/AccessControl.sol";
import "./campaign.sol";

contract CampaignFactory is AccessControl {
    bytes32 public constant FACTORY_ADMIN = keccak256("FACTORY_ADMIN");

    uint256 public nextCampaignId;

    struct CampaignInfo {
        address campaignAddress;
        address creator;
        uint256 createdAt;
        string label;
    }

    
    mapping(uint256 => CampaignInfo) public campaigns;

    
    address[] public allCampaigns;

    event CampaignCreated(uint256 indexed campaignId, address indexed campaignAddress, address indexed creator, string label, uint256 createdAt);

    constructor(address admin) {
        require(admin != address(0), "zero admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FACTORY_ADMIN, admin);
        nextCampaignId = 1; 
    }


    function createCampaign(
        IERC20 asset,
        string memory name,
        string memory symbol,
        uint256 fundingCap,
        uint256 minDeposit,
        uint256 unlockTime,
        string calldata label
    ) external returns (uint256 campaignId, address campaignAddr) {
        require(address(asset) != address(0), "zero asset");
        require(unlockTime > block.timestamp, "invalid unlock");

    
        CampaignVault campaign = new CampaignVault(
            asset,
            name,
            symbol,
            msg.sender,    
            fundingCap,
            minDeposit,
            unlockTime
        );

        campaignAddr = address(campaign);
        campaignId = nextCampaignId++;

        campaigns[campaignId] = CampaignInfo({
            campaignAddress: campaignAddr,
            creator: msg.sender,
            createdAt: block.timestamp,
            label: label
        });

        allCampaigns.push(campaignAddr);

        emit CampaignCreated(campaignId, campaignAddr, msg.sender, label, block.timestamp);
    }



    function totalCampaigns() external view returns (uint256) {
        return allCampaigns.length;
    }

    function getCampaignAddress(uint256 id) external view returns (address) {
        return campaigns[id].campaignAddress;
    }

    function getCampaignInfo(uint256 id) external view returns (CampaignInfo memory) {
        return campaigns[id];
    }

    function updateLabel(uint256 id, string calldata newLabel) external onlyRole(FACTORY_ADMIN) {
        require(campaigns[id].campaignAddress != address(0), "unknown id");
        campaigns[id].label = newLabel;
    }
}
