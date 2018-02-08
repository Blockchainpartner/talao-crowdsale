pragma solidity ^0.4.18;

import './token/MintableToken.sol';

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public; }

contract EmindhubToken is MintableToken {

  string public constant name = "Talao";
  string public constant symbol = "TALAO";
  uint8 public constant decimals = 18;

  uint256 public vaultDeposit;
  uint public minBalanceForAccounts;
  uint256 public totalDeposit;
  uint public buyPrice;
  uint public sellPrice;
  uint public unitPrice;

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

  function EmindhubToken() public {
      setMinBalance(5);
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
      if(msg.sender.balance < minBalanceForAccounts && result)
          sell((minBalanceForAccounts - msg.sender.balance).mul(unitPrice).div(sellPrice));
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
      require (newSellPrice > 0 && newBuyPrice > 0 && newUnitPrice > 0);
      sellPrice = newSellPrice;
      buyPrice = newBuyPrice;
      unitPrice = newUnitPrice;
  }

  function buy() payable public returns (uint amount){
      amount = msg.value.mul(unitPrice).div(buyPrice);
      require(balanceOf(this)-totalDeposit >= amount);
      _transfer(this, msg.sender, amount);
      return amount;
  }

  function sell(uint amount) public returns (uint revenue){
      require(balanceOf(msg.sender) >= amount);
      transfer(this, amount);
      revenue = amount.mul(sellPrice).div(unitPrice);
      msg.sender.transfer(revenue);
      return revenue;
  }

  /**
   * function to get contract ethers back to owner
   */
  function withdrawEther(uint256 ethers) onlyOwner public returns (bool) {
      if (this.balance >= ethers) {
          return owner.send(ethers);
      }
  }

  /**
   * function to get contract tokens back to owner
   * do not take token vault deposit (totalDeposit) transfeered from user
   */
  function withdrawTalao(uint256 tokens) onlyOwner public  {
      require (balanceOf(this).sub(totalDeposit) >= tokens);
      _transfer(this, msg.sender, tokens);
  }

  /******************************************/
  /*      vault functions start here        */
  /******************************************/

  /** To create a vault access
  * vault is setup in another contract
  * Vault deposit is transferred to token contract and sum is stored in totalDeposit
  * price must be lower than Vault deposit
  * to change price you need to close and re create
  * @param price to ask clients to pay to access certificate vault
  */
  function createVaultAccess (uint256 price) public {
      require (AccessAllowance[msg.sender][msg.sender].clientAgreement==false);
      if (price>vaultDeposit) {
          Vault(msg.sender, msg.sender, 2);
          return;
      }
      if (balanceOf(msg.sender)<vaultDeposit) {
          Vault(msg.sender, msg.sender,3);
          return;
      }
      Data[msg.sender].accessPrice=price;
      transfer(this, vaultDeposit);
      totalDeposit += vaultDeposit;
      Data[msg.sender].userDeposit=vaultDeposit;
      Data[msg.sender].sharingPlan=100;
      AccessAllowance[msg.sender][msg.sender].clientAgreement=true;
      Vault(msg.sender, msg.sender, 1);
  }

  /**
  * to close a vault access, deposit is back to freelance wallet
  * total deposit in token contract is reduced by user deposit
  * to change vault access price one needs to close and open a new access
  */
  function closeVaultAccess() public {
      require (AccessAllowance[msg.sender][msg.sender].clientAgreement==true);
      assert(_transfer(this, msg.sender, Data[msg.sender].userDeposit));
      totalDeposit-=Data[msg.sender].userDeposit;
      AccessAllowance[msg.sender][msg.sender].clientAgreement=false;
      Data[msg.sender].sharingPlan=0;
      Vault(msg.sender, msg.sender, 0);
  }

  /**
  * Internal transfer, only can be called by this contract
  */
  function _transfer(address _from, address _to, uint _value) internal returns (bool) {
      require(_to != 0x0);
      require(balances[_from] >= _value);
      require((balances[_to].add(_value)) > balances[_to]);

      balances[_from] = balances[_from].sub(_value);
      balances[_to] = balances[_to].add(_value);
      Transfer(_from, _to, _value);
      return true;
  }

  /**
  * to appoint an agent or a new agent
  * former agent is replaced by new agent
  * agent will receive token on behalf freelance
  * @param newagent to appoint
  * @param newplan => sharing plan is %, 100 means 100% for freelance
  */
  function agentApproval (address newagent, uint newplan) public {
      require (newplan<=100);
      require (AccessAllowance[msg.sender][msg.sender].clientAgreement==true);
      AccessAllowance[Data[msg.sender].appointedAgent][msg.sender].clientAgreement=false;
      Vault(Data[msg.sender].appointedAgent, msg.sender, 4);
      Data[msg.sender].appointedAgent=newagent;
      Data[msg.sender].sharingPlan=newplan;
      AccessAllowance[newagent][msg.sender].clientAgreement=true;
      Vault(newagent, msg.sender, 5);
  }

  /**
   * to initialize vault Deposit
   * @param newdeposit initializes deposit for vote access creation
   */
  function setVaultDeposit (uint newdeposit) onlyOwner public returns (bool){
      vaultDeposit=newdeposit;
      return true;
  }

  /**
  * to buy an unlimited access to a freelancer vault
  * vault access  price is transfered from client to agent or freelance
  * depending on the sharing plan
  * if sharing plan is 100 then freelance receives 100% of access price
  * allowance is given to client and one stores block.number for future use
  */
  function getVaultAccess (address freelance) public returns (bool){
      require(AccessAllowance[freelance][freelance].clientAgreement==true);
      require(AccessAllowance[msg.sender][freelance].clientAgreement!=true);
      if (balanceOf(msg.sender)<Data[freelance].accessPrice){
          Vault(msg.sender, freelance, 7);
          return false;
      }
      uint256 freelance_share = Data[freelance].accessPrice.mul(Data[freelance].sharingPlan).div(100);
      uint256 agent_share = Data[freelance].accessPrice.sub(freelance_share);
      transfer(freelance, freelance_share);
      transfer(Data[freelance].appointedAgent, agent_share);
      AccessAllowance[msg.sender][freelance].clientAgreement=true;
      AccessAllowance[msg.sender][freelance].clientDate=block.number;
      Vault(msg.sender, freelance, 6);
      return true;
  }

  function getFreelanceAgent(address freelance) public returns (address) {
    return Data[freelance].appointedAgent;
  }

  function () public payable {}

}
