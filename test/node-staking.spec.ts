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
    account2 = wallets[2];
  });

  beforeEach(async () => {
    loadFixture = waffle.createFixtureLoader(wallets as any);
    ({ STRK, XCN, nodeStaking, nodeStakingFactory } = await loadFixture(fixture));
  });

  it("test", async () => {
    await nodeStaking.setRequireStakeAmount(ethers.utils.parseEther("100"));

    // check balance of user 1
    const user1Balance01 = await STRK.balanceOf(account1.address);
    console.log("\x1b[36m%s\x1b[0m", "user1Balance01", user1Balance01.toString(), user1Balance01.toString().length);

    // approve STRK
    await STRK.connect(account1).approve(nodeStaking.address, ethers.utils.parseUnits("100", 35));
    // user1 stake count 1 => take 100
    await nodeStaking.connect(account1).deposit(1);
    // user1 stake again with count = 2 => take 200
    await nodeStaking.connect(account1).deposit(2);

    // enable address for user 1
    await nodeStaking.enableAddress(account1.address);
    await nodeStaking.enableAddress(account1.address);
    await nodeStaking.enableAddress(account1.address);
    // increase to 100 block
    await time.advanceBlockTo(115);

    // check balance of user 1
    const user1Balance02 = await STRK.balanceOf(account1.address);
    console.log("\x1b[36m%s\x1b[0m", "user1Balance02", user1Balance02.toString(), user1Balance02.toString().length);

    // user1 withdraw
    await nodeStaking.connect(account1).withdraw(3, true);
    // check balance of user 1
    const user1Balance03 = await STRK.balanceOf(account1.address);
    console.log("\x1b[36m%s\x1b[0m", "user1Balance03", user1Balance03.toString(), user1Balance03.toString().length);
  });
});
