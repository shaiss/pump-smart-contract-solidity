/**
 * Run Hardhat without going through `npm` / `npx`, so bogus env vars like
 * npm_config_metrics_registry do not trigger npm's "Unknown env config" warning.
 */
const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const cwd = path.join(__dirname, "..");
const hhCli = path.join(cwd, "node_modules", "hardhat", "internal", "cli", "cli.js");

if (!fs.existsSync(hhCli)) {
  console.error("Hardhat CLI not found. Run: npm install");
  process.exit(1);
}

const cleanEnv = { ...process.env };
delete cleanEnv.npm_config_metrics_registry;
delete cleanEnv.NPM_CONFIG_METRICS_REGISTRY;

const args = process.argv.slice(2);
const r = spawnSync(process.execPath, [hhCli, ...args], {
  cwd,
  env: cleanEnv,
  stdio: "inherit",
  windowsHide: true,
});

process.exit(r.status === null ? 1 : r.status);
