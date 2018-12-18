pragma solidity ^0.4.24;

/*
 SmartBank use as a tokens storage for SmartFund
 All trade operation are performed in SmartFund, but tokens for this operation,
 SmartFund get from SmartBank.

 Motivation
 SmartBank help with abstarction, if we do update in App, users do not need,
 transfer tokens from old smartFund version to new smartFund version.
 User just set new SmartFund in SmartBank.
*/

import "./zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./zeppelin-solidity/contracts/ownership/Ownable.sol";

contract SmartBank is Ownable{
  // fund address and bool state
  address public fund;
  bool public isFundSet = false;

  // An array of all the erc20 token addresses the smart fund holds
  address[] public tokenAddresses;
  // ETH Token
  ERC20 constant private ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
  // so that we can easily check that we don't add duplicates to our array
  mapping (address => bool) public tokensTraded;

  /**
   * @dev Throws if called by any other address
   */
  modifier onlyFund() {
    require(msg.sender == fund);
    _;
  }

  /**
   * @dev Throws if fund not set
   */
  modifier onlyIfFundSet() {
    require(isFundSet);
    _;
  }

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

  function approveTokensForFund() private onlyIfFundSet{

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
  function addTokenInBank(address _token) public onlyFund, onlyIfFundSet{

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


  /**
  * @dev Fund can recive ETH from BANK via Interface
  * @param _value ETH value in wei
  */
  function sendETHToFund(uint256 _value) public onlyFund, onlyIfFundSet{
    // TODO add and balance ETH allowance modifiers
    address(fund).transfer(_value);
  }


  // TODO
  // Remove allowance
  // SEND to exchange directly from BANK, just trigger in SEND vie IBank in FUND!
  // NOT FINISHED

  function sendETH(address _to, uint256 _value) public onlyFund, onlyIfFundSet{
    // TODO add add check balance ETH and  allowance modifiers
    address(_to).transfer(_value);
  }

  function sendTokens(address _to, uint256 _value, ERC20 _token) public onlyFund, onlyIfFundSet{
    // TODO add and balance and allowance modifiers
    _token.transfer(_to, _value);
  }


  // Fallback payable function in order to be able to receive ether from other contracts
  function() public payable {}
}
