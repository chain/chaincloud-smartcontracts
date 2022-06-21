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
    // user1 stake
    await nodeStaking.deposit(1);
    // user1 stake again
    await nodeStaking.deposit(1);
    // increase to 100 block
    await time.advanceBlockTo(100);
    // user1 withdraw
    // user1 get
  });
});
