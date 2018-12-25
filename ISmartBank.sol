pragma solidity ^0.4.24;

//import "../zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
//import "./ExchangePortalInterface.sol";

contract ISmartBank {

  function tradeFromBank(
    ERC20 _source,
    uint256 _sourceAmount,
    ERC20 _destination,
    uint256 _type,
    bytes32[] _additionalArgs,
    ExchangePortalInterface exchangePortal
    )
    public
    returns(uint256);


  function TokensLength() public view returns (uint);

  function TokensAddressByIndex(uint _index) public view returns (address);

  function getAllTokenAddresses() public view returns (address[]);

  function removeToken(address _token, uint256 _tokenIndex) public;


  function sendETH(address _to, uint256 _value) public;

  function sendTokens(address _to, uint256 _value, ERC20 _token) public;


  function getTotalEtherDeposited() public view returns (uint256);

  function increaseTotalEtherDeposited(uint256 _value) public;


  function getTotalShares() public view returns (uint256);

  function increaseTotalShares(uint256 _value) public;

  function decreaseTotalShares(uint256 _value) public returns(uint256);


  function getAddressesNetDeposit(address _sender) public view returns (int256);

  function increaseAddressesNetDeposit(address _sender, uint256 _value) public returns(int256);

  function decreaseAddressesNetDeposit(address _sender, uint256 _value) public returns(int256);


  function getAddressToShares(address _sender) public view returns (uint256);

  function increaseAddressToShares(address _sender, uint256 _value) public returns(uint256);

  function decreaseAddressToShares(address _sender, uint256 _value) public returns(uint256);

}
