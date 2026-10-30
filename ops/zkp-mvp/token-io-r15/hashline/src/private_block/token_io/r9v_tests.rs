//! **TOKEN I/O ROUND 9: WHAT THE VERIFIER DOES WITH A RUN THE OLD PROVER
//! FINISHED** (the coordinator's question on t34, 2026-10-20 ~01:15 UTC).
//! TEST CODE ONLY, public synthetic data.
//!
//! t34 showed that the round-8 prover path does NOT refuse two inadmissible
//! witnesses at all: a stage-IN lookup miss (`B_in` row 1, word 3, is not
//! `E[tok_1]`: t34's exact witness, nothing downstream re-derived) and an
//! input token endpoint sealed over another prompt (the stage-IN witness
//! honest). Refusal TIMING (ruling H-1) is the prover's matter; SOUNDNESS is
//! the verifier's. Each case here runs the prover WITHOUT the round-9
//! sealing check, lets it finish if it can, and verifies what it produced:
//!
//! * the PLAIN prover: on a build without the sealing pass this IS the
//!   round-8 path; on a build with it, the sealing pass refuses (printed);
//! * the CHEATING prover (`protocol::CheatingProver`: none of the honest
//!   prover's refusals, the sealing pass included): on any build, the round-8
//!   path without the new check.
//!
//! The verifier must REJECT every run that reaches it, at the site the design
//! predicts (asserted; the verifier's error is printed, naming the failing
//! check). A prover that stops says where. Nothing here may verify, and each
//! case must reach the verifier at least once. Also covered: t34's output
//! endpoint case (another token sealed, stage OUT honest) and the CONSISTENT
//! stage-IN forger (everything downstream re-derived from the forged `B_in`,
//! as R1 control #16b).

use super::run::*;
use super::tests::*;
use super::*;
use super::super::protocol::CheatingProver;
use crate::field::Fp;

const POLICY: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 93 };

/// how one prover path ended
enum Ended {
    /// the prover refused (its message)
    ProverStopped(String),
    /// the prover finished and the verifier rejected (its message)
    VerifierRejected(String),
}

/// seal the endpoints over `in_plane` / `out_plane` (the pipeline's unless
/// given), prove with the plain or the cheating prover, and verify what a
/// finished prover produced. PANICS if such a run verifies.
fn run_then_verify(fx: &Fx, tp: &TokenProfile, mut pipe: HonestPipeline, in_plane: Option<Vec<Fp>>, out_plane: Option<Vec<Fp>>, cheat: bool) -> Ended {
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), tp).unwrap();
    let ip = in_plane.unwrap_or_else(|| pipe.in_plane.clone());
    let op = out_plane.unwrap_or_else(|| pipe.out_plane.clone());
    let (roots, owners) = seal_endpoints(&ins, &outs, &ip, &op, &fx.sh.hash_tag()).unwrap();
    let st = statement(fx, roots, tp.variant).unwrap();
    let mut segs: Vec<Vec<u8>> = Vec::new();
    let proved = {
        let _cheat = if cheat { Some(CheatingProver::on()) } else { None };
        prove_token_run(&st, &fx.blocks, &fx.tables, &mut PipelineSource(&mut pipe), owners, &mut |_, b| {
            segs.push(b);
            Ok(())
        })
        .map(|_| ())
    };
    match proved {
        Err(e) => Ended::ProverStopped(e),
        Ok(()) => match verify_token_run(&st, &fx.blocks, &fx.tables, &segs, POLICY) {
            Ok(()) => panic!("ROUND 9 SOUNDNESS: A RUN FROM A PROVER WITHOUT THE SEALING CHECK VERIFIED ({} prover, {} segments)", if cheat { "cheating" } else { "plain" }, segs.len()),
            Err(e) => Ended::VerifierRejected(e),
        },
    }
}

fn short(e: &str) -> String {
    e.chars().take(240).collect()
}

/// both prover paths on a fresh copy of the case; every run that reaches the
/// verifier is rejected at a predicted site; at least one reaches it
fn case(n: &str, what: &str, predicted: &[Site], fx: &Fx, tp: &TokenProfile, make: &dyn Fn() -> (HonestPipeline, Option<Vec<Fp>>, Option<Vec<Fp>>)) {
    let mut reached = 0usize;
    for cheat in [false, true] {
        let who = if cheat { "cheating prover (no sealing check)" } else { "plain prover" };
        let (pipe, ip, op) = make();
        match run_then_verify(fx, tp, pipe, ip, op, cheat) {
            Ended::ProverStopped(e) => {
                eprintln!("TOKEN-IO ROUND 9 VERIFIER | {n} {what} | {who}: STOPPED before finishing: {}", short(&e));
            }
            Ended::VerifierRejected(e) => {
                reached += 1;
                let hit = predicted.iter().any(|s| s.matches(&e));
                eprintln!(
                    "TOKEN-IO ROUND 9 VERIFIER | {n} {what} | {who}: FINISHED; verify REJECTED | predicted {predicted:?} | {} | {}",
                    if hit { "AS PREDICTED" } else { "NOT AS PREDICTED" },
                    short(&e)
                );
                assert!(hit, "{n} ({what}, {who}): the verifier rejected elsewhere than predicted {predicted:?}: {e}");
            }
        }
    }
    assert!(reached >= 1, "{n} ({what}): no prover path finished, so the verifier was never exercised");
}

/// **t34's stage-IN case, exactly** (B_in row 1 word 3 + 1; the blocks, B_out
/// and stage OUT left as the honest pipeline made them): the verifier must
/// reject at stage IN's LogUp (the embedding lookup). And the consistent
/// forger (everything downstream re-derived from that B_in): the same site.
#[test]
fn r9v_a_stage_in_lookup_miss_that_a_prover_finishes_is_rejected_by_the_verifier() {
    let fx = fx_generic();
    let tp = profile(&fx);
    case("V1", "t34's stage-IN lookup miss (B_in row 1 is not E[tok_1]; downstream as honest)", &[Site::InLogUp], &fx, &tp, &|| {
        let mut p = honest(&fx, &tp);
        p.b_in[tp.d_pad + 3] += 1;
        (p, None, None)
    });
    case("V2", "the same miss with everything downstream re-derived from the forged B_in (R1 #16b's forger)", &[Site::InLogUp], &fx, &tp, &|| {
        let mut p = honest(&fx, &tp);
        let mut b = p.b_in.clone();
        b[tp.d_pad + 3] += 1;
        with_b_in(&fx, &tp, &mut p, b);
        (p, None, None)
    });
}

/// **t34's endpoint cases**: the input endpoint sealed over another prompt
/// (stage IN honest) must be rejected at stage IN's IO claim (the token
/// plane against the input endpoint, slot SI_IO); the output endpoint
/// sealed over another token (stage OUT honest) at stage OUT's output IO
/// claim (slot SO_IOOUT).
#[test]
fn r9v_an_endpoint_over_another_prompt_or_token_that_a_prover_finishes_is_rejected_by_the_verifier() {
    let fx = fx_generic();
    let tp = profile(&fx);
    case("V3", "t34's input endpoint sealed over another prompt (stage IN honest)", &[Site::InSlot(stage_in::SI_IO)], &fx, &tp, &|| {
        let p = honest(&fx, &tp);
        let mut ip = p.in_plane.clone();
        ip[1] = Fp::new((ip[1].0 + 1) % tp.v as u64);
        (p, Some(ip), None)
    });
    case("V4", "t34's output endpoint sealed over another token (stage OUT honest)", &[Site::OutSlot(stage_out::SO_IOOUT)], &fx, &tp, &|| {
        let p = honest(&fx, &tp);
        let other = (p.out_values.tok + 1) % tp.v;
        let op = stage_out::endpoint_plane(&tp, other as u64);
        (p, None, Some(op))
    });
}
