import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "dotenv/config";

const pkRaw = process.env.PRIVATE_KEY?.trim();
function parseDeployerKey(raw: string | undefined): string[] {
  if (!raw) return [];
  const hex = raw.startsWith("0x") ? raw.slice(2) : raw;
  if (!/^[0-9a-fA-F]{64}$/.test(hex)) {
    throw new Error(
      "PRIVATE_KEY in .env must be exactly 64 hex digits (with or without 0x). " +
        "It is not your wallet address. Remove the line to run compile-only."
    );
  }
  return [raw.startsWith("0x") ? raw : `0x${hex}`];
}
const deployerAccounts = parseDeployerKey(pkRaw);

const leoRpc =
  process.env.LEO_RPC_URL ??
  "https://rpc-leo-jqsck8sctd.t.conduit.xyz";

const networkAccounts =
  deployerAccounts.length > 0 ? { accounts: deployerAccounts } : {};

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    monad: {
      url: "https://testnet-rpc.monad.xyz",
      chainId: 10143,
      ...networkAccounts,
    },
    leo: {
      url: leoRpc,
      chainId: 71757,
      ...networkAccounts,
    },
  },
  etherscan: {
    enabled: false,
  },
  sourcify: {
    apiUrl: "https://sourcify-api-monad.blockvision.org",
    browserUrl: "https://testnet.monadexplorer.com",
    enabled: true,
  },
  solidity: {
    version: "0.8.28",
    settings: {
      metadata: {
        bytecodeHash: "none", // disable ipfs
        useLiteralContent: true, // use source code
      }
    },
  },
};
export default config;
