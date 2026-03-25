import * as fs from "fs";
import * as path from "path";
import { ethers, network } from "hardhat";
import { argValue, scriptArgv } from "./parseCliArgs";

async function main() {
  const argv = scriptArgv();
  const tokenAddr = (
    argValue(argv, "--token") ?? process.env.TOKEN_ADDRESS
  )?.trim();
  const amountWei = (
    argValue(argv, "--amount") ?? process.env.TOKEN_AMOUNT
  )?.trim();
  if (!tokenAddr || !amountWei) {
    throw new Error(
      "Pass --token 0x... --amount <wei> (after --) or set TOKEN_ADDRESS / TOKEN_AMOUNT"
    );
  }

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
    throw new Error(`Missing ${deployPath}. Deploy the factory first.`);
  }
  const { factory: factoryAddr } = JSON.parse(
    fs.readFileSync(deployPath, "utf8")
  ) as { factory: string };

  const token = await ethers.getContractAt("PumpToken", tokenAddr);
  const factory = await ethers.getContractAt("PumpCloneFactory", factoryAddr);

  const bal = await token.balanceOf(signer.address);
  const amt = BigInt(amountWei);
  if (bal < amt) {
    throw new Error(`Insufficient token balance: have ${bal}, need ${amt}`);
  }

  const cur = await token.allowance(signer.address, factoryAddr);
  if (cur < amt) {
    console.log("Approving factory to spend tokens...");
    const approveTx = await token.approve(factoryAddr, amt);
    await approveTx.wait();
  }

  const tx = await factory.sellToken(tokenAddr, amt);
  console.log("sellToken tx:", tx.hash);
  await tx.wait();
  console.log("done");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
