pragma solidity ^0.4.24;

contract ISmartBank {

  function tradeFromBank(
    ERC20 _source,
    uint256 _sourceAmount,
    ERC20 _destination,
    address _destAddress,
    uint256 _type,
    bytes32[] _additionalArgs,
    ExchangePortalInterface exchangePortal
  )
  public {

  }

  function sendETH(address _to, uint256 _value) public {

  }

  function sendTokens(address _to, uint256 _value, ERC20 _token) public {

  }

}
