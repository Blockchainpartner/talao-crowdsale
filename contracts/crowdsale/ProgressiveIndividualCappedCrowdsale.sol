pragma solidity ^0.4.18;

import './RefundableCrowdsale.sol';
import './CappedCrowdsale.sol';
import '../ownership/Ownable.sol';

/**
 * @title ProgressiveIndividualCappedCrowdsale
 * @dev Extension of Crowdsale with a progressive individual cap
 * @dev This contract is not made for crowdsale superior to 256 * TIME_PERIOD_IN_SEC
 * @author Request.network ; some modifications by Blockchain Partner
 */
contract ProgressiveIndividualCappedCrowdsale is RefundableCrowdsale, CappedCrowdsale {

    uint public startGeneralSale;
    uint public constant TIME_PERIOD_IN_SEC = 1 days;
    uint public constant minimumParticipation = 10 finney;
    uint public constant GAS_LIMIT_IN_WEI = 5E10 wei; // limit gas price -50 Gwei wales stopper
    uint256 public baseEthCapPerAddress;

    mapping(address=>uint) public participated;

    function ProgressiveIndividualCappedCrowdsale(uint _baseEthCapPerAddress, uint _startGeneralSale)
        public
    {
        baseEthCapPerAddress = _baseEthCapPerAddress;
        startGeneralSale = _startGeneralSale;
    }

    /**
     * @dev setting cap before the general sale starts
     * @param _newBaseCap the new cap
     */
    function setBaseCap(uint _newBaseCap)
        public
        onlyOwner
    {
        require(now < startGeneralSale);
        baseEthCapPerAddress = _newBaseCap;
    }

    /**
     * @dev overriding CappedCrowdsale#validPurchase to add an individual cap
     * @return true if investors can buy at the moment
     */
    function validPurchase()
        internal
        returns(bool)
    {
        bool gasCheck = tx.gasprice <= GAS_LIMIT_IN_WEI;
        uint ethCapPerAddress = getCurrentEthCapPerAddress();
        participated[msg.sender] = participated[msg.sender].add(msg.value);
        bool enough = participated[msg.sender] >= minimumParticipation;
        return participated[msg.sender] <= ethCapPerAddress && enough && gasCheck;
    }

    /**
     * @dev Get the current individual cap.
     * @dev This amount increase everyday in an exponential way. Day 1: base cap, Day 2: 2 * base cap, Day 3: 4 * base cap ...
     * @return individual cap in wei
     */
    function getCurrentEthCapPerAddress()
        public
        constant
        returns(uint)
    {
        if (block.timestamp < startGeneralSale) return 0;
        uint timeSinceStartInSec = block.timestamp.sub(startGeneralSale);
        uint currentPeriod = timeSinceStartInSec.div(TIME_PERIOD_IN_SEC).add(1);

        // for currentPeriod > 256 will always return 0
        return (2 ** currentPeriod.sub(1)).mul(baseEthCapPerAddress);
    }
}
