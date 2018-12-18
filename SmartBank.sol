pragma solidity ^0.4.24;

import "./zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./zeppelin-solidity/contracts/ownership/Ownable.sol";

contract SmartBank is Ownable{
  address public fund;
  bool public isFundSet = false;
  // An array of all the erc20 token addresses the smart fund holds
  address[] public tokenAddresses;
  // ETH Token
  ERC20 constant private ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
  // so that we can easily check that we don't add duplicates to our array
  mapping (address => bool) public tokensTraded;

  /**
  * @dev onwer can set or change FUND
  */
  function setFund(address _fund) public onlyOwner{
    fund = _fund;

    isFundSet = true;

    approveTokensForFund();
  }

  /**
  * @dev Approve All SmartBank tokens for SmartFund
  */

  function approveTokensForFund() private {
    require(isFundSet);

    uint256 balance;

    for (uint256 i = 1; i < tokenAddresses.length; i++) {

    ERC20 token = ERC20(tokenAddresses[i]);

    // WE don't need approve for ETH token
    if(token != ETH_TOKEN_ADDRESS)

    balance = token.balanceOf(address(this));

    token.approve(fund, balance);
   }
  }

  /**
  * @dev Adds a token to tokensTraded if it's not already there
  * @param _token    The token to add
  */
  function addTokenInBank(address _token) public{
    require(isFundSet);
    // Only Fund contract can set tokens
    require(msg.sender == fund);

    // don't add token to if we already have it in our list
    if (tokensTraded[_token] || (_token == address(ETH_TOKEN_ADDRESS)))
      return;

    tokensTraded[_token] = true;

    uint256 tokenCount = tokenAddresses.push(_token);
  }



  // This method was added to easily record the funds token balances, may (should?) be removed in the future
  function getFundTokenHolding(ERC20 _token) external view returns (uint256) {
    if (_token == ETH_TOKEN_ADDRESS)
      return this.balance;
    return _token.balanceOf(this);
  }


  // MAIBY WE CAN SEND to exchange directly from BANK, just trigger in FUND?

  /**
  * @dev Fund can recive ETH from BANK via Interface
  * @param _value ETH value in wei
  */
  function sendETHToFund(uint256 _value) public {
    // TODO add and balance ETH allowance modifiers
    require(isFundSet);
    address(fund).transfer(_value);
  }

  // Fallback payable function in order to be able to receive ether from other contracts
  function() public payable {}
}
