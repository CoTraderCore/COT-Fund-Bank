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
import "./ExchangePortalInterface.sol";

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

  // The maximum amount of tokens that can be traded via the smart fund
  uint256 public MAX_TOKENS = 50;

  event Trade(address src, uint256 srcAmount, address dest, uint256 destReceived);

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
  * @dev constructor
  *
  * @param _owner                        Address of the fund manager
  */

  constructor(address _owner){

    // set owners
    if (_owner == address(0))
      owner = msg.sender;
    else
      owner = _owner;


    // Initial Token is Ether
    tokenAddresses.push(address(ETH_TOKEN_ADDRESS));
  }

  /**
  * @dev onwer can set or change FUND
  */

  function setFund(address _fund) public onlyOwner{
    fund = _fund;

    isFundSet = true;
  }



  // This method was added to easily record the funds token balances, may (should?) be removed in the future
  function getFundTokenHolding(ERC20 _token) external view returns (uint256) {
    if (_token == ETH_TOKEN_ADDRESS)
      return this.balance;
    return _token.balanceOf(this);
  }

  /**
  * @dev Facilitates a trade of the funds holdings via the exchange portal
  *
  * @param _source            ERC20 token to convert from
  * @param _sourceAmount      Amount to convert (in _source token)
  * @param _destination       ERC20 token to convert to
  * @param _type              The type of exchange to trade with
  * @param _additionalArgs    Array of bytes32 additional arguments
  * @param exchangePortal     exchange Portal
  */
  function tradeFromBank(
    ERC20 _source,
    uint256 _sourceAmount,
    ERC20 _destination,
    uint256 _type,
    bytes32[] _additionalArgs,
    ExchangePortalInterface exchangePortal
    ) public onlyFund{

    uint256 receivedAmount;

    if (_source == ETH_TOKEN_ADDRESS) {
      // Make sure we set fund
      require(isFundSet);
      // Make sure BANK contains enough ether
      require(this.balance >= _sourceAmount);
      // Call trade on ExchangePortal along with ether
      receivedAmount = exchangePortal.trade.value(_sourceAmount)(
        _source,
        _sourceAmount,
        _destination,
        _type,
        _additionalArgs
      );
    } else {
      _source.approve(exchangePortal, _sourceAmount);
      receivedAmount = exchangePortal.trade(
        _source,
        _sourceAmount,
        _destination,
        _type,
        _additionalArgs
      );
    }

    if (receivedAmount > 0)
      _addToken(_destination);

    emit Trade(_source, _sourceAmount, _destination, receivedAmount);
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

  /**
  * @dev Fund can remove token from tokensTraded in bank
  *
  * @param _token         The address of the token to be removed
  * @param _tokenIndex    The index of the token to be removed
  *
  */
  function removeToken(address _token, uint256 _tokenIndex) public onlyFund {
    require(tokensTraded[_token]);
    require(ERC20(_token).balanceOf(this) == 0);
    require(tokenAddresses[_tokenIndex] == _token);

    tokensTraded[_token] = false;

    // remove token from array
    uint256 arrayLength = tokenAddresses.length - 1;
    tokenAddresses[_tokenIndex] = tokenAddresses[arrayLength];
    delete tokenAddresses[arrayLength];
    tokenAddresses.length--;
  }

  /**
  * @dev view all tokens address in Bank
  */
  function getAllTokenAddresses() public view returns (address[]) {
    return tokenAddresses;
  }

  /**
  * @dev view bank tokens length
  */
  function TokensLength() public view returns (uint) {
    return tokenAddresses.length;
  }

  /**
  * @dev view address of bank token by index
  */
  function TokensAddressByIndex(uint _index) public view returns (address){
    return tokenAddresses[_index];
  }

  /**
  * @dev Fund can send ETH from BANK via Interface
  * @param _value ETH value in wei
  */
  function sendETH(address _to, uint256 _value) public onlyFund{
    // TODO add add check balance ETH and  allowance modifiers
    _to.transfer(_value);
  }

  /**
  * @dev Fund can send tokens from BANK via Interface
  * @param _value ETH value in wei
  */
  function sendTokens(address _to, uint256 _value, ERC20 _token) public onlyFund{
    // TODO add and balance and allowance modifiers
    _token.transfer(_to, _value);
  }

  // Fallback payable function in order to be able to receive ether from other contracts
  function() public payable {}
}
