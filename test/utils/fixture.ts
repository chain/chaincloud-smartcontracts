import { deployContract, Fixture } from "ethereum-waffle";
import web3 from "web3";

import { MockOracle, NodeStakingPool, NodeStakingPoolFactory, Payment } from "./../../typechain/";
import { XCN } from "../../typechain/XCN";
import * as XCNTokenJSON from "../../artifacts/contracts/XCNToken.sol/XCN.json";
import * as NodeStakingFactoryJSON from "../../artifacts/contracts/NodeStakingFactory.sol/NodeStakingPoolFactory.json";
import * as NodeStakingJSON from "../../artifacts/contracts/NodeStaking.sol/NodeStakingPool.json";
import * as PaymentJSON from "../../artifacts/contracts/Payment.sol/Payment.json";
import * as MockOracleJSON from "../../artifacts/contracts/mocks/MockOracle.sol/MockOracle.json";
import * as time from "./time";
import { ethers } from "ethers";

interface IFixture {
  XCN: XCN;
  STRK: XCN;
  USDT: XCN;
  nodeStakingFactory: NodeStakingPoolFactory;
  nodeStaking: NodeStakingPool;
  payment: Payment;
  oracle: MockOracle;
}

const { toWei } = web3.utils;

export const fixture: Fixture<IFixture | any> = async ([wallet, account1, , account2], _) => {
  const USDT = (await deployContract(wallet as any, XCNTokenJSON)) as unknown as XCN;
  const XCN = (await deployContract(wallet as any, XCNTokenJSON)) as unknown as XCN;
  const STRK = (await deployContract(wallet as any, XCNTokenJSON)) as unknown as XCN;
  await XCN.initialize("XCN Token", "XCN", toWei("100000000000000"));
  await STRK.initialize("STRK Token", "STRK", toWei("100000000000000"));
  await USDT.initialize("STRK Token", "STRK", toWei("100000000000000"));

  // mint
  await XCN.mint(wallet.address, toWei("100000000000000"));
  await STRK.mint(wallet.address, toWei("100000000000000"));
  await USDT.mint(wallet.address, toWei("100000000000000"));
  // transfer token
  await XCN.transfer(account1.address, toWei("100000"));
  await XCN.transfer(account2.address, toWei("100000"));
  await STRK.transfer(account1.address, toWei("100000"));
  await STRK.transfer(account2.address, toWei("100000"));
  await USDT.transfer(account1.address, toWei("100000"));
  await USDT.transfer(account2.address, toWei("100000"));

  const nodeStakingFactory = (await deployContract(
    wallet as any,
    NodeStakingFactoryJSON,
  )) as unknown as NodeStakingPoolFactory;

  const nodeStaking = (await deployContract(wallet as any, NodeStakingJSON)) as unknown as NodeStakingPool;

  const startBlock = await time.latestBlock();
  await nodeStaking.initialize(
    "Solana",
    "SOL",
    XCN.address,
    rewardPerBlock,
    requireStakeAmount,
    startBlock,
    STRK.address,
    10,
    10,
    wallet.address,
  );

  const oracle = (await deployContract(wallet as any, MockOracleJSON)) as unknown as MockOracle;
  await oracle.setDecimals(decimals);
  await oracle.setPrice(price);

  const payment = (await deployContract(wallet as any, PaymentJSON)) as unknown as Payment;
  await payment.initialize(wallet.address, XCN.address, USDT.address, oracle.address, oracle.address);

  return {
    STRK,
    XCN,
    USDT,
    oracle,
    payment,
    nodeStaking,
    nodeStakingFactory,
  };
};

export const requireStakeAmount = ethers.utils.parseEther("100");
export const rewardPerBlock = ethers.utils.parseEther("1");
export const price = ethers.utils.parseUnits("10", 8);
export const decimals = 8;
