import { Wallet } from "ethers";
import { ethers, waffle } from "hardhat";
import { decimals, fixture, price, requireStakeAmount } from "./utils/fixture";
import { MockOracle, Payment } from "../typechain";
import { XCN } from "../typechain/XCN";
import { beautifyObject } from "./utils/utils";
import { expect } from "chai";

describe("Payment", () => {
  let wallets: Wallet[];
  let deployer: Wallet;
  let account1: Wallet;
  let treasury: Wallet;
  let XCN: XCN;
  let USDT: XCN;
  let payment: Payment;
  let oracle: MockOracle;
  let loadFixture: ReturnType<typeof waffle.createFixtureLoader>;
  const discount = ethers.utils.parseEther("0.1");

  before("create fixture loader", async () => {
    wallets = await (ethers as any).getSigners();
    deployer = wallets[0];
    account1 = wallets[1];
    treasury = wallets[5];
  });

  beforeEach(async () => {
    loadFixture = waffle.createFixtureLoader(wallets as any);
    ({ USDT, XCN, payment, oracle } = await loadFixture(fixture));
    await USDT.approve(payment.address, ethers.constants.MaxUint256);
    await XCN.approve(payment.address, ethers.constants.MaxUint256);
    await USDT.connect(account1).approve(payment.address, ethers.constants.MaxUint256);
  });

  it("admin should able to set contract infor", async () => {
    await expect(payment.connect(account1).setOracle(oracle.address, oracle.address)).to.revertedWith(
      "Ownable: caller is not the owner",
    );

    await expect(payment.setOracle(account1.address, account1.address))
      .to.emit(payment, "SetOracle")
      .withArgs(account1.address, account1.address);
    expect(await payment.usdtEthPriceFeed()).to.eq(account1.address);
    expect(await payment.usdtXcnPriceFeed()).to.eq(account1.address);

    await expect(payment.setTokenAddress(account1.address, account1.address))
      .to.emit(payment, "SetTokenAddress")
      .withArgs(account1.address, account1.address);
    expect(await payment.USDTToken()).to.eq(account1.address);
    expect(await payment.XCNToken()).to.eq(account1.address);

    await expect(payment.setPaymentAmount(1, requireStakeAmount))
      .to.emit(payment, "SetPaymentAmount")
      .withArgs(1, requireStakeAmount);
    expect(await payment.paymentAmountInUSDT(1)).to.eq(requireStakeAmount);

    await expect(payment.setDiscount(1, XCN.address, discount))
      .to.emit(payment, "SetDiscount")
      .withArgs(1, XCN.address, discount);
    expect(await payment.getDiscountAmount(1, XCN.address)).to.eq(discount);

    await expect(payment.changeTreasury(account1.address))
      .to.emit(payment, "ChangeTreasury")
      .withArgs(account1.address);
    expect(await payment.treasury()).to.eq(account1.address);
  });

  context("Payment", () => {
    beforeEach(async () => {
      await payment.setPaymentAmount(0, requireStakeAmount);
      await payment.setDiscount(0, XCN.address, discount);
      await payment.changeTreasury(treasury.address);
    });

    it("Should able to get lastest price", async () => {
      await expect(payment.getLatestPrice(account1.address)).to.revertedWith("Payment: invalid token");

      const xcnPriceRecord = await payment.getLatestPrice(XCN.address);
      const ethPriceRecord = await payment.getLatestPrice(ethers.constants.AddressZero);
      expect(xcnPriceRecord[0]).to.eq(price);
      expect(xcnPriceRecord[1]).to.eq(decimals);
      expect(ethPriceRecord[0]).to.eq(price);
      expect(ethPriceRecord[1]).to.eq(decimals);
    });

    it("Should able to get XCN amount from USDT amount", async () => {
      // const;
    });

    it("pause contract", async () => {
      await payment.pause();
      await expect(payment.connect(account1).pay(0, XCN.address, 1)).to.revertedWith("Pausable: paused");

      await payment.unpause();
      await XCN.connect(account1).approve(payment.address, ethers.constants.MaxUint256);
      await expect(payment.connect(account1).pay(0, XCN.address, 1)).to.not.reverted;
    });

    it("Payment with USDT", async () => {
      const preBalance = await USDT.balanceOf(account1.address);

      const paymentId = 0;
      await expect(payment.connect(account1).pay(0, USDT.address, paymentId))
        .to.emit(payment, "Payment")
        .withArgs(account1.address, USDT.address, requireStakeAmount, 0, 0, paymentId);

      const postBalance = await USDT.balanceOf(account1.address);
      expect(preBalance.sub(postBalance)).to.eq(requireStakeAmount);
    });

    it("Payment with XCN", async () => {
      await XCN.connect(account1).approve(payment.address, ethers.constants.MaxUint256);
      const xcnRequire = requireStakeAmount.mul(9).div(10).mul(price).div(ethers.BigNumber.from(10).pow(decimals));
      const preBalance = await XCN.balanceOf(account1.address);

      const paymentId = 0;
      await expect(payment.connect(account1).pay(0, XCN.address, paymentId))
        .to.emit(payment, "Payment")
        .withArgs(account1.address, XCN.address, xcnRequire, discount, 0, paymentId);

      const postBalance = await XCN.balanceOf(account1.address);
      expect(preBalance.sub(postBalance)).to.eq(xcnRequire);
    });

    it("Payment with ETH", async () => {
      const preBalance = await account1.getBalance();
      const ethRequire = requireStakeAmount.mul(price).div(ethers.BigNumber.from(10).pow(decimals));

      const paymentId = 0;

      await expect(payment.connect(account1).pay(0, ethers.constants.AddressZero, paymentId)).to.be.revertedWith(
        "Payment: not valid pay amount",
      );
      await expect(
        payment.connect(account1).pay(0, ethers.constants.AddressZero, paymentId, { value: ethRequire.mul(2) }),
      )
        .to.emit(payment, "Payment")
        .withArgs(account1.address, ethers.constants.AddressZero, ethRequire, 0, 0, paymentId);

      const postBalance = await account1.getBalance();
      expect(preBalance.sub(postBalance)).to.gt(ethRequire);
      expect(preBalance.sub(postBalance)).to.lt(ethRequire.add(ethers.utils.parseEther("0.05")));
    });

    it("Payment with ETH", async () => {
      const preBalance = await account1.getBalance();
      const ethRequire = requireStakeAmount.mul(price).div(ethers.BigNumber.from(10).pow(decimals));

      const paymentId = 0;

      await expect(payment.connect(account1).pay(0, ethers.constants.AddressZero, paymentId)).to.be.revertedWith(
        "Payment: not valid pay amount",
      );
      await expect(payment.connect(account1).pay(0, ethers.constants.AddressZero, paymentId, { value: ethRequire }))
        .to.emit(payment, "Payment")
        .withArgs(account1.address, ethers.constants.AddressZero, ethRequire, 0, 0, paymentId);

      const postBalance = await account1.getBalance();
      expect(preBalance.sub(postBalance)).to.gt(ethRequire);
      expect(preBalance.sub(postBalance)).to.lt(ethRequire.add(ethers.utils.parseEther("0.05")));
    });
  });
});
