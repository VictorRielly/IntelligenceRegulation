//! Public parameter calculator, using the installed upstream formulas directly.
//! No witness, receipt, prover, transcript or logging of private execution.
use risc0_zkp::{
    adapter::TapsProvider,
    field::baby_bear::BabyBear,
    hal::cpu::CpuHal,
    prove::soundness,
};

fn main() {
    let rv = risc0_circuit_rv32im::CircuitImpl;
    let recursion = risc0_circuit_recursion::CircuitImpl::new();
    let mut records = Vec::new();
    for (name, taps) in [("rv32im-v4.0.5", rv.get_taps()), ("recursion-v4.0.5", recursion.get_taps())] {
        for po2 in 14..=20 {
            // prover.rs allocates final_poly_coeffs = cycles * extension degree.
            let coefficients = (1usize << po2) * 4;
            records.push(serde_json::json!({
                "circuit":name,"trace_po2":po2,"extension_degree":4,
                "conjectured_security_bits":soundness::toy_model_security::<CpuHal<BabyBear>>(taps,coefficients),
                "proven_list_decoding_bits":soundness::proven::<CpuHal<BabyBear>>(taps,coefficients),
            }));
        }
    }
    println!("{}", serde_json::to_string_pretty(&serde_json::json!({
        "risc0_zkp":"3.0.5","upstream_calculator":"src/prove/soundness.rs",
        "kind":"public parameter calculation, not captured prover telemetry",
        "whole_proof_security_bound":false,"records":records
    })).unwrap());
}
