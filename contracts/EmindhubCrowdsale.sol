pragma solidity ^0.4.18;

import './EmindhubToken.sol';
import './crowdsale/RefundableCrowdsale.sol';
import './crowdsale/CappedCrowdsale.sol';

contract EmindhubCrowdsale is RefundableCrowdsale, CappedCrowdsale {

  //Presale
  uint256 public weiRaisedPreSale;
  uint256 public presaleCap;
  uint256 public startGeneralSale;

  uint256 public constant PRESALERATE = 1700;
  uint256 public constant GENERALRATE = 1300;

  // these might not be available before the sale
  address public constant teamWallet = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7046;
  address public constant futureRoundWallet = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7046;

  //whitelisted addresses
  mapping (address => bool) public whiteListedAddress;
  mapping (address => bool) public whiteListedAddressPresale;

  function EmindhubCrowdsale(uint256 _startDate, uint256 _startGeneralSale, uint256 _endDate,
                             uint256 _goal,uint256 _presaleCap, uint256 _cap, address _wallet)
   CappedCrowdsale(_cap) FinalizableCrowdsale()
   RefundableCrowdsale(_goal) Crowdsale(_startDate, _endDate, _wallet)
  {
    require(_goal <= _cap);
    require(_startGeneralSale > _startDate);
    require(_endDate > _startGeneralSale);
    require(_presaleCap > 0);
    require(_presaleCap < _cap);

    startGeneralSale = _startGeneralSale;
    presaleCap = _presaleCap;
  }

  function createTokenContract() internal returns (MintableToken) {
    return new EmindhubToken();
  }

  modifier onlyPresaleWhitelisted() {
    require( isWhitelistedPresale(msg.sender) ) ;
    _;
  }

  modifier onlyWhitelisted() {
    require( isWhitelisted(msg.sender) || isWhitelistedPresale(msg.sender) ) ;
    _;
  }

  /**
   * @dev Add a list of address to be whitelisted for the crowdsale only.
   * @param _users , the list of user Address. Tested for out of gas until 200 addresses.
   */
  function whitelistAddresses( address[] _users) onlyOwner {
    for(uint i = 0 ; i < _users.length ; i++) {
      whiteListedAddress[_users[i]] = true;
    }
  }

  function unwhitelistAddress( address _users) onlyOwner {
    whiteListedAddress[_users] = false;
  }

  /**
   * @dev Add a list of address to be whitelisted for the Presale And sale.
   * @param _users , the list of user Address. Tested for out of gas until 200 addresses.
   */
  function whitelistAddressesPresale( address[] _users) onlyOwner {
    for( uint i = 0 ; i < _users.length ; i++ ) {
      whiteListedAddressPresale[_users[i]] = true;
    }
  }

  function unwhitelistAddressPresale( address _users) onlyOwner {
    whiteListedAddressPresale[_users] = false;
  }

  function isWhitelisted(address _user) public constant returns (bool) {
    return whiteListedAddress[_user];
  }

  function isWhitelistedPresale(address _user) public constant returns (bool) {
    return whiteListedAddressPresale[_user];
  }

  function () external payable {
    if (validPurchasePresale()){
      buyTokensPresale(msg.sender);
    } else {
      buyTokens(msg.sender);
    }
  }

  function buyTokens(address beneficiary) payable onlyWhitelisted {
    require(beneficiary != 0x0);
    require(validPurchase());

    uint256 weiAmount = msg.value;
    uint256 tokens = weiAmount.mul(GENERALRATE);
    weiRaised = weiRaised.add(weiAmount);

    token.mint(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
    forwardFunds();
  }

  function buyTokensPresale(address beneficiary) payable onlyPresaleWhitelisted {
    require(beneficiary != 0x0);
    require(validPurchasePresale());

    uint256 weiAmount = msg.value;
    uint256 tokens = weiAmount.mul(PRESALERATE);
    weiRaisedPreSale = weiRaisedPreSale.add(weiAmount);

    token.mint(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
    forwardFunds();
  }

  function finalization() internal {
    if (goalReached()) {
      uint256 totalSupply = token.totalSupply();
      if(weiRaised<30000000000000000000000000)
      // mint 15 000 000 tokens for team
      token.mint(teamWallet, 15000000000000000000000000);
      // mint 30 000 000 tokens to be timelocked for future round(s)
      token.mint(futureRoundWallet, 30000000000000000000000000);
      token.finishMinting();
    }
    super.finalization();
  }

  // Override of the validPurchase function so that the new sale periode start at StartSale instead of Startblock.
  function validPurchase() internal constant returns (bool) {
    bool withinPeriod = block.number >= startGeneralSale && block.number <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    bool withinCap = weiRaised.add(msg.value) <= cap;
    return withinCap && withinPeriod && nonZeroPurchase;
  }

  // Sale period start at StartBlock until the sale Start ( startSale )
  function validPurchasePresale() internal constant returns (bool) {
    bool withinPeriod = block.number >= startTime && block.number < startGeneralSale;
    bool nonZeroPurchase = msg.value != 0;
    bool withinCap = weiRaisedPreSale.add(msg.value) <= presaleCap;
    return withinPeriod && nonZeroPurchase && withinCap;
  }

  // Override of the goalReached function so that the goal take into account the token raised during the Presale.
  function goalReached() public constant returns (bool) {
    uint256 totalWeiRaised = weiRaisedPreSale.add(weiRaised);
    return totalWeiRaised >= goal || super.goalReached();
  }

}
