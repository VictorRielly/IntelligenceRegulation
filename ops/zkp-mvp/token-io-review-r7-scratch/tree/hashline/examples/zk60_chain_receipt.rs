//! PUBLIC synthetic two-block receipt demo. Never use sensitive data.
//! Verification needs independently trusted expected state and four approved
//! weight roots; it does not generate weights, witnesses or proofs.
use hashline::causal_oracle::{
    public_synthetic_fixture, public_synthetic_registration, FixedCausalOracle,
};
use hashline::pcs::Commitment;
use hashline::private_block_contract::ApprovedP1BlockContract;
use hashline::public_chain_receipt::{
    verify_public_chain_bytes, ExpectedPublicChain, PublicChainOracle, EXPECTED_CHAIN_BYTES,
    MAX_CHAIN_BYTES,
};
use std::io::{Read, Write};

fn root(text: &str) -> Result<[u8; 32], String> {
    if text.len() != 64 || !text.bytes().all(|c| c.is_ascii_hexdigit()) {
        return Err("expected root must be 64 hexadecimal characters".into());
    }
    let mut out = [0; 32];
    for (i, x) in out.iter_mut().enumerate() {
        *x = u8::from_str_radix(&text[2 * i..2 * i + 2], 16).map_err(|_| "root")?;
    }
    Ok(out)
}

fn registration(
    layer: usize,
    attention: [u8; 32],
    ffn: [u8; 32],
) -> Result<ApprovedP1BlockContract, String> {
    let mut r = public_synthetic_registration(
        Commitment {
            root: attention,
            rows: 4,
            log_cols: 8,
        },
        Commitment {
            root: ffn,
            rows: 3,
            log_cols: 8,
        },
    );
    r.attention.layer = layer;
    r.ffn.l = layer;
    ApprovedP1BlockContract::from_trusted_registration(r).map_err(|e| e.to_string())
}

fn read_bounded(path: &str, max: usize) -> Result<Vec<u8>, String> {
    let file = std::fs::File::open(path).map_err(|e| format!("open input: {e}"))?;
    let mut out = Vec::new();
    file.take(max as u64 + 1)
        .read_to_end(&mut out)
        .map_err(|e| format!("read input: {e}"))?;
    if out.len() > max {
        return Err("input exceeds public chain bound".into());
    }
    Ok(out)
}

fn save_new(path: &str, bytes: &[u8]) -> Result<(), String> {
    let mut file = std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(path)
        .map_err(|e| format!("create new artifact: {e}"))?;
    file.write_all(bytes)
        .and_then(|_| file.sync_all())
        .map_err(|e| format!("write artifact: {e}"))
}

fn run() -> Result<(), String> {
    if cfg!(feature = "gpu-cuda") || std::env::var_os("HL_GPU").is_some_and(|v| !v.is_empty()) {
        return Err("public demo requires CPU-only build and HL_GPU unset".into());
    }
    let args: Vec<_> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("prepare" | "prove") if (args[1] == "prepare" && args.len() == 3)
            || (args[1] == "prove" && args.len() == 4) => {
            // The synthetic fixture intentionally reuses public weights across
            // two DISTINCT registered layer positions; not a trained model.
            let (first, weights, input) = public_synthetic_fixture();
            let r = first.registration();
            let second = registration(1, r.attention_weights.root, r.ffn_weights.root)?;
            let approved = [first, second];
            if args[1] == "prepare" {
                let mut output = input.clone();
                for contract in &approved {
                    let block = FixedCausalOracle::new(contract, weights.clone())
                        .map_err(|e| e.to_string())?
                        .build(&output)
                        .map_err(|e| e.to_string())?;
                    output = block.residual.xres2.iter().map(|x| i16::try_from(*x))
                        .collect::<Result<_, _>>().map_err(|_| "fixture output range")?;
                }
                let expected = ExpectedPublicChain::new(&approved, [53; 32], &input, &output)?;
                save_new(&args[2], &expected.to_bytes())?;
                println!("{{\"mode\":\"P0-public-synthetic\",\"blocks\":2,\"expected_bytes\":{},\"attention_root_0\":\"{}\",\"ffn_root_0\":\"{}\",\"attention_root_1\":\"{}\",\"ffn_root_1\":\"{}\",\"proving_executed\":false,\"goal_met\":false}}",
                    EXPECTED_CHAIN_BYTES, hashline::silu::hex(&r.attention_weights.root),
                    hashline::silu::hex(&r.ffn_weights.root), hashline::silu::hex(&r.attention_weights.root),
                    hashline::silu::hex(&r.ffn_weights.root));
            } else {
                let expected = ExpectedPublicChain::from_bytes(
                    &approved, &read_bounded(&args[2], EXPECTED_CHAIN_BYTES)?,
                )?;
                let receipt = PublicChainOracle::new(&approved, [weights.clone(), weights])?
                    .prove(&expected)?;
                let bytes = receipt.to_bytes()?;
                verify_public_chain_bytes(&approved, &expected, &bytes)?;
                save_new(&args[3], &bytes)?;
                println!("{{\"coverage\":\"two-fixed-public-blocks-with-external-IO\",\"blocks\":2,\"bytes\":{},\"verified_from_bytes\":true,\"goal_met\":false}}", bytes.len());
            }
            Ok(())
        }
        Some("verify") if args.len() == 8 => {
            // No synthetic_fixture, FixedCausalOracle or prover in this branch.
            // Never recover expected roots from candidate receipt/header bytes.
            let approved = [
                registration(0, root(&args[4])?, root(&args[5])?)?,
                registration(1, root(&args[6])?, root(&args[7])?)?,
            ];
            let expected = ExpectedPublicChain::from_bytes(
                &approved, &read_bounded(&args[2], EXPECTED_CHAIN_BYTES)?,
            )?;
            let bytes = read_bounded(&args[3], MAX_CHAIN_BYTES)?;
            verify_public_chain_bytes(&approved, &expected, &bytes)?;
            println!("{{\"coverage\":\"two-fixed-public-blocks-with-external-IO\",\"blocks\":2,\"verified_from_bytes\":true,\"proving_executed\":false,\"goal_met\":false}}");
            Ok(())
        }
        _ => Err("usage: zk60_chain_receipt prepare NEW_EXPECTED | prove EXPECTED NEW_RECEIPT | verify EXPECTED RECEIPT EXPECTED_AW0 EXPECTED_FW0 EXPECTED_AW1 EXPECTED_FW1".into()),
    }
}

fn main() {
    if let Err(e) = run() {
        eprintln!("PUBLIC CHAIN RECEIPT REJECT: {e}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roots_are_exact_ascii_hex() {
        assert_eq!(root(&"aB".repeat(32)).unwrap(), [171; 32]);
        for text in [
            "a".repeat(63),
            "a".repeat(65),
            "z".repeat(64),
            "é".repeat(32),
        ] {
            assert!(root(&text).is_err());
        }
    }

    #[test]
    fn metadata_registration_pins_layer_and_roots() {
        let a = registration(0, [1; 32], [2; 32]).unwrap();
        let b = registration(1, [3; 32], [4; 32]).unwrap();
        a.preflight_next_boundary(&b).unwrap();
        assert_ne!(a.public_digest(), b.public_digest());
        assert_eq!(b.registration().attention_weights.root, [3; 32]);
        assert_eq!(b.registration().ffn_weights.root, [4; 32]);
        assert!(registration(32, [1; 32], [2; 32]).is_err());
    }
}
