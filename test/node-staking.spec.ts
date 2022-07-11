import { Wallet } from "ethers";
import { ethers, waffle } from "hardhat";
import { fixture } from "./utils/fixture";
import * as time from "./utils/time";
import { expect } from "chai";
import { NodeStakingPool, NodeStakingPoolFactory } from "../typechain";
import { XCN } from "../typechain/XCN";

describe("Node Staking", () => {
  let wallets: Wallet[];
  let deployer: Wallet;
  let account1: Wallet;
  let account2: Wallet;
  let XCN: XCN;
  let STRK: XCN;
  let nodeStakingFactory: NodeStakingPoolFactory;
  let nodeStaking: NodeStakingPool;
  let loadFixture: ReturnType<typeof waffle.createFixtureLoader>;

  before("create fixture loader", async () => {
    wallets = await (ethers as any).getSigners();
    deployer = wallets[0];
    account1 = wallets[1];
    account2 = wallets[3];
  });

  beforeEach(async () => {
    loadFixture = waffle.createFixtureLoader(wallets as any);
    ({ STRK, XCN, nodeStaking } = await loadFixture(fixture));
    await STRK.approve(nodeStaking.address, ethers.constants.MaxUint256);
    await XCN.approve(nodeStaking.address, ethers.constants.MaxUint256);
  });

  // it("test", async () => {
  //   await nodeStaking.setRequireStakeAmount(ethers.utils.parseEther("100"));

  //   // check balance of user 1
  //   const user1Balance01 = await STRK.balanceOf(account1.address);
  //   const user1Balance01XCN = await XCN.balanceOf(account1.address);
  //   console.log("\x1b[36m%s\x1b[0m", "user1Balance01", user1Balance01.toString(), user1Balance01.toString().length);
  //   console.log(
  //     "\x1b[36m%s\x1b[0m",
  //     "user1Balance01XCN",
  //     user1Balance01XCN.toString(),
  //     user1Balance01XCN.toString().length,
  //   );
  //   // approve STRK
  //   await STRK.connect(account1).approve(nodeStaking.address, ethers.utils.parseUnits("100", 35));
  //   await STRK.connect(account2).approve(nodeStaking.address, ethers.utils.parseUnits("100", 35));
  //   // user1 stake count 1 => take 100
  //   await nodeStaking.connect(account1).deposit(1);
  //   await nodeStaking.connect(account2).deposit(1);
  //   // user1 stake again with count = 2 => take 200
  //   await nodeStaking.connect(account1).deposit(1);

  //   // enable address for user 1
  //   await nodeStaking.enableAddress(account1.address, 0);
  //   await nodeStaking.enableAddress(account1.address, 1);
  //   await nodeStaking.enableAddress(account2.address, 0);
  //   // increase to 100 block
  //   await time.advanceBlockTo(115);

  //   // check balance of user 1
  //   const user1Balance02 = await STRK.balanceOf(account1.address);
  //   console.log("\x1b[36m%s\x1b[0m", "user1Balance02", user1Balance02.toString(), user1Balance02.toString().length);

  //   // user1 withdraw
  //   await nodeStaking.connect(account1).withdraw(0, true);
  //   const user1Balance02XCN = await XCN.balanceOf(account1.address);
  //   console.log(
  //     "\x1b[36m%s\x1b[0m",
  //     "user1Balance02XCN",
  //     user1Balance02XCN.toString(),
  //     user1Balance02XCN.toString().length,
  //   );
  //   console.log("\x1b[36m%s\x1b[0m", "=============================================");
  //   await nodeStaking.connect(account1).withdraw(1, true);
  //   await nodeStaking.connect(account2).withdraw(0, true);

  //   // check balance of user 1
  //   const user1Balance03 = await STRK.balanceOf(account1.address);
  //   console.log("\x1b[36m%s\x1b[0m", "user1Balance03", user1Balance03.toString(), user1Balance03.toString().length);

  //   // check XCN balance
  //   const user1Balance03XCN = await XCN.balanceOf(account1.address);
  //   console.log(
  //     "\x1b[36m%s\x1b[0m",
  //     "user1Balance03XCN",
  //     user1Balance03XCN.toString(),
  //     user1Balance03XCN.toString().length,
  //   );
  // });

  describe("basic function: getter, setter", async () => {
    it("get pool infor", async () => {
      expect(await nodeStaking.name()).to.eq("Solana");
      expect(await nodeStaking.symbol()).to.eq("SOL");
      expect(await nodeStaking.stakeToken()).to.eq(STRK.address);
      expect(await nodeStaking.rewardToken()).to.eq(XCN.address);
      expect(await nodeStaking.requireStakeAmount()).to.eq(ethers.utils.parseEther("100"));
      expect(await nodeStaking.rewardPerBlock()).to.eq(ethers.utils.parseEther("1"));
    });

    it("setRequireStakeAmount", async () => {
      const amount = ethers.utils.parseEther("50");
      await expect(await nodeStaking.setRequireStakeAmount(amount))
        .to.emit(nodeStaking, "SetRequireStakeAmount")
        .withArgs(amount);

      expect(await nodeStaking.requireStakeAmount()).to.eq(amount);
    });

    it("setRewardDistributor", async () => {
      await expect(await nodeStaking.setRewardDistributor(account1.address))
        .to.emit(nodeStaking, "SetRewardDistributor")
        .withArgs(account1.address);

      expect(await nodeStaking.rewardDistributor()).to.eq(account1.address);
    });

    it("setRewardPerBlock", async () => {
      const amount = ethers.utils.parseEther("50");
      await expect(await nodeStaking.setRewardPerBlock(amount))
        .to.emit(nodeStaking, "SetRewardPerBlock")
        .withArgs(amount);

      expect(await nodeStaking.rewardPerBlock()).to.eq(amount);
    });

    it("setEndBlock", async () => {
      const block = 100000000000;
      await expect(await nodeStaking.setEndBlock(block))
        .to.emit(nodeStaking, "SetEndBlock")
        .withArgs(block);

      expect(await nodeStaking.endBlockNumber()).to.eq(block);
    });

    it("setPoolInfor", async () => {
      const rewardPerBlock = 100000000000;
      const endBlock = 100000000000;
      const lockupDuration = 100000000000;
      const withdrawPeriod = 100000000000;
      const rewardDistributor = account2.address;
      await expect(
        await nodeStaking.setPoolInfor(rewardPerBlock, endBlock, lockupDuration, withdrawPeriod, rewardDistributor),
      )
        .to.emit(nodeStaking, "SetPoolInfor")
        .withArgs(rewardPerBlock, endBlock, lockupDuration, withdrawPeriod, rewardDistributor);

      expect(await nodeStaking.rewardPerBlock()).to.eq(rewardPerBlock);
      expect(await nodeStaking.endBlockNumber()).to.eq(endBlock);
      expect(await nodeStaking.lockupDuration()).to.eq(lockupDuration);
      expect(await nodeStaking.withdrawPeriod()).to.eq(withdrawPeriod);
      expect(await nodeStaking.rewardDistributor()).to.eq(rewardDistributor);
    });

    it("timeMultiplier", async () => {
      // get current block
      let currentBlock = await time.latestBlock();
      const oldCurrBlock = currentBlock;
      await nodeStaking.setEndBlock(currentBlock.add(100));

      let timeMultiplier = await nodeStaking.timeMultiplier(currentBlock, currentBlock.add(10));
      expect(timeMultiplier).to.be.eq(ethers.BigNumber.from(10));

      // increase 200 block
      await time.advanceBlockTo(currentBlock.add(200).toNumber());
      currentBlock = await time.latestBlock();
      timeMultiplier = await nodeStaking.timeMultiplier(currentBlock, currentBlock.add(10));
      expect(timeMultiplier).to.be.eq(ethers.BigNumber.from(0));

      timeMultiplier = await nodeStaking.timeMultiplier(oldCurrBlock.add(20), currentBlock.add(10));
      expect(timeMultiplier).to.be.lt(ethers.BigNumber.from(100));
    });

    it("isInWithdrawTime", async () => {
      // lock time = 10, withdraw time = 10
      await time.advanceBlockTo(500);
      expect(await nodeStaking.isInWithdrawTime(485)).to.eq(true);
      expect(await nodeStaking.isInWithdrawTime(495)).to.eq(false);
      expect(await nodeStaking.isInWithdrawTime(490)).to.eq(true);
      expect(await nodeStaking.isInWithdrawTime(480)).to.eq(false);
    });

    it("getNextStartLockingTime", async () => {
      // lock time = 10, withdraw time = 10
      await time.advanceBlockTo(700);
      expect(await nodeStaking.getNextStartLockingTime(700)).to.eq(720);
      expect(await nodeStaking.getNextStartLockingTime(690)).to.eq(710);
    });
  });
});
