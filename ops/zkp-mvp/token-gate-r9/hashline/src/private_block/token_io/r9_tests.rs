//! **TOKEN I/O ROUND 9: F-T1, THE TOKEN RUN'S SEALING PASS** (the privacy
//! gate's finding). TEST CODE ONLY, public synthetic data.
//!
//! Ruling H-1: every refusal of an inadmissible run happens before the run
//! header. Native blocks run ruling CS-3's lookup-miss check in their
//! sealing pass since R6 (`protocol::check_lookup_misses`); the token run
//! checked stage OUT's bytes before the header (review R2-5) but left stage
//! IN, the token endpoints and the blocks to their own stage, mid-run. Each
//! test here gives the prover ONE inadmissible witness and requires the
//! refusal before the header: no header built (the prover's test-only
//! header count does not move) and no segment handed to the sink.

use super::run::*;
use super::tests::*;
use super::*;
use super::super::layout::{Ids, A_E};

/// one attempt: seal the endpoints over `in_plane` / `out_plane` (the
/// pipeline's unless given), build the statement, prove; `(result,
/// segments sunk, headers built)`
fn attempt(fx: &Fx, tp: &TokenProfile, pipe: &mut HonestPipeline, in_plane: Option<Vec<Fp>>, out_plane: Option<Vec<Fp>>) -> (Result<(), String>, usize, u64) {
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), tp).unwrap();
    let ip = in_plane.unwrap_or_else(|| pipe.in_plane.clone());
    let op = out_plane.unwrap_or_else(|| pipe.out_plane.clone());
    let (roots, owners) = seal_endpoints(&ins, &outs, &ip, &op, &fx.sh.hash_tag()).unwrap();
    let st = statement(fx, roots, tp.variant).unwrap();
    let h0 = run_headers();
    let mut sunk = 0usize;
    let r = prove_token_run(&st, &fx.blocks, &fx.tables, &mut PipelineSource(pipe), owners, &mut |_, _| {
        sunk += 1;
        Ok(())
    })
    .map(|_| ());
    (r, sunk, run_headers() - h0)
}

fn refused_before_the_header(what: &str, got: (Result<(), String>, usize, u64)) -> String {
    let (r, sunk, headers) = got;
    let e = r.err().unwrap_or_else(|| panic!("ROUND 9 (F-T1): {what}: the run was NOT refused"));
    assert_eq!(headers, 0, "ROUND 9 (F-T1): {what}: refused ({e}) only AFTER the run header was built");
    assert_eq!(sunk, 0, "ROUND 9 (F-T1): {what}: {sunk} segment(s) reached the sink before the refusal ({e})");
    e
}

/// **F-T1, FAILING FIRST (stage IN):** one row of `B_in` is not the
/// embedding row of its token (the indexed lookup misses). Refused before
/// the header, nothing written.
#[test]
fn r9_a_stage_in_lookup_miss_is_refused_before_the_header() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    pipe.b_in[tp.d_pad + 3] += 1;
    let e = refused_before_the_header("a stage-IN lookup miss", attempt(&fx, &tp, &mut pipe, None, None));
    eprintln!("TOKEN-IO ROUND 9 F-T1 | stage IN: B_in row 1 is not E[tok_1] -> refused before the header: {e}");
}

/// **F-T1 (stage OUT):** a looked-up limb of stage OUT that is not a byte.
/// Refused before the header (review R2-5 already did; kept as a control).
#[test]
fn r9_a_stage_out_lookup_miss_is_refused_before_the_header() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    pipe.stage_out.planes[stage_out::A_LIMB][0] = Fp::new(300);
    let e = refused_before_the_header("a stage-OUT lookup miss", attempt(&fx, &tp, &mut pipe, None, None));
    eprintln!("TOKEN-IO ROUND 9 F-T1 | stage OUT: a looked limb of 300 -> refused before the header: {e}");
}

/// **F-T1, FAILING FIRST (a block, alongside the stages):** block 1's exp
/// plane misses its table at one position (CS-3). Refused in the sealing
/// pass, before the header, as the native trained stack does.
#[test]
fn r9_a_block_lookup_miss_is_refused_before_the_header() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let at = Ids::new(&fx.sh).unwrap().at(A_E);
    pipe.witnesses[1].as_mut().unwrap().planes[at][0] += 1;
    let e = refused_before_the_header("a block-1 exp lookup miss", attempt(&fx, &tp, &mut pipe, None, None));
    eprintln!("TOKEN-IO ROUND 9 F-T1 | block 1: an exp miss -> refused before the header: {e}");
}

/// **F-T1, FAILING FIRST (the endpoints):** the input endpoint sealed over
/// another prompt than the stage-IN witness's, and the output endpoint over
/// another token than stage OUT's. Each refused before the header.
#[test]
fn r9_an_endpoint_that_is_not_the_witnesss_is_refused_before_the_header() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let mut ip = pipe.in_plane.clone();
    ip[1] = Fp::new((ip[1].0 + 1) % tp.v as u64);
    let e1 = refused_before_the_header("an input endpoint over another prompt", attempt(&fx, &tp, &mut pipe, Some(ip), None));
    let mut pipe = honest(&fx, &tp);
    let other = (pipe.out_values.tok + 1) % tp.v;
    let op = stage_out::endpoint_plane(&tp, other as u64);
    let e2 = refused_before_the_header("an output endpoint over another token", attempt(&fx, &tp, &mut pipe, None, Some(op)));
    eprintln!("TOKEN-IO ROUND 9 F-T1 | endpoints: input over another prompt -> {e1}; output over another token -> {e2}");
}

/// the honest run still proves and verifies, with exactly one header
#[test]
fn r9_the_honest_run_still_proves_with_one_header() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let (r, sunk, headers) = attempt(&fx, &tp, &mut pipe, None, None);
    r.expect("the honest run proves");
    assert_eq!((sunk, headers), (fx.blocks.len() + 2, 1));
}
