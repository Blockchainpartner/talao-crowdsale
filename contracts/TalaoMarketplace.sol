pragma solidity ^0.4.23;

import "./ownership/Ownable.sol";
import "./math/SafeMath.sol";
import "./TalaoToken.sol";

/**
 * @title TalaoMarketplace
 * @dev This contract is allowing users to buy or sell Talao tokens at a price set by the owner
 * @author Blockchain Partner
 */
contract TalaoMarketplace is Ownable {
  using SafeMath for uint256;

  TalaoToken public token;

  struct MarketplaceData {
    uint buyPrice;
    uint sellPrice;
    uint unitPrice;
  }

  MarketplaceData public marketplace;

  event SellingPrice(uint sellingPrice);
  event TalaoBought(address buyer, uint amount, uint price, uint unitPrice);
  event TalaoSold(address seller, uint amount, uint price, uint unitPrice);

  /**
  * @dev Constructor of the marketplace pointing to the TALAO token address
  * @param talao the talao token address
  **/
  constructor(address talao)
      public
  {
      token = TalaoToken(talao);
  }

  /**
  * @dev Allow users to buy tokens for `newBuyPrice` eth and sell tokens for `newSellPrice` eth
  * @param newSellPrice price the users can sell to the contract
  * @param newBuyPrice price users can buy from the contract
  * @param newUnitPrice to manage decimal issue 0,35 = 35 /100 (100 is unit)
  */
  function setPrices(uint256 newSellPrice, uint256 newBuyPrice, uint256 newUnitPrice)
      public
      onlyOwner
  {
      require (newSellPrice > 0 && newBuyPrice > 0 && newUnitPrice > 0, "wrong inputs");
      marketplace.sellPrice = newSellPrice;
      marketplace.buyPrice = newBuyPrice;
      marketplace.unitPrice = newUnitPrice;
  }

  /**
  * @dev Allow anyone to buy tokens against ether, depending on the buyPrice set by the contract owner.
  * @return amount the amount of tokens bought
  **/
  function buy()
      public
      payable
      returns (uint amount)
  {
      amount = msg.value.mul(marketplace.unitPrice).div(marketplace.buyPrice);
      token.transfer(msg.sender, amount);
      emit TalaoBought(msg.sender, amount, marketplace.buyPrice, marketplace.unitPrice);
      return amount;
  }

  /**
  * @dev Allow anyone to sell tokens for ether, depending on the sellPrice set by the contract owner.
  * @param amount the number of tokens to be sold
  * @return revenue ethers sent in return
  **/
  function sell(uint amount)
      public
      returns (uint revenue)
  {
      require(token.balanceOf(msg.sender) >= amount, "sender has not enough tokens");
      token.transferFrom(msg.sender, this, amount);
      revenue = amount.mul(marketplace.sellPrice).div(marketplace.unitPrice);
      msg.sender.transfer(revenue);
      emit TalaoSold(msg.sender, amount, marketplace.sellPrice, marketplace.unitPrice);
      return revenue;
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
   * @dev Allow the owner to withdraw tokens from the contract.
   * @param tokens quantity of tokens to be withdrawn
   */
  function withdrawTalao(uint256 tokens)
      public
      onlyOwner
  {
      token.transfer(msg.sender, tokens);
  }


  /**
  * @dev Fallback function ; only owner can send ether.
  **/
  function ()
      public
      payable
      onlyOwner
  {

  }

}
