pragma solidity ^0.4.18;

import './TalaoToken.sol';
import './crowdsale/ProgressiveIndividualCappedCrowdsale.sol';
import './token/TokenTimelock.sol';
import './token/TokenVesting.sol';

/**
 * @title TalaoCrowdsale
 * @dev This contract handles the presale and the crowdsale of the Talao platform.
 * @author Blockchain Partner
 */
contract TalaoCrowdsale is ProgressiveIndividualCappedCrowdsale {
  using SafeMath for uint256;

  uint256 public weiRaisedPreSale;
  uint256 public presaleCap;
  uint256 public startGeneralSale;

  mapping (address => uint256) public presaleParticipation;
  mapping (address => uint256) public presaleIndividualCap;

  uint256 public presaleBonus;
  uint256 public generalRate;
  uint256 public dateOfBonusRelease;

  // TBD : need final addresses
  address public constant reserveWallet = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7046;
  address public constant futureRoundWallet = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7047;
  address public constant advisorsWallet = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7048;
  address public constant foundersWallet1 = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7050;
  address public constant foundersWallet2 = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7051;
  address public constant foundersWallet3 = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7052;
  address public constant shareholdersWallet = 0xE7305033fE4D5994Cd88d69740E9DB59F27c7053;

  uint256 public constant cliffTeamTokensRelease = 1 years;
  uint256 public constant lockTeamTokens = 2 years;
  uint256 public constant futureRoundTokensRelease = 1 years;
  uint256 public constant presaleBonusLock = 90 days;

  uint256 public baseEthCapPerAddress = 3 ether;

  mapping (address => address) public timelockedTokensContracts;

  mapping (address => bool) public whiteListedAddress;
  mapping (address => bool) public whiteListedAddressPresale;

  /**
  * @dev Creates the crowdsale. Set starting dates, ending date, caps and wallet. Set the date of presale bonus release.
  * @param _startDate start of the presale (EPOCH format)
  * @param _startGeneralSale start of the crowdsale (EPOCH format)
  * @param _endDate end of the crowdsale (EPOCH format)
  * @param _goal soft cap
  * @param _presaleCap hard cap of the presale
  * @param _cap global hard cap
  * @param _generalRate number of tokens for 1 ether
  * @param _presaleBonus number of tokens for 1 ether in presale in addition of the general rate
  * @param _wallet address receiving ether if sale is successful
  **/
  function TalaoCrowdsale(uint256 _startDate, uint256 _startGeneralSale, uint256 _endDate,
                          uint256 _goal, uint256 _presaleCap, uint256 _cap, uint256 _generalRate,
                          uint256 _presaleBonus, address _wallet)
      public
      CappedCrowdsale(_cap)
      FinalizableCrowdsale()
      RefundableCrowdsale(_goal)
      Crowdsale(_startDate, _endDate, _wallet)
      ProgressiveIndividualCappedCrowdsale(baseEthCapPerAddress, _startGeneralSale)
  {
      require(_goal <= _cap);
      require(_startGeneralSale > _startDate);
      require(_endDate > _startGeneralSale);
      require(_presaleCap > 0);
      require(_presaleCap <= _cap);

      startGeneralSale = _startGeneralSale;
      presaleCap = _presaleCap;
      dateOfBonusRelease = endTime.add(presaleBonusLock);
      generalRate = _generalRate;
      presaleBonus = _presaleBonus;
  }

  /**
  * @dev Creates the talao token.
  * @return the TalaoToken address
  **/
  function createTokenContract()
      internal
      returns (MintableToken)
  {
      return new TalaoToken();
  }

  /**
  * @dev Checks if the sender is whitelisted for the presale.
  **/
  modifier onlyPresaleWhitelisted()
  {
      require(isWhitelistedPresale(msg.sender));
      _;
  }

  /**
  * @dev Checks if the sender is whitelisted for the crowdsale.
  **/
  modifier onlyWhitelisted()
  {
      require(isWhitelisted(msg.sender) || isWhitelistedPresale(msg.sender));
      _;
  }

  /**
   * @dev Whitelists an array of users for the crowdsale.
   * @param _users the users to be whitelisted
   */
  function whitelistAddresses(address[] _users)
      public
      onlyOwner
  {
      for(uint i = 0 ; i < _users.length ; i++) {
        whiteListedAddress[_users[i]] = true;
      }
  }

  /**
   * @dev Removes a user from the crowdsale whitelist.
   * @param _user the user to be removed from the crowdsale whitelist
   */
  function unwhitelistAddress(address _user)
      public
      onlyOwner
  {
      whiteListedAddress[_user] = false;
  }

  /**
   * @dev Whitelists a user for the presale with an individual cap ; cap needs to be above participation if set again
   * @param _user the users to be whitelisted
   * @param _cap the user individual cap in wei
   */
  function whitelistAddressPresale(address _user, uint _cap)
      public
      onlyOwner
  {
      require(_cap > presaleParticipation[_user]);
      whiteListedAddressPresale[_user] = true;
      presaleIndividualCap[_user] = _cap;
  }

  /**
   * @dev Removes a user from the presale whitelist.
   * @param _user the user to be removed from the presale whitelist
   */
  function unwhitelistAddressPresale(address _user)
      public
      onlyOwner
  {
      whiteListedAddressPresale[_user] = false;
  }

  /**
   * @dev Mints tokens corresponding to the transaction value for a whitelisted user during the crowdsale.
   * @param beneficiary the user wanting to buy tokens
   */
  function buyTokens(address beneficiary)
      public
      payable
      onlyWhitelisted
  {
      require(beneficiary != 0x0);
      require(validPurchase());

      uint256 weiAmount = msg.value;
      uint256 tokens = weiAmount.mul(generalRate);
      weiRaised = weiRaised.add(weiAmount);

      token.mint(beneficiary, tokens);
      TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
      forwardFunds();
  }

  /**
   * @dev Mints tokens corresponding to the transaction value for a whitelisted user during the presale.
   *      Presale bonus is timelocked.
   * @param beneficiary the user wanting to buy tokens
   */
  function buyTokensPresale(address beneficiary)
      public
      payable
      onlyPresaleWhitelisted
  {
      require(beneficiary != 0x0);
      require(validPurchasePresale());

      // minting tokens at general rate because these tokens are not timelocked
      uint256 weiAmount = msg.value;
      uint256 tokens = weiAmount.mul(generalRate);

      // checking if a timelock contract has been already created (not the first presale investment)
      // creating a timelock contract if none exists
      if(timelockedTokensContracts[msg.sender] == 0) {
        address timelockContract = new TokenTimelock(token, msg.sender, dateOfBonusRelease);
        timelockedTokensContracts[msg.sender] = timelockContract;
      }

      // minting timelocked tokens ; balance goes to the timelock contract
      uint256 timelockedTokens = weiAmount.mul(presaleBonus);
      weiRaisedPreSale = weiRaisedPreSale.add(weiAmount);

      token.mint(beneficiary, tokens);
      token.mint(timelockedTokensContracts[msg.sender], timelockedTokens);
      TokenPurchase(msg.sender, beneficiary, weiAmount, (tokens.add(timelockedTokens)));
      forwardFunds();
  }

  /**
   * @dev Overriding the finalization method to add minting for founders/team/reserve if soft cap is reached.
   */
  function finalization()
      internal
  {
      if (goalReached()) {
        uint cliffDate = now.add(cliffTeamTokensRelease);
        uint unlockDate = now.add(lockTeamTokens);

        // advisors tokens : 3M ; 1 year cliff, vested for another year
        address lockedAdvisorsTokensWallet = new TokenVesting(advisorsWallet, now, cliffDate, unlockDate, false);
        timelockedTokensContracts[advisorsWallet] = lockedAdvisorsTokensWallet;

        // Vesting for founders ; not revocable ; 1 year cliff, vested for another year
        address lockedFoundersTokensWallet1 = new TokenVesting(foundersWallet1, now, cliffDate, unlockDate, false);
        timelockedTokensContracts[foundersWallet1] = lockedFoundersTokensWallet1;
        address lockedFoundersTokensWallet2 = new TokenVesting(foundersWallet2, now, cliffDate, unlockDate, false);
        timelockedTokensContracts[foundersWallet2] = lockedFoundersTokensWallet2;
        address lockedFoundersTokensWallet3 = new TokenVesting(foundersWallet3, now, cliffDate, unlockDate, false);
        timelockedTokensContracts[foundersWallet3] = lockedFoundersTokensWallet3;

        // mint remaining tokens out of 150M to be timelocked for future round(s)
        uint dateOfFutureRoundRelease = now.add(futureRoundTokensRelease);
        address lockedRoundsTokensWallet = new TokenTimelock(token, futureRoundWallet, dateOfFutureRoundRelease);
        timelockedTokensContracts[futureRoundWallet] = lockedRoundsTokensWallet;

        token.mint(lockedAdvisorsTokensWallet, 3000000000000000000000000);
        token.mint(lockedFoundersTokensWallet1, 4000000000000000000000000);
        token.mint(lockedFoundersTokensWallet2, 4000000000000000000000000);
        token.mint(lockedFoundersTokensWallet3, 4000000000000000000000000);

        // talao shareholders & employees
        token.mint(shareholdersWallet, 6000000000000000000000000);
        // tokens reserve for talent ambassador, bounty and cash reserve : 29M tokens ; no timelock
        token.mint(reserveWallet, 29000000000000000000000000);

        uint256 totalSupply = token.totalSupply();
        uint256 maxSupply = 150000000000000000000000000;
        uint256 toMint = maxSupply.sub(totalSupply);
        token.mint(lockedRoundsTokensWallet, toMint);
        token.finishMinting();

        // give the token ownership to the crowdsale owner for marketplace and vault purposes
        token.transferOwnership(owner);
      }
      // if soft cap not reached ; vault opens for refunds
      super.finalization();
  }

  /**
  * @dev Fallback function redirecting to buying tokens functions depending on the time period.
  **/
  function ()
      external
      payable
  {
      if (now >= startTime && now < startGeneralSale){
        buyTokensPresale(msg.sender);
      } else {
        buyTokens(msg.sender);
      }
  }

  /**
  * @dev Checks if the crowdsale purchase is valid: correct time, value and hard cap not reached.
  *      Calls ProgressiveIndividualCappedCrowdsale's validPurchase to get individual cap.
  * @return true if all criterias are satisfied ; false otherwise
  **/
  function validPurchase()
      internal
      returns (bool)
  {
      bool withinPeriod = now >= startGeneralSale && now <= endTime;
      bool nonZeroPurchase = msg.value != 0;
      uint256 totalWeiRaised = weiRaisedPreSale.add(weiRaised);
      bool withinCap = totalWeiRaised.add(msg.value) <= cap;
      return withinCap && withinPeriod && nonZeroPurchase && super.validPurchase();
  }

  /**
  * @dev Checks if the presale purchase is valid: correct time, value and presale hard cap not reached.
  * @return true if all criterias are satisfied ; false otherwise
  **/
  function validPurchasePresale()
      internal
      returns (bool)
  {
      presaleParticipation[msg.sender] = presaleParticipation[msg.sender].add(msg.value);
      bool enough = presaleParticipation[msg.sender] >= 100 ether;
      bool notTooMuch = presaleIndividualCap[msg.sender] >= presaleParticipation[msg.sender];
      bool withinPeriod = now >= startTime && now < startGeneralSale;
      bool nonZeroPurchase = msg.value != 0;
      bool withinCap = weiRaisedPreSale.add(msg.value) <= presaleCap;
      return withinPeriod && nonZeroPurchase && withinCap && enough && notTooMuch;
  }

  /**
  * @dev Override of the goalReached function in order to add presale weis to crowdsale weis and check if the total amount has reached the soft cap.
  * @return true if soft cap has been reached ; false otherwise
  **/
  function goalReached()
      public
      constant
      returns (bool)
  {
      uint256 totalWeiRaised = weiRaisedPreSale.add(weiRaised);
      return totalWeiRaised >= goal || super.goalReached();
  }

  /**
  * @dev Check if the user is whitelisted for the crowdsale.
  * @return true if user is whitelisted ; false otherwise
  **/
  function isWhitelisted(address _user)
      public
      constant
      returns (bool)
  {
      return whiteListedAddress[_user];
  }

  /**
  * @dev Check if the user is whitelisted for the presale.
  * @return true if user is whitelisted ; false otherwise
  **/
  function isWhitelistedPresale(address _user)
      public
      constant
      returns (bool)
  {
      return whiteListedAddressPresale[_user];
  }

}
