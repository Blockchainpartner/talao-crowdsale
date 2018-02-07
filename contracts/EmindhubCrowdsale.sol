pragma solidity ^0.4.18;

import './EmindhubToken.sol';
import './crowdsale/ProgressiveIndividualCappedCrowdsale.sol';
import './token/TokenTimelock.sol';
import './token/TokenVesting.sol';

contract EmindhubCrowdsale is ProgressiveIndividualCappedCrowdsale {

  //Presale
  uint256 public weiRaisedPreSale;
  uint256 public presaleCap;
  uint256 public startGeneralSale;

  uint256 public constant presaleBonus = 400;
  uint256 public constant generalRate = 1300;
  uint256 public dateOfBonusRelease;

  address public constant reserveWallet = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7046;
  address public constant futureRoundWallet = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7047;
  address public constant foundersWallet = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7048;
  uint256 public constant cliffTeamTokensRelease = 1 years;
  uint256 public constant lockTeamTokens = 2 years;
  uint256 public constant futureRoundTokensRelease = 3 years;

  uint256 public baseEthCapPerAddress = 3 ether; // TBD

  // vested tokens
  mapping (address => address) public timelockedTokensContracts;

  //whitelisted addresses
  mapping (address => bool) public whiteListedAddress;
  mapping (address => bool) public whiteListedAddressPresale;

  function EmindhubCrowdsale(uint256 _startDate, uint256 _startGeneralSale, uint256 _endDate,
                             uint256 _goal,uint256 _presaleCap, uint256 _cap, address _wallet)
   CappedCrowdsale(_cap) FinalizableCrowdsale()
   RefundableCrowdsale(_goal) Crowdsale(_startDate, _endDate, _wallet)
   ProgressiveIndividualCappedCrowdsale(baseEthCapPerAddress, _startGeneralSale)
  {
    require(_goal <= _cap);
    require(_startGeneralSale > _startDate);
    require(_endDate > _startGeneralSale);
    require(_presaleCap > 0);
    require(_presaleCap < _cap);

    startGeneralSale = _startGeneralSale;
    presaleCap = _presaleCap;
    dateOfBonusRelease = endTime + 90 days;
  }

  function createTokenContract() internal returns (MintableToken) {
    return new EmindhubToken(1, 1, 10);
  }

  modifier onlyPresaleWhitelisted() {
    require(isWhitelistedPresale(msg.sender));
    _;
  }

  modifier onlyWhitelisted() {
    require(isWhitelisted(msg.sender) || isWhitelistedPresale(msg.sender));
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
    for(uint i = 0 ; i < _users.length ; i++) {
      whiteListedAddressPresale[_users[i]] = true;
    }
  }

  function unwhitelistAddressPresale( address _users) onlyOwner {
    whiteListedAddressPresale[_users] = false;
  }

  function buyTokens(address beneficiary) payable onlyWhitelisted {
    require(beneficiary != 0x0);
    require(validPurchase());

    uint256 weiAmount = msg.value;
    uint256 tokens = weiAmount.mul(generalRate);
    weiRaised = weiRaised.add(weiAmount);

    token.mint(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
    forwardFunds();
  }

  function buyTokensPresale(address beneficiary) payable onlyPresaleWhitelisted {
    require(beneficiary != 0x0);
    require(validPurchasePresale());

    // minting tokens at general rate because these tokens are not timelocked
    uint256 weiAmount = msg.value;
    uint256 tokens = weiAmount.mul(generalRate);
    token.mint(beneficiary, tokens);

    // checking if a timelock contract has been already created (not the first presale investment)
    // creating a timelock contract if none exists
    if(timelockedTokensContracts[msg.sender] == 0) {
      address timelockContract = new TokenTimelock(token, msg.sender, dateOfBonusRelease);
      timelockedTokensContracts[msg.sender] = timelockContract;
    }

    // minting timelocked tokens ; balance goes to the timelock contract
    uint256 timelockedTokens = weiAmount.mul(presaleBonus);
    token.mint(timelockedTokensContracts[msg.sender], timelockedTokens);
    weiRaisedPreSale = weiRaisedPreSale.add(weiAmount);

    TokenPurchase(msg.sender, beneficiary, weiAmount, (tokens + timelockedTokens));
    forwardFunds();
  }

  function finalization() internal {
    if (goalReached()) {
      // Vesting for founders ; not revocable
      uint date1 = now.add(cliffTeamTokensRelease);
      uint date2 = now.add(lockTeamTokens);
      address lockedFoundersTokensWallet = new TokenVesting(foundersWallet, now, date1, date2, false);
      timelockedTokensContracts[foundersWallet] = lockedFoundersTokensWallet;
      token.mint(lockedFoundersTokensWallet, 15000000000000000000000000);
      // tokens reserve for advisors, bounty and employees : TBD token number ; no timelock
      token.mint(reserveWallet, 15000000000000000000000000);
      uint dateOfFutureRoundRelease = now.add(futureRoundTokensRelease);
      address lockedRoundsTokensWallet = new TokenTimelock(token, futureRoundWallet, dateOfFutureRoundRelease);
      timelockedTokensContracts[futureRoundWallet] = lockedRoundsTokensWallet;
      // mint remaining tokens (should be at least 30M) to be timelocked for future round(s)
      uint256 totalSupply = token.totalSupply();
      uint256 maxSupply = 100000000000000000000000000;
      uint256 toMint = maxSupply.sub(totalSupply);
      token.mint(lockedRoundsTokensWallet, toMint);
      token.finishMinting();
    }
    // if soft cap not reached ; vault opens for refunds
    super.finalization();
  }

  function () external payable {
    if (validPurchasePresale()){
      buyTokensPresale(msg.sender);
    } else {
      buyTokens(msg.sender);
    }
  }

  // TODO doc
  function validPurchase() internal returns (bool) {
    // getting individual cap and checking if cap is not reached
    bool withinPeriod = now >= startGeneralSale && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    bool withinCap = weiRaised.add(msg.value) <= cap;
    return withinCap && withinPeriod && nonZeroPurchase && super.validPurchase();
  }

  // TODO doc
  function validPurchasePresale() internal constant returns (bool) {
    // contribution minimum TBD
    bool withinPeriod = now >= startTime && now < startGeneralSale;
    bool nonZeroPurchase = msg.value != 0;
    bool withinCap = weiRaisedPreSale.add(msg.value) <= presaleCap;
    return withinPeriod && nonZeroPurchase && withinCap;
  }

  // Override of the goalReached function so that the goal take into account the token raised during the Presale.
  function goalReached() public constant returns (bool) {
    uint256 totalWeiRaised = weiRaisedPreSale.add(weiRaised);
    return totalWeiRaised >= goal || super.goalReached();
  }

  function isWhitelisted(address _user) public constant returns (bool) {
    return whiteListedAddress[_user];
  }

  function isWhitelistedPresale(address _user) public constant returns (bool) {
    return whiteListedAddressPresale[_user];
  }

}
