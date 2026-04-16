# PIX Oracle Settlement

**Charli3 Oracles Hackathon 2026 — Track: Real World Settlements**

## What it does

PIX is Brazil's instant payment system — the largest in the world by transaction volume. In 2025, PIX processed over **R$ 30 trillion** (~$5 trillion USD) across 50+ billion transactions, used by 160 million Brazilians daily.

**PIX Oracle Settlement** is an atomic swap on Cardano that bridges PIX payments to ADA. A payer locks ADA in a smart contract, the Charli3 Pull Oracle provides the verified ADA/USD price at the exact moment of settlement, and the contract either releases ADA to the recipient or refunds the sender — no intermediaries, no hidden slippage, fully on-chain.

## Why the Pull Oracle is the right fit

The Pull Oracle fetches data **only when needed** — exactly the model of a PIX settlement. There is no reason to maintain a constant price feed if you only need the price at the exact moment T of the transaction. This reduces costs and guarantees the freshest possible price at settlement time.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   PIX Oracle Settlement                   │
├─────────────────┬───────────────────┬───────────────────┤
│   Frontend      │   ODV Client      │   Settlement       │
│   (Next.js)     │   (Python SDK)    │   Contract         │
│                 │                   │   (Aiken/Plutus)   │
│  • Create order │  • Pull ADA/USD   │  • Validate datum  │
│  • View status  │    from Charli3   │  • Verify NFT      │
│  • History      │  • Fetch USD/BRL  │  • Release funds   │
│  • Live demo    │    from BCB API   │  • Atomic swap     │
└─────────────────┴───────────────────┴───────────────────┘
```

## Stack

- **Smart Contract:** Aiken (Plutus V3)
- **Oracle:** Charli3 Pull Oracle — ODV Client SDK
- **Backend:** FastAPI + PyCardano
- **Frontend:** Next.js + TypeScript
- **Blockchain:** Cardano Preprod
- **Price Feed:** ADA/USD (Charli3) + USD/BRL (Banco Central do Brasil)

## Oracle Integration

Uses Charli3's Pull Oracle (ODV multisig) to fetch ADA/USD price on-demand — exactly when a settlement is needed.

```bash
charli3 feeds --config backend/config.yaml --output backend/feeds.json
# Calculated median: 0.251900
```

## Setup

```bash
git clone https://github.com/bosconfts/pix-oracle-settlement
cd pix-oracle-settlement
cp backend/.env.example backend/.env  # fill in your keys
poetry install
uvicorn backend.main:app --reload
```

## Network

- Cardano **Preprod**
- Oracle policy: `886dcb2363e160c944e63cf544ce6f6265b22ef7c4e2478dd975078e`
