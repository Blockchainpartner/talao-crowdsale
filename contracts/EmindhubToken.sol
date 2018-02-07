pragma solidity ^0.4.18;

import './token/MintableToken.sol';

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public; }

contract EmindhubToken is MintableToken {
  using SafeMath for uint256;
  string public constant name = "Talao";
  string public constant symbol = "TALAO";
  uint8 public constant decimals = 18;

  uint256 public sellPrice;
  uint256 public buyPrice;
  uint256 public unitPrice;
  uint256 public vaultDeposit;
  uint minBalanceForAccounts;
  uint256 public totalDeposit;

  struct FreelanceData {
      uint256 accessPrice;
      address appointedAgent;
      uint sharingPlan;
      uint256 userDeposit;
  }

  struct ClientAccess {
      bool clientAgreement;
      uint clientDate;
  }

  // Vault allowance client x freelancer
  mapping (address => mapping (address => ClientAccess)) public AccessAllowance;

  // Freelance data is public
  mapping (address=>FreelanceData) public Data;

  // Those event notifies UI about vaults action with msg code
  // msg = 0 Vault access closed
  // msg = 1 Vault access created
  // msg = 2 Vault access price too high
  // msg = 3 not enough tokens to pay deposit
  // msg = 4 agent removed
  // msg = 5 new agent appointed
  // msg = 6 vault access granted to client
  // msg = 7 client not enough token to pay vault access
  event Vault(address indexed client, address indexed freelance, uint msg);

  modifier onlyMintingFinished() {
    require(mintingFinished == true);
    _;
  }

  /**
   *Initializes contract with initial supply tokens to the creator of the contract
   * refill is initialized with 5 finneys
   * @param _sell is sell price for 1 _unit to tokens in ether
   * @param _buy price for 1 _unit to token in ethers
   * @param _unit the unit
   */
  function EmindhubToken(uint256 _sell, uint256 _buy, uint256 _unit) public {
      require (_sell!=0 && _buy!=0 && _unit!=0);
      //setPrices (_sell, _buy, _unit);
      //setMinBalance(5);
  }

  /// @dev Same ERC20 behavior, but require the token to be unlocked
  /// @param _spender address The address which will spend the funds.
  /// @param _value uint256 The amount of tokens to be spent.
  function approve(address _spender, uint256 _value) public onlyMintingFinished returns (bool) {
      return super.approve(_spender, _value);
  }

  /// @dev Same ERC20 behavior, but require the token to be unlocked
  /// @param _to address The address to transfer to.
  /// @param _value uint256 The amount to be transferred.
  /**
   * basic ERC20 transfer tokens function with ether refill
   *
   * Send `_value` tokens to `_to` from your account
   * ethers refill is included
   * @param _to The address of the recipient
   * @param _value the amount to send
   */
  function transfer(address _to, uint256 _value) public onlyMintingFinished returns (bool) {
      bool result = super.transfer(_to, _value);
      //if(msg.sender.balance < minBalanceForAccounts && result)
          //sell((minBalanceForAccounts - msg.sender.balance)* unitPrice / sellPrice);
      return result;
  }

  /// @dev Same ERC20 behavior, but require the token to be unlocked
  /// @param _from address The address which you want to send tokens from.
  /// @param _to address The address which you want to transfer to.
  /// @param _value uint256 the amount of tokens to be transferred.
  function transferFrom(address _from, address _to, uint256 _value) public onlyMintingFinished returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  /**
   * Set allowance for other address and notify
   *
   * Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
   *
   * @param _spender The address authorized to spend
   * @param _value the max amount they can spend
   * @param _extraData some extra information to send to the approved contract
   */
  function approveAndCall(address _spender, uint256 _value, bytes _extraData) public onlyMintingFinished returns (bool) {
      tokenRecipient spender = tokenRecipient(_spender);
      if (approve(_spender, _value)) {
          spender.receiveApproval(msg.sender, _value, this, _extraData);
          return true;
      }
  }

  /**
   * to initialize automatic refill with finneys
   */
  function setMinBalance(uint minimumBalanceInFinney) onlyOwner public {
       minBalanceForAccounts = minimumBalanceInFinney * 1 finney;
  }

  /**
  * Allow users to buy tokens for `newBuyPrice` eth and sell tokens for `newSellPrice` eth
  * @param newSellPrice Price the users can sell to the contract
  * @param newBuyPrice Price users can buy from the contract
  * @param newUnitPrice to manage decimal issue 0,35 = 35 /100 (100 is unit)
  */
  function setPrices(uint256 newSellPrice, uint256 newBuyPrice, uint256 newUnitPrice) onlyOwner public {
      require (newSellPrice !=0 && newBuyPrice !=0 && newUnitPrice != 0);
      sellPrice = newSellPrice;
      buyPrice = newBuyPrice;
      unitPrice = newUnitPrice;
  }

}
