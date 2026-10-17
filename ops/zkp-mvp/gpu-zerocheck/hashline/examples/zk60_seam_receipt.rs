//! Two-process demonstration of a PRIVATE EQUALITY GADGET, not an LLM proof.
//! The fixture values are public synthetic data. Expected roots for `verify`
//! must be supplied independently; roots printed by `create` are not model
//! approval. Output files use create_new and existing files are never replaced.
use hashline::field::Fp;
use hashline::ntt::NttTables;
use hashline::pcs::Commitment;
use hashline::private_seam::{self as seam, ExperimentalSeamProof, SeamSpec, Side};
use std::io::{Read, Write};

fn hex(bytes: &[u8; 32]) -> String {
    bytes.iter().map(|x| format!("{x:02x}")).collect()
}
fn root(text: &str) -> Result<[u8; 32], String> {
    if text.len() != 64 || !text.bytes().all(|c| c.is_ascii_hexdigit()) {
        return Err("expected commitment root must be 64 hex characters".into());
    }
    let mut out = [0; 32];
    for (i, x) in out.iter_mut().enumerate() {
        *x = u8::from_str_radix(&text[i * 2..i * 2 + 2], 16).map_err(|_| "invalid root")?;
    }
    Ok(out)
}
fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    let s = SeamSpec::new([37; 32], 32, 16, -8, 10, 11)?;
    let ntt = NttTables::new(12);
    match args.get(1).map(String::as_str) {
        Some("create") if args.len()==3 => {
            // Reserve output first; never overwrite or spend proving work on a
            // target already occupied by a previous artifact.
            let mut out=std::fs::OpenOptions::new().write(true).create_new(true).open(&args[2])
                .map_err(|e| format!("create receipt: {e}"))?;
            let vals:Vec<Fp>=(0..s.len()).map(|i| Fp::from_i64((i%257) as i64-128)).collect();
            let left=seam::prepare(&s,Side::Left,&vals,&ntt)?;
            let right=seam::prepare(&s,Side::Right,&vals,&ntt)?;
            let l=left.commitment(); let r=right.commitment();
            let p=seam::prove(&s,left,right,&ntt)?;
            seam::verify(&s,&l,&r,&p,&ntt)?;
            let bytes=p.to_bytes(&s)?;
            out.write_all(&bytes).map_err(|e| format!("write receipt: {e}"))?;
            out.sync_all().map_err(|e| format!("flush receipt: {e}"))?;
            println!("{{\"coverage\":\"experimental-equality-only\",\"fixture\":\"public-synthetic\",\"bytes\":{},\"left_root\":\"{}\",\"right_root\":\"{}\",\"goal_met\":false}}",bytes.len(),hex(&l.root),hex(&r.root));
            Ok(())
        }
        Some("verify") if args.len()==5 => {
            let l=Commitment{root:root(&args[3])?,rows:7,log_cols:8};
            let r=Commitment{root:root(&args[4])?,rows:7,log_cols:8};
            let file=std::fs::File::open(&args[2]).map_err(|e| format!("read receipt: {e}"))?;
            let mut bytes=Vec::new();
            file.take(ExperimentalSeamProof::encoded_len(&s) as u64+1)
                .read_to_end(&mut bytes).map_err(|e| format!("read receipt: {e}"))?;
            let p=ExperimentalSeamProof::from_bytes(&s,&bytes)?;
            seam::verify(&s,&l,&r,&p,&ntt)?;
            println!("{{\"coverage\":\"experimental-equality-only\",\"verified_from_bytes\":true,\"goal_met\":false}}");
            Ok(())
        }
        _ => Err("usage: zk60_seam_receipt create NEW_PROOF | verify PROOF EXPECTED_LEFT_ROOT EXPECTED_RIGHT_ROOT".into()),
    }
}
fn main() {
    if let Err(e) = run() {
        eprintln!("EXPERIMENTAL SEAM REJECT: {e}");
        std::process::exit(1);
    }
}
