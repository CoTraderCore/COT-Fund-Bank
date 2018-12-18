pragma solidity ^0.4.24;

import "./zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./zeppelin-solidity/contracts/ownership/Ownable.sol";

contract SmartBank is Ownable{
  address public fund;
  // An array of all the erc20 token addresses the smart fund holds
  address[] public tokenAddresses;
  // The maximum amount of tokens that can be traded via the smart fund
  uint256 public MAX_TOKENS = 50;
  // ETH Token
  ERC20 constant private ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
  // so that we can easily check that we don't add duplicates to our array
  mapping (address => bool) public tokensTraded;


  function setFund(address _fund) public{
    fund = _fund;
  }

  /**
  * @dev Adds a token to tokensTraded if it's not already there
  * @param _token    The token to add
  */
  function _addToken(address _token) private {
    // don't add token to if we already have it in our list
    if (tokensTraded[_token] || (_token == address(ETH_TOKEN_ADDRESS)))
      return;

    tokensTraded[_token] = true;
    uint256 tokenCount = tokenAddresses.push(_token);

    // we can't hold more than MAX_TOKENS tokens
    require(tokenCount <= MAX_TOKENS);
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
    // TODO add modifiers
    address(fund).transfer(_value);
  }

  // Fallback payable function in order to be able to receive ether from other contracts
  function() public payable {}
}
