//! Exports the SYNTHETIC-ONLY public token model of `private-model-kernel`
//! (`synthetic_raw_model()`) in the `Z60TOK01` format. The words are
//! deterministic LCG/integer-formula data: not trained, not approved, and
//! their noncanonical RoPE/exp/activation test tables are NOT a registered
//! calibration. Never overwrites its output.
use private_model_kernel::synthetic::{synthetic_raw_model, SYNTHETIC_LABEL};
use std::{fs::OpenOptions, io::Write};
use zk60_token_model::{encode_raw, Model, MODEL_BYTES};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 2 {
        eprintln!("usage: zk60_token_synthetic_model NEW_OUTPUT_MODEL_BIN");
        std::process::exit(1);
    }
    let bytes = encode_raw(&synthetic_raw_model());
    let model = Model::decode(&bytes).expect("synthetic model must be canonical");
    let mut f = OpenOptions::new().write(true).create_new(true).open(&args[1])
        .expect("output must be a new file");
    f.write_all(&bytes).and_then(|_| f.sync_all()).expect("write failed");
    let digest: String = model.digest.iter().map(|b| format!("{b:02x}")).collect();
    println!("{{\"synthetic\":true,\"label\":\"{SYNTHETIC_LABEL}\",\"format\":\"Z60TOK01\",\"model_bytes\":{MODEL_BYTES},\"model_digest\":\"{digest}\",\"registered_calibration\":false,\"model_approved\":false}}");
}
