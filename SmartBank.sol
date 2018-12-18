pragma solidity ^0.4.24;
import "./zeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract SmartBank {
  address public fund;
  // An array of all the erc20 token addresses the smart fund holds
  address[] public tokenAddresses;

  ERC20 constant private ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);


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

  // Fallback payable function in order to be able to receive ether from other contracts
  function() public payable {}
}
