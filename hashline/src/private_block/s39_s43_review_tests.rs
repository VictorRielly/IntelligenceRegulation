//! **REVIEW BRANCH ONLY** (`zk60-private-block-125m-review`): the independent
//! adversarial code review of lane stages 39–43 (`a9d6d4c..f486e6f`), report
//! `docs/zkmatrix-poc/ZK60_LANE_S39_S43_CODE_REVIEW.md`. NOT part of the
//! lane's delta and not to be integrated with it.
//!
//! Test-only; no production line is touched. Everything proved here is
//! PUBLIC SYNTHETIC test data. A reproducer of a real failure is `#[ignore]`d
//! with its finding number and fails when run with `--ignored`, as a
//! reproducer must.

use super::layout::*;
use super::protocol::{self, prove_inner_at};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::{Shape, TOY_PROFILE};
use super::witness::{self, Witness};
use super::*;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;

fn ctx() -> Digest {
    *blake3::hash(b"review of lane stages 39-43 (a9d6d4c..f486e6f)").as_bytes()
}

/// every registered block shape, and the test-only rung-K8
fn registered() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125(), super::k8_tests::rung_k8()]
}

fn xorshift(seed: &mut u64) -> u64 {
    let mut x = *seed;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    *seed = x;
    x
}

/// the padded `(t_pad, d_pad)` endpoint planes of a witness, committed by
/// fresh owners under this review's context
fn endpoints_at(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[ids.at(p)].iter().map(|v| i16::try_from(*v).expect("an int16 endpoint word")).collect() };
    let spec = IoSpec::new_shaped(sh, ctx(), 0, 0).expect("the endpoint spec");
    prepare_endpoints(spec, &plane(A_X), &plane(A_X2)).expect("the endpoint owner commits")
}

/// The HONEST path at a shape, end to end: the builder, the honest prover
/// (ruling CS-3 ON — no `CheatingProver` guard anywhere in this file), the
/// encoder and a fresh bytes verifier. One outcome line.
fn honest_outcome(sh: &Shape, blk: &BlockPublic, x: &[i16]) -> String {
    let w = match catch_unwind(AssertUnwindSafe(|| witness::build_shaped(sh, blk.attention(), blk.feed_forward(), x))) {
        Err(_) => return "the builder PANICS".into(),
        Ok(Err(e)) => return format!("the builder refuses: {e}"),
        Ok(Ok(w)) => w,
    };
    let run = catch_unwind(AssertUnwindSafe(|| {
        let (expected, owners) = endpoints_at(sh, &w);
        match prove_inner_at(sh, blk, w, &expected, owners) {
            Err(e) => format!("PROVER REFUSED an input its builder admits: {e}"),
            Ok((receipt, _)) => match receipt.to_bytes_at(sh, blk, &expected) {
                Err(e) => format!("ENCODER REFUSED: {e}"),
                Ok(bytes) => match verify_bytes_at(sh, blk, &expected, &bytes) {
                    Ok(()) => format!("ACCEPTED ({} B)", bytes.len()),
                    Err(e) => format!("VERIFIER REJECTED an honest proof: {e}"),
                },
            },
        }
    }));
    run.unwrap_or_else(|_| "the prover or verifier PANICS".into())
}

fn is_bad(outcome: &str) -> bool {
    outcome.contains("PROVER REFUSED") || outcome.contains("VERIFIER REJECTED") || outcome.contains("ENCODER REFUSED") || outcome.contains("PANICS")
}

// ============================================================ question 2: completeness

/// **Q2.** Every registered shape (and rung-K8) passes every re-check the
/// delta adds, with its own statement and its own endpoint policy: CS-8's
/// `Shape::check_constructed` and `Layout::check_is_for_shape` (also on a
/// layout whose IO pair rows a run moved with `with_io_mask_rows`, which the
/// re-check deliberately does not compare), CS-4's `IoSpec::check_for_shape`
/// and `validate`, CS-1/CS-4's `BlockPublic::check_for_shape` on the tame
/// and (below 125M) the dense statement, and CS-7's `RunShape::new` for every
/// registered run profile at L = 1, 2 and 12. Nothing proved; cheap.
#[test]
fn rv_every_registered_shape_and_its_own_statement_pass_every_new_recheck() {
    for sh in registered() {
        sh.check_constructed().unwrap_or_else(|e| panic!("CS-8 refuses the registered shape {:?}: {e}", sh.name));
        Layout::for_shape(&sh).expect("the layout").check_is_for_shape(&sh).unwrap_or_else(|e| panic!("CS-8 refuses the layout of {:?}: {e}", sh.name));
        Layout::for_shape(&sh).expect("the layout").with_io_mask_rows([1, 3]).check_is_for_shape(&sh).unwrap_or_else(|e| panic!("CS-8 refuses a run stage layout of {:?}: {e}", sh.name));
        let spec = IoSpec::new_shaped(&sh, ctx(), 0, 0).unwrap_or_else(|e| panic!("the endpoint spec of {:?}: {e}", sh.name));
        spec.check_for_shape(&sh).unwrap_or_else(|e| panic!("CS-4 refuses the policy of {:?}: {e}", sh.name));
        spec.validate().unwrap_or_else(|e| panic!("validate refuses the policy of {:?}: {e}", sh.name));
        let (att, ff, _) = super::grow_tests::tame_case(&sh);
        BlockPublic::new(att, ff).check_for_shape(&sh).unwrap_or_else(|e| panic!("CS-1/CS-4 refuse the tame statement of {:?}: {e}", sh.name));
        if sh.profile != Shape::m125().profile {
            let (att, ff, _) = super::dense_tests::dense_case(&sh);
            BlockPublic::new(att, ff).check_for_shape(&sh).unwrap_or_else(|e| panic!("CS-1/CS-4 refuse the dense statement of {:?}: {e}", sh.name));
        }
        eprintln!("RV Q2 {:?}: check_constructed, check_is_for_shape (also with moved IO rows), IoSpec check_for_shape + validate, tame (and dense) statement check_for_shape: all admitted", sh.name);
    }
    for l in [1usize, 2, 12] {
        let made = [
            RunShape::rung_g(l),
            RunShape::rung_k4(l),
            RunShape::rung_p2(l),
            RunShape::rung_c6(l),
            RunShape::rung_w14(l),
            RunShape::rung_e32(l),
            RunShape::m125(l),
            RunShape::new(super::k8_tests::rung_k8(), l, super::k8_tests::K8_RUN_PROFILE),
        ];
        for (i, r) in made.into_iter().enumerate() {
            let rs = r.unwrap_or_else(|e| panic!("CS-7 refuses registered run shape {i} at L = {l}: {e}"));
            rs.sh().check_constructed().unwrap_or_else(|e| panic!("CS-8 refuses the block shape of registered run shape {i}: {e}"));
        }
    }
    eprintln!("RV Q2: the eight registered run shapes (seven + test-only rung-K8) construct at L = 1, 2, 12 and their block shapes pass CS-8");
}

/// **Q2 / Q5, ruling CS-3 on the HONEST toy path at the int16 extremes.**
/// The public `prove_with_stats` (the only toy prover a caller outside the
/// crate has), sixteen hidden inputs chosen to stress every range the toy
/// builder admits — all zero, all `i16::MAX`, all `i16::MIN`, alternating
/// extremes by word and by token row, single spikes, eight seeded full-range
/// inputs — and the synthetic fixture as the control. For each: the builder
/// refuses by name (a pre-existing, public-statement-free refusal), or the
/// honest prover proves and a fresh verifier accepts. Ruling CS-3 must never
/// be the refusal: it would be a new, input-dependent refusal on the D22 path.
#[test]
fn rv_cs3_never_refuses_an_honest_toy_input_at_the_int16_extremes() {
    let (blk, fixture) = BlockPublic::synthetic_fixture();
    let n = fixture.len();
    let d = Shape::toy().width;
    let mut cases: Vec<(String, Vec<i16>)> = vec![
        ("the synthetic fixture (control)".into(), fixture.clone()),
        ("all 0".into(), vec![0; n]),
        ("all i16::MAX".into(), vec![i16::MAX; n]),
        ("all i16::MIN".into(), vec![i16::MIN; n]),
        ("alternating MAX / MIN by word".into(), (0..n).map(|i| if i % 2 == 0 { i16::MAX } else { i16::MIN }).collect()),
        ("alternating MAX / MIN by token row".into(), (0..n).map(|i| if (i / d) % 2 == 0 { i16::MAX } else { i16::MIN }).collect()),
        ("one MAX spike at word 0".into(), (0..n).map(|i| if i == 0 { i16::MAX } else { 0 }).collect()),
        ("one MIN spike at the last word".into(), (0..n).map(|i| if i == n - 1 { i16::MIN } else { 0 }).collect()),
    ];
    for s in 1..=8u64 {
        let mut seed = 0x5339_5343_0000_0000 ^ (s * 0x9E37_79B9);
        cases.push((format!("seeded full-range input {s}"), (0..n).map(|_| xorshift(&mut seed) as i16).collect()));
    }
    let (mut proved, mut refused) = (0usize, 0usize);
    for (name, x) in &cases {
        let out = match compute_output(&blk, x) {
            Err(e) => {
                assert!(!e.contains("ruling CS-3"), "{name}: CS-3 fired inside the toy builder: {e}");
                eprintln!("RV Q2 toy {name}: the builder refuses by name: {e}");
                refused += 1;
                continue;
            }
            Ok(o) => o,
        };
        let (expected, owners) = prepare_endpoints(IoSpec::new(ctx(), 0, 0).expect("the approved scales"), x, &out).expect("the endpoint owner commits");
        let (receipt, _) = prove_with_stats(&blk, x, &expected, owners).unwrap_or_else(|e| panic!("{name}: the honest toy prover refuses an input its builder admits: {e}"));
        let bytes = receipt.to_bytes(&blk, &expected).expect("the toy receipt encodes");
        assert_eq!(bytes.len(), 2_816_472, "{name}: the toy receipt moved");
        verify_bytes(&blk, &expected, &bytes).unwrap_or_else(|e| panic!("{name}: a fresh toy verifier rejects an honest proof: {e}"));
        eprintln!("RV Q2 toy {name}: proved (2,816,472 B) and ACCEPTED");
        proved += 1;
    }
    eprintln!("RV Q2 toy: {proved} honest inputs proved and accepted, {refused} refused by the builder by name, 0 refused by CS-3, 0 rejected");
    assert!(proved >= 2, "fewer than two honest toy inputs proved: nothing was exercised");
}

/// **Q2 / Q5, ruling CS-3 on the honest SHAPED path at the int16 extremes.**
/// The dense statement at rung-G (Dom::F and Dom::D pad) and at rung-K4 (a
/// padded head slot in every key-value group), each with its own dense input,
/// the three constant / alternating extremes and two seeded full-range
/// inputs, through the honest `prove_inner_at` (CS-3 on) and a fresh bytes
/// verifier. The builder may refuse by name; the prover may not, and no
/// honest proof may be rejected.
#[test]
fn rv_cs3_never_refuses_an_honest_padded_shape_input_at_the_int16_extremes() {
    let mut bad = Vec::new();
    let mut accepted = 0usize;
    for sh in [Shape::rung_g(), Shape::rung_k4()] {
        let (att, ff, dense_x) = super::dense_tests::dense_case(&sh);
        let blk = BlockPublic::new(att, ff);
        let n = dense_x.len();
        let mut cases: Vec<(String, Vec<i16>)> = vec![
            ("the dense input (control)".into(), dense_x.clone()),
            ("all i16::MAX".into(), vec![i16::MAX; n]),
            ("all i16::MIN".into(), vec![i16::MIN; n]),
            ("alternating MAX / MIN by word".into(), (0..n).map(|i| if i % 2 == 0 { i16::MAX } else { i16::MIN }).collect()),
        ];
        for s in 1..=2u64 {
            let mut seed = 0x5339_5343_1111_0000 ^ (s * 0x9E37_79B9);
            cases.push((format!("seeded full-range input {s}"), (0..n).map(|_| xorshift(&mut seed) as i16).collect()));
        }
        // seeded inputs in magnitude bands the builder admits more often
        // (the full-range ones above are refused for the residual's range)
        for band in [256i64, 2_048, 16_384] {
            for s in 1..=2u64 {
                let mut seed = 0x5339_5343_2222_0000 ^ (s * 0x9E37_79B9) ^ (band as u64);
                cases.push((format!("seeded input in [-{band}, {band}) no. {s}"), (0..n).map(|_| ((xorshift(&mut seed) % (2 * band as u64)) as i64 - band) as i16).collect()));
            }
        }
        // the dense input with its signs flipped, and reversed
        cases.push(("the dense input negated".into(), dense_x.iter().map(|v| v.saturating_neg()).collect()));
        cases.push(("the dense input reversed".into(), dense_x.iter().rev().copied().collect()));
        for (name, x) in &cases {
            let v = honest_outcome(&sh, &blk, x);
            eprintln!("RV Q2 {:?} {name}: {v}", sh.name);
            if is_bad(&v) || v.contains("ruling CS-3") {
                bad.push(format!("{:?} {name}: {v}", sh.name));
            }
            if v.starts_with("ACCEPTED") {
                accepted += 1;
            }
        }
    }
    eprintln!("RV Q2 padded shapes: {accepted} honest inputs proved and accepted through the honest prover (CS-3 on); none refused by CS-3, none rejected");
    assert!(bad.is_empty(), "an honest padded-shape input is refused by the prover or rejected:\n{}", bad.join("\n"));
    assert!(accepted >= 6, "only {accepted} honest padded-shape inputs reached the verifier: CS-3 was barely exercised");
}

/// **Q2, note C-6's lower edge.** Stage 40 bounded `f_e` above (`> 31`
/// refused by name) and MEASURED 0, 1 (refused by the layout) and 4..=31
/// (ACCEPTED); `f_e = 2` and `f_e = 3` are admitted by `Shape::new` and were
/// never measured (`s40_tests.rs:866`). Measured here at rung-G's geometry on
/// the dense statement's words with a legal exp table at each scale (`E[d] =
/// 2^f_e >> d`), through the honest prover and a fresh verifier: each must be
/// refused by name before a proof exists, or ACCEPTED — never a rejected
/// honest proof, never a panic.
#[test]
fn rv_c6_the_exp_scales_below_four_prove_or_are_refused_by_name() {
    let g = Shape::rung_g();
    let (att, ff, x) = super::dense_tests::dense_case(&g);
    let mut bad = Vec::new();
    for f_e in [0u32, 1, 2, 3, 4] {
        let profile: &'static str = Box::leak(format!("hashline-zk-mr1/rv-s39-s43-fe{f_e}-dev/1").into_boxed_str());
        let v = (|| -> String {
            let sh = match catch_unwind(|| Shape::new("review: rung-G geometry, a small exp scale", profile, 24, 96, 192, 6, 16, 2, 10, 4, f_e, 9, None, None, None, None)) {
                Err(_) => return "Shape::new PANICS".into(),
                Ok(Err(e)) => return format!("Shape::new refuses: {e}"),
                Ok(Ok(s)) => s,
            };
            if let Err(e) = sh.check_constructed() {
                return format!("CS-8 REFUSED a shape Shape::new built: {e}");
            }
            match catch_unwind(|| Layout::for_shape(&sh).map(|_| ())) {
                Err(_) => return format!("wrho_s {} / Layout::for_shape PANICS", sh.wrho_s),
                Ok(Err(e)) => return format!("wrho_s {} / Layout::for_shape refuses: {e}", sh.wrho_s),
                Ok(Ok(())) => {}
            }
            let one_e = 1i64 << f_e;
            let exp: Vec<i64> = (0..256u32).map(|d| if d < 63 { one_e >> d } else { 0 }).collect();
            let att_fe = match AttentionPublic::new_shaped(&sh, &att.wq, &att.wk, &att.wv, &att.wo, &att.gamma_a, &att.rope_cos, &att.rope_sin, &exp) {
                Err(e) => return format!("wrho_s {} / the statement refuses: {e}", sh.wrho_s),
                Ok(a) => a,
            };
            let blk = BlockPublic::new(att_fe, ff.clone());
            format!("wrho_s {} / {}", sh.wrho_s, honest_outcome(&sh, &blk, &x))
        })();
        eprintln!("RV Q2 C-6 f_e = {f_e}: {v}");
        if is_bad(&v) || v.contains("CS-8 REFUSED") {
            bad.push(format!("f_e = {f_e}: {v}"));
        }
    }
    assert!(bad.is_empty(), "an f_e below 4 that Shape::new admits yields a failing honest proof or a panic:\n{}", bad.join("\n"));
}

// ============================================================ question 3 / 5: the CS-3 refusal's text in a run

/// the padded plane of a witness as the int16 words an IO commitment carries
fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("an int16 plane word")).collect()
}

/// the true `tokens x width` state inside a padded plane
fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// A run's private side that LOGS what the run prover asks it for, in order,
/// and tampers one activation word of one block's witness after it is built
/// (a lookup miss: the pair `(g8 + 128, a16 + 1)` is not a table row).
struct LoggedChain {
    sh: Shape,
    att: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
    tamper_block: usize,
    log: Vec<String>,
}

impl RunWitnessSource for LoggedChain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        self.log.push(format!("witness({k})"));
        let mut w = witness::build_shaped(&self.sh, &self.att, &self.ff, &self.inputs[k])?;
        if k == self.tamper_block {
            let ids = Ids::new(&self.sh)?;
            w.planes[ids.at(A_A16)][0] += 1;
        }
        Ok(w)
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.log.push(format!("boundary_plane({k})"));
        Ok(self.planes[k + 1].clone())
    }
}

/// **REPRODUCER of finding K-1 (erratum).** Ruling CS-3's refusal text says
/// "refused before the A commitment; nothing of this block was drawn,
/// absorbed or committed". In a RUN, `prove_run` absorbs `pb-run-stage` and
/// `pb-run-block`, asks the source for boundary `k`'s plane, commits it with
/// draws from the run's stream (`boundary::prepare`) and absorbs its root
/// (`run.rs:746-757`) — all BEFORE `prove_core` reaches the refusal
/// (`run.rs:774`, `protocol.rs:965`). The disposition accepted that ordering
/// (§5, M-9); the TEXT contradicts it. Measured on a rung-G `L = 2` run with
/// block 0 tampered: the prover asks for `boundary_plane(0)` before
/// `witness(0)`, then refuses by CS-3's name with the "nothing of this block
/// was ... committed" sentence. Fails until the text is corrected (or made
/// true in a run).
#[test]
#[ignore = "reproducer of review finding K-1 (erratum): in a run the CS-3 refusal text claims nothing of the block was drawn, absorbed or committed, after the block's outgoing boundary was drawn, committed and absorbed"]
fn rv_k1_the_cs3_refusal_text_is_false_in_a_run() {
    let sh = Shape::rung_g();
    let (att, ff, x0) = super::grow_tests::tame_case(&sh);
    let ids = Ids::new(&sh).expect("the plane map");
    let w0 = witness::build_shaped(&sh, &att, &ff, &x0).expect("block 0's honest witness");
    let (p0, p1) = (padded(&w0, ids.at(A_X)), padded(&w0, ids.at(A_X2)));
    let x1 = true_input(&sh, &w0.output().expect("block 0's output"));
    let w1 = witness::build_shaped(&sh, &att, &ff, &x1).expect("block 1's honest witness");
    let p2 = padded(&w1, ids.at(A_X2));
    let spec = IoSpec::new_shaped(&sh, ctx(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &p0, &p2).expect("the external endpoint owners");
    let blocks = vec![BlockPublic::new(att.clone(), ff.clone()), BlockPublic::new(att.clone(), ff.clone())];
    let st = RunStatement::new(RunShape::rung_g(2).expect("the rung-G run shape"), ctx(), expected, &blocks, &[(0, 0), (0, 0)]).expect("the run statement");
    let mut src = LoggedChain { sh: sh.clone(), att, ff, inputs: vec![x0, x1], planes: vec![p0, p1, p2], tamper_block: 0, log: Vec::new() };
    let mut sunk = 0usize;
    let r = run::prove_run(&st, &blocks, &mut src, owners, &mut |_, _| {
        sunk += 1;
        Ok(())
    });
    let e = r.err().expect("the run prover must refuse the tampered block 0");
    eprintln!("RV K-1: the run prover asked for {:?}, sank {sunk} segment(s), and refused: {e}", src.log);
    assert!(e.starts_with(protocol::LOOKUP_MISS_REFUSAL), "the refusal is not ruling CS-3's: {e}");
    assert_eq!(sunk, 0, "a segment was sunk before the stage-0 refusal");
    let committed_first = src.log.first().map(String::as_str) == Some("boundary_plane(0)");
    assert!(committed_first, "measurement: the boundary was not requested before the witness: {:?}", src.log);
    // THE REPRODUCER'S CLAIM: the text must not say nothing of the block was
    // committed when the block's outgoing boundary already was
    assert!(
        !e.contains("nothing of this block was drawn, absorbed or committed"),
        "K-1: the CS-3 refusal says nothing of block 0 was drawn, absorbed or committed, but its outgoing boundary B_0 was requested ({:?}), committed with draws from the run's stream and absorbed before the refusal",
        src.log
    );
}

// ============================================================ question 7: the declaration pin

/// the stage-43 pin's own parser (`s43_tests.rs:151-161`, `:399-407`),
/// reimplemented exactly, applied to a SOURCE TEXT instead of the file
fn pin_visible_fields(src: &str, decl: &str) -> Vec<String> {
    let at = src.find(decl).unwrap_or_else(|| panic!("{decl} is not in the source"));
    let end = src[at..].find("\n}\n").unwrap_or_else(|| panic!("{decl}'s body does not close")) + at;
    let body = &src[at..end];
    body.lines().skip(1).map(str::trim).filter(|l| !l.is_empty() && !l.starts_with("//") && !l.starts_with("#[")).filter(|f| f.starts_with("pub")).map(str::to_string).collect()
}

/// **A STRONGER GUARD (proposed, finding K-3):** what would reopen S42-N1 is
/// not only a field regaining a modifier, but any second way to MAKE a value
/// or to change one in place. In `run.rs`: exactly one `RunShape` struct
/// literal (inside `RunShape::new`) and one `RunStatement` literal (inside
/// `RunStatement::new`); the two statement escape hatches `with_run_shape`
/// and `with_calibration` each directly under `#[cfg(test)]`; no method of
/// either type hands out `&mut` to a field.
fn stronger_guard(src: &str) -> Vec<String> {
    let mut out = Vec::new();
    let lit_rs = src.matches("RunShape { sh").count();
    if lit_rs != 1 {
        out.push(format!("{lit_rs} RunShape struct literals (1 expected, in RunShape::new)"));
    }
    let lit_st = src.matches("RunStatement { rs").count();
    if lit_st != 1 {
        out.push(format!("{lit_st} RunStatement struct literals (1 expected, in RunStatement::new)"));
    }
    let new_body = {
        let at = src.find("    pub(crate) fn new(sh: Shape, l: usize, profile: &'static str) -> Result<RunShape, String> {").expect("RunShape::new");
        let end = src[at..].find("\n    }\n").expect("RunShape::new closes") + at;
        &src[at..end]
    };
    if !new_body.contains("RunShape { sh") {
        out.push("the RunShape literal is not inside RunShape::new".into());
    }
    for hatch in ["pub(crate) fn with_run_shape(", "pub(crate) fn with_calibration("] {
        match src.find(hatch) {
            None => out.push(format!("{hatch} is gone")),
            Some(at) => {
                // the line above the one the hatch's signature starts on
                let line_start = src[..at].rfind('\n').unwrap_or(0);
                let above = src[..line_start].lines().last().map(str::trim);
                if above != Some("#[cfg(test)]") {
                    out.push(format!("{hatch} is not directly under #[cfg(test)]"));
                }
            }
        }
    }
    for pat in ["-> &mut Shape", "-> &mut RunShape", "-> &mut ExpectedIo", "-> &mut Vec<Digest>", "&mut self.sh", "&mut self.rs", "&mut self.block_digests"] {
        if src.contains(pat) {
            out.push(format!("a mutable accessor: {pat}"));
        }
    }
    out
}

/// **Q7. The declaration pin that replaced the deleted S42-N1 test and the
/// four-route measurement is a real guard, but a narrow one (finding K-3).**
/// Measured on `run.rs`'s own text: (a) as it stands, the stage-43 pin sees
/// 0 visible fields and the stronger guard 0 violations; (b) with one
/// `pub(crate)` constructor added inside `impl RunShape` that builds a
/// literal and skips ruling CS-7 — S42-N1 again, from any file of the crate
/// — the pin still sees 0; (c) with `#[cfg(test)]` removed from
/// `with_run_shape` — a production path that swaps a statement's run shape
/// past every check `RunStatement::new` makes — the pin still sees 0; (d) a
/// field made `pub` again: the pin catches it (its real guard). The
/// stronger guard catches (b), (c) and nothing in (a).
#[test]
fn rv_q7_the_declaration_pin_misses_a_new_constructor_and_an_uncfgd_escape_hatch() {
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("src/private_block/run.rs");
    let src = std::fs::read_to_string(&path).expect("run.rs");
    let decl = "pub(crate) struct RunShape {";
    // (a) the source as it stands
    assert!(pin_visible_fields(&src, decl).is_empty(), "(a) the pin sees a visible field in the source as it stands");
    assert!(pin_visible_fields(&src, "pub(crate) struct RunStatement {").is_empty());
    assert_eq!(stronger_guard(&src), Vec::<String>::new(), "(a) the stronger guard fails on the source as it stands");
    // (b) a second constructor, skipping CS-7
    let anchor = "impl RunShape {\n";
    assert_eq!(src.matches(anchor).count(), 1, "one impl RunShape block");
    let b = src.replacen(anchor, "impl RunShape {\n    pub(crate) fn from_parts(sh: Shape, l: usize, profile: &'static str) -> RunShape {\n        RunShape { sh, l, profile }\n    }\n", 1);
    let pin_b = pin_visible_fields(&b, decl);
    let guard_b = stronger_guard(&b);
    eprintln!("RV Q7 (b) a pub(crate) RunShape::from_parts skipping CS-7: the stage-43 pin sees {} visible field(s); the stronger guard: {guard_b:?}", pin_b.len());
    assert!(pin_b.is_empty(), "(b) the pin now catches a second constructor (update the review)");
    assert!(!guard_b.is_empty(), "(b) the stronger guard missed the second constructor");
    // (c) the escape hatch un-cfg'd
    let hatch = "    #[cfg(test)]\n    pub(crate) fn with_run_shape(";
    assert_eq!(src.matches(hatch).count(), 1, "with_run_shape sits directly under #[cfg(test)]");
    let c = src.replacen(hatch, "    pub(crate) fn with_run_shape(", 1);
    let pin_c = pin_visible_fields(&c, "pub(crate) struct RunStatement {");
    let guard_c = stronger_guard(&c);
    eprintln!("RV Q7 (c) with_run_shape without #[cfg(test)]: the stage-43 pin sees {} visible field(s); the stronger guard: {guard_c:?}", pin_c.len());
    assert!(pin_c.is_empty(), "(c) the pin now catches an un-cfg'd escape hatch (update the review)");
    assert!(!guard_c.is_empty(), "(c) the stronger guard missed the un-cfg'd escape hatch");
    // (d) the pin's real guard: a field made visible again
    let d = src.replacen("pub(crate) struct RunShape {\n    sh: Shape,", "pub(crate) struct RunShape {\n    pub sh: Shape,", 1);
    assert_ne!(d, src, "(d) the RunShape declaration moved; update the mutation");
    assert_eq!(pin_visible_fields(&d, decl), vec!["pub sh: Shape,".to_string()], "(d) the pin no longer catches a visible field");
    eprintln!("RV Q7: the stage-43 declaration pin catches a field made visible (d) and misses a second constructor (b) and an un-cfg'd escape hatch (c); the stronger guard catches (b) and (c) and passes the source as it stands");
}

// ============================================================ the sweep's edge: a block profile names no one shape

/// the frozen toy's PROFILE STRING at rung-G's geometry — a value
/// `Shape::new` returns
fn toy_profile_at_rung_g() -> Shape {
    Shape::new("review: the toy profile at rung-G geometry", TOY_PROFILE, 24, 96, 192, 6, 16, 2, 10, 4, 12, 9, None, None, None, None).expect("Shape::new admits the toy profile string at rung-G's geometry")
}

/// The honest path at `sh` IN MEMORY (the bytes path stops at the toy
/// profile's frame bound): builder, honest prover (CS-3 on), in-memory
/// verifier. One outcome line.
fn honest_in_memory(sh: &Shape, blk: &BlockPublic, x: &[i16]) -> String {
    let w = match witness::build_shaped(sh, blk.attention(), blk.feed_forward(), x) {
        Err(e) => return format!("the builder refuses: {e}"),
        Ok(w) => w,
    };
    let (expected, owners) = endpoints_at(sh, &w);
    match prove_inner_at(sh, blk, w, &expected, owners) {
        Err(e) => format!("PROVER REFUSED: {e}"),
        Ok((receipt, _)) => match protocol::verify_inner_at(sh, blk, &expected, &receipt) {
            Ok(_) => "ACCEPTED in memory".to_string(),
            Err(e) => format!("VERIFIER REJECTED an honest proof: {e}"),
        },
    }
}

/// **Note K-4, MEASURED (pre-existing, outside the delta; it bears on
/// CS-7's rationale and on the completeness of CS-8's sweep).** Ruling CS-7
/// binds a RUN profile to exactly one block shape because "privacy
/// statements and hash keys (D19a) are per PROFILE". Nothing binds a BLOCK
/// profile string to its geometry: `Shape::new` takes any profile string,
/// and CS-8's `check_constructed` admits exactly what `Shape::new` admits.
/// The frozen toy's profile string at rung-G's geometry passes CS-8, is
/// `is_frozen_toy()`, carries NO pad rule (ruling P-1 keys it on the
/// profile) although its `Dom::F` and `Dom::D` pad, and hashes under the
/// legacy rule; its layout builds and its builder admits. What its honest
/// proofs do is measured here and asserted by the ignored reproducer below.
#[test]
fn rv_k4_the_toy_profile_string_at_another_geometry_passes_every_cs8_check() {
    let sh = toy_profile_at_rung_g();
    sh.check_constructed().expect("CS-8 admits it: it is exactly a value Shape::new returns");
    assert!(sh.is_frozen_toy(), "the shape is the frozen toy by its profile");
    assert!(!sh.carries_pad_rule(), "the pad rule is keyed on the profile");
    assert!(sh.pads(Dom::F) && sh.pads(Dom::D), "rung-G's geometry pads Dom::F and Dom::D");
    assert!(sh.hash_tag().is_legacy(), "the toy profile hashes under the legacy rule");
    Layout::for_shape(&sh).expect("its layout builds");
    let (att, ff, x) = super::dense_tests::dense_case(&Shape::rung_g());
    let blk = BlockPublic::new(att, ff);
    blk.check_for_shape(&sh).expect("CS-1 / CS-4 admit rung-G's dense statement at it");
    IoSpec::new_shaped(&sh, ctx(), 0, 0).expect("CS-4 admits a policy made for it");
    eprintln!("RV K-4 the toy profile string at rung-G geometry: Shape::new, CS-8, the layout, CS-1/CS-4 and the policy admit it; is_frozen_toy, NO pad rule while Dom::F and Dom::D pad, legacy hash; bytes path: {}", honest_outcome(&sh, &blk, &x));
}

/// **REPRODUCER of note K-4.** At the toy profile string over rung-G's
/// geometry — admitted by `Shape::new`, CS-8, the layout, CS-1/CS-4 and the
/// builder — the honest prover (CS-3 on) proves and the in-memory verifier
/// REJECTS every honest proof measured (slot 2, the norm squares
/// zero-check: without the pad rule nothing switches the relation off on
/// the padded width), on three inputs: the dense input, the tame input and
/// all zeros. That is the class stages 38–43 refuse by name at construction
/// (C-6, CS-2: an admitted shape whose honest proofs fail). Fails until a
/// block profile is bound to its registered geometry (or such a shape is
/// otherwise refused by name before a proof exists).
#[test]
#[ignore = "reproducer of review note K-4: the frozen toy profile string at rung-G geometry is admitted by Shape::new and every CS-8 check, and the verifier rejects its honest proofs"]
fn rv_k4_an_admitted_toy_profile_shape_at_another_geometry_fails_its_honest_proofs() {
    let sh = toy_profile_at_rung_g();
    let (att, ff, dense_x) = super::dense_tests::dense_case(&Shape::rung_g());
    let blk = BlockPublic::new(att, ff);
    let (_, _, tame_x) = super::grow_tests::tame_case(&Shape::rung_g());
    let zero = vec![0i16; sh.tokens * sh.width];
    let mut rejected = Vec::new();
    for (name, x) in [("the dense input", &dense_x), ("the tame input", &tame_x), ("all zeros", &zero)] {
        let v = honest_in_memory(&sh, &blk, x);
        eprintln!("RV K-4 {name}: {v}");
        if is_bad(&v) {
            rejected.push(format!("{name}: {v}"));
        }
    }
    assert!(rejected.is_empty(), "K-4: a shape Shape::new and every CS-8 check admit (the toy profile string at rung-G geometry) fails its honest proofs:\n{}", rejected.join("\n"));
}
