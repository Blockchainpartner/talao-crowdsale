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
  describe('Constructor', () => {
        let EmindhubCrowdsaleInstance;
        // start and end timestamps where investments are allowed (both inclusive)
        let startTime = latestTime() + duration.minutes(1);
        let startSale = latestTime() + duration.minutes(2);
        let endTime = latestTime() + duration.minutes(3);
        // presale cap  5 000 ETH
        let presaleCap = 5000000000000000000000;
        // minimum amount of funds to be raised in weis - 1 000 ETH
        let goal = 1000000000000000000000;
        // Maximum amount of funds to be raised - 20 000 ETH
        let cap = 20000000000000000000000;
        // address where funds are collected
        let wallet = "0xcf09f36227aa07e3318fa57a16b453d29ecf786d";

        before(async () => {
          EmindhubCrowdsaleInstance = await EmindhubCrowdsale.new(startTime,startSale,endTime,goal,presaleCap,cap,wallet, { from: accounts[0]});
        });

        it('should set startblock', async () => {
          let time = await EmindhubCrowdsaleInstance.startTime.call();
          assert.equal(time, startTime);
        });
        it('should set endblock', async () => {
          let time = await EmindhubCrowdsaleInstance.endTime.call();
          assert.equal(time, endTime);
        });
        it('should set goal', async () => {
          let instanceGoal = await EmindhubCrowdsaleInstance.goal.call();
          assert.equal(instanceGoal, goal);
        });
        it('should set wallet', async () => {
          let instanceWallet = await EmindhubCrowdsaleInstance.wallet.call();
          assert.equal(instanceWallet, wallet);
        });
        it('should instanciate EXP Token', async () => {
          let expAddress = await EmindhubCrowdsaleInstance.token.call();
          let expInstance = EmindhubToken.at(expAddress);
          let expSymbol = await expInstance.symbol.call();
          assert.equal(expSymbol, "EXP");
        });
    });

    describe('Sale Features', () => {
      let EmindhubCrowdsaleInstance;
      let expInstance;
      // start and end timestamps where investments are allowed (both inclusive)
      let startTime = latestTime() + duration.minutes(1);
      let startSale = latestTime() + duration.minutes(2);
      let endTime = latestTime() + duration.minutes(3);
      // presale cap  5 000 ETH
      let presaleCap = 5000000000000000000000;
      // minimum amount of funds to be raised in weis - 1 000 ETH
      let goal = 1000000000000000000000;
      // Maximum amount of funds to be raised - 20 000 ETH
      let cap = 20000000000000000000000;
      // address where funds are collected
      let wallet = "0xcf09f36227aa07e3318fa57a16b453d29ecf786d";

        beforeEach(async () => {
          // start and end timestamps where investments are allowed (both inclusive)
          startTime = latestTime() + duration.minutes(1);
          startSale = latestTime() + duration.minutes(2);
          endTime = latestTime() + duration.minutes(3);
          EmindhubCrowdsaleInstance = await EmindhubCrowdsale.new(startTime,startSale,endTime,goal,presaleCap,cap,wallet, { from: accounts[0]});
          let expAddress = await EmindhubCrowdsaleInstance.token.call();
          expInstance = EmindhubToken.at(expAddress);
          await EmindhubCrowdsaleInstance.whitelistAddresses(new Array(accounts[1]), { from: accounts[0]})
        });

        it('should prevent exeeding the hard cap', async () => {
          await increaseTimeTo(startSale);
          await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[1], to: EmindhubCrowdsaleInstance.address , value: "300000000000000000000000" ,gas: 4700000}).should.be.rejectedWith(revert);
        });

        it( 'should give the team their tokens if the sale is successful', async () => {
          await increaseTimeTo(startSale+1);
          await web3.eth.sendTransaction({ from: accounts[1], to: EmindhubCrowdsaleInstance.address , value: "20000000000000000000000" ,gas: 4700000});
          await increaseTimeTo(endTime+1);
          await EmindhubCrowdsaleInstance.finalize({from: accounts[0]});
          let foundationBalance = await expInstance.balanceOf(wallet);
          // nb of tokens generated missing
          assert.equal(foundationBalance.toNumber(), 15850000000000000000000000);
        });

        it( 'should not give the team their tokens if the sale is unsuccessful', async () => {
          await increaseTimeTo(startSale+1);
          await web3.eth.sendTransaction({ from: accounts[1], to: EmindhubCrowdsaleInstance.address , value: "1" ,gas: 4700000});
          await increaseTimeTo(endTime+1);
          await EmindhubCrowdsaleInstance.finalize({from: accounts[0]});
          let foundationBalance = await expInstance.balanceOf(wallet);
          assert.equal(foundationBalance.toNumber(), 0);
        });

        it('should not be able to participate after end time', async () => {
          await increaseTimeTo(endTime+1);
          await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[1], to: EmindhubCrowdsaleInstance.address , value: "100" ,gas: 4700000}).should.be.rejectedWith(revert);
          let saleEnded = await EmindhubCrowdsaleInstance.hasEnded();
          console.log(saleEnded);
          assert.equal(saleEnded, true);
        });

        it('should not be able to participate if the cap is reached', async () => {
          await increaseTimeTo(startSale+1);
          await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[1], to: EmindhubCrowdsaleInstance.address , value: "20000000000000000000000" ,gas: 4700000});
          await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[1], to: EmindhubCrowdsaleInstance.address , value: "100" ,gas: 4700000}).should.be.rejectedWith(revert);
        });

        it('should not be able to finalize twice', async () => {
          await increaseTimeTo(startSale+1);
          await web3.eth.sendTransaction({ from: accounts[1], to: EmindhubCrowdsaleInstance.address , value: "100" ,gas: 4700000});
          await increaseTimeTo(endTime+1);
          await EmindhubCrowdsaleInstance.finalize({from: accounts[0]});
          let finalized = await EmindhubCrowdsaleInstance.isFinalized.call();
          await EmindhubCrowdsaleInstance.finalize({from: accounts[0]}).should.be.rejectedWith(revert);
        });

        it('should allow refunds if the softcap is not reached', async () => {
          await increaseTimeTo(startSale+1);
          await web3.eth.sendTransaction({ from: accounts[1], to: EmindhubCrowdsaleInstance.address , value: "100000000000000000000" ,gas: 4700000});
          let balanceAfterPurchase = await web3.eth.getBalance(accounts[1]);
          await increaseTimeTo(endTime+1);
          await EmindhubCrowdsaleInstance.finalize({from: accounts[0]});
          await EmindhubCrowdsaleInstance.claimRefund({ from: accounts[1] });
          let afterRefundBalance = await web3.eth.getBalance(accounts[1]);
          assert.isAbove(afterRefundBalance.toNumber(), balanceAfterPurchase.toNumber(), 'balance is greater after refund');
        });


        it('should not be able to participate if hasnt started', async () => {
          await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[1], to: EmindhubCrowdsaleInstance.address , value: "100" ,gas: 4700000}).should.be.rejectedWith(revert);
        });


        it('should not be able to participate if sender isnt whitelisted', async () => {
          await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[2], to: EmindhubCrowdsaleInstance.address , value: "100" ,gas: 4700000}).should.be.rejectedWith(revert);
        });

        it('should be sucessfully completing the sale', async () => {
          await increaseTimeTo(startSale+1);
          await EmindhubCrowdsaleInstance.sendTransaction({ from: accounts[1], to: EmindhubCrowdsaleInstance.address , value: "20000000000000000000000" ,gas: 4700000});
          await EmindhubCrowdsaleInstance.finalize({from: accounts[0]});
          let balance = await expInstance.balanceOf(accounts[1]);
          //assert.equal(balance, 15850000000000000000000000);
          let isFinalized = await EmindhubCrowdsaleInstance.isFinalized();
          assert.isTrue(isFinalized);
          let balanceOwner = await expInstance.balanceOf(wallet);
          //assert.equal(balanceOwner, 15850000000000000000000000);
        });

    });
});
