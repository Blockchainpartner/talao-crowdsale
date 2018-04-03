pragma solidity ^0.4.18;

import './token/MintableToken.sol';

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }

/**
 * @title TalaoCrowdsale
 * @dev This contract details the TALAO token and allows freelancers to create/revoke vault access, appoint agents.
 *      This contract also implements a marketplace to buy and sell on-chain TALAO tokens.
 * @author Blockchain Partner
 */
contract TalaoToken is MintableToken {
  using SafeMath for uint256;

  // token details
  string public constant name = "Talao";
  string public constant symbol = "TALAO";
  uint8 public constant decimals = 18;

  address public marketplace;

  // vault details
  uint256 public vaultDeposit;
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

  modifier onlyMintingFinished()
  {
      require(mintingFinished == true);
      _;
  }

  /**
  * @dev Let the owner set the marketplace address once minting is over
  *      Possible to do it more than once to ensure maintainability
  * @param theMarketplace the marketplace address
  **/
  function setMarketplace(address theMarketplace)
      public
      onlyMintingFinished
      onlyOwner
  {
      marketplace = theMarketplace;
  }

  /**
  * @dev Same ERC20 behavior, but require the token to be unlocked
  * @param _spender address The address that will spend the funds.
  * @param _value uint256 The amount of tokens to be spent.
  **/
  function approve(address _spender, uint256 _value)
      public
      onlyMintingFinished
      returns (bool)
  {
      return super.approve(_spender, _value);
  }

  /**
  * @dev Same ERC20 behavior, but require the token to be unlocked and sells some tokens to refill ether balance up to minBalanceForAccounts
  * @param _to address The address to transfer to.
  * @param _value uint256 The amount to be transferred.
  **/
  function transfer(address _to, uint256 _value)
      public
      onlyMintingFinished
      returns (bool result)
  {
      return super.transfer(_to, _value);
  }

  /**
  * @dev Same ERC20 behavior, but require the token to be unlocked
  * @param _from address The address which you want to send tokens from.
  * @param _to address The address which you want to transfer to.
  * @param _value uint256 the amount of tokens to be transferred.
  **/
  function transferFrom(address _from, address _to, uint256 _value)
      public
      onlyMintingFinished
      returns (bool)
  {
      return super.transferFrom(_from, _to, _value);
  }

  /**
   * @dev Set allowance for other address and notify
   *      Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
   * @param _spender The address authorized to spend
   * @param _value the max amount they can spend
   * @param _extraData some extra information to send to the approved contract
   */
  function approveAndCall(address _spender, uint256 _value, bytes _extraData)
      public
      onlyMintingFinished
      returns (bool)
  {
      tokenRecipient spender = tokenRecipient(_spender);
      if (approve(_spender, _value)) {
          spender.receiveApproval(msg.sender, _value, this, _extraData);
          return true;
      }
  }

  /**
   * @dev Allows the owner to withdraw ethers from the contract.
   * @param ethers quantity of ethers to be withdrawn
   * @return true if withdrawal successful ; false otherwise
   */
  function withdrawEther(uint256 ethers)
      public
      onlyOwner
  {
      if (this.balance >= ethers) {
          msg.sender.transfer(ethers);
      }
  }

  /**
   * @dev Allow the owner to withdraw tokens from the contract without taking tokens from deposits.
   * @param tokens quantity of tokens to be withdrawn
   */
  function withdrawTalao(uint256 tokens)
      public
      onlyOwner
  {
      require(balanceOf(this).sub(totalDeposit) >= tokens);
      _transfer(this, msg.sender, tokens);
  }

  /******************************************/
  /*      vault functions start here        */
  /******************************************/

  /**
  * @dev Allows anyone to create a vault access.
  *      Vault is setup in another contract
  *      Vault deposit is transferred to token contract and sum is stored in totalDeposit
  *      Price must be lower than Vault deposit
  * @param price to pay to access certificate vault
  */
  function createVaultAccess (uint256 price)
      public
      onlyMintingFinished
  {
      require(AccessAllowance[msg.sender][msg.sender].clientAgreement==false);
      if (price>vaultDeposit) {
          Vault(msg.sender, msg.sender, 2);
          return;
      }
      if (balanceOf(msg.sender)<vaultDeposit) {
          Vault(msg.sender, msg.sender,3);
          return;
      }
      Data[msg.sender].accessPrice=price;
      super.transfer(this, vaultDeposit);
      totalDeposit = totalDeposit.add(vaultDeposit);
      Data[msg.sender].userDeposit=vaultDeposit;
      Data[msg.sender].sharingPlan=100;
      AccessAllowance[msg.sender][msg.sender].clientAgreement=true;
      Vault(msg.sender, msg.sender, 1);
  }

  /**
  * @dev Closes a vault access, deposit is sent back to freelance wallet
  *      Total deposit in token contract is reduced by user deposit
  */
  function closeVaultAccess()
      public
      onlyMintingFinished
  {
      require(AccessAllowance[msg.sender][msg.sender].clientAgreement==true);
      require(_transfer(this, msg.sender, Data[msg.sender].userDeposit));
      AccessAllowance[msg.sender][msg.sender].clientAgreement=false;
      totalDeposit=totalDeposit.sub(Data[msg.sender].userDeposit);
      Data[msg.sender].sharingPlan=0;
      Vault(msg.sender, msg.sender, 0);
  }

  /**
  * @dev Internal transfer function used to transfer tokens from an address to another without prior authorization.
  *      Only used in these situations:
  *           * Send tokens from the contract to a token buyer (buy() function)
  *           * Send tokens from the contract to the owner in order to withdraw tokens (withdrawTalao(tokens) function)
  *           * Send tokens from the contract to a user closing its vault thus claiming its deposit back (closeVaultAccess() function)
  * @param _from address The address which you want to send tokens from.
  * @param _to address The address which you want to transfer to.
  * @param _value uint256 the amount of tokens to be transferred.
  * @return true if transfer is successful ; should throw otherwise
  */
  function _transfer(address _from, address _to, uint _value)
      internal
      returns (bool)
  {
      require(_to != 0x0);
      require(balances[_from] >= _value);
      require((balances[_to].add(_value)) > balances[_to]);

      balances[_from] = balances[_from].sub(_value);
      balances[_to] = balances[_to].add(_value);
      Transfer(_from, _to, _value);
      return true;
  }

  /**
  * @dev Appoint an agent or a new agent
  *      Former agent is replaced by new agent
  *      Agent will receive token on behalf of the freelance talent
  * @param newagent agent to appoint
  * @param newplan sharing plan is %, 100 means 100% for freelance
  */
  function agentApproval (address newagent, uint newplan)
      public
      onlyMintingFinished
  {
      require(newplan<=100);
      require(AccessAllowance[msg.sender][msg.sender].clientAgreement==true);
      AccessAllowance[Data[msg.sender].appointedAgent][msg.sender].clientAgreement=false;
      Vault(Data[msg.sender].appointedAgent, msg.sender, 4);
      Data[msg.sender].appointedAgent=newagent;
      Data[msg.sender].sharingPlan=newplan;
      AccessAllowance[newagent][msg.sender].clientAgreement=true;
      Vault(newagent, msg.sender, 5);
  }

  /**
   * @dev Set the quantity of tokens necessary for vault access creation
   * @param newdeposit deposit (in tokens) for vault access creation
   */
  function setVaultDeposit (uint newdeposit)
      public
      onlyOwner
  {
      vaultDeposit = newdeposit;
  }

  /**
  * @dev Buy unlimited access to a freelancer vault
  *      Vault access price is transfered from client to agent or freelance depending on the sharing plan
  *      Allowance is given to client and one stores block.number for future use
  * @param freelance the address of the talent
  * @return true if access is granted ; false if not
  */
  function getVaultAccess (address freelance)
      public
      onlyMintingFinished
      returns (bool)
  {
      require(AccessAllowance[freelance][freelance].clientAgreement==true);
      require(AccessAllowance[msg.sender][freelance].clientAgreement!=true);
      if (balanceOf(msg.sender)<Data[freelance].accessPrice){
          Vault(msg.sender, freelance, 7);
          return false;
      }
      uint256 freelance_share = Data[freelance].accessPrice.mul(Data[freelance].sharingPlan).div(100);
      uint256 agent_share = Data[freelance].accessPrice.sub(freelance_share);
      super.transfer(freelance, freelance_share);
      super.transfer(Data[freelance].appointedAgent, agent_share);
      AccessAllowance[msg.sender][freelance].clientAgreement=true;
      AccessAllowance[msg.sender][freelance].clientDate=block.number;
      Vault(msg.sender, freelance, 6);
      return true;
  }

  /**
  * @dev Simple getter to retrieve talent agent
  * @param freelance talent address
  * @return address of the agent
  **/
  function getFreelanceAgent(address freelance)
      public
      view
      returns (address)
  {
      return Data[freelance].appointedAgent;
  }

}
