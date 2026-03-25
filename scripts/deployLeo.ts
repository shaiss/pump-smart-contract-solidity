import * as fs from "fs";
import * as path from "path";
import { ethers, network } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  if (!deployer) {
    throw new Error(
      "No deployer: set PRIVATE_KEY in .env for network leo (see .env.example)"
    );
  }
  console.log("Deployer:", deployer.address);

  let routerAddr = process.env.UNISWAP_V2_ROUTER?.trim();
  let wethAddr: string | null = null;

  if (!routerAddr) {
    const Weth = await ethers.getContractFactory("PlaceholderWETH");
    const weth = await Weth.deploy();
    await weth.waitForDeployment();
    wethAddr = await weth.getAddress();

    const Router = await ethers.getContractFactory("MockUniswapV2Router");
    const router = await Router.deploy(wethAddr);
    await router.waitForDeployment();
    routerAddr = await router.getAddress();

    console.log("PlaceholderWETH:", wethAddr);
    console.log("MockUniswapV2Router:", routerAddr);
  } else {
    console.log("Using UNISWAP_V2_ROUTER:", routerAddr);
  }

  const Factory = await ethers.getContractFactory("PumpCloneFactory");
  const factory = await Factory.deploy(routerAddr);
  const deployRc = await factory.deploymentTransaction()?.wait();
  await factory.waitForDeployment();
  const factoryAddr = await factory.getAddress();
  console.log("PumpCloneFactory:", factoryAddr);

  const outDir = path.join(__dirname, "..", "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const deployment = {
    network: network.name,
    chainId: chainId.toString(),
    factory: factoryAddr,
    factoryDeploymentBlock: deployRc?.blockNumber ?? null,
    uniswapV2Router: routerAddr,
    mockWeth: wethAddr,
    deployedAt: new Date().toISOString(),
  };
  const outFile = path.join(outDir, `${network.name}.json`);
  fs.writeFileSync(outFile, JSON.stringify(deployment, null, 2));
  console.log("Wrote", outFile);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
