import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment): Promise<void> {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("Payment", {
    from: deployer,
    log: true,
    proxy: {
      proxyContract: "OptimizedTransparentProxy",
      owner: deployer,
      // execute: {
      //   methodName: "initialize",
      //   args: [deployer], // change me
      // },
    },
  });
};

func.tags = ["Payment"];
export default func;
