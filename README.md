# 💊 PumpFun EVM Smart Contract

## This fork (Conduit / OP Stack L3)

This repo is a **derivative of** [vvizardev/pump-smart-contract-solidity](https://github.com/vvizardev/pump-smart-contract-solidity), extended for **Conduit‑hosted rollups** (tested on **Leo**: OP Stack, chain ID **71757**, Base settlement). It adds:

- Hardhat **`leo`** network + optional **mock Uniswap V2 router** deploy when no router is set  
- **`scripts/run-hardhat.cjs`** — run Hardhat without `npx` (avoids npm env‑var noise on Windows)  
- **`scripts/pump-cli.ps1`** / **`pump-cli.sh`** — [gum](https://github.com/charmbracelet/gum) menu, `.env` defaults, **4‑char symbol from name**, list → **`gum table --print`**  
- **`deployments/*.json`** + **`listTokens` / `launchToken` / `sellToken`** quality‑of‑life  

See **NOTICE** and **LICENSE** for attribution. **Not audited** — testnet / prototyping only.

### This fork on GitHub

**https://github.com/shaiss/pump-smart-contract-solidity**

`origin` → that repo; `upstream` → [vvizardev/pump-smart-contract-solidity](https://github.com/vvizardev/pump-smart-contract-solidity). The clone was **shallow** at first; run `git fetch --unshallow upstream` before pushing if you see remote unpack errors.

- Confirm secrets stay out of git: `git ls-files .env` should print nothing.  
- Sync from upstream: `git fetch upstream` then merge or rebase as you prefer.

---

The **Pump.fun EVM Smart Contract** brings the power of viral, one-click token creation to the **EVM-Compatible blockchain**, mirroring the simplicity and virality of the original **Pump.fun** on Solana. The upstream project targets **Monad testnet**; this fork additionally documents **Conduit Leo** below.

---

## ✨ Key Features

- **Token Creation**  
  Instantly create customizable tokens (name, symbol, total supply) on Monad.

- **Bonding Curve Pricing**  
  Implements a linear bonding curve for fair price discovery, rewarding early buyers.

- **Auto Liquidity Management**  
  Seamlessly manage buys/sells using an embedded bonding curve—no AMM setup required.

- **🔄 Uniswap Migration**  
  Once the liquidity threshold is hit, migrate liquidity to **Uniswap V2/V3** for open DeFi trading.

- **Full Onchain Execution**  
  All logic is executed onchain—including minting, pricing, and migration—for maximum transparency and decentralization.

- **EVM-Compatible**  
  Written in **Solidity**, deployed on Monad, and fully interoperable with Ethereum tooling like **Hardhat**, **Foundry**, and **MetaMask**.

---

## 🚀 Latest Enhancements

### 🔄 Uniswap Liquidity Migration  
After sufficient buy-in volume is reached, token liquidity is automatically migrated to a Uniswap pool—allowing users to continue trading in the open market with real-time pricing and increased exposure.

### ✅ Token Authority Options  
Smart contract logic supports optional authority revocation or time-bound admin permissions, ensuring flexibility in launch strategy (community-led or project-driven).

### 📊 Real-Time Metrics (Coming Soon)  
Planned dashboard support for token metrics, price charts, migration status, and market depth.

---

## 🧠 Technical Stack

- **Smart Contract Language:** Solidity  
- **Blockchain:** Monad (Testnet)  
- **DEX Integration:** Uniswap V2/V3  
- **Bundling Tools:** Jito-style bundling, MEV-optimized TX batching (optional)  
- **Dev Tools:** Hardhat, Foundry, Ethers.js

---

## 💻 Proof of Work

[Contract Address](https://testnet.monadexplorer.com/address/0x802Bbb3924BEE46831cadD23e9CfA9e74B499Efb)
- [Launch Token](https://testnet.monadexplorer.com/tx/0x44ce82f48eabc5e5f1be7bfb6414d380071a4993cd458b191d571568bb2c3190)
- [Buy Tx](https://testnet.monadexplorer.com/tx/0xaf91c0e9254248b27310652da1c1bdfbf7a40d88cf7c72b0fabbd76ce24ec160)
- [Sell Tx](https://testnet.monadexplorer.com/tx/0x3058ceca20593a1acff0e4c3534a92243ff554dc951f40e61a87476b75c29e9d)
- [Buy & Migration to Uniswap](https://testnet.monadexplorer.com/tx/0x1dd9da4ec6acab116cc2b4a24c97ff5e6a93a0fe5ce0c8413436a0489243cad2)

## Conduit Leo (OP Stack testnet)

This fork adds a **`leo` Hardhat network** (chain ID **71757**, default RPC from the Conduit dashboard). There is **no frontend** in this repo; use the **Pump CLI** (optional [gum](https://github.com/charmbracelet/gum) menus), npm scripts, or `cast`.

### Pump CLI (menu or flags)

Install **gum**: `winget install charmbracelet.gum` (Windows) or see [charmbracelet/gum](https://github.com/charmbracelet/gum).

From the project root (`pump-smart-contract-solidity`):

| Action | Command |
|--------|---------|
| Interactive menu | `npm run pump` (PowerShell) or `npm run pump:sh` / `./scripts/pump-cli.sh` (bash) |
| Deploy factory | `.\scripts\pump-cli.ps1 deploy` |
| Launch (flags) | `.\scripts\pump-cli.ps1 launch -Name "Meme" -Symbol MEME -BuyEth 0.01` |
| List tokens | `.\scripts\pump-cli.ps1 list` (pipes CSV through [`gum table`](https://github.com/charmbracelet/gum)) or `npm run list:leo` (pretty text in terminal) |
| Sell | `.\scripts\pump-cli.ps1 sell -Token 0x... -AmountWei 1000000000000000000` |
| Other network | `.\scripts\pump-cli.ps1 -Network monad list` |

**Hardhat passthrough** (no gum): arguments after `--` go to the script:

```bash
node scripts/run-hardhat.cjs run scripts/launchToken.ts --network leo -- --name "Meme" --symbol MEME --buy 0
node scripts/run-hardhat.cjs run scripts/sellToken.ts --network leo -- --token 0x... --amount 1000000000000000000
```

Scripts use `node scripts/run-hardhat.cjs` instead of `npx hardhat` so npm does not warn about stray env vars (e.g. `npm_config_metrics_registry`).

**List tokens** reads `TokenLaunched` logs from the factory (from `factoryDeploymentBlock` in `deployments/<network>.json`; redeploy if that field is missing and the chain is large). Set `PUMP_LIST_FORMAT=csv` for machine-readable rows (used by the Pump CLI for `gum table`).

---

1. Copy `.env.example` → `.env` and set `PRIVATE_KEY` (funded on Leo).
2. Deploy factory (uses a **mock Uniswap V2 router** unless you set `UNISWAP_V2_ROUTER`):

   ```bash
   npm run deploy:leo
   ```

3. Launch a token (optional first buy in ETH):

   PowerShell / cmd:

   ```bash
   set TOKEN_NAME=MyCoin
   set TOKEN_SYMBOL=COIN
   set INITIAL_BUY_ETH=0.01
   npm run launch:leo
   ```

   bash:

   ```bash
   export TOKEN_NAME=MyCoin TOKEN_SYMBOL=COIN INITIAL_BUY_ETH=0.01
   npm run launch:leo
   ```

4. Sell back to the curve (set `TOKEN_ADDRESS` from launch logs; `TOKEN_AMOUNT` in wei):

   ```bash
   set TOKEN_ADDRESS=0x...
   set TOKEN_AMOUNT=1000000000000000000
   npm run sell:leo
   ```

**`cast` (Foundry)** against `deployments/leo.json` → `factory`:

```bash
cast send <FACTORY> "launchToken(string,string)" "Name" "SYM" --value 0ether --rpc-url https://rpc-leo-jqsck8sctd.t.conduit.xyz --chain 71757 --private-key $PRIVATE_KEY
```

Use the ABI at `artifacts/contracts/PumpFactory.sol/PumpCloneFactory.json` for other calls.

**Contract caveat:** `PumpCloneFactory` in this repository has **no separate “buy” function** after launch—only `launchToken` (with optional ETH in the same tx) and `sellToken`. Uniswap migration is described in the README but **not implemented** in the Solidity here. This is still enough to prototype deploy + launch + sell on your rollup.

## ⚠️ Notes

- Currently deployed on **Monad Testnet**. Awaiting Monad mainnet release for production launch.
- Bonding curve mechanics mirror Solana Pump.fun’s pricing structure.
- Liquidity migration requires minimum bonding curve volume (configurable via contract params).

---

## 🤝 Credits

- **Upstream EVM repo:** [vvizardev/pump-smart-contract-solidity](https://github.com/vvizardev/pump-smart-contract-solidity)  
- **Original Solana inspiration:** [Pump.fun Solana Smart Contract](https://github.com/vvizardev/Pump.fun-Smart-Contract)  

---

## 📬 Contributing

Issues and PRs are welcome on **this fork**. Upstream also accepts contributions on the [original Monad‑focused repository](https://github.com/vvizardev/pump-smart-contract-solidity).

---

## 📩 Contact  
For inquiries, custom integrations, or tailored solutions, reach out via:  

💬 **Telegram**: [@vvizardev](https://t.me/vvizardev)