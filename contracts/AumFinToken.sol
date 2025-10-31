// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// ProjectToken.sol
/// Simple ERC20 mintable token with AccessControl for MINTER_ROLE
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AumFinBEPToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(string memory name_, string memory symbol_, address admin) ERC20(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mint(address to, uint256 amount) external {
        require(hasRole(MINTER_ROLE, msg.sender), "ProjectToken: not minter");
        _mint(to, amount);
    }
}

