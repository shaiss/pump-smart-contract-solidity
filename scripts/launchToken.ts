import * as fs from "fs";
import * as path from "path";
import { ethers, network } from "hardhat";
import { argValue, scriptArgv } from "./parseCliArgs";

async function main() {
  const [signer] = await ethers.getSigners();
  if (!signer) {
    throw new Error("No signer: set PRIVATE_KEY in .env");
  }

  const deployPath = path.join(
    __dirname,
    "..",
    "deployments",
    `${network.name}.json`
  );
  if (!fs.existsSync(deployPath)) {
    throw new Error(
      `Missing ${deployPath}. Run: npx hardhat run scripts/deployLeo.ts --network ${network.name}`
    );
  }
  const { factory: factoryAddr } = JSON.parse(
    fs.readFileSync(deployPath, "utf8")
  ) as { factory: string };

  const argv = scriptArgv();
  const name =
    argValue(argv, "--name") ?? process.env.TOKEN_NAME ?? "CLI Token";
  const symbol =
    argValue(argv, "--symbol") ?? process.env.TOKEN_SYMBOL ?? "CLI";
  const initialBuyRaw =
    argValue(argv, "--buy") ?? process.env.INITIAL_BUY_ETH ?? "0";
  const initialBuyEth = String(initialBuyRaw).trim() || "0";
  let value: bigint;
  try {
    value = ethers.parseEther(initialBuyEth);
  } catch {
    throw new Error(
      `Invalid INITIAL_BUY_ETH / --buy "${initialBuyEth}". Use decimal ETH (e.g. 0, 0.01), not wei.`
    );
  }

  const maxAutoEth = ethers.parseEther(
    process.env.MAX_INITIAL_BUY_ETH ?? "10"
  );
  if (value > maxAutoEth && process.env.ALLOW_LARGE_INITIAL_BUY !== "1") {
    throw new Error(
      `Initial buy ${ethers.formatEther(value)} ETH exceeds MAX_INITIAL_BUY_ETH (${ethers.formatEther(maxAutoEth)}). ` +
        `This is usually a typo (e.g. 100 means one hundred ETH). Use 0 to only create the token, or a small value like 0.01. ` +
        `To allow anyway: ALLOW_LARGE_INITIAL_BUY=1`
    );
  }

  const bal = await ethers.provider.getBalance(signer.address);
  if (bal < value) {
    throw new Error(
      `Initial buy needs ${ethers.formatEther(value)} native token but wallet ${signer.address} has ${ethers.formatEther(bal)}. ` +
        `Set INITIAL_BUY_ETH=0 (or --buy 0) to launch without a first purchase, then fund the wallet for smaller buys.`
    );
  }

  const factory = await ethers.getContractAt("PumpCloneFactory", factoryAddr);
  const tx = await factory.launchToken(name, symbol, { value });
  console.log("launchToken tx:", tx.hash);
  const receipt = await tx.wait();
  console.log("confirmed in block", receipt?.blockNumber);

  const launched = receipt?.logs.find((l) => {
    try {
      const parsed = factory.interface.parseLog({
        topics: l.topics as string[],
        data: l.data,
      });
      return parsed?.name === "TokenLaunched";
    } catch {
      return false;
    }
  });
  if (launched) {
    const parsed = factory.interface.parseLog({
      topics: launched.topics as string[],
      data: launched.data,
    });
    console.log("Token address:", parsed?.args.token);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
