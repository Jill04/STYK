const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");

const truffleAssert = require("truffle-assertions");
const { assert, expect } = require("chai");
const STYK = artifacts.require("STYK_I");

const denominator = new BN(10).pow(new BN(15));

const getWith15Decimals = function (amount) {
  return new BN(amount).mul(denominator);
};

require("chai").use(require("chai-bignumber")(BN)).should();

contract("STYK", () => {
  it("Should deploy smart contract properly", async () => {
    const styk = await STYK.deployed();

    assert(styk.address !== "");
  });
  beforeEach(async function () {
    styk = await STYK.new(
      4796668740,
      1614556740,
      web3.utils.toWei("10000", "ether"),
      web3.utils.toWei("1", "ether")
    );
    accounts = await web3.eth.getAccounts();
  });

  describe("[Testcase 1: To purchase the token]", () => {
    it("Token Buy", async () => {
      await styk.buy(accounts[1], {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      });
    });
  });

  describe("[Testcase 2: To sell tokens]", () => {
    it("Token Sell", async () => {
      await styk.buy(accounts[0], {
        from: accounts[1],
        value: web3.utils.toWei("2", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[2],
        value: web3.utils.toWei("2", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[3],
        value: web3.utils.toWei("2", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[4],
        value: web3.utils.toWei("2", "ether"),
      });
      try {
        await styk.sell(getWith15Decimals(9), { from: accounts[2] });
      } catch (error) {}
    });
  });

  describe("[Testcase 3: To reinvest]", () => {
    it("Token Reinvest", async () => {
      await styk.buy(accounts[0], {
        from: accounts[1],
        value: web3.utils.toWei("2", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[2],
        value: web3.utils.toWei("2", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[4],
        value: web3.utils.toWei("2", "ether"),
      });
      await styk.reinvest({ from: accounts[2] });
    });
  });

  describe("[Testcase 4: To validate dividends of user]", () => {
    it("Token Dividends", async () => {
      await styk.buy(accounts[0], {
        from: accounts[1],
        value: web3.utils.toWei("1", "ether"),
      });
      var actual = await styk._dividendsOf(accounts[1]);
      var expected = "4277644328871934";
      assert.equal(actual, expected);
    });
  });

  describe("[Testcase 5: To validate total dividends of user]", () => {
    it("Token Total Dividends", async () => {
      await styk.buy(accounts[0], {
        from: accounts[1],
        value: web3.utils.toWei("1", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[2],
        value: web3.utils.toWei("1", "ether"),
      });
      var actual = await styk.totalDividends(accounts[1]);
      var expected = "56379202109853480";
      assert.equal(actual, expected);
    });
  });

  describe("[Testcase 6: To withdraw dividends]", () => {
    it("Token Withdraw", async () => {
      await styk.buy(accounts[0], {
        from: accounts[1],
        value: web3.utils.toWei("2", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[2],
        value: web3.utils.toWei("2", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[3],
        value: web3.utils.toWei("2", "ether"),
      });
      await styk.withdraw({ from: accounts[3] });
    });
  });

  describe("[Testcase 7: To calculate monthly rewards before auction ]", () => {
    it("Token Reward", async () => {
      await styk.buy(accounts[0], {
        from: accounts[1],
        value: web3.utils.toWei("1", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[2],
        value: web3.utils.toWei("2", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[3],
        value: web3.utils.toWei("1", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[4],
        value: web3.utils.toWei("1", "ether"),
      });
      var actual = await styk.calculateMonthlyRewards(accounts[3]);
      var expected = "0";
      assert.equal(actual, expected);
    });
  });

  describe("[Testcase 8: To get the early adopter bonus of a user]", () => {
    it("Early Adopter Bonus", async () => {
      await styk.buy(accounts[0], {
        from: accounts[1],
        value: web3.utils.toWei("1", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[2],
        value: web3.utils.toWei("1", "ether"),
      });
      await styk.buy(accounts[1], {
        from: accounts[3],
        value: web3.utils.toWei("1", "ether"),
      });
      var actual = await styk.earlyAdopterBonus(accounts[1]);
      var expected = "109175101870594300";
      assert.equal(actual, expected);
    });
  });
});
