// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/interfaces/IERC20.sol";


library Structs {

    enum PayoutType { CapitalAppreciation, Dividends, Both }

    struct deployParams {
        address admin;
        address signer;
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
        uint256 maturityTime;
        uint256 interestPermile;
    }

}
