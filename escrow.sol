// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;



contract escrow is accesscontrol {
    event Deposited(address indexed payee, uint256 weiAmount);
    event Withdrawn(address indexed payee, uint256 weiAmount);


    mapping(address => uint256) private _deposits;

    function depositsOf(address payee) public view returns (uint256) {
    return _deposits[payee];

}


  function deposit(address payee) public onlyPrimary payable {
    uint256 amount = msg.value;
    _deposits[payee] = _deposits[payee].add(amount);

    emit Deposited(payee, amount);
  }


   function withdraw(address payee) public onlyPrimary {
    uint256 payment = _deposits[payee];

    _deposits[payee] = 0;

    payee.transfer(payment);

    emit Withdrawn(payee, payment);
  }
}
