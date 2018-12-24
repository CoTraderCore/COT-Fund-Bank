pragma solidity ^0.4.24;

import "./SmartFundInterface.sol";
import "./ISmartBank.sol";

/*
  The SmartFund contract is what holds all the tokens and ether, and contains all the logic
  for calculating its value (and ergo profit), allows users to deposit/withdraw their funds,
  and calculates the fund managers cut of the funds profit among other things.
  The SmartFund gets the value of its token holdings (in Ether) and trades through the ExchangePortal
  contract. This means that as new exchange capabalities are added to new exchange portals, the
  SmartFund will be able to upgrade to a new exchange portal, and trade a wider variety of assets
  with a wider variety of exchanges. The SmartFund is also connected to a PermittedExchanges contract,
  which determines which exchange portals the SmartFund is allowed to connect to, restricting
  the fund owners ability to connect to a potentially malicious contract. In order for a new
  exchange portal to be added to PermittedExchanges, a 3 day timeout must pass, in which time
  the public may audit the new contract code to be assured that the new exchange portal does
  not allow the manager to act maliciously with the funds holdings.
*/
contract SmartFund is SmartFundInterface, Ownable, ERC20 {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  // bank address
  address public bank;

  // check if bank isSet
  bool public isBankSet = false;

  // bank interface
  ISmartBank public Ibank;

  // The address of the Exchange Portal
  ExchangePortalInterface public exchangePortal;

  // The Smart Contract which stores the addresses of all the authorized Exchange Portals
  PermittedExchangesInterface public permittedExchanges;

  // For ERC20 compliance
  string public name;

  // The maximum amount of tokens that can be traded via the smart fund
  uint256 public MAX_TOKENS = 50;

  // Percentages are rounded to 3 decimal places
  uint256 public TOTAL_PERCENTAGE = 10000;

  // Address of the platform that takes a cut from the fund manager success cut
  address public platformAddress;

  // the total number of shares in the fund
  uint256 public totalShares = 0;

  // KyberExchange recognizes ETH by this address
  ERC20 constant private ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);

  // Denomination of initial shares
  uint256 constant private INITIAL_SHARES = 10 ** 18;

  // Total amount of ether withdrawn by all users
  uint256 public totalEtherWithdrawn = 0;

  // The percentage of earnings paid to the fund manager. 10000 = 100%
  // e.g. 10% is 1000
  uint256 public successFee;

  // The percentage of fund manager earnings paid to the platform. 10000 = 100%
  // e.g. 10% is 1000
  uint256 public platformFee;

  // The earnings the fund manager has already cashed out
  uint256 public fundManagerCashedOut = 0;

  // Standart Kyber Parametrs
  bytes32[] KyberAdditionalParams;

  // Boolean value that determines whether the fund accepts deposits from anyone or
  // only specific addresses approved by the manager
  bool public onlyWhitelist = false;

  // Mapping of addresses that are approved to deposit if the manager only want's specific
  // addresses to be able to invest in their fund
  mapping (address => bool) public whitelist;

  // how many shares belong to each address
  mapping (address => uint256) public addressToShares;

  // so that we can easily check that we don't add duplicates to our array
  mapping (address => bool) public tokensTraded;

  // this is really only being used to more easily show profits, but may not be necessary
  // if we do a lot of this offchain using events to track everything
  // total `depositToken` deposited - total `depositToken` withdrawn
  mapping (address => int256) public addressesNetDeposit;

  // Events
  event Deposit(address indexed user, uint256 amount, uint256 sharesReceived, uint256 totalShares);
  event Withdraw(address indexed user, uint256 sharesRemoved, uint256 totalShares);
  event SmartFundCreated(address indexed owner);

  /**
  * @dev constructor
  *
  * @param _owner                        Address of the fund manager
  * @param _name                         Name of the fund, required for DetailedERC20 compliance
  * @param _successFee                   Percentage of profit that the fund manager receives
  * @param _platformFee                  Percentage of the success fee that goes to the platform
  * @param _platformAddress              Address of platform to send fees to
  * @param _exchangePortalAddress        Address of initial exchange portal
  * @param _permittedExchangesAddress    Address of PermittedExchanges contract
  */
  constructor(
    address _owner,
    string _name,
    uint256 _successFee,
    uint256 _platformFee,
    address _platformAddress,
    address _exchangePortalAddress,
    address _permittedExchangesAddress
  ) public {
    // never allow a 100% fee
    require(_successFee < TOTAL_PERCENTAGE);
    require(_platformFee < TOTAL_PERCENTAGE);

    name = _name;
    successFee = _successFee;
    platformFee = _platformFee;

    if (_owner == address(0))
      owner = msg.sender;
    else
      owner = _owner;

    if (_platformAddress == address(0))
      platformAddress = msg.sender;
    else
      platformAddress = _platformAddress;


    exchangePortal = ExchangePortalInterface(_exchangePortalAddress);
    permittedExchanges = PermittedExchangesInterface(_permittedExchangesAddress);

    // Standard Kyber Parametrs converted to bytes32
    // maxDestAmount = bytes32(2**256 - 1)
    KyberAdditionalParams.push(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    // minConversionRat = bytes32(1)
    KyberAdditionalParams.push(0x0000000000000000000000000000000000000000000000000000000000000001);
    // walletId bytes32(0)
    KyberAdditionalParams.push(0x0000000000000000000000000000000000000000000000000000000000000000);

    emit SmartFundCreated(owner);
  }

  /**
  * @dev owner can change BANK
  */
  function changeBank(address _bank) public onlyOwner{
    bank = _bank;

    Ibank = ISmartBank(_bank);

    isBankSet = true;
  }


  /**
  * @dev contract SmartFundRegistry can set BANK in FUND during initialization
  */
  function BankInitializer(address _bank) public {
    require(!isBankSet);

    require(msg.sender == platformAddress);

    bank = _bank;

    Ibank = ISmartBank(_bank);

    isBankSet = true;
  }

  /**
  * @dev Rebalance ETH input value to % balance of each asset in curent fund
  *
  * HOW IT WORK
  * for example we have 3 ETH and 2582 KNC in fund and Rate 2582 KNC = 7 Ether (For the current day)
  * in this case if user send 10 ETH fund rebalance 30% ETH to ETH and 70% ETH send to exchange for get KNC
  *
  * In other words, the greater the balance of an asset, the more it receives ETH
  * for convert this ETH to asset value
  *
  * Algoritm to calculate tokens value Ratio in ETH % to INPUT ETH
  * 1) get sum all tokens value in Ether via calculateFundValue() function
  * 2) get 1% of total sum all tokens = total sum / 100
  * 3) get rate percent of each asset = each asset balance / 1% of total sum
  * 4) get 1% of input sum = input sum / 100
  * 5) get percent ETH of each active by input rate = input sum 1% percent * each asset percent
  *
  * @param _value               ETH value
  * @param _type                type of exchange
  */
  function _rebalance(uint256 _value, uint256 _type) private{
  require(isBankSet);

  if(Ibank.TokensLength() > 1){

  // checking if not empty token array
  // array should be more 1 because we store ETH in token array also

  uint256 tokenValueINETH;

  uint256 TokensSumInETH = calculateFundValue();
  // get 1% of tokens sum
  // now we do not need sub new value from balance to do right calculation
  // uint256 onePercentFromTokensSum = TokensSumInETH.sub(_value).div(100);
  uint256 onePercentFromTokensSum = TokensSumInETH.div(100);
  // get 1% of input _value
  uint256 onePercentOfInput = _value.div(100);

  // get tokensArray from BANK
  address[] memory tokensInBank = Ibank.getAllTokenAddresses();


  for (uint256 i = 1; i < tokensInBank.length; i++) {

  ERC20 token = ERC20(tokensInBank[i]);

  // WE don't need rebalance for ETH token
  if(token != ETH_TOKEN_ADDRESS)

  // get Token Value in ETH
  tokenValueINETH = exchangePortal.getValue(token, ETH_TOKEN_ADDRESS, token.balanceOf(bank));
  // if return value of 0 indicates that an exchange from source to dest
  // is currently not available.
  if(tokenValueINETH > 0)

  uint256 eachTokenPercent = tokenValueINETH.div(onePercentFromTokensSum).mul(onePercentOfInput);

  // Trade for dest allow exchange ETH to token and send to any address, not for msg.sender
  exchangePortal.tradeForDest.value(eachTokenPercent)(
    ETH_TOKEN_ADDRESS, // ERC20 _source,
    eachTokenPercent, // uint256 _sourceAmount,
    token,           // ERC20 _destination,
    bank,            // address _destAddress,
    KyberAdditionalParams //bytes32[] _additionalArgs
  );
  }

  // Send all remains ETH after rebalance to BANK
  bank.transfer(address(this).balance);
  }
  else{
  // Send all recived ETH to BANK
  bank.transfer(address(this).balance);
  }
  }


  /**
  * @dev Deposits ether into the fund and allocates a number of shares to the sender
  * depending on the current number of shares, the funds value, and amount deposited
  *
  * @return The amount of shares allocated to the depositor
  */
  function deposit() external payable returns (uint256) {
    require(isBankSet);
    // Check if the sender is allowed to deposit into the fund
    if (onlyWhitelist)
      require(whitelist[msg.sender]);

    // Require that the amount sent is not 0
    require(msg.value != 0);

    // totalEtherDeposited += msg.value;
    Ibank.increaseTotalEtherDeposited(msg.value);

    // Call rebalance
    _rebalance(msg.value, 0);

    // Calculate number of shares
    uint256 shares = calculateDepositToShares(msg.value);

    // If user would receive 0 shares, don't continue with deposit
    require(shares != 0);

    // Add shares to total
    totalShares = totalShares.add(shares);

    // Add shares to address
    addressToShares[msg.sender] = addressToShares[msg.sender].add(shares);

    addressesNetDeposit[msg.sender] += int256(msg.value);

    emit Deposit(msg.sender, msg.value, shares, totalShares);

    return shares;
  }

  // NOT TESTED!!!
  /**
  * @dev Sends (_mul/_div) of every token (and ether) the funds holds to _withdrawAddress
  *
  * @param _mul                The numerator
  * @param _div                The denominator
  * @param _withdrawAddress    Address to send the tokens/ether to
  */
  function _withdraw(uint256 _mul, uint256 _div, address _withdrawAddress) private returns (uint256) {
    require(isBankSet);

    address[] memory TokensInBANK = Ibank.getAllTokenAddresses();

    for (uint256 i = 1; i < TokensInBANK.length; i++) {
      // Transfer that _mul/_div of each token we hold to the user
      ERC20 token = ERC20(TokensInBANK[i]);
      uint256 fundAmount = token.balanceOf(bank);
      uint256 payoutAmount = fundAmount.mul(_mul).div(_div);

    //  token.transfer(_withdrawAddress, payoutAmount);
    //  windraw tokens FROM BANK
    Ibank.sendTokens(_withdrawAddress, payoutAmount, token);
    }
    // Transfer ether to _withdrawAddress
    uint256 etherPayoutAmount = (bank.balance).mul(_mul).div(_div);
    // _withdrawAddress.transfer(etherPayoutAmount);
    // windraw ETH from BANK
    Ibank.sendETH(_withdrawAddress, etherPayoutAmount);
  }

  /**
  * @dev Withdraws users fund holdings, sends (userShares/totalShares) of every held token
  * to msg.sender, defaults to 100% of users shares.
  *
  * @param _percentageWithdraw    The percentage of the users shares to withdraw.
  */
  function withdraw(uint256 _percentageWithdraw) external {
    require(totalShares != 0);

    uint256 percentageWithdraw = (_percentageWithdraw == 0) ? TOTAL_PERCENTAGE : _percentageWithdraw;

    uint256 addressShares = addressToShares[msg.sender];

    uint256 numberOfWithdrawShares = addressShares.mul(percentageWithdraw).div(TOTAL_PERCENTAGE);

    uint256 fundManagerCut;
    uint256 fundValue;

    // Withdraw the users share minus the fund manager's success fee
    (fundManagerCut, fundValue, ) = calculateFundManagerCut();

    uint256 withdrawShares = numberOfWithdrawShares.mul(fundValue.sub(fundManagerCut)).div(fundValue);

    _withdraw(withdrawShares, totalShares, msg.sender);

    // Store the value we are withdrawing in ether
    uint256 valueWithdrawn = fundValue.mul(withdrawShares).div(totalShares);

    totalEtherWithdrawn = totalEtherWithdrawn.add(valueWithdrawn);
    addressesNetDeposit[msg.sender] -= int256(valueWithdrawn);

    // Subtract from total shares the number of withdrawn shares
    totalShares = totalShares.sub(numberOfWithdrawShares);
    addressToShares[msg.sender] = addressToShares[msg.sender].sub(numberOfWithdrawShares);

    emit Withdraw(msg.sender, numberOfWithdrawShares, totalShares);
  }

  /**
  * @dev Facilitates a trade of the funds holdings via the exchange portal
  *
  * @param _source            ERC20 token to convert from
  * @param _sourceAmount      Amount to convert (in _source token)
  * @param _destination       ERC20 token to convert to
  * @param _type              The type of exchange to trade with
  * @param _additionalArgs    Array of bytes32 additional arguments
  */
  function trade(
    ERC20 _source,
    uint256 _sourceAmount,
    ERC20 _destination,
    uint256 _type,
    bytes32[] _additionalArgs
  ) external onlyOwner {
    require(isBankSet);
    Ibank.tradeFromBank(
    _source,
    _sourceAmount,
    _destination,
    _type,
    _additionalArgs,
    exchangePortal // pass to bank curent exchange portall
    );
  }

  /**
  * @dev Calculates the amount of shares received according to ether deposited
  *
  * @param _amount    Amount of ether to convert to shares
  *
  * @return Amount of shares to be received
  */
  function calculateDepositToShares(uint256 _amount) public view returns (uint256) {
    uint256 fundManagerCut;
    uint256 fundValue;

    // If there are no shares in the contract, whoever deposits owns 100% of the fund
    // we will set this to 10^18 shares, but this could be any amount
    if (totalShares == 0)
      return INITIAL_SHARES;

    (fundManagerCut, fundValue, ) = calculateFundManagerCut();

    uint256 fundValueBeforeDeposit = fundValue.sub(_amount).sub(fundManagerCut);

    if (fundValueBeforeDeposit == 0)
      return 0;

    return _amount.mul(totalShares).div(fundValueBeforeDeposit);

  }

  /**
  * @dev Calculates the FUND value in BANK in deposit token (Ether)
  *
  * @return The current total ETH + All tokens in ETH rate
  */
  function calculateFundValue() public view returns (uint256) {
    require(isBankSet);

    uint256 ethBalance = bank.balance;

    // If the BANK only contains ether, return the funds ether balance
    if (Ibank.TokensLength() == 1)
      return ethBalance;

    // Otherwise, we get the value of all the other tokens in ether via exchangePortal
    address[] memory TokensInBANK = Ibank.getAllTokenAddresses();
    address[] memory fromAddresses = new address[](TokensInBANK.length - 1);
    uint256[] memory amounts = new uint256[](TokensInBANK.length - 1);


    for (uint i = 1; i < TokensInBANK.length; i++) {
      fromAddresses[i-1] = TokensInBANK[i];
      amounts[i-1] = ERC20(TokensInBANK[i]).balanceOf(bank);
    }

    // Ask the Exchange Portal for the value of all the funds tokens in eth
    uint256 tokensValue = exchangePortal.getTotalValue(fromAddresses, amounts, ETH_TOKEN_ADDRESS);

    return ethBalance + tokensValue;
  }

  // NOT TESTED!!!
  /**
  * @dev get al token address in fund
  */
  function getAllTokenAddresses() public view returns (address[]) {
    return Ibank.getAllTokenAddresses();
  }

  function getTokenValue(ERC20 _token) public view returns (uint256) {
    if (_token == ETH_TOKEN_ADDRESS)
      return bank.balance;
    uint256 tokenBalance = _token.balanceOf(bank);

    return exchangePortal.getValue(_token, ETH_TOKEN_ADDRESS, tokenBalance);
  }


  /**
  * @dev Adds a token to tokensTraded if it's not already there
  * @param _token    The token to add
  */
  /* function _addToken(address _token) private {
    // don't add token to if we already have it in our list
    if (tokensTraded[_token] || (_token == address(ETH_TOKEN_ADDRESS)))
      return;

    tokensTraded[_token] = true;
    uint256 tokenCount = tokenAddresses.push(_token);

    // we can't hold more than MAX_TOKENS tokens
    require(tokenCount <= MAX_TOKENS);
  } */


  //THIS NOT TESTED!!!
  /**
  * @dev Removes a token from tokensTraded
  *
  * @param _token         The address of the token to be removed
  * @param _tokenIndex    The index of the token to be removed
  *
  */
  function removeToken(address _token, uint256 _tokenIndex) public onlyOwner {
    Ibank.removeToken(_token, _tokenIndex);
  }


  // This method should be removed asap, all this data can be grabbed without this method,
  // albeit with a few more calls required
  function getSmartFundData() public view returns (
    address _owner,
    string _name,
    uint256 _totalShares,
    address[] _tokenAddresses,
    uint256 _successFee
  ) {
    _owner = owner;
    _name = name;
    _totalShares = totalShares;
    _tokenAddresses = Ibank.getAllTokenAddresses();
    _successFee = successFee;
  }

  /**
  * @dev Calculates the fund managers cut, depending on the funds profit and success fee
  *
  * @return fundManagerRemainingCut    The fund managers cut that they have left to withdraw
  * @return fundValue                  The funds current value
  * @return fundManagerTotalCut        The fund managers total cut of the profits until now
  */
  function calculateFundManagerCut() public view returns (
    uint256 fundManagerRemainingCut, // fm's cut of the profits that has yet to be cashed out (in `depositToken`)
    uint256 fundValue, // total value of fund (in `depositToken`)
    uint256 fundManagerTotalCut // fm's total cut of the profits (in `depositToken`)
  ) {
    fundValue = calculateFundValue();
    // The total amount of ether currently deposited into the fund, takes into account the total ether
    // withdrawn by investors as well as ether withdrawn by the fund manager
    // NOTE: value can be negative if the manager performs well and investors withdraw more
    // ether than they deposited
    uint256 totalEtherDeposited = Ibank.getTotalEtherDeposited();
    int256 curTotalEtherDeposited = int256(totalEtherDeposited) - int256(totalEtherWithdrawn.add(fundManagerCashedOut));

    // If profit < 0, the fund managers totalCut and remainingCut are 0
    if (int256(fundValue) <= curTotalEtherDeposited) {
      fundManagerTotalCut = 0;
      fundManagerRemainingCut = 0;
    } else {
      // calculate profit. profit = current fund value - total deposited + total withdrawn + total withdrawn by fm
      uint256 profit = uint256(int256(fundValue) - curTotalEtherDeposited);
      // remove the money already taken by the fund manager and take percentage
      fundManagerTotalCut = profit.mul(successFee).div(TOTAL_PERCENTAGE);
      fundManagerRemainingCut = fundManagerTotalCut.sub(fundManagerCashedOut);
    }
  }

  /**
  * @dev Allows the fund manager to withdraw their cut of the funds profit
  */
  function fundManagerWithdraw() public onlyOwner {
    uint256 fundManagerCut;
    uint256 fundValue;

    (fundManagerCut, fundValue, ) = calculateFundManagerCut();

    uint256 platformCut = (platformFee == 0) ? 0 : fundManagerCut.mul(platformFee).div(TOTAL_PERCENTAGE);

    _withdraw(platformCut, fundValue, platformAddress);
    _withdraw(fundManagerCut - platformCut, fundValue, msg.sender);

    fundManagerCashedOut = fundManagerCashedOut.add(fundManagerCut);
  }

  // calculate the current value of an address's shares in the fund
  function calculateAddressValue(address _address) public view returns (uint256) {
    if (totalShares == 0)
      return 0;

    return calculateFundValue().mul(addressToShares[_address]).div(totalShares);
  }

  // calculate the net profit/loss for an address in this fund
  function calculateAddressProfit(address _address) public view returns (int256) {
    uint256 currentAddressValue = calculateAddressValue(_address);

    return int256(currentAddressValue) - addressesNetDeposit[_address];
  }

  /**
  * @dev Calculates the funds profit
  *
  * @return The funds profit in deposit token (Ether)
  */
  function calculateFundProfit() public view returns (int256) {
    uint256 fundValue = calculateFundValue();
    uint256 totalEtherDeposited = Ibank.getTotalEtherDeposited();
    return int256(fundValue) + int256(totalEtherWithdrawn) - int256(totalEtherDeposited);
  }

  // This method was added to easily record the funds token balances, may (should?) be removed in the future
  function getFundTokenHolding(ERC20 _token) external view returns (uint256) {
    if (_token == ETH_TOKEN_ADDRESS)
      return bank.balance;
    return _token.balanceOf(bank);
  }

  /**
  * @dev Allows the manager to set whether or not only whitelisted addresses can deposit into
  * their fund
  *
  * @param _onlyWhitelist    boolean representing whether only whitelisted addresses can deposit
  */
  function setWhitelistOnly(bool _onlyWhitelist) external onlyOwner {
    onlyWhitelist = _onlyWhitelist;
  }

  /**
  * @dev Allows the fund manager to whitelist specific addresses to control
  * whos allowed to deposit into the fund
  *
  * @param _user       The user address to whitelist
  * @param _allowed    The status of _user, true means allowed to deposit, false means not allowed
  */
  function setWhitelistAddress(address _user, bool _allowed) external onlyOwner {
    whitelist[_user] = _allowed;
  }

  /**
  * @dev Allows the fund manager to connect to a new exchange portal
  *
  * @param _newExchangePortalAddress    The address of the new exchange portal to use
  */
  function setNewExchangePortal(address _newExchangePortalAddress) public onlyOwner {
    // Require that the new exchange portal is permitted by permittedExchanges
    require(permittedExchanges.permittedAddresses(_newExchangePortalAddress));

    exchangePortal = ExchangePortalInterface(_newExchangePortalAddress);
  }

  /**
  * @dev This method is present in the alpha testing phase in case for some reason there are funds
  * left in the SmartFund after all shares were withdrawn
  *
  * @param _token    The address of the token to withdraw
  */
  function emergencyWithdraw(address _token) external onlyOwner {
    require(totalShares == 0);
    if (_token == address(ETH_TOKEN_ADDRESS)) {
      msg.sender.transfer(this.balance);
    } else {
      ERC20(_token).transfer(msg.sender, ERC20(_token).balanceOf(this));
    }
  }


  // Fallback payable function in order to be able to receive ether from other contracts
  function() public payable {}

  /**
    **************************** ERC20 Compliance ****************************
  **/

  // Note that addressesNetDeposit does not get updated when transferring shares, since
  // this is used for updating off-chain data it doesn't affect the smart contract logic,
  // but is an issue that currently exists

  event Transfer(address indexed from, address indexed to, uint256 value);

  event Approval(address indexed owner, address indexed spender, uint256 value);

  uint8 public decimals = 18;

  string public symbol = "FND";

  mapping (address => mapping (address => uint256)) internal allowed;

  /**
  * @dev Total number of shares in existence
  */
  function totalSupply() public view returns (uint256) {
    return totalShares;
  }

  /**
  * @dev Gets the balance of the specified address.
  *
  * @param _who    The address to query the the balance of.
  *
  * @return A uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _who) public view returns (uint256) {
    return addressToShares[_who];
  }

  /**
  * @dev Transfer shares for a specified address
  *
  * @param _to       The address to transfer to.
  * @param _value    The amount to be transferred.
  *
  * @return true upon success
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= addressToShares[msg.sender]);

    addressToShares[msg.sender] = addressToShares[msg.sender].sub(_value);
    addressToShares[_to] = addressToShares[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
   * @dev Transfer shares from one address to another
   *
   * @param _from     The address which you want to send tokens from
   * @param _to       The address which you want to transfer to
   * @param _value    The amount of shares to be transferred
   *
   * @return true upon success
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= addressToShares[_from]);
    require(_value <= allowed[_from][msg.sender]);

    addressToShares[_from] = addressToShares[_from].sub(_value);
    addressToShares[_to] = addressToShares[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of shares on behalf of msg.sender.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   *
   * @param _spender    The address which will spend the funds.
   * @param _value      The amount of shares to be spent.
   *
   * @return true upon success
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of shares that an owner allowed to a spender.
   *
   * @param _owner      The address which owns the funds.
   * @param _spender    The address which will spend the funds.
   *
   * @return A uint256 specifying the amount of shares still available for the spender.
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

}
