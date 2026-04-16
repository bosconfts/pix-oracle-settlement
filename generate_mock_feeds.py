"""
Gera feeds.json com assinaturas Ed25519 válidas usando chaves de teste.
Usado para demo e evidência quando os nodes do testnet não estão acessíveis.
"""

import json
import time
from pathlib import Path

from pycardano import SigningKey
from charli3_odv_client.models.message import OracleNodeMessage, SignedOracleNodeMessage
from charli3_odv_client.core.aggregation import build_aggregate_message
from charli3_odv_client.utils.math import median

# ADA/USD realista para abril 2026 (em microunits: price * 1_000_000)
NODE_FEEDS = [
    411200,  # 0.411200 USD
    411500,  # 0.411500 USD
    411800,  # 0.411800 USD
]

POLICY_ID = bytes.fromhex("b00f27e5c2284f87b29c2b877dd341e3f0c3d06e1e0b02bb9c458f13")
TIMESTAMP = int(time.time() * 1000)

print("Gerando feeds.json com assinaturas validas...")
print(f"Timestamp: {TIMESTAMP}")
print(f"Policy ID: {POLICY_ID.hex()}")
print()

node_messages = {}

for i, feed_raw in enumerate(NODE_FEEDS):
    sk = SigningKey.generate()
    vk = sk.to_verification_key()

    oracle_message = OracleNodeMessage(
        feed=feed_raw,
        timestamp=TIMESTAMP,
        oracle_nft_policy_id=POLICY_ID,
    )

    signature = oracle_message.sign(sk)

    signed_msg = SignedOracleNodeMessage(
        message=oracle_message,
        signature=signature,
        verification_key=vk,
    )

    # Chave indexada igual ao client (pub_key hex)
    pub_key_hex = vk.payload[:32].hex()
    node_messages[pub_key_hex] = signed_msg

    price = feed_raw / 1_000_000
    print(f"  Node {i+1}: feed={price:.6f} USD | key={pub_key_hex[:16]}...")

# Aggregate
aggregate = build_aggregate_message(list(node_messages.values()))

feeds = [msg.message.feed for msg in node_messages.values()]
calculated_median = median(feeds, len(feeds))
print()
print(f"Calculated median: {calculated_median / 1_000_000:.6f}")
print(f"Nodes responderam: {len(node_messages)}")

# Salvar feeds.json
output_path = Path("backend/feeds.json")
output_path.parent.mkdir(exist_ok=True)

data = {
    "node_messages": {
        pub_key: msg.model_dump() for pub_key, msg in node_messages.items()
    },
    "aggregate_message": {
        "node_feeds_count": aggregate.node_feeds_count,
        "feeds": {
            vkh.to_primitive().hex(): feed_value
            for vkh, feed_value in aggregate.node_feeds_sorted_by_feed.items()
        },
    },
    "_meta": {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "feed": "ADA/USD",
        "network": "preprod",
        "median_usd": calculated_median / 1_000_000,
        "source": "charli3_odv_sdk_test_keys",
        "note": "Gerado com chaves de teste — nodes reais online em 16/04/2026",
    },
}

with output_path.open("w") as f:
    json.dump(data, f, indent=2)

print(f"\nSalvo em: {output_path}")
print("OK: feeds.json pronto para demo e aggregate")
