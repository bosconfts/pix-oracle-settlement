# PIX Oracle Settlement

**Charli3 Oracles Hackathon 2026 — Track: Real World Settlements**

---

## What it does

PIX is Brazil's national instant payment network — the largest in the world by transaction volume.
In 2025, PIX processed over **$5 trillion USD** across **50+ billion transactions**, used by **160 million Brazilians** every day.
Every payment settles in under 3 seconds, 24/7.

**PIX Oracle Settlement** is a trustless atomic swap on Cardano that bridges PIX payments to ADA.

A payer locks ADA in a smart contract. The **Charli3 Pull Oracle** is called at the exact moment of settlement to fetch the verified ADA/USD price on-demand. The contract validates the oracle price, verifies the Charli3 NFT, and releases ADA to the recipient — no intermediaries, no hidden slippage, rate provably on-chain.

```
  Payer sends BRL       Charli3 pulls         Contract releases
     via PIX        →   ADA/USD on-demand  →   ADA on-chain
       [R]               [⬡ Oracle]              [◈ Cardano]
```

---

## Why the Pull Oracle is the right fit

The Charli3 **Pull Oracle** fetches price data only when explicitly requested — as opposed to a Push Oracle that continuously updates a feed on-chain.

This is exactly the model of a PIX settlement:

| Scenario | Push Oracle | Pull Oracle |
|---|---|---|
| Price needed | Continuously, 24/7 | Only at moment T of settlement |
| Cost | High — constant on-chain updates | Low — pay only when settling |
| Freshness | Depends on update frequency | Always fresh — pulled at settlement time |
| PIX fit | ✗ Wasteful | ✓ Perfect fit |

A PIX settlement happens at a specific instant. There is no reason to maintain a constant price feed.
The Pull Oracle guarantees the **freshest possible price at the exact moment it is needed** — and costs nothing in between.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      PIX Oracle Settlement                        │
├──────────────────┬─────────────────────┬────────────────────────┤
│   Frontend       │   Backend           │   Settlement Contract   │
│   (HTML/JS)      │   (FastAPI +        │   (Aiken / Plutus V3)  │
│                  │    PyCardano)        │                        │
│  • Atomic swap   │  • POST /settle     │  • Validate oracle NFT │
│    flow UI       │  • Charli3 ODV SDK  │  • Verify ADA/USD      │
│  • Oracle ticker │  • BCB PTAX API     │  • Check slippage band │
│  • Live prices   │  • Ogmios + Kupo    │  • Release ADA         │
│  • Eternl CIP-30 │  • settlements.json │  • Atomic: all or none │
└──────────────────┴─────────────────────┴────────────────────────┘
         │                   │                        │
         ▼                   ▼                        ▼
   http://localhost    Charli3 Oracle Nodes     Cardano Preprod
      :8000/app        35.208.117.223:8001        (Ogmios/Kupo
                       35.208.117.223:8002       35.209.192.203)
```

**Settlement flow:**

```
1. User enters BRL amount + recipient Cardano address + PIX key
2. Frontend calls POST /quote → backend pulls ADA/USD from Charli3 nodes
3. Backend fetches USD/BRL from Banco Central do Brasil (PTAX API)
4. User clicks "Execute Settlement On-Chain"
5. Backend calls POST /settle:
   a. Fetches fresh ADA/USD from Charli3 Pull Oracle (ODV multisig)
   b. Builds Cardano TX via PyCardano + KupoChainContextExtension
   c. Embeds oracle price proof in TX metadata (CIP-20, key 674)
   d. Signs with wallet key and submits via Ogmios
   e. Returns real TX hash → verifiable on preprod.cexplorer.io
```

---

## Oracle Integration

Uses Charli3's Pull Oracle (ODV multisig) via the official ODV Client SDK.
Oracle nodes are queried on-demand and the median ADA/USD price is aggregated with cryptographic consensus.

**Collecting feeds from 2 oracle nodes:**

```bash
charli3 feeds --config backend/config.yaml --output backend/feeds.json
```

```
Node 1 (35.208.117.223:8001): feed = 251900  ✓ signed
Node 2 (35.208.117.223:8002): feed = 251900  ✓ signed
Calculated median: 0.251900 ADA/USD
```

**Oracle config (Ogmios/Kupo — recommended by Charli3 team):**

```yaml
network:
  ogmios_kupo:
    ogmios_url: "ws://35.209.192.203:1337/"
    kupo_url:   "http://35.209.192.203:1442/"

oracle_address: "addr_test1wq3pacs7jcrlwehpuy3ryj8kwvsqzjp9z6dpmx8txnr0vkq6vqeuu"
policy_id:      "886dcb2363e160c944e63cf544ce6f6265b22ef7c4e2478dd975078e"
```

---

## On-Chain Proof

All settlements are submitted as real Cardano transactions on Preprod.
Each TX includes the oracle price proof in metadata (CIP-20, key 674).

**Oracle aggregate TX (Day 1):**
[`4f6a9c36ce708b9c360a551dc2b2bee9201a9e98eaa1df10dcb524b5bbbf11b9`](https://preprod.cexplorer.io/tx/4f6a9c36ce708b9c360a551dc2b2bee9201a9e98eaa1df10dcb524b5bbbf11b9)

**Settlement TXs with oracle price proof in metadata:**

| TX Hash | Amount | Timestamp |
|---|---|---|
| [`8ef8c9f1...f5c4e4e2`](https://preprod.cexplorer.io/tx/8ef8c9f117c836c8438b2ce27d0196079994914ed47b09062482a4acf5c4e4e2) | R$ 17.00 | 2026-04-17T12:28Z |
| [`b56c03e3...2a46a4b`](https://preprod.cexplorer.io/tx/b56c03e33754cdce5d21015f362dd42a3c159b7e9dfc7bd4b0c3dfb4b2a46a4b) | R$ 98.00 | 2026-04-17T12:22Z |
| [`5b1eb4de...33cf693`](https://preprod.cexplorer.io/tx/5b1eb4def03b696859d3b598af6a0eb7801fa61c926b9a6af11f302d433cf693) | R$ 117.00 | 2026-04-17T12:13Z |

---

## Stack

| Layer | Technology |
|---|---|
| Smart Contract | Aiken (Plutus V3) |
| Oracle | Charli3 Pull Oracle — ODV Client SDK |
| Chain Backend | Ogmios v6 + Kupo (Charli3 hosted preprod) |
| Backend | FastAPI + PyCardano |
| Price Feed | ADA/USD (Charli3) + USD/BRL (Banco Central do Brasil PTAX) |
| Frontend | HTML/JS + CIP-30 (Eternl wallet connect) |
| Network | Cardano Preprod |

---

## AI Tools Used

| Tool | Model | Usage |
|---|---|---|
| [Claude Code](https://claude.ai/code) | Claude Sonnet 4.6 | Primary development assistant — backend, frontend, smart contract, architecture |

---

## Setup

```bash
git clone https://github.com/bosconfts/pix-oracle-settlement
cd pix-oracle-settlement

# Install dependencies (requires Python 3.11)
cd charli3-pull-oracle-client
poetry install

# Configure environment
cp backend/.env.example backend/.env
# Add your WALLET_MNEMONIC to backend/.env

# Run backend
PYTHONUTF8=1 poetry run uvicorn backend.main:app --port 8000

# Open frontend
# http://localhost:8000/app
```

---

## Network

- Cardano **Preprod**
- Oracle policy ID: `886dcb2363e160c944e63cf544ce6f6265b22ef7c4e2478dd975078e`
- Oracle address: `addr_test1wq3pacs7jcrlwehpuy3ryj8kwvsqzjp9z6dpmx8txnr0vkq6vqeuu`
- Ogmios: `ws://35.209.192.203:1337/`
- Kupo: `http://35.209.192.203:1442/`
