pragma solidity ^0.4.23;

import './TalaoToken.sol';
import './crowdsale/ProgressiveIndividualCappedCrowdsale.sol';
import './token/TokenTimelock.sol';
import './token/TokenVesting.sol';
import "./TalaoMarketplace.sol";


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

  uint256 public constant generalRate = 1000;
  uint256 public constant presaleBonus = 250;
  uint256 public constant presaleBonusTier2 = 150;
  uint256 public constant presaleBonusTier3 = 100;
  uint256 public constant presaleBonusTier4 = 50;

  uint256 public dateOfBonusRelease;

  address public constant reserveWallet = 0xC9a2BE82Ba706369730BDbd64280bc1132347F85;
  address public constant futureRoundWallet = 0x80a27A56C29b83b25492c06b39AC049e8719a8fd;
  address public constant advisorsWallet = 0xC9a2BE82Ba706369730BDbd64280bc1132347F85;
  address public constant foundersWallet1 = 0x76934C75Ef9a02D444fa9d337C56c7ab0094154C;
  address public constant foundersWallet2 = 0xd21aF5665Dc81563328d5cA2f984b4f6281c333f;
  address public constant foundersWallet3 = 0x0DceD36d883752203E01441bD006725Acd128049;
  address public constant shareholdersWallet = 0x554bC53533876fC501b230274F47598cbD435B5E;

  uint256 public constant cliffTeamTokensRelease = 3 years;
  uint256 public constant lockTeamTokens = 4 years;
  uint256 public constant cliffAdvisorsTokens = 1 years;
  uint256 public constant lockAdvisorsTokens = 2 years;
  uint256 public constant futureRoundTokensRelease = 1 years;
  uint256 public constant presaleBonusLock = 90 days;
  uint256 public constant presaleParticipationMinimum = 10 ether;

  // 15%
  uint256 public constant dateTier2 = 1528761600; // Tuesday 12 June 2018 00:00:00
  // 10%
  uint256 public constant dateTier3 = 1529366400; // Tuesday 19 June 2018 00:00:00
  // 5%
  uint256 public constant dateTier4 = 1529971200; // Tuesday 26 June 2018 00:00:00

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
  * @param _wallet address receiving ether if sale is successful
  **/
  constructor(uint256 _startDate, uint256 _startGeneralSale, uint256 _endDate,
                          uint256 _goal, uint256 _presaleCap, uint256 _cap,
                          address _wallet)
      public
      CappedCrowdsale(_cap)
      FinalizableCrowdsale()
      RefundableCrowdsale(_goal)
      Crowdsale(generalRate, _startDate, _endDate, _wallet)
      ProgressiveIndividualCappedCrowdsale(baseEthCapPerAddress, _startGeneralSale)
  {
      require(_goal <= _cap, "goal is superior to cap");
      require(_startGeneralSale > _startDate, "general sale is starting before presale");
      require(_endDate > _startGeneralSale, "sale ends before general start");
      require(_presaleCap > 0, "presale cap is inferior or equal to 0");
      require(_presaleCap <= _cap, "presale cap is superior to sale cap");

      startGeneralSale = _startGeneralSale;
      presaleCap = _presaleCap;
      dateOfBonusRelease = endTime.add(presaleBonusLock);
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
      require(isWhitelistedPresale(msg.sender), "address is not whitelisted for presale");
      _;
  }

  /**
  * @dev Checks if the sender is whitelisted for the crowdsale.
  **/
  modifier onlyWhitelisted()
  {
      require(isWhitelisted(msg.sender) || isWhitelistedPresale(msg.sender),
              "address is not whitelisted for sale");
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
      require(_cap > presaleParticipation[_user], "address has reached participation cap");
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
      require(beneficiary != 0x0, "beneficiary cannot be 0x0");
      require(validPurchase(), "purchase is not valid");

      uint256 weiAmount = msg.value;
      uint256 tokens = weiAmount.mul(generalRate);
      weiRaised = weiRaised.add(weiAmount);

      token.mint(beneficiary, tokens);
      emit TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
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
      require(beneficiary != 0x0, "beneficiary cannot be 0x0");
      require(validPurchasePresale(), "presale purchase is not valid");

      // minting tokens at general rate because these tokens are not timelocked
      uint256 weiAmount = msg.value;
      uint256 tokens = weiAmount.mul(generalRate);

      // checking if a timelock contract has been already created (not the first presale investment)
      // creating a timelock contract if none exists
      if(timelockedTokensContracts[beneficiary] == 0) {
        address timelockContract = new TokenTimelock(token, beneficiary, dateOfBonusRelease);
        timelockedTokensContracts[beneficiary] = timelockContract;
      }

      // minting timelocked tokens ; balance goes to the timelock contract
      uint256 timelockedTokens = preSaleBonus(weiAmount);
      weiRaisedPreSale = weiRaisedPreSale.add(weiAmount);

      token.mint(beneficiary, tokens);
      token.mint(timelockedTokensContracts[beneficiary], timelockedTokens);
      emit TokenPurchase(msg.sender, beneficiary, weiAmount, (tokens.add(timelockedTokens)));
      forwardFunds();
  }

  /**
   * @dev Overriding the finalization method to add minting for founders/team/reserve if soft cap is reached.
   *      Also deploying the marketplace and transferring ownership to the crowdsale owner.
   */
  function finalization()
      internal
  {
      if (goalReached()) {
        uint cliffDate = now.add(cliffTeamTokensRelease);
        uint unlockDate = now.add(lockTeamTokens);
        uint unlockAdvisors = now.add(lockAdvisorsTokens);
        uint cliffAdvisors = now.add(cliffAdvisors);

        // advisors tokens : 3M ; 1 year cliff, vested for another year
        timelockedTokensContracts[advisorsWallet] = new TokenVesting(advisorsWallet, now, cliffAdvisors, unlockAdvisors, false);

        // Vesting for founders ; not revocable ; 1 year cliff, vested for another year
        timelockedTokensContracts[foundersWallet1] = new TokenVesting(foundersWallet1, now, cliffDate, unlockDate, false);
        timelockedTokensContracts[foundersWallet2] = new TokenVesting(foundersWallet2, now, cliffDate, unlockDate, false);
        timelockedTokensContracts[foundersWallet3] = new TokenVesting(foundersWallet3, now, cliffDate, unlockDate, false);

        // mint remaining tokens out of 150M to be timelocked 1 year for future round(s)
        uint dateOfFutureRoundRelease = now.add(futureRoundTokensRelease);
        timelockedTokensContracts[futureRoundWallet] = new TokenTimelock(token, futureRoundWallet, dateOfFutureRoundRelease);

        token.mint(timelockedTokensContracts[advisorsWallet], 3000000000000000000000000);
        token.mint(timelockedTokensContracts[foundersWallet1], 4000000000000000000000000);
        token.mint(timelockedTokensContracts[foundersWallet2], 4000000000000000000000000);
        token.mint(timelockedTokensContracts[foundersWallet3], 4000000000000000000000000);

        // talao shareholders & employees
        token.mint(shareholdersWallet, 6000000000000000000000000);
        // tokens reserve for talent ambassador, bounty and cash reserve : 29M tokens ; no timelock
        token.mint(reserveWallet, 29000000000000000000000000);

        uint256 totalSupply = token.totalSupply();
        uint256 maxSupply = 150000000000000000000000000;
        uint256 toMint = maxSupply.sub(totalSupply);
        token.mint(timelockedTokensContracts[futureRoundWallet], toMint);
        token.finishMinting();
        // deploy the marketplace
        TalaoToken talao = TalaoToken(address(token));
        TalaoMarketplace marketplace = new TalaoMarketplace(address(token));
        talao.setMarketplace(address(marketplace));
        marketplace.transferOwnership(owner);

        // give the token ownership to the crowdsale owner for vault purposes
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
      bool enough = presaleParticipation[msg.sender] >= presaleParticipationMinimum;
      bool notTooMuch = presaleIndividualCap[msg.sender] >= presaleParticipation[msg.sender];
      bool withinPeriod = now >= startTime && now < startGeneralSale;
      bool nonZeroPurchase = msg.value != 0;
      bool withinCap = weiRaisedPreSale.add(msg.value) <= presaleCap;
      return withinPeriod && nonZeroPurchase && withinCap && enough && notTooMuch;
  }

  function preSaleBonus(uint amount)
      internal
      returns (uint)
  {
      if(now < dateTier2) {
        return amount.mul(presaleBonus);
      } else if (now < dateTier3) {
        return amount.mul(presaleBonusTier2);
      } else if (now < dateTier4) {
        return amount.mul(presaleBonusTier3);
      } else {
        return amount.mul(presaleBonusTier4);
      }
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
