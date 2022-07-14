import { Wallet } from "ethers";
import { ethers, waffle } from "hardhat";
import { fixture, requireStakeAmount, rewardPerBlock } from "./utils/fixture";
import * as time from "./utils/time";
import { expect } from "chai";
import { NodeStakingPool, NodeStakingPoolFactory } from "../typechain";
import { XCN } from "../typechain/XCN";
import { beautifyObject } from "./utils/utils";

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
    await STRK.connect(account1).approve(nodeStaking.address, ethers.utils.parseUnits("100", 35));
    await STRK.connect(account2).approve(nodeStaking.address, ethers.utils.parseUnits("100", 35));
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

  // describe("basic function: getter, setter", async () => {
  //   it("get pool infor", async () => {
  //     expect(await nodeStaking.name()).to.eq("Solana");
  //     expect(await nodeStaking.symbol()).to.eq("SOL");
  //     expect(await nodeStaking.stakeToken()).to.eq(STRK.address);
  //     expect(await nodeStaking.rewardToken()).to.eq(XCN.address);
  //     expect(await nodeStaking.requireStakeAmount()).to.eq(ethers.utils.parseEther("100"));
  //     expect(await nodeStaking.rewardPerBlock()).to.eq(ethers.utils.parseEther("1"));
  //   });

  //   it("setRequireStakeAmount", async () => {
  //     const amount = ethers.utils.parseEther("50");
  //     await expect(await nodeStaking.setRequireStakeAmount(amount))
  //       .to.emit(nodeStaking, "SetRequireStakeAmount")
  //       .withArgs(amount);

  //     expect(await nodeStaking.requireStakeAmount()).to.eq(amount);
  //   });

  //   it("setRewardDistributor", async () => {
  //     await expect(await nodeStaking.setRewardDistributor(account1.address))
  //       .to.emit(nodeStaking, "SetRewardDistributor")
  //       .withArgs(account1.address);

  //     expect(await nodeStaking.rewardDistributor()).to.eq(account1.address);
  //   });

  //   it("setRewardPerBlock", async () => {
  //     const amount = ethers.utils.parseEther("50");
  //     await expect(await nodeStaking.setRewardPerBlock(amount))
  //       .to.emit(nodeStaking, "SetRewardPerBlock")
  //       .withArgs(amount);

  //     expect(await nodeStaking.rewardPerBlock()).to.eq(amount);
  //   });

  //   it("setEndBlock", async () => {
  //     const block = 100000000000;
  //     await expect(await nodeStaking.setEndBlock(block))
  //       .to.emit(nodeStaking, "SetEndBlock")
  //       .withArgs(block);

  //     expect(await nodeStaking.endBlockNumber()).to.eq(block);
  //   });

  //   it("setPoolInfor", async () => {
  //     const rewardPerBlock = 100000000000;
  //     const endBlock = 100000000000;
  //     const lockupDuration = 100000000000;
  //     const withdrawPeriod = 100000000000;
  //     const rewardDistributor = account2.address;
  //     await expect(
  //       await nodeStaking.setPoolInfor(rewardPerBlock, endBlock, lockupDuration, withdrawPeriod, rewardDistributor),
  //     )
  //       .to.emit(nodeStaking, "SetPoolInfor")
  //       .withArgs(rewardPerBlock, endBlock, lockupDuration, withdrawPeriod, rewardDistributor);

  //     expect(await nodeStaking.rewardPerBlock()).to.eq(rewardPerBlock);
  //     expect(await nodeStaking.endBlockNumber()).to.eq(endBlock);
  //     expect(await nodeStaking.lockupDuration()).to.eq(lockupDuration);
  //     expect(await nodeStaking.withdrawPeriod()).to.eq(withdrawPeriod);
  //     expect(await nodeStaking.rewardDistributor()).to.eq(rewardDistributor);
  //   });

  //   it("timeMultiplier", async () => {
  //     // get current block
  //     let currentBlock = await time.latestBlock();
  //     const oldCurrBlock = currentBlock;
  //     await nodeStaking.setEndBlock(currentBlock.add(100));

  //     let timeMultiplier = await nodeStaking.timeMultiplier(currentBlock, currentBlock.add(10));
  //     expect(timeMultiplier).to.be.eq(ethers.BigNumber.from(10));

  //     // increase 200 block
  //     await time.advanceBlockTo(currentBlock.add(200).toNumber());
  //     currentBlock = await time.latestBlock();
  //     timeMultiplier = await nodeStaking.timeMultiplier(currentBlock, currentBlock.add(10));
  //     expect(timeMultiplier).to.be.eq(ethers.BigNumber.from(0));

  //     timeMultiplier = await nodeStaking.timeMultiplier(oldCurrBlock.add(20), currentBlock.add(10));
  //     expect(timeMultiplier).to.be.lt(ethers.BigNumber.from(100));
  //   });

  //   it("isInWithdrawTime", async () => {
  //     // lock time = 10, withdraw time = 10
  //     await time.advanceBlockTo(500);
  //     expect(await nodeStaking.isInWithdrawTime(485)).to.eq(true);
  //     expect(await nodeStaking.isInWithdrawTime(495)).to.eq(false);
  //     expect(await nodeStaking.isInWithdrawTime(490)).to.eq(true);
  //     expect(await nodeStaking.isInWithdrawTime(480)).to.eq(false);
  //   });

  //   it("getNextStartLockingTime", async () => {
  //     // lock time = 10, withdraw time = 10
  //     await time.advanceBlockTo(700);
  //     expect(await nodeStaking.getNextStartLockingTime(700)).to.eq(720);
  //     expect(await nodeStaking.getNextStartLockingTime(690)).to.eq(710);
  //   });
  // });

  describe("Deposit, withdraw, not enable address => haven't reward", async () => {
    // it("should able to deposit and withdraw", async () => {
    //   // acc1 deposit
    //   const acc1XCNBalance1 = await XCN.balanceOf(account1.address);
    //   const acc1STRKBalance1 = await STRK.balanceOf(account1.address);
    //   await nodeStaking.connect(account1).deposit(1);
    //   // check balance STRK account1
    //   const acc1STRKBalance2 = await STRK.balanceOf(account1.address);
    //   expect(acc1STRKBalance1.sub(acc1STRKBalance2)).to.eq(ethers.utils.parseEther("100"));
    //   // increase 100 block
    //   await time.advanceBlockBy(100);
    //   // acc2 deposit
    //   const acc2XCNBalance1 = await XCN.balanceOf(account2.address);
    //   const acc2STRKBalance1 = await STRK.balanceOf(account2.address);
    //   await nodeStaking.connect(account2).deposit(1);
    //   // check balance STRK account2
    //   const acc2STRKBalance2 = await STRK.balanceOf(account1.address);
    //   expect(acc2STRKBalance1.sub(acc2STRKBalance2)).to.eq(ethers.utils.parseEther("100"));
    //   // increase 100 block
    //   await time.advanceBlockBy(100);
    //   // withdraw and check state
    //   await nodeStaking.connect(account1).withdraw(0, true);
    //   await nodeStaking.connect(account2).withdraw(0, true);
    //   const acc2XCNBalance2 = await XCN.balanceOf(account2.address);
    //   const acc2STRKBalance3 = await STRK.balanceOf(account2.address);
    //   expect(acc2XCNBalance2.sub(acc2XCNBalance1)).to.eq(ethers.utils.parseEther("0"));
    //   expect(acc2STRKBalance3.sub(acc2STRKBalance2)).to.eq(ethers.utils.parseEther("100"));
    //   const acc1XCNBalance2 = await XCN.balanceOf(account1.address);
    //   const acc1STRKBalance3 = await STRK.balanceOf(account1.address);
    //   expect(acc1XCNBalance2.sub(acc1XCNBalance1)).to.eq(ethers.utils.parseEther("0"));
    //   expect(acc1STRKBalance3.sub(acc1STRKBalance2)).to.eq(ethers.utils.parseEther("100"));
    // });
  });

  describe("Deposit => enable => withdraw", async () => {
    // it("Deposit => enable => withdraw", async () => {
    //   // acc1 deposit
    //   const acc1XCNBalance1 = await XCN.balanceOf(account1.address);
    //   const acc1STRKBalance1 = await STRK.balanceOf(account1.address);

    //   await nodeStaking.connect(account1).deposit(1);
    //   // enable address for node 0 acc 1
    //   await nodeStaking.enableAddress(account1.address, 0);

    //   // check balance STRK account1
    //   const acc1STRKBalance2 = await STRK.balanceOf(account1.address);
    //   expect(acc1STRKBalance1.sub(acc1STRKBalance2)).to.eq(ethers.utils.parseEther("100"));

    //   // increase 100 block
    //   await time.advanceBlockBy(100);

    //   // acc2 deposit
    //   const acc2XCNBalance1 = await XCN.balanceOf(account2.address);
    //   const acc2STRKBalance1 = await STRK.balanceOf(account2.address);

    //   await nodeStaking.connect(account2).deposit(1);
    //   // enable address for node 0 acc 2
    //   await nodeStaking.enableAddress(account2.address, 0);

    //   // check balance STRK account2
    //   const acc2STRKBalance2 = await STRK.balanceOf(account1.address);
    //   expect(acc2STRKBalance1.sub(acc2STRKBalance2)).to.eq(ethers.utils.parseEther("100"));

    //   // increase 110 block
    //   await time.advanceBlockBy(110);

    //   // withdraw and check state: acc2 + 55, acc1 + 100 + 55
    //   await nodeStaking.connect(account1).withdraw(0, true);
    //   console.log("\x1b[36m%s\x1b[0m", "=========================");
    //   const tx = await nodeStaking.connect(account2).withdraw(0, true);
    //   console.log("\x1b[36m%s\x1b[0m", "tx", tx.blockNumber);
    //   const eventFilter = nodeStaking.filters.NodeStakingRewardsHarvested();
    //   const events = await nodeStaking.queryFilter(eventFilter, tx.blockNumber, tx.blockNumber);
    //   console.log("\x1b[36m%s\x1b[0m", "events", events[0].args);

    //   const acc2XCNBalance2 = await XCN.balanceOf(account2.address);
    //   const acc2STRKBalance3 = await STRK.balanceOf(account2.address);
    //   expect(acc2XCNBalance2.sub(acc2XCNBalance1)).to.gte(ethers.utils.parseEther("55"));
    //   expect(acc2XCNBalance2.sub(acc2XCNBalance1)).to.lte(ethers.utils.parseEther("57"));
    //   expect(acc2STRKBalance3.sub(acc2STRKBalance2)).to.eq(ethers.utils.parseEther("100"));

    //   const acc1XCNBalance2 = await XCN.balanceOf(account1.address);
    //   const acc1STRKBalance3 = await STRK.balanceOf(account1.address);
    //   expect(acc1XCNBalance2.sub(acc1XCNBalance1)).to.gte(ethers.utils.parseEther("155"));
    //   expect(acc1XCNBalance2.sub(acc1XCNBalance1)).to.lte(ethers.utils.parseEther("157"));
    //   expect(acc1STRKBalance3.sub(acc1STRKBalance2)).to.eq(ethers.utils.parseEther("100"));
    // });

    // it("Deposit", async () => {
    //   // acc1 deposit
    //   const acc1XCNBalance1 = await STRK.balanceOf(account1.address);

    //   await expect(nodeStaking.connect(account1).deposit(1))
    //     .emit(nodeStaking, "NodeStakingDeposit")
    //     .withArgs(account1.address, requireStakeAmount, 0, 1);

    //   const acc1XCNBalance2 = await STRK.balanceOf(account1.address);

    //   expect(acc1XCNBalance1.sub(acc1XCNBalance2)).to.equal(requireStakeAmount);

    //   const userNodeCount = await nodeStaking.userNodeCount(account1.address);
    //   expect(userNodeCount).to.eq(1);

    //   const userNodeInfo = await nodeStaking.getUserNodeInfo(account1.address, 0);
    //   expect(userNodeInfo.amount).to.eq(requireStakeAmount);
    //   expect(userNodeInfo.stakeTime).to.eq(0);
    //   expect(userNodeInfo.pendingReward).to.eq(0);
    //   expect(userNodeInfo.rewardDebt).to.eq(0);
    // });

    // it("Deposit, then enable address", async () => {
    //   // acc1 deposit
    //   const acc1XCNBalance1 = await STRK.balanceOf(account1.address);

    //   await expect(nodeStaking.connect(account1).deposit(1))
    //     .emit(nodeStaking, "NodeStakingDeposit")
    //     .withArgs(account1.address, requireStakeAmount, 0, 1);

    //   const acc1XCNBalance2 = await STRK.balanceOf(account1.address);

    //   expect(acc1XCNBalance1.sub(acc1XCNBalance2)).to.equal(requireStakeAmount);

    //   // enable address
    //   await expect(nodeStaking.enableAddress(account1.address, 0))
    //     .emit(nodeStaking, "NodeStakingEnableAddress")
    //     .withArgs(account1.address, 0);

    //   // after enable address, user node stake time and reward debt will be update
    //   const userNodeCount = await nodeStaking.userNodeCount(account1.address);
    //   expect(userNodeCount).to.eq(1);

    //   const userNodeInfo = await nodeStaking.getUserNodeInfo(account1.address, 0);
    //   expect(userNodeInfo.amount).to.eq(requireStakeAmount);
    //   expect(userNodeInfo.stakeTime).to.gt(0);
    //   expect(userNodeInfo.pendingReward).to.eq(0);
    //   expect(userNodeInfo.rewardDebt).to.eq(0);

    //   await nodeStaking.connect(account1).deposit(1);
    //   await expect(nodeStaking.enableAddress(account1.address, 0)).to.revertedWith(
    //     "NodeStakingPool: node already enabled",
    //   );
    //   await expect(nodeStaking.enableAddress(account1.address, 3)).to.revertedWith("NodeStakingPool: invalid node id");

    //   await nodeStaking.enableAddress(account1.address, 1);
    //   const userNodeInfo1 = await nodeStaking.getUserNodeInfo(account1.address, 1);
    //   expect(userNodeInfo1.amount).to.eq(requireStakeAmount);
    //   expect(userNodeInfo1.stakeTime).to.gt(0);
    //   expect(userNodeInfo1.pendingReward).to.eq(0);
    //   expect(userNodeInfo1.rewardDebt).to.gt(0);
    // });

    // it("Deposit, then enable address, then disable address", async () => {
    //   // acc1 deposit
    //   await expect(nodeStaking.connect(account1).deposit(1))
    //     .emit(nodeStaking, "NodeStakingDeposit")
    //     .withArgs(account1.address, requireStakeAmount, 0, 1);
    //   // enable address
    //   const { blockNumber: firstEABlock } = await nodeStaking.enableAddress(account1.address, 0);

    //   // increase 100 blocks
    //   await time.advanceBlockBy(100);

    //   await nodeStaking.connect(account2).deposit(1);
    //   const { blockNumber: secondEABlock } = await nodeStaking.enableAddress(account2.address, 0);

    //   const greaterReward = rewardPerBlock.mul(secondEABlock! - firstEABlock!);
    //   // increase 110 blocks
    //   await time.advanceBlockBy(110);

    //   const rewardInLastDuration = rewardPerBlock.mul(110);
    //   // disable address
    //   await nodeStaking.disableAddress(account2.address, 0);
    //   await expect(nodeStaking.disableAddress(account2.address, 0)).to.revertedWith(
    //     "NodeStakingPool: node already disabled",
    //   );
    //   await expect(nodeStaking.disableAddress(account1.address, 0))
    //     .emit(nodeStaking, "NodeStakingDisableAddress")
    //     .withArgs(account1.address, 0);

    //   // get pending reward
    //   const acc2NodeInfo = await nodeStaking.getUserNodeInfo(account2.address, 0);
    //   const acc1NodeInfo = await nodeStaking.getUserNodeInfo(account1.address, 0);
    //   const twoInBN = ethers.utils.parseEther("2");
    //   expect(acc1NodeInfo.pendingReward.sub(acc2NodeInfo.pendingReward)).to.gte(greaterReward);
    //   expect(acc1NodeInfo.pendingReward.sub(acc2NodeInfo.pendingReward)).to.lte(greaterReward.add(twoInBN));
    //   expect(acc1NodeInfo.pendingReward).to.gte(greaterReward.add(rewardInLastDuration.div(2)));
    //   expect(acc1NodeInfo.pendingReward).to.lte(greaterReward.add(rewardInLastDuration.div(2)).add(twoInBN));
    //   expect(acc2NodeInfo.pendingReward).to.gte(rewardInLastDuration.div(2));
    //   expect(acc2NodeInfo.pendingReward).to.lte(rewardInLastDuration.div(2).add(twoInBN));

    //   expect(acc1NodeInfo.stakeTime).to.eq(0);
    //   expect(acc1NodeInfo.amount).to.eq(requireStakeAmount);
    //   expect(acc2NodeInfo.stakeTime).to.eq(0);
    //   expect(acc2NodeInfo.amount).to.eq(requireStakeAmount);
    // });

    // it("Deposit, then enable address, then disable address and claim", async () => {
    //   // acc1 deposit
    //   await expect(nodeStaking.connect(account1).deposit(1))
    //     .emit(nodeStaking, "NodeStakingDeposit")
    //     .withArgs(account1.address, requireStakeAmount, 0, 1);
    //   // enable address
    //   await nodeStaking.enableAddress(account1.address, 0);

    //   // increase 100 blocks
    //   await time.advanceBlockBy(100);

    //   await nodeStaking.connect(account2).deposit(1);
    //   await nodeStaking.enableAddress(account2.address, 0);

    //   // disable address
    //   await nodeStaking.disableAddress(account2.address, 0);
    //   await expect(nodeStaking.disableAddress(account2.address, 0)).to.revertedWith(
    //     "NodeStakingPool: node already disabled",
    //   );
    //   await expect(nodeStaking.disableAddress(account1.address, 0))
    //     .emit(nodeStaking, "NodeStakingDisableAddress")
    //     .withArgs(account1.address, 0);

    //   // get pending reward
    //   const acc1NodeInfo = await nodeStaking.getUserNodeInfo(account1.address, 0);

    //   // claim reward
    //   const acc1XCNBalance1 = await XCN.balanceOf(account1.address);

    //   const acc1PendingReward = await nodeStaking.pendingReward(account1.address, 0);
    //   expect(acc1PendingReward).to.eq(acc1NodeInfo.pendingReward);

    //   await expect(nodeStaking.connect(account1).claimReward(0))
    //     .emit(nodeStaking, "NodeStakingRewardsHarvested")
    //     .withArgs(account1.address, acc1PendingReward);

    //   const acc1XCNBalance2 = await XCN.balanceOf(account1.address);
    //   expect(acc1XCNBalance2.sub(acc1XCNBalance1)).to.eq(acc1PendingReward);
    // });

    // it("Deposit, then enable address, then disable address and claim, then withdraw", async () => {
    //   // acc1 deposit
    //   await expect(nodeStaking.connect(account1).deposit(1))
    //     .emit(nodeStaking, "NodeStakingDeposit")
    //     .withArgs(account1.address, requireStakeAmount, 0, 1);
    //   // enable address
    //   await nodeStaking.enableAddress(account1.address, 0);

    //   // increase 100 blocks
    //   await time.advanceBlockBy(100);
    //   await expect(nodeStaking.connect(account1).withdraw(0)).to.revertedWith("NodeStakingPool: not in withdraw time");

    //   await nodeStaking.connect(account2).deposit(1);
    //   await nodeStaking.enableAddress(account2.address, 0);

    //   // disable address
    //   await nodeStaking.disableAddress(account2.address, 0);
    //   await expect(nodeStaking.disableAddress(account2.address, 0)).to.revertedWith(
    //     "NodeStakingPool: node already disabled",
    //   );
    //   await expect(nodeStaking.disableAddress(account1.address, 0))
    //     .emit(nodeStaking, "NodeStakingDisableAddress")
    //     .withArgs(account1.address, 0);

    //   // get pending reward
    //   const acc1NodeInfo = await nodeStaking.getUserNodeInfo(account1.address, 0);

    //   // claim reward
    //   const acc1XCNBalance1 = await XCN.balanceOf(account1.address);

    //   const acc1PendingReward = await nodeStaking.pendingReward(account1.address, 0);
    //   expect(acc1PendingReward).to.eq(acc1NodeInfo.pendingReward);

    //   await expect(nodeStaking.connect(account1).claimReward(0))
    //     .emit(nodeStaking, "NodeStakingRewardsHarvested")
    //     .withArgs(account1.address, acc1PendingReward);

    //   const acc1XCNBalance2 = await XCN.balanceOf(account1.address);
    //   expect(acc1XCNBalance2.sub(acc1XCNBalance1)).to.eq(acc1PendingReward);

    //   // withdraw
    //   const acc1STRKBalance1 = await STRK.balanceOf(account1.address);

    //   await expect(nodeStaking.connect(account1).withdraw(0))
    //     .emit(nodeStaking, "NodeStakingRewardsHarvested")
    //     .withArgs(account1.address, 0)
    //     .emit(nodeStaking, "NodeStakingWithdraw")
    //     .withArgs(account1.address, requireStakeAmount);

    //   await expect(nodeStaking.connect(account1).withdraw(0)).to.revertedWith(
    //     "NodeStakingPool: have not any token to withdraw",
    //   );

    //   const acc1STRKBalance2 = await STRK.balanceOf(account1.address);

    //   expect(acc1STRKBalance2.sub(acc1STRKBalance1)).to.eq(requireStakeAmount);
    // });

    it("Deposit, then enable address, then withdraw", async () => {
      // acc1 deposit
      await expect(nodeStaking.connect(account1).deposit(1))
        .emit(nodeStaking, "NodeStakingDeposit")
        .withArgs(account1.address, requireStakeAmount, 0, 1);
      // enable address
      await nodeStaking.enableAddress(account1.address, 0);

      // increase 100 blocks
      await time.advanceBlockBy(100);

      await nodeStaking.connect(account2).deposit(1);
      await nodeStaking.enableAddress(account2.address, 0);

      const acc1STRKBalance1 = await STRK.balanceOf(account1.address);

      // increase 110 blocks
      await time.advanceBlockBy(110);

      // withdraw
      await expect(nodeStaking.connect(account1).withdraw(0))
        .emit(nodeStaking, "NodeStakingRewardsHarvested")
        .withArgs(account1.address, ethers.utils.parseEther("157.5")) // 157.5 = 1 + 1 + 100 + 111/2
        .emit(nodeStaking, "NodeStakingWithdraw")
        .withArgs(account1.address, requireStakeAmount);

      const acc1STRKBalance2 = await STRK.balanceOf(account1.address);

      expect(acc1STRKBalance2.sub(acc1STRKBalance1)).to.eq(requireStakeAmount);

      // increase 100 blocks
      await time.advanceBlockBy(100);

      await expect(nodeStaking.connect(account2).withdraw(0))
        .emit(nodeStaking, "NodeStakingRewardsHarvested")
        .withArgs(account2.address, ethers.utils.parseEther("156.5")) // 157.5 = 1 + 100 + 111/2
        .emit(nodeStaking, "NodeStakingWithdraw")
        .withArgs(account2.address, requireStakeAmount);
    });

    it("Deposit, then enable address, then claim reward", async () => {
      // acc1 deposit
      await expect(nodeStaking.connect(account1).deposit(1))
        .emit(nodeStaking, "NodeStakingDeposit")
        .withArgs(account1.address, requireStakeAmount, 0, 1);
      // enable address
      await nodeStaking.enableAddress(account1.address, 0);

      // increase 100 blocks
      await time.advanceBlockBy(100);

      await nodeStaking.connect(account2).deposit(1);
      await nodeStaking.enableAddress(account2.address, 0);

      // increase 110 blocks
      await time.advanceBlockBy(110);

      // withdraw
      await expect(nodeStaking.connect(account1).claimReward(0))
        .emit(nodeStaking, "NodeStakingRewardsHarvested")
        .withArgs(account1.address, ethers.utils.parseEther("157.5")); // 157.5 = 1 + 1 + 100 + 111/2

      // increase 100 blocks
      await time.advanceBlockBy(100);

      await expect(nodeStaking.connect(account2).claimReward(0))
        .emit(nodeStaking, "NodeStakingRewardsHarvested")
        .withArgs(account2.address, ethers.utils.parseEther("106")); // 106 = 50 + 112/2

      // withdraw
      await expect(nodeStaking.connect(account1).withdraw(0))
        .emit(nodeStaking, "NodeStakingRewardsHarvested")
        .withArgs(account1.address, ethers.utils.parseEther("51")) // 50 + 1
        .emit(nodeStaking, "NodeStakingWithdraw")
        .withArgs(account1.address, requireStakeAmount);
    });
  });

  // describe("Deposit => enable => disable => withdraw", async () => {
  //   it("Deposit => enable => withdraw", async () => {
  //     // acc1 deposit
  //     const acc1XCNBalance1 = await XCN.balanceOf(account1.address);
  //     const acc1STRKBalance1 = await STRK.balanceOf(account1.address);

  //     await nodeStaking.connect(account1).deposit(1);
  //     // enable address for node 0 acc 1
  //     await nodeStaking.enableAddress(account1.address, 0);

  //     // check balance STRK account1
  //     const acc1STRKBalance2 = await STRK.balanceOf(account1.address);
  //     expect(acc1STRKBalance1.sub(acc1STRKBalance2)).to.eq(ethers.utils.parseEther("100"));

  //     // increase 100 block
  //     await time.advanceBlockBy(100);

  //     // acc2 deposit
  //     const acc2XCNBalance1 = await XCN.balanceOf(account2.address);
  //     const acc2STRKBalance1 = await STRK.balanceOf(account2.address);

  //     await nodeStaking.connect(account2).deposit(1);
  //     // enable address for node 0 acc 2
  //     await nodeStaking.enableAddress(account2.address, 0);

  //     // check balance STRK account2
  //     const acc2STRKBalance2 = await STRK.balanceOf(account1.address);
  //     expect(acc2STRKBalance1.sub(acc2STRKBalance2)).to.eq(ethers.utils.parseEther("100"));

  //     // increase 110 block
  //     await time.advanceBlockBy(110);

  //     // disable address account 1 node 0 and account 2 node 0
  //     await nodeStaking.disableAddress(account1.address, 0);
  //     await nodeStaking.disableAddress(account2.address, 0);

  //     // increase 110 block
  //     await time.advanceBlockBy(110);

  //     // withdraw and check state: acc2 + 55, acc1 + 100 + 55
  //     await nodeStaking.connect(account1).withdraw(0, true);
  //     console.log("\x1b[36m%s\x1b[0m", "=========================");
  //     const tx = await nodeStaking.connect(account2).withdraw(0, true);
  //     console.log("\x1b[36m%s\x1b[0m", "tx", tx.blockNumber);
  //     const eventFilter = nodeStaking.filters.NodeStakingRewardsHarvested();
  //     const events = await nodeStaking.queryFilter(eventFilter, tx.blockNumber, tx.blockNumber);
  //     console.log("\x1b[36m%s\x1b[0m", "events", events[0].args);

  //     const acc2XCNBalance2 = await XCN.balanceOf(account2.address);
  //     const acc2STRKBalance3 = await STRK.balanceOf(account2.address);
  //     expect(acc2XCNBalance2.sub(acc2XCNBalance1)).to.gte(ethers.utils.parseEther("55"));
  //     expect(acc2XCNBalance2.sub(acc2XCNBalance1)).to.lte(ethers.utils.parseEther("57"));
  //     expect(acc2STRKBalance3.sub(acc2STRKBalance2)).to.eq(ethers.utils.parseEther("100"));

  //     const acc1XCNBalance2 = await XCN.balanceOf(account1.address);
  //     const acc1STRKBalance3 = await STRK.balanceOf(account1.address);
  //     expect(acc1XCNBalance2.sub(acc1XCNBalance1)).to.gte(ethers.utils.parseEther("155"));
  //     expect(acc1XCNBalance2.sub(acc1XCNBalance1)).to.lte(ethers.utils.parseEther("159"));
  //     expect(acc1STRKBalance3.sub(acc1STRKBalance2)).to.eq(ethers.utils.parseEther("100"));
  //   });
  // });
});
