import EVMThrow from './helpers/EVMThrow';
import revert from './helpers/revert';

import latestTime from './helpers/latestTime';
import { increaseTimeTo, duration } from './helpers/increaseTime';

const EmindhubCrowdsale = artifacts.require("EmindhubCrowdsale");
const EmindhubToken = artifacts.require("EmindhubToken");
const RefundVault = artifacts.require("RefundVault")
const should = require('chai')
  .use(require('chai-as-promised'))
  .should();

contract('EmindhubCrowdsale', function(accounts) {
  describe('Buy and sell TALAO', () => {
    let EmindhubCrowdsaleInstance;
    let expInstance;
    // start and end timestamps where investments are allowed (both inclusive)
    let startPresale = latestTime() + duration.minutes(1);
    let startSale = latestTime() + duration.days(10);
    let endSale = latestTime() + duration.days(30);
    // presale cap  5 000 ETH
    let presaleCap = 5000000000000000000000;
    // minimum amount of funds to be raised in weis - 1 000 ETH
    let goal = 1000000000000000000000;
    // Maximum amount of funds to be raised - 20 000 ETH
    let cap = 20000000000000000000000;
    // address where funds are collected
    let wallet = "0xE7305033fE4D5994Cd88d69740E9DB59F27c7045";

    before(async () => {
      startPresale = latestTime() + duration.minutes(1);
      startSale = latestTime() + duration.days(10);
      endSale = latestTime() + duration.days(30);
      EmindhubCrowdsaleInstance = await EmindhubCrowdsale.new(startPresale,startSale,endSale,goal,presaleCap,cap,wallet, { from: accounts[0], gas:"17592186044415", gasPrice:1});
      let expAddress = await EmindhubCrowdsaleInstance.token.call();
      expInstance = EmindhubToken.at(expAddress);
      await EmindhubCrowdsaleInstance.whitelistAddresses(new Array(accounts[1], accounts[2], accounts[3], accounts[4], accounts[5], accounts[6]), { from: accounts[0]});
      await increaseTimeTo(startSale+duration.days(19));
      await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[1], to: EmindhubCrowdsaleInstance.address , value: "1000000000000000000000" ,gas: 4700000, gasPrice: 1});
      await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[2], to: EmindhubCrowdsaleInstance.address , value: "1000000000000000000000" ,gas: 4700000, gasPrice: 1});
      await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[3], to: EmindhubCrowdsaleInstance.address , value: "1000000000000000000000" ,gas: 4700000, gasPrice: 1});
      await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[4], to: EmindhubCrowdsaleInstance.address , value: "1000000000000000000000" ,gas: 4700000, gasPrice: 1});
      await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[5], to: EmindhubCrowdsaleInstance.address , value: "1000000000000000000000" ,gas: 4700000, gasPrice: 1});
      await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[6], to: EmindhubCrowdsaleInstance.address , value: "1000000000000000000000" ,gas: 4700000, gasPrice: 1});
      await increaseTimeTo(endSale+1);
      await EmindhubCrowdsaleInstance.finalize({from: accounts[0]});
      let finalized = await EmindhubCrowdsaleInstance.isFinalized.call();
      assert.equal(finalized, true);
      await expInstance.transfer.sendTransaction(expInstance.address, "10000000000000000000000", {from: accounts[6]});
      await expInstance.sendTransaction({from: accounts[0], value:"100000000000000000000"});
      //await expInstance.setMinBalance.sendTransaction("50000000000000000" ,{from: accounts[0]});
      let minBalance = await expInstance.minBalanceForAccounts.call();
      console.log(minBalance);
      let balanceContract = await web3.eth.getBalance(expInstance.address);
      assert.isAbove(balanceContract.toNumber(), 0, "no eth on the contract");
    });

    it("should be possible to set prices", async() => {
      await expInstance.setPrices.sendTransaction("1000000000000000000", "1000000000000000000", "1000000000000000000", {from: accounts[0]});
      //let buyPrice = await expInstance.buyPrice.call();
      //assert.equal(buyPrice.toNumber(), 1000000000000000000, "buyPrice not set");
    });

    it("should be possible to buy 1 TALAO for 1 ETH", async() => {
      await expInstance.buy.sendTransaction({from: accounts[7], value:"1000000000000000000"});
      let userBalance = await expInstance.balanceOf.call(accounts[7]);
      assert.equal(userBalance.toNumber(), 1000000000000000000, "not a correct buy");
    });

    it("should be possible to buy 2 TALAO for 2 ETH", async() => {
      await expInstance.buy.sendTransaction({from: accounts[8], value:"2000000000000000000"});
      let userBalance = await expInstance.balanceOf.call(accounts[8]);
      assert.equal(userBalance.toNumber(), 2000000000000000000, "not a correct buy");
    });

    it("should be possible to sell 1 TALAO for 1 ETH", async() => {
      let ethBalanceUser1 = await web3.eth.getBalance(accounts[7]);
      await expInstance.sell.sendTransaction("1000000000000000000", {from: accounts[7], gasPrice:1});
      let ethBalanceUser2 = await web3.eth.getBalance(accounts[7]);
      let userBalance = await expInstance.balanceOf.call(accounts[7]);
      assert.equal(userBalance.toNumber(), 0, "not a correct sell");
      assert.isAbove(ethBalanceUser2.toNumber(), ethBalanceUser1.toNumber());
    });

    it("sell sell sell sell", async() => {
      let ethBalanceUser1;
      let ethBalanceUser2;
      let userBalance;
      ethBalanceUser1 = await web3.eth.getBalance(accounts[5]);
      await expInstance.sell.sendTransaction("1000000000000000000", {from: accounts[5], gasPrice:1});
      ethBalanceUser2 = await web3.eth.getBalance(accounts[5]);
      userBalance = await expInstance.balanceOf.call(accounts[5]);
      assert.isAbove(ethBalanceUser2.toNumber(), ethBalanceUser1.toNumber());
      ethBalanceUser1 = await web3.eth.getBalance(accounts[5]);
      await expInstance.sell.sendTransaction("1000000000000000000", {from: accounts[5], gasPrice:1});
      ethBalanceUser2 = await web3.eth.getBalance(accounts[5]);
      userBalance = await expInstance.balanceOf.call(accounts[5]);
      assert.isAbove(ethBalanceUser2.toNumber(), ethBalanceUser1.toNumber());
      ethBalanceUser1 = await web3.eth.getBalance(accounts[5]);
      await expInstance.sell.sendTransaction("1000000000000000000", {from: accounts[5], gasPrice:1});
      ethBalanceUser2 = await web3.eth.getBalance(accounts[5]);
      userBalance = await expInstance.balanceOf.call(accounts[5]);
      assert.isAbove(ethBalanceUser2.toNumber(), ethBalanceUser1.toNumber());
      ethBalanceUser1 = await web3.eth.getBalance(accounts[5]);
      await expInstance.sell.sendTransaction("1000000000000000000", {from: accounts[5], gasPrice:1});
      ethBalanceUser2 = await web3.eth.getBalance(accounts[5]);
      userBalance = await expInstance.balanceOf.call(accounts[5]);
      assert.isAbove(ethBalanceUser2.toNumber(), ethBalanceUser1.toNumber());
      ethBalanceUser1 = await web3.eth.getBalance(accounts[5]);
      await expInstance.sell.sendTransaction("1000000000000000000", {from: accounts[5], gasPrice:1});
      ethBalanceUser2 = await web3.eth.getBalance(accounts[5]);
      userBalance = await expInstance.balanceOf.call(accounts[5]);
      assert.isAbove(ethBalanceUser2.toNumber(), ethBalanceUser1.toNumber());
      ethBalanceUser1 = await web3.eth.getBalance(accounts[5]);
      await expInstance.sell.sendTransaction("1000000000000000000", {from: accounts[5], gasPrice:1});
      ethBalanceUser2 = await web3.eth.getBalance(accounts[5]);
      userBalance = await expInstance.balanceOf.call(accounts[5]);
      assert.isAbove(ethBalanceUser2.toNumber(), ethBalanceUser1.toNumber());
    });

    it("should be possible to get ether refill", async() => {
      let tokensUser = await expInstance.balanceOf.call(accounts[5]);
      console.log(tokensUser);
      let balanceUser5 = await web3.eth.getBalance(accounts[5]);
      let toSend = balanceUser5 - web3.toWei("4", "finney");
      await web3.eth.sendTransaction({from:accounts[5], to:accounts[4], value: toSend});
      let ethBalanceUser1 = await web3.eth.getBalance(accounts[5]);
      console.log(ethBalanceUser1);
      await expInstance.transfer.sendTransaction(accounts[3], "1000000000000000000", {from: accounts[5], gasPrice:1});
      let ethBalanceUser2 = await web3.eth.getBalance(accounts[5]);
      console.log(ethBalanceUser2);
      assert.isAbove(ethBalanceUser2, web3.toWei("50", "finney"));
      assert.isAbove(ethBalanceUser2.toNumber(), ethBalanceUser1.toNumber(), "refill did not happen");
    });

    it("should be possible to transfer tokens endlessly", async() => {
      await expInstance.transfer.sendTransaction(accounts[9], "10000000000000000000000", {from: accounts[3]});
      await expInstance.transfer.sendTransaction(accounts[1], "10000000000000000000000", {from: accounts[2]});
      await expInstance.transfer.sendTransaction(accounts[2], "10000000000000000000000", {from: accounts[1]});
      await expInstance.transfer.sendTransaction(accounts[1], "10000000000000000000000", {from: accounts[2]});
      await expInstance.transfer.sendTransaction(accounts[2], "10000000000000000000000", {from: accounts[1]});
      await expInstance.transfer.sendTransaction(accounts[1], "10000000000000000000000", {from: accounts[2]});
      await expInstance.transfer.sendTransaction(accounts[2], "10000000000000000000000", {from: accounts[1]});
      await expInstance.transfer.sendTransaction(accounts[1], "10000000000000000000000", {from: accounts[2]});
      await expInstance.transfer.sendTransaction(accounts[2], "10000000000000000000000", {from: accounts[1]});
      await expInstance.transfer.sendTransaction(accounts[1], "10000000000000000000000", {from: accounts[2]});
      await expInstance.transfer.sendTransaction(accounts[2], "10000000000000000000000", {from: accounts[1]});
      await expInstance.transfer.sendTransaction(accounts[1], "10000000000000000000000", {from: accounts[2]});
      await expInstance.transfer.sendTransaction(accounts[2], "10000000000000000000000", {from: accounts[1]});
      await expInstance.transfer.sendTransaction(accounts[1], "10000000000000000000000", {from: accounts[2]});
      await expInstance.transfer.sendTransaction(accounts[2], "10000000000000000000000", {from: accounts[1]});
      await expInstance.transfer.sendTransaction(accounts[1], "10000000000000000000000", {from: accounts[2]});
      await expInstance.transfer.sendTransaction(accounts[2], "10000000000000000000000", {from: accounts[1]});
      await expInstance.transfer.sendTransaction(accounts[1], "10000000000000000000000", {from: accounts[2]});
      await expInstance.transfer.sendTransaction(accounts[2], "10000000000000000000000", {from: accounts[1]});
      await expInstance.transfer.sendTransaction(accounts[9], "10000000000000000000000", {from: accounts[3]});
    });
  });
});
