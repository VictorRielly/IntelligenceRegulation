//! Small paired-mask FFN demonstration. All tensors here are PUBLIC synthetic
//! fixtures; only the proof randomness is secret. This is not a model benchmark.
use hashline::causal_oracle::{public_synthetic_fixture, FixedCausalOracle};
use hashline::layer::StatementV3;
use hashline::zk::{fresh_poc, ZkPrivacy};
use std::io::{Read, Write};

// Public constants only. In particular the verify command never constructs
// weights, calls the oracle, creates commitments or invokes the prover.
fn expected_statement() -> Result<StatementV3, String> {
    use hashline::tables_v3::{int16out_member, Act16Fn};
    let (table, table_digest) =
        int16out_member(Act16Fn::Silu, -3, -11).ok_or("missing public fixture table")?;
    Ok(StatementV3 {
        l: 0,
        t_rows: 32,
        d: 16,
        f: 16,
        shifts: (7, 0, 14, 6),
        act: Act16Fn::Silu,
        table,
        table_digest,
    })
}

fn fixture() -> Result<(hashline::export_v3::V3Witness, [u8; 32]), String> {
    let (approved, weights, input) = public_synthetic_fixture();
    let public_root = approved.registration().ffn_weights.root;
    let block = FixedCausalOracle::new(&approved, weights)
        .map_err(|e| e.to_string())?
        .build(&input)
        .map_err(|e| e.to_string())?;
    Ok((block.ffn, public_root))
}

fn policy(privacy: ZkPrivacy, root: [u8; 32]) -> fresh_poc::WeightStatement {
    match privacy {
        ZkPrivacy::P1 => fresh_poc::WeightStatement::Public(root),
        ZkPrivacy::P3 => fresh_poc::WeightStatement::FreshPrivate,
    }
}

fn privacy(text: &str) -> Result<ZkPrivacy, String> {
    match text {
        "p1" => Ok(ZkPrivacy::P1),
        "p3" => Ok(ZkPrivacy::P3),
        _ => Err("mode must be p1 or p3".into()),
    }
}

fn root(text: &str) -> Result<[u8; 32], String> {
    if text.len() != 64 || !text.bytes().all(|c| c.is_ascii_hexdigit()) {
        return Err("expected public root must be 64 hexadecimal characters".into());
    }
    let mut out = [0; 32];
    for (i, x) in out.iter_mut().enumerate() {
        *x = u8::from_str_radix(&text[2 * i..2 * i + 2], 16).map_err(|_| "root")?;
    }
    Ok(out)
}

fn context(text: &str) -> Result<&[u8], String> {
    if text.len() > fresh_poc::MAX_CONTEXT_BYTES {
        return Err("request context too long".into());
    }
    Ok(text.as_bytes())
}

fn demo() -> Result<(), String> {
    let (w, public_root) = fixture()?;
    let st = expected_statement()?;
    for privacy in [ZkPrivacy::P1, ZkPrivacy::P3] {
        let proof = fresh_poc::prove(&w, privacy, b"synthetic-ffn-demo")?;
        let weights = policy(privacy, public_root);
        let bytes = proof.to_bytes(&st, weights, b"synthetic-ffn-demo")?;
        fresh_poc::verify_bytes(&st, weights, &bytes, b"synthetic-ffn-demo")?;
        println!(
            "paired-mask FFN: {privacy:?}, T32/d16/f16, verified from {} bytes",
            bytes.len()
        );
    }
    println!("Scope: one FFN; fresh private weights have no registered model identity.");
    Ok(())
}

fn run() -> Result<(), String> {
    if cfg!(feature = "gpu-cuda") || std::env::var_os("HL_GPU").is_some_and(|v| !v.is_empty()) {
        return Err("fresh FFN demo requires the default CPU build and HL_GPU unset".into());
    }
    let args: Vec<_> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        None => demo(),
        Some("prepare") if args.len() == 2 => {
            // Run before proving; keep this public root as verifier policy.
            let (approved, _, _) = public_synthetic_fixture();
            println!("{{\"fixture\":\"T32-d16-f16-silu\",\"public_weight_root\":\"{}\",\"proving_executed\":false}}",
                hashline::silu::hex(&approved.registration().ffn_weights.root));
            Ok(())
        }
        Some("prove") if args.len() == 5 => {
            let privacy = privacy(&args[2])?;
            let ctx = context(&args[3])?;
            let mut out = std::fs::OpenOptions::new().write(true).create_new(true).open(&args[4])
                .map_err(|e| format!("create new proof artifact: {e}"))?;
            let (w, public_root) = fixture()?;
            let st = expected_statement()?;
            let weights = policy(privacy, public_root);
            let proof = fresh_poc::prove(&w, privacy, ctx)?;
            let bytes = proof.to_bytes(&st, weights, ctx)?;
            fresh_poc::verify_bytes(&st, weights, &bytes, ctx)?;
            out.write_all(&bytes).and_then(|_| out.sync_all()).map_err(|e| format!("write proof: {e}"))?;
            println!("{{\"mode\":\"{privacy:?}\",\"wire_bytes\":{},\"verified_from_bytes\":true}}", bytes.len());
            Ok(())
        }
        Some("verify") if args.len() == 6 => {
            let privacy = privacy(&args[2])?;
            let weights = match privacy {
                ZkPrivacy::P1 => fresh_poc::WeightStatement::Public(root(&args[3])?),
                ZkPrivacy::P3 if args[3] == "fresh" => fresh_poc::WeightStatement::FreshPrivate,
                ZkPrivacy::P3 => return Err("p3 requires explicit 'fresh' weight policy (no registered model)".into()),
            };
            let ctx = context(&args[4])?;
            let st = expected_statement()?;
            let max = fresh_poc::encoded_len(&st, weights)?;
            let file = std::fs::File::open(&args[5]).map_err(|e| format!("open proof: {e}"))?;
            let mut bytes = Vec::new();
            file.take(max as u64 + 1).read_to_end(&mut bytes).map_err(|e| format!("read proof: {e}"))?;
            fresh_poc::verify_bytes(&st, weights, &bytes, ctx)?;
            println!("{{\"mode\":\"{privacy:?}\",\"wire_bytes\":{},\"verified_from_bytes\":true,\"proving_executed\":false}}", bytes.len());
            Ok(())
        }
        _ => Err("usage: zk60_fresh_ffn [prepare | prove p1|p3 CONTEXT NEW_PROOF | verify p1 EXPECTED_PUBLIC_ROOT CONTEXT PROOF | verify p3 fresh CONTEXT PROOF]".into()),
    }
}

fn main() {
    if let Err(e) = run() {
        eprintln!("{e}");
        std::process::exit(1);
    }
}
