//! Prints the fixed PUBLIC layout vectors in the same three-line format as
//! `../reference/reference_vectors.py vectors`, so the two independent
//! implementations can be compared byte for byte. Not a verifier.
use zk60_token_statement::{endpoint, model_digest, vector_cases, Hash, Role};

fn hex(h: &Hash) -> String { h.iter().map(|b| format!("{b:02x}")).collect() }

fn main() {
    let (tokens, token, payload) = vector_cases();
    println!("input  {}", hex(&endpoint(Role::Input, &[1; 32], &[2; 32], &[3; 32], &tokens).unwrap()));
    println!("output {}", hex(&endpoint(Role::Output, &[1; 32], &[2; 32], &[4; 32], &[token]).unwrap()));
    println!("model  {}", hex(&model_digest(&payload)));
}
