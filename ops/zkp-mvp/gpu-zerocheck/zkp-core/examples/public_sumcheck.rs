//! A complete terminal check for a tiny public dot-product sumcheck.
//! Primitive example only: no commitment, FFN relation or privacy claim.

use zkp_core::field::Fp2;
use zkp_core::mle::eval_mle_ext;
use zkp_core::sumcheck;
use zkp_core::transcript::Transcript;

fn main() -> Result<(), String> {
    let a: Vec<_> = (1..=8).map(Fp2::from_i64).collect();
    let b: Vec<_> = (9..=16).map(Fp2::from_i64).collect();
    let claim = a.iter().zip(&b).fold(Fp2::ZERO, |s, (x, y)| s.add(x.mul(*y)));
    let mut prover = Transcript::new(b"zkp-core-public-sumcheck-example");
    let output = sumcheck::prove(&mut vec![a.clone(), b.clone()], 2,
        |v| v[0].mul(v[1]), &mut prover);
    let mut verifier = Transcript::new(b"zkp-core-public-sumcheck-example");
    let (terminal, point) = sumcheck::verify(claim, 2, 3, &output.proof, &mut verifier)?;
    if terminal != eval_mle_ext(&a, &point).mul(eval_mle_ext(&b, &point)) {
        return Err("public dot-product terminal mismatch".into());
    }
    assert_eq!(prover.state(), verifier.state());
    let mut corrupt = output.proof.clone();
    corrupt.rounds[0][0] = corrupt.rounds[0][0].add(Fp2::ONE);
    assert!(sumcheck::verify(claim, 2, 3, &corrupt,
        &mut Transcript::new(b"zkp-core-public-sumcheck-example")).is_err());
    println!("public dot-product sumcheck verified; altered round refused (primitive example, no privacy claim)");
    Ok(())
}
