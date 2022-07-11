import { deployContract, Fixture } from "ethereum-waffle";
import web3 from "web3";

import { NodeStakingPool, NodeStakingPoolFactory } from "./../../typechain/";
import { XCN } from "../../typechain/XCN";
import * as XCNTokenJSON from "../../artifacts/contracts/XCNToken.sol/XCN.json";
import * as NodeStakingFactoryJSON from "../../artifacts/contracts/NodeStakingFactory.sol/NodeStakingPoolFactory.json";
import * as NodeStakingJSON from "../../artifacts/contracts/NodeStaking.sol/NodeStakingPool.json";
import * as time from "./time";

interface IFixture {
  XCN: XCN;
  STRK: XCN;
  nodeStakingFactory: NodeStakingPoolFactory;
  nodeStaking: NodeStakingPool;
}

const { toWei } = web3.utils;

export const fixture: Fixture<IFixture | any> = async ([wallet, account1, , account2], _) => {
  const XCN = (await deployContract(wallet as any, XCNTokenJSON)) as unknown as XCN;
  const STRK = (await deployContract(wallet as any, XCNTokenJSON)) as unknown as XCN;
  await XCN.initialize("XCN Token", "XCN", toWei("100000000000000"));
  await STRK.initialize("STRK Token", "STRK", toWei("100000000000000"));

  // mint
  await XCN.mint(wallet.address, toWei("100000000000000"));
  await STRK.mint(wallet.address, toWei("100000000000000"));
  // transfer token
  await XCN.transfer(account1.address, toWei("100000"));
  await XCN.transfer(account2.address, toWei("100000"));
  await STRK.transfer(account1.address, toWei("100000"));
  await STRK.transfer(account2.address, toWei("100000"));

  const nodeStakingFactory = (await deployContract(
    wallet as any,
    NodeStakingFactoryJSON,
  )) as unknown as NodeStakingPoolFactory;

  const nodeStaking = (await deployContract(wallet as any, NodeStakingJSON)) as unknown as NodeStakingPool;

  const startBlock = await time.latestBlock();
  const endBlock = startBlock.add(1000000000);
  await nodeStaking.initialize(
    "Solana",
    "SOL",
    XCN.address,
    toWei("1"),
    startBlock,
    endBlock,
    STRK.address,
    10,
    10,
    wallet.address,
  );
  await nodeStaking.setRequireStakeAmount(toWei("100"));

  return {
    STRK,
    XCN,
    nodeStaking,
    nodeStakingFactory,
  };
};
