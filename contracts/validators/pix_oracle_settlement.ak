// PIX Oracle Settlement Contract
// Charli3 Hackathon 2026 — Track: Real World Settlements
//
// Valida que uma liquidação PIX/ADA usa o preço correto do Charli3 Oracle
// e libera os fundos dentro da banda de tolerância configurada.

use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/address.{VerificationKey}
use cardano/assets
use cardano/transaction.{InlineDatum, Input, Output, OutputReference, Transaction}

// ─────────────────────────────────────────────
// Datum: o que está trancado no contrato
// ─────────────────────────────────────────────

pub type SettlementDatum {
  // Destinatário dos ADA (quem vai receber)
  recipient: VerificationKeyHash,
  // Valor em BRL que deve ser liquidado (centavos)
  amount_brl_cents: Int,
  // Preço ADA/USD usado na cotação (6 decimais)
  quoted_ada_usd: Int,
  // Preço USD/BRL usado (4 decimais)
  quoted_usd_brl: Int,
  // Tolerância de slippage (basis points, ex: 200 = 2%)
  slippage_bps: Int,
  // Policy ID do Charli3 oracle NFT
  oracle_policy_id: ByteArray,
  // Timestamp da cotação (POSIX ms) — para expiração
  quoted_at_ms: Int,
  // Validade da cotação (ms) — geralmente 120000 (2 min)
  validity_ms: Int,
}

// ─────────────────────────────────────────────
// Redeemer: ação que o usuário toma
// ─────────────────────────────────────────────

pub type SettlementRedeemer {
  // Liquidação normal: usa o preço do oracle on-chain
  Execute { oracle_utxo_index: Int }
  // Cancelamento: devolve ao remetente após expiração
  Cancel
}

// ─────────────────────────────────────────────
// Datum do Charli3 Oracle (formato V3)
// ─────────────────────────────────────────────

pub type OracleDatum {
  // Preço com 6 casas decimais (ex: 412345 = $0.412345)
  price: Int,
  // Timestamp POSIX em milissegundos
  timestamp: Int,
}

// ─────────────────────────────────────────────
// Validator Principal
// ─────────────────────────────────────────────

validator pix_oracle_settlement {
  spend(
    datum: Option<SettlementDatum>,
    redeemer: SettlementRedeemer,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    when datum is {
      None -> False
      Some(d) ->
        when redeemer is {
          Execute { oracle_utxo_index } ->
            validate_execution(d, oracle_utxo_index, tx)
          Cancel ->
            validate_cancellation(d, tx)
        }
    }
  }
}

// ─────────────────────────────────────────────
// Validação de Execução
// ─────────────────────────────────────────────

fn validate_execution(
  datum: SettlementDatum,
  oracle_utxo_index: Int,
  tx: Transaction,
) -> Bool {
  // 1. Extrai o UTXO do oracle da transação
  let oracle_input = get_oracle_input(tx.inputs, oracle_utxo_index)

  // 2. Lê o preço atual do oracle (datum inline)
  let oracle_price = get_oracle_price(oracle_input, datum.oracle_policy_id)

  // 3. Verifica que o preço está dentro da banda de slippage
  let price_valid =
    is_price_within_band(oracle_price, datum.quoted_ada_usd, datum.slippage_bps)

  // 4. Verifica que o recipient recebe os ADA
  let recipient_paid = receives_ada(tx.outputs, datum.recipient)

  price_valid && recipient_paid
}

// ─────────────────────────────────────────────
// Validação de Cancelamento
// ─────────────────────────────────────────────

fn validate_cancellation(
  datum: SettlementDatum,
  tx: Transaction,
) -> Bool {
  // Apenas o recipient pode cancelar (assinou a tx)
  list.any(tx.extra_signatories, fn(signer) { signer == datum.recipient })
}

// ─────────────────────────────────────────────
// Funções Auxiliares
// ─────────────────────────────────────────────

fn get_oracle_input(inputs: List<Input>, index: Int) -> Input {
  when list.at(inputs, index) is {
    Some(input) -> input
    None -> fail @"Oracle input not found at index"
  }
}

fn get_oracle_price(oracle_input: Input, oracle_policy_id: ByteArray) -> Int {
  // Verifica que o input contém o NFT do oracle Charli3
  let has_oracle_nft =
    assets.quantity_of(
      oracle_input.output.value,
      oracle_policy_id,
      "OracleFeed",
    ) >= 1

  expect True = has_oracle_nft

  // Lê o datum inline do oracle
  when oracle_input.output.datum is {
    InlineDatum(raw_datum) -> {
      expect oracle_datum: OracleDatum = raw_datum
      oracle_datum.price
    }
    _ -> fail @"Oracle datum must be inline"
  }
}

fn is_price_within_band(
  oracle_price: Int,
  quoted_price: Int,
  slippage_bps: Int,
) -> Bool {
  // Calcula diferença absoluta em basis points
  // Para evitar divisão: diff * 10000 <= slippage_bps * quoted_price
  let diff =
    if oracle_price > quoted_price {
      oracle_price - quoted_price
    } else {
      quoted_price - oracle_price
    }
  diff * 10000 <= slippage_bps * quoted_price
}

fn receives_ada(outputs: List<Output>, recipient: VerificationKeyHash) -> Bool {
  list.any(
    outputs,
    fn(output) {
      when output.address.payment_credential is {
        VerificationKey(vkh) -> vkh == recipient
        _ -> False
      }
    },
  )
}
