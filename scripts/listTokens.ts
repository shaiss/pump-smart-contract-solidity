import * as fs from "fs";
import * as path from "path";
import { ethers, network } from "hardhat";

type Deployment = {
  factory: string;
  factoryDeploymentBlock?: number | null;
};

function csvCell(s: string): string {
  const t = String(s);
  if (/[",\n\r]/.test(t)) return `"${t.replace(/"/g, '""')}"`;
  return t;
}

function shortAddr(addr: string, head = 8, tail = 6): string {
  if (!addr || addr.length < head + tail + 2) return addr;
  return `${addr.slice(0, head + 2)}…${addr.slice(-tail)}`;
}

async function main() {
  const fmt = (process.env.PUMP_LIST_FORMAT ?? "pretty").toLowerCase();

  const deployPath = path.join(
    __dirname,
    "..",
    "deployments",
    `${network.name}.json`
  );
  if (!fs.existsSync(deployPath)) {
    throw new Error(
      `Missing ${deployPath}. Deploy the factory first (deploy menu / deploy:leo).`
    );
  }
  const dep = JSON.parse(fs.readFileSync(deployPath, "utf8")) as Deployment;
  const fromBlock = dep.factoryDeploymentBlock ?? 0;

  const factory = await ethers.getContractAt("PumpCloneFactory", dep.factory);
  const filter = factory.filters.TokenLaunched();
  const logs = await factory.queryFilter(filter, fromBlock);

  const rows: { token: string; name: string; symbol: string; creator: string }[] =
    [];

  for (const log of logs) {
    let parsed;
    try {
      parsed = factory.interface.parseLog({
        topics: log.topics as string[],
        data: log.data,
      });
    } catch {
      continue;
    }
    if (parsed.name !== "TokenLaunched") continue;
    const { token, name, symbol, creator } = parsed.args;
    rows.push({
      token: String(token),
      name: String(name),
      symbol: String(symbol),
      creator: String(creator),
    });
  }

  if (rows.length === 0) {
    if (fmt === "csv") {
      console.log("token,name,symbol,creator");
    } else {
      console.log("No TokenLaunched events found for this factory.");
    }
    return;
  }

  if (fmt === "csv") {
    console.log("token,name,symbol,creator");
    for (const r of rows) {
      console.log(
        [r.token, r.name, r.symbol, r.creator].map(csvCell).join(",")
      );
    }
    return;
  }

  // pretty (default): compact summary + aligned columns
  const wTok = 44;
  const wName = 22;
  const wSym = 10;
  const bar = "─".repeat(80);
  console.log("");
  console.log(
    `  Network  ${network.name}    Factory  ${shortAddr(dep.factory, 10, 8)}    ${rows.length} token(s)`
  );
  console.log(`  ${bar}`);
  console.log(
    `  ${"Token".padEnd(wTok)} ${"Name".padEnd(wName)} ${"Symbol".padEnd(wSym)} Creator`
  );
  console.log(`  ${bar}`);
  for (const r of rows) {
    const name =
      r.name.length > wName ? r.name.slice(0, wName - 1) + "…" : r.name;
    const sym =
      r.symbol.length > wSym
        ? r.symbol.slice(0, wSym - 1) + "…"
        : r.symbol;
    console.log(
      `  ${r.token.padEnd(wTok)} ${name.padEnd(wName)} ${sym.padEnd(wSym)} ${shortAddr(r.creator)}`
    );
  }
  console.log(`  ${bar}`);
  console.log("");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
