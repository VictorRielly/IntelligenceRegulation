//! Small paired-mask FFN demonstration. All tensors here are PUBLIC synthetic
//! fixtures; only the proof randomness is secret. This is not a model benchmark.
use hashline::causal_oracle::{public_synthetic_fixture, FixedCausalOracle};
use hashline::layer::StatementV3;
use hashline::zk::{fresh_poc, ZkPrivacy};

fn run() -> Result<(), String> {
    if cfg!(feature = "gpu-cuda") {
        return Err("run this demonstration with the default CPU build".into());
    }
    let (approved, weights, input) = public_synthetic_fixture();
    // The public root comes from the trusted fixture BEFORE any proof exists.
    let public_root = approved.registration().ffn_weights.root;
    let block = FixedCausalOracle::new(&approved, weights)
        .map_err(|e| e.to_string())?
        .build(&input)
        .map_err(|e| e.to_string())?;
    let w = block.ffn;
    let st = StatementV3 {
        l: w.l,
        t_rows: w.t_rows,
        d: w.dims.d,
        f: w.dims.f,
        shifts: w.shifts,
        act: w.act,
        table: w.table,
        table_digest: w.table_digest.clone(),
    };
    for privacy in [ZkPrivacy::P1, ZkPrivacy::P3] {
        let proof = fresh_poc::prove(&w, privacy, b"synthetic-ffn-demo")?;
        let weights = match privacy {
            ZkPrivacy::P1 => fresh_poc::WeightStatement::Public(public_root),
            ZkPrivacy::P3 => fresh_poc::WeightStatement::FreshPrivate,
        };
        fresh_poc::verify(&st, weights, &proof, b"synthetic-ffn-demo")?;
        println!(
            "paired-mask FFN: {privacy:?}, T32/d16/f16, verified, {} payload bytes",
            proof.payload_size()
        );
    }
    println!("Scope: one FFN; typed verification; fresh private weights have no registered model identity.");
    Ok(())
}

fn main() {
    if let Err(e) = run() {
        eprintln!("{e}");
        std::process::exit(1);
    }
}
