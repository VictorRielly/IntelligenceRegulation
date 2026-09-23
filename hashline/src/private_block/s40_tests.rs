//! **STAGE 40 (test-only): rulings CS-1, CS-2 and CS-3 of the shaped refusal
//! census disposition** (`docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS_DISPOSITION.md`,
//! security owner, 2026-09-22 23:22 PDT), on the two findings of the
//! adversarial check (`ZK60_SHAPED_REFUSAL_CENSUS_CHECK.md`, review branch
//! `zk60-private-block-125m-review` at `cda7d05`), and the check's note C-6.
//!
//! FAILING FIRST. The check's two reproducers were first copied here as they
//! stand on the review branch (`census_check_tests.rs`) and run at the lane
//! tip: both honest proofs were REJECTED BY THE VERIFIER (`H: pcs zk: group
//! 8`; `results/zk60_block125m_lane/s40-before-reproducers.log`). They were
//! then rewritten, as below, to expect the NAMED refusals of the rulings, and
//! run failing before any production line moved
//! (`s40-before-named.log`).
//!
//! * **C-1 / ruling CS-1** — the S38-F1(a) refusal and ruling P-2's support
//!   check were evaluated against the shape PASSED TO the constructor, which
//!   the statement does not carry. A feed-forward half built at rung-P2 and
//!   used in a rung-K4 block was admitted everywhere. The ruling: one check of
//!   a feed-forward statement against a shape, run by the constructor and
//!   again, by name, wherever a statement meets the shape it is proved at —
//!   the builder, the prover's and the verifier's entry, the run statement,
//!   the run prover and the run verifier — before anything is absorbed,
//!   committed or drawn.
//! * **C-2 / ruling CS-2** — `Shape::new` admitted a softmax window override
//!   below `clog2(tokens) + f_e`, under which an input the builder admits
//!   fails at the verifier (input-dependent), and a norm window override below
//!   its derivation. The ruling: both refused by name at construction.
//! * **ruling CS-3** — a looked-up word or pair that is not a row of its
//!   table is ONE named prover refusal before the `A` commitment, with
//!   nothing drawn or absorbed.
//! * **note C-6** — do a `width` other than `q_heads * head_dim`, or an
//!   unbounded `f_e`, admit a shape whose honest proofs fail? MEASURED: the
//!   width does not (dense proofs accepted at five widths); `f_e` DID (from
//!   64 on, every honest proof rejected), so `Shape::new` now refuses
//!   `f_e > 31`, the reference kernel's bound, by name.
//!
//! Nothing here is a privacy result. Everything proved is PUBLIC SYNTHETIC
//! test data with hand-chosen or seeded integers.

use super::layout::*;
use super::protocol::{self, act_indices, exp_deltas, lookup_values, prove_inner_at};
use super::review_tests::{outcome, Outcome};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use crate::zk::ZkRng;

// ---------------------------------------------------------------- the names

/// ruling S38-F1(a)'s refusal text, as a literal (the census file keeps its own)
const S38_F1_REFUSAL: &str = "private block: activation table act[128] must be 0 at a shape whose feed-forward domain pads (ruling S38-F1(a))";
/// ruling P-2's refusal for a weight off the width support
const P2_PADDED_WIDTH: &str = "private block: a public weight is nonzero at a padded width index";
/// **RULING CS-1's name**: the prefix every re-check puts before the
/// constructor's own refusal. Held as a literal so that the tests could be
/// written, and run failing, before the production text existed.
const CS1: &str = "private block: ruling CS-1 — the feed-forward statement does not fit the shape it is proved at";
/// **RULING CS-2's names**, the two window overrides
const CS2_WRHO: &str = "private block shape: ruling CS-2 — the softmax window override wrho_s = ";
const CS2_NORM: &str = "private block shape: ruling CS-2 — the norm window override norm_wrho = ";
/// **RULING CS-3's name**
const CS3: &str = "private block: ruling CS-3 — the witness looks up a value that is not a row of its table";

fn cs1(inner: &str) -> String {
    format!("{CS1}: {inner}")
}

fn cs1_run(k: usize, inner: &str) -> String {
    format!("private run: block {k}: {}", cs1(inner))
}

fn cs3(u8: usize, exp: usize, act: usize) -> String {
    format!("{CS3} (refused before the A commitment; nothing of this block was drawn, absorbed or committed): {u8} U8 words outside the byte table, {exp} exp pairs and {act} activation pairs not rows of the statement's tables")
}

fn check_context() -> Digest {
    *blake3::hash(b"census check (review branch): C-1 / C-2 reproducers").as_bytes()
}

// ---------------------------------------------------------------- shared helpers

/// `[Wq, Wk, Wv, Wo, gamma_a, gamma_m, Wg, Wu, Wd]`, TRUE-sized: every matrix
/// zero, both gains 127
fn zero_words(s: &Shape) -> [Vec<i8>; 9] {
    let (d, f, kvw) = (s.width, s.hidden, s.kv_heads * s.head_dim);
    [vec![0; d * d], vec![0; kvw * d], vec![0; kvw * d], vec![0; d * d], vec![127; d], vec![127; d], vec![0; d * f], vec![0; d * f], vec![0; f * d]]
}

fn silu() -> Vec<i16> {
    let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("frozen SiLU int16-out member");
    let act = act.to_vec();
    assert_eq!(act[128], 0, "the SiLU member's gate-0 row");
    act
}

/// the identity rotation at every position (legal: position 0 is the identity,
/// every entry in [-128, 128])
fn identity_rope(s: &Shape) -> (Vec<i64>, Vec<i64>) {
    let n = s.tokens * (s.head_dim / 2);
    (vec![1i64 << F_RO; n], vec![0i64; n])
}

fn statement(s: &Shape, w: &[Vec<i8>; 9], cos: &[i64], sin: &[i64], exp: &[i64], act: &[i16]) -> Result<BlockPublic, String> {
    let aw = super::grow_tests::pad_attention_weights(s, &w[0], &w[1], &w[2], &w[3], &w[4]);
    let fw = super::grow_tests::pad_ff_weights(s, &w[5], &w[6], &w[7], &w[8]);
    let att = AttentionPublic::new_shaped(s, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], cos, sin, exp)?;
    let ff = FeedForwardPublic::new_shaped(s, &fw[0], &fw[1], &fw[2], &fw[3], act)?;
    Ok(BlockPublic::new(att, ff))
}

/// every U8 word the PROVER would look up that is not a byte, as
/// `(domain, lookup index, position, value)`
fn u8_misses(s: &Shape, w: &Witness) -> Vec<(Dom, usize, usize, i64)> {
    let lay = Layout::for_shape(s).expect("the layout");
    let mut out = Vec::new();
    for dom in lay.lookup_doms().iter() {
        for (li, col) in lookup_values(&lay, w, *dom).iter().enumerate() {
            for (x, v) in col.iter().enumerate() {
                if !(0..U8_LEN as i64).contains(v) {
                    out.push((*dom, li, x, *v));
                }
            }
        }
    }
    out
}

/// the exp pairs the prover would look up that are not rows of the
/// statement's exp table, by position (computed here from `exp_deltas`, not
/// from the prover's own loop)
fn exp_misses(s: &Shape, blk: &BlockPublic, w: &Witness) -> Vec<usize> {
    let lay = Layout::for_shape(s).expect("the layout");
    let e = &w.planes[lay.ids().at(A_E)];
    exp_deltas(&lay, w).iter().enumerate().filter(|(x, d)| !((0..U8_LEN as i64).contains(*d) && blk.attention().exp[**d as usize] == e[*x])).map(|(x, _)| x).collect()
}

/// the activation pairs the prover would look up that are not rows of `ff`'s
/// table, by position
fn act_misses(s: &Shape, ff: &FeedForwardPublic, w: &Witness) -> Vec<usize> {
    let lay = Layout::for_shape(s).expect("the layout");
    let a = &w.planes[lay.ids().at(A_A16)];
    act_indices(&lay, w).iter().enumerate().filter(|(x, i)| !((0..U8_LEN as i64).contains(*i) && i64::from(ff.act[**i as usize]) == a[*x])).map(|(x, _)| x).collect()
}

/// the padded endpoint planes of a witness, committed by a fresh owner
fn endpoints_at(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[ids.at(p)].iter().map(|v| i16::try_from(*v).expect("an int16 endpoint word")).collect() };
    let spec = IoSpec::new_shaped(sh, check_context(), 0, 0).expect("the endpoint spec");
    prepare_endpoints(spec, &plane(A_X), &plane(A_X2)).expect("the endpoint owner commits")
}

/// an honest proof of `blk` at `sh`, to bytes
fn prove_to_bytes(sh: &Shape, blk: &BlockPublic, w: Witness) -> (ExpectedIo, Vec<u8>) {
    let (expected, owners) = endpoints_at(sh, &w);
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners).expect("the honest proof");
    let bytes = receipt.to_bytes_at(sh, blk, &expected).expect("the frame");
    (expected, bytes)
}

/// What the shared proving body did with the caller's randomness and
/// transcript: the result, the bytes the generator gave out, the
/// transcript's squeeze count and whether its state moved. `ZkRng::
/// consumed_bytes` and `Transcript::squeezes` are `zkp-core`'s read-only
/// test observers (stage 36).
struct Core {
    res: Result<(), String>,
    consumed: u64,
    squeezes: u64,
    state_moved: bool,
}

/// Drive `protocol::prove_core` directly — the body the single-block prover
/// and every stage of a run share — with a deterministic public fixture
/// stream and the block's own transcript header, on real endpoint data.
fn direct_prove_core(sh: &Shape, blk: &BlockPublic, w: Witness) -> Core {
    let (expected, owners) = endpoints_at(sh, &w);
    let [ein, eout] = protocol::check_endpoints(sh, &expected, owners).expect("the endpoint owners");
    let lay = Layout::for_shape(sh).expect("the layout");
    let ntt = crate::ntt::NttTables::new(protocol::ntt_log_at(sh));
    let mut rng = ZkRng::new(40, b"stage 40: a public fixture stream for the direct prove_core call");
    let mut tr = protocol::transcript(blk, &expected, &lay);
    let (before, sq) = (tr.state(), tr.squeezes());
    let mut ph = timing::Phases::start();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let mut tick = std::time::Instant::now();
    let res = protocol::prove_core(sh, &lay, blk, w, [ein.data.as_slice(), eout.data.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).map(|_| ());
    Core { res, consumed: rng.consumed_bytes(), squeezes: tr.squeezes() - sq, state_moved: tr.state() != before }
}

/// a one-block run's witness source: the one witness it was handed
struct OneWitness(Option<Witness>);

impl RunWitnessSource for OneWitness {
    fn witness(&mut self, _k: usize) -> Result<Witness, String> {
        self.0.take().ok_or_else(|| "stage 40: the one witness was already handed out".to_string())
    }
    fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
        Err("stage 40: a one-block run has no internal boundary".into())
    }
}

// ------------------------------------------------------------------ C-1 / CS-1

/// The C-1 case: the attention half built at rung-K4, the feed-forward half's
/// SAME padded words (rung-K4's own zero-padded matrices) built at rung-P2 with
/// `act[128] = 1`, and the all-ones input.
struct C1 {
    k4: Shape,
    w: [Vec<i8>; 9],
    cos: Vec<i64>,
    sin: Vec<i64>,
    exp: Vec<i64>,
    act: Vec<i16>,
    x: Vec<i16>,
}

fn c1_case() -> C1 {
    let k4 = Shape::rung_k4();
    let w = zero_words(&k4);
    let (cos, sin) = identity_rope(&k4);
    let (exp, _) = crate::tables_attn::exp_member(0, k4.head_dim, k4.f_e);
    let mut act = silu();
    act[128] = 1;
    let x = vec![1i16; k4.tokens * k4.width];
    C1 { k4, w, cos, sin, exp: exp.to_vec(), act, x }
}

/// the cross-shape statement: attention at rung-K4, feed-forward at rung-P2
fn c1_statement(c: &C1) -> Result<BlockPublic, String> {
    let p2 = Shape::rung_p2();
    let aw = super::grow_tests::pad_attention_weights(&c.k4, &c.w[0], &c.w[1], &c.w[2], &c.w[3], &c.w[4]);
    let fw = super::grow_tests::pad_ff_weights(&c.k4, &c.w[5], &c.w[6], &c.w[7], &c.w[8]);
    let att = AttentionPublic::new_shaped(&c.k4, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &c.cos, &c.sin, &c.exp)?;
    let ff = FeedForwardPublic::new_shaped(&p2, &fw[0], &fw[1], &fw[2], &fw[3], &c.act)?;
    Ok(BlockPublic::new(att, ff))
}

/// The P-2 sibling of C-1 (the check names it and did not build it): the
/// same zero words and the SiLU member (`act[128] = 0`), but one `Wg` entry
/// at feed-forward column 200 — a TRUE column at rung-P2 (`hidden = 256`)
/// and a PADDED one at rung-K4 (`hidden = 192`) — with the feed-forward half
/// built at rung-P2.
fn c1b_statement(k4: &Shape) -> Result<BlockPublic, String> {
    let p2 = Shape::rung_p2();
    let w = zero_words(k4);
    let (cos, sin) = identity_rope(k4);
    let (exp, _) = crate::tables_attn::exp_member(0, k4.head_dim, k4.f_e);
    let aw = super::grow_tests::pad_attention_weights(k4, &w[0], &w[1], &w[2], &w[3], &w[4]);
    let mut fw = super::grow_tests::pad_ff_weights(k4, &w[5], &w[6], &w[7], &w[8]);
    assert!(k4.hidden <= 200 && 200 < p2.hidden && 200 < k4.f_pad, "column 200 is padded at rung-K4 and true at rung-P2");
    fw[1][200] = 5; // Wg (input 0, output 200)
    let att = AttentionPublic::new_shaped(k4, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp)?;
    let ff = FeedForwardPublic::new_shaped(&p2, &fw[0], &fw[1], &fw[2], &fw[3], &silu())?;
    Ok(BlockPublic::new(att, ff))
}

/// **RULING CS-1, END TO END: a feed-forward statement is re-checked against
/// the shape it is proved at, and refused BY NAME at every point it meets
/// it.** The C-1 statement (rung-K4 block, feed-forward half built at
/// rung-P2 with `act[128] = 1`), offered at rung-K4:
///
/// 1. the witness builder refuses it;
/// 2. the single-block prover's entry refuses it, handed a real witness (of
///    the same block with the member table) and real endpoint owners;
/// 3. the shared proving body `prove_core`, called directly, refuses it with
///    NOTHING drawn from the generator, nothing squeezed and the transcript
///    state unmoved;
/// 4. the verifier's bytes entry and its in-memory entry refuse it, offered
///    an honest receipt of that other block;
/// 5. `RunStatement::new` refuses it;
/// 6. the run prover refuses it, handed a run statement of the honest block,
///    before the sink is called once;
/// 7. the run verifier refuses it, offered that honest run's segment.
///
/// Every refusal is ruling CS-1's name followed by the constructor's own
/// (S38-F1(a)'s) — the run's prefixed with the block index. The constructor
/// at rung-P2 still admits the words (the constructor sees rung-P2).
#[test]
fn s40_cs1_a_cross_shape_feed_forward_statement_is_refused_by_name_wherever_it_meets_the_shape_it_is_proved_at() {
    let c = c1_case();
    let k4 = c.k4.clone();
    let blk = c1_statement(&c).expect("the constructor at rung-P2 admits the words (it is asked about rung-P2)");
    let want = cs1(S38_F1_REFUSAL);
    // the SAME block with the member table (act[128] = 0) is a legal rung-K4 statement
    let good = statement(&k4, &c.w, &c.cos, &c.sin, &c.exp, &silu()).expect("the rung-K4 statement with the member table");
    let honest = || witness::build_shaped(&k4, good.attention(), good.feed_forward(), &c.x).expect("the builder admits the honest block");

    // 0. the one function, asked directly (added after the fix: it did not
    //    exist before it); it admits the half at the shape it was built at
    assert_eq!(blk.feed_forward().check_for_shape(&k4).err(), Some(want.clone()), "0. check_for_shape at rung-K4");
    assert!(blk.feed_forward().check_for_shape(&Shape::rung_p2()).is_ok(), "0. check_for_shape refuses the half at the shape it was built at");
    // 1. the builder
    let r = witness::build_shaped(&k4, blk.attention(), blk.feed_forward(), &c.x);
    assert_eq!(r.err(), Some(want.clone()), "1. the witness builder did not refuse the cross-shape statement by ruling CS-1's name");
    // 2. the prover's entry
    let w = honest();
    let (expected, owners) = endpoints_at(&k4, &w);
    let r = prove_inner_at(&k4, &blk, w, &expected, owners);
    assert_eq!(r.err(), Some(want.clone()), "2. the prover's entry did not refuse by ruling CS-1's name");
    // 3. the shared body, nothing drawn or absorbed
    let core = direct_prove_core(&k4, &blk, honest());
    assert_eq!(core.res.as_ref().err(), Some(&want), "3. prove_core did not refuse by ruling CS-1's name");
    assert_eq!((core.consumed, core.squeezes, core.state_moved), (0, 0, false), "3. prove_core drew, squeezed or absorbed before the CS-1 refusal");
    // 4. the verifier: an honest receipt of the GOOD block, offered with the cross-shape one
    let (expected_g, bytes_g) = prove_to_bytes(&k4, &good, honest());
    assert!(verify_bytes_at(&k4, &good, &expected_g, &bytes_g).is_ok(), "the honest control receipt does not verify");
    let r = verify_bytes_at(&k4, &blk, &expected_g, &bytes_g);
    assert_eq!(r.err(), Some(want.clone()), "4. the verifier's bytes entry did not refuse by ruling CS-1's name");
    let receipt = Receipt::from_bytes_at(&k4, &good, &expected_g, &bytes_g).expect("the control frame decodes");
    let r = protocol::verify_inner_at(&k4, &blk, &expected_g, &receipt).map(|_| ());
    assert_eq!(r.err(), Some(want.clone()), "4. the verifier's in-memory entry did not refuse by ruling CS-1's name");
    // 5. the run statement
    let w = honest();
    let (expected_r, _owners) = endpoints_at(&k4, &w);
    let r = RunStatement::new(RunShape::rung_k4(1).expect("run shape"), check_context(), expected_r, &[blk.clone()], &[(0, 0)]);
    assert_eq!(r.err(), Some(cs1_run(0, S38_F1_REFUSAL)), "5. RunStatement::new did not refuse by ruling CS-1's name");
    // 6. the run prover, under a statement of the honest block
    let (expected_r, owners) = endpoints_at(&k4, &w);
    let st = RunStatement::new(RunShape::rung_k4(1).expect("run shape"), check_context(), expected_r, &[good.clone()], &[(0, 0)]).expect("the honest one-block run statement");
    let mut src = OneWitness(Some(w));
    let mut sunk = 0usize;
    let r = run::prove_run(&st, &[blk.clone()], &mut src, owners, &mut |_, _| {
        sunk += 1;
        Ok(())
    });
    assert_eq!(r.err(), Some(cs1_run(0, S38_F1_REFUSAL)), "6. the run prover did not refuse by ruling CS-1's name");
    assert_eq!(sunk, 0, "6. the run prover handed a segment to the sink before refusing");
    // 7. the run verifier, offered the honest run's segment
    let w = honest();
    let (expected_r, owners) = endpoints_at(&k4, &w);
    let st = RunStatement::new(RunShape::rung_k4(1).expect("run shape"), check_context(), expected_r, &[good.clone()], &[(0, 0)]).expect("the honest one-block run statement");
    let mut segs: Vec<Vec<u8>> = Vec::new();
    run::prove_run(&st, &[good.clone()], &mut OneWitness(Some(w)), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the honest one-block run");
    assert!(run::verify_run(&st, &[good.clone()], &segs).is_ok(), "the honest control run does not verify");
    let r = run::verify_run(&st, &[blk.clone()], &segs);
    assert_eq!(r.err(), Some(cs1_run(0, S38_F1_REFUSAL)), "7. the run verifier did not refuse by ruling CS-1's name");
    eprintln!("S40 CS-1 (C-1 case): the rung-P2-built feed-forward half in a rung-K4 block is refused by ruling CS-1's name at the builder, the prover's entry, prove_core (0 bytes drawn, 0 squeezes, transcript unmoved), the verifier's two entries, RunStatement::new, the run prover (0 segments sunk) and the run verifier");
}

/// **RULING CS-1 carries ruling P-2 as well** (the sibling the check named
/// and did not build): a `Wg` entry at feed-forward column 200, legal at
/// rung-P2 and padded at rung-K4, with the half built at rung-P2 — refused by
/// ruling CS-1's name followed by P-2's at the builder, the prover's entry
/// and the verifier's entry. The same words ASKED about rung-K4 are refused
/// by the constructor with P-2's own name (the control).
#[test]
fn s40_cs1_the_padded_weight_check_of_ruling_p2_is_re_run_against_the_shape_it_is_proved_at() {
    let k4 = Shape::rung_k4();
    let blk = c1b_statement(&k4).expect("the constructor at rung-P2 admits a Wg entry at column 200");
    // control: the same padded words asked about rung-K4
    let fw = blk.feed_forward();
    let own = FeedForwardPublic::new_shaped(&k4, &fw.gamma_m, &fw.wg_t, &fw.wu_t, &fw.wd_t, &fw.act);
    assert_eq!(own.err().as_deref(), Some(P2_PADDED_WIDTH), "the constructor at rung-K4 no longer refuses the padded Wg entry by P-2's name");
    let want = cs1(P2_PADDED_WIDTH);
    let x = vec![1i16; k4.tokens * k4.width];
    let r = witness::build_shaped(&k4, blk.attention(), blk.feed_forward(), &x);
    assert_eq!(r.err(), Some(want.clone()), "the builder did not refuse the P-2 cross-shape statement by ruling CS-1's name");
    // the prover's and the verifier's entries, on a real witness and an honest receipt of the zero block
    let (cos, sin) = identity_rope(&k4);
    let (exp, _) = crate::tables_attn::exp_member(0, k4.head_dim, k4.f_e);
    let good = statement(&k4, &zero_words(&k4), &cos, &sin, &exp, &silu()).expect("the zero rung-K4 statement");
    let honest = || witness::build_shaped(&k4, good.attention(), good.feed_forward(), &x).expect("the honest zero block");
    let w = honest();
    let (expected, owners) = endpoints_at(&k4, &w);
    assert_eq!(prove_inner_at(&k4, &blk, w, &expected, owners).err(), Some(want.clone()), "the prover's entry did not refuse by ruling CS-1's name");
    let (expected_g, bytes_g) = prove_to_bytes(&k4, &good, honest());
    assert_eq!(verify_bytes_at(&k4, &blk, &expected_g, &bytes_g).err(), Some(want.clone()), "the verifier's entry did not refuse by ruling CS-1's name");
    eprintln!("S40 CS-1 (P-2 sibling): a Wg entry at column 200 (true at rung-P2, padded at rung-K4) refused by ruling CS-1 + P-2's name at the builder, the prover and the verifier");
}

/// **C-1 REPRODUCER (the check's, re-run): an admitted cross-shape statement
/// never reaches a receipt the verifier rejects.** Before stage 40 it did —
/// `verifier rejected: H: pcs zk: group 8` (`s40-before-reproducers.log`).
/// Since ruling CS-1 the builder refuses it, so no receipt exists.
#[test]
fn c1_reproducer_an_admitted_cross_shape_statement_is_refused_before_a_receipt_exists() {
    let c = c1_case();
    let r: Result<Outcome, String> = (|| {
        let blk = c1_statement(&c)?;
        let wit = witness::build_shaped(&c.k4, blk.attention(), blk.feed_forward(), &c.x)?;
        Ok(outcome(&c.k4, &blk, wit))
    })();
    let verdict = match &r {
        Err(e) => format!("refused before any receipt: {e}"),
        Ok(o) => o.short(),
    };
    eprintln!("C-1 REPRODUCER rung-K4 + rung-P2 feed-forward, act[128] = 1: {verdict}");
    assert!(!matches!(r, Ok(Outcome::VerifierRejected(_))), "C-1: an admitted statement produced a receipt the verifier rejects ({verdict})");
}

/// **The P-2 sibling's reproducer**, the same property: before stage 40 the
/// rung-P2-built `Wg` entry at a column rung-K4 pads was admitted by the
/// builder and proved, and the verifier rejected the receipt
/// (`s40-before-named.log`). Since ruling CS-1 the builder refuses it.
#[test]
fn c1b_reproducer_a_cross_shape_padded_weight_is_refused_before_a_receipt_exists() {
    let k4 = Shape::rung_k4();
    let x = vec![1i16; k4.tokens * k4.width];
    let r: Result<Outcome, String> = (|| {
        let blk = c1b_statement(&k4)?;
        let wit = witness::build_shaped(&k4, blk.attention(), blk.feed_forward(), &x)?;
        Ok(outcome(&k4, &blk, wit))
    })();
    let verdict = match &r {
        Err(e) => format!("refused before any receipt: {e}"),
        Ok(o) => o.short(),
    };
    eprintln!("C-1b REPRODUCER rung-K4 + rung-P2 feed-forward, Wg column 200: {verdict}");
    assert!(!matches!(r, Ok(Outcome::VerifierRejected(_))), "C-1b: an admitted statement produced a receipt the verifier rejects ({verdict})");
}

// ------------------------------------------------------------------ C-2 / CS-2

/// rung-G's geometry with the softmax window overridden to `w` bits (its own
/// derivation, `clog2(24) + 12`, is 17)
fn rung_g_with_wrho_s(w: u32) -> Result<Shape, String> {
    let profile: &'static str = Box::leak(format!("hashline-zk-mr1/s40-wrho{w}-dev/1").into_boxed_str());
    Shape::new("stage 40: rung-G geometry, softmax window overridden (T24 / d96 / f192)", profile, 24, 96, 192, 6, 16, 2, 10, 4, 12, 9, None, None, None, Some(w))
}

/// rung-G's geometry with the norm window overridden to `w` bits
fn rung_g_with_norm_wrho(w: u32) -> Result<Shape, String> {
    let profile: &'static str = Box::leak(format!("hashline-zk-mr1/s40-norm{w}-dev/1").into_boxed_str());
    Shape::new("stage 40: rung-G geometry, norm window overridden (T24 / d96 / f192)", profile, 24, 96, 192, 6, 16, 2, 10, 4, 12, 9, None, None, Some(w), None)
}

/// The C-2 statement, TRUE-sized, at rung-G's geometry (the check's words):
///
/// * the input is one-hot per token with magnitude 1000: token 0 on column
///   0, tokens 1..=22 on column 1, token 23 on column 2;
/// * keys: column 0 gives `k = (64, 0, ..)`, columns 1 and 2 give `k = (0, 64,
///   ..)`; queries: column 1 gives `q = (2, 0, ..)`, column 2 gives `q = (0,
///   1, ..)`; identity RoPE;
/// * the exp table is `[4096, 1250, 0, ...]` (legal);
/// * values, output projection and the feed-forward are zero.
///
/// Row 23 has 23 tied maxima and `j = 0` one step below: `Sum = 95,458`,
/// `rho_s = 92,534` (and 67,252 at `j = 0`) — above `2^15`, below `2^17`.
fn c2_words(s: &Shape) -> ([Vec<i8>; 9], Vec<i64>, Vec<i64>, Vec<i64>, Vec<i16>, Vec<i16>) {
    let mut w = zero_words(s);
    let (d, dh) = (s.width, s.head_dim);
    for h in 0..s.q_heads {
        w[0][(h * dh) * d + 1] = 3;
        w[0][(h * dh + 1) * d + 2] = 1;
    }
    for kv in 0..s.kv_heads {
        w[1][(kv * dh) * d] = 127;
        w[1][(kv * dh + 1) * d + 1] = 127;
        w[1][(kv * dh + 1) * d + 2] = 127;
    }
    let (cos, sin) = identity_rope(s);
    let mut exp = vec![0i64; 256];
    exp[0] = 1 << s.f_e;
    exp[1] = 1250;
    let mut x = vec![0i16; s.tokens * d];
    for t in 0..s.tokens {
        let col = if t == 0 {
            0
        } else if t + 1 < s.tokens {
            1
        } else {
            2
        };
        x[t * d + col] = 1000;
    }
    (w, cos, sin, exp, silu(), x)
}

/// **RULING CS-2, THE SOFTMAX WINDOW.** `Shape::new` refuses, by name, a
/// `wrho_s` override below `clog2(tokens) + f_e` — at rung-G's geometry 15
/// and 16 (the check's reproducer is 15) — and keeps one at or above it: 17
/// (the derivation) builds the same windows as no override, and 18 is
/// admitted and PROVES the C-2 input (the case whose last-row `rho_s` needs
/// more than 15 bits), accepted by the verifier.
///
/// Over a grid of geometries `Shape::new` admits, an override equal to the
/// derivation is admitted and one bit below it is refused: the refusal is
/// exactly "below the derivation", which is exactly `tokens 2^f_e > 2^wrho_s`.
#[test]
fn s40_cs2_a_softmax_window_override_below_its_derivation_is_refused_by_name() {
    for w in [15u32, 16] {
        let r = rung_g_with_wrho_s(w);
        let e = r.err().unwrap_or_else(|| panic!("CS-2: Shape::new admitted wrho_s = {w} at rung-G's geometry (derived 17)"));
        assert!(e.starts_with(&format!("{CS2_WRHO}{w} ")), "wrho_s = {w} refused, but not by ruling CS-2's name: {e}");
    }
    let at = rung_g_with_wrho_s(17).expect("the derivation itself is admitted");
    let g = Shape::rung_g();
    assert_eq!((at.wrho_s, at.norm_wrho, at.limbs_sigma_s()), (g.wrho_s, g.norm_wrho, g.limbs_sigma_s()), "an override equal to the derivation builds other windows");
    let above = rung_g_with_wrho_s(18).expect("an override above the derivation is kept");
    let (w, cos, sin, exp, act, x) = c2_words(&above);
    let blk = statement(&above, &w, &cos, &sin, &exp, &act).expect("the C-2 statement at wrho_s = 18");
    let wit = witness::build_shaped(&above, blk.attention(), blk.feed_forward(), &x).expect("the builder admits the C-2 input at wrho_s = 18");
    assert!(u8_misses(&above, &wit).is_empty(), "the C-2 input misses the byte table at wrho_s = 18");
    let o = outcome(&above, &blk, wit);
    assert_eq!(o, Outcome::Accepted, "the C-2 input at the kept override wrho_s = 18 did not prove: {}", o.short());
    // the grid: the refusal is exactly "one bit below the derivation"
    let (mut shapes, mut refused) = (0usize, 0usize);
    for tokens in [16usize, 24, 32, 48, 64] {
        for (q, dh, kv) in [(6usize, 16usize, 2usize), (12, 8, 4), (8, 16, 2), (4, 32, 1)] {
            for f_e in [9u32, 12, 16] {
                let width = q * dh;
                let base = Shape::new("stage 40 grid", "hashline-zk-mr1/s40-grid/1", tokens, width, 2 * width, q, dh, kv, 10, 4, f_e, 9, None, None, None, None);
                let Ok(base) = base else { continue };
                shapes += 1;
                let derived = base.wrho_s;
                assert!((tokens as u128) << f_e <= 1u128 << derived, "the derivation itself does not hold tokens 2^f_e at {tokens}/{width}/{f_e}");
                let at = Shape::new("stage 40 grid", "hashline-zk-mr1/s40-grid/1", tokens, width, 2 * width, q, dh, kv, 10, 4, f_e, 9, None, None, None, Some(derived));
                assert_eq!(at.map(|s| s.wrho_s), Ok(derived), "the derivation as an override is refused at {tokens}/{width}/{f_e}");
                let below = Shape::new("stage 40 grid", "hashline-zk-mr1/s40-grid/1", tokens, width, 2 * width, q, dh, kv, 10, 4, f_e, 9, None, None, None, Some(derived - 1));
                let e = below.err().unwrap_or_else(|| panic!("CS-2: one bit below the derivation admitted at {tokens}/{width}/{f_e}"));
                assert!(e.starts_with(CS2_WRHO), "one bit below refused, but not by ruling CS-2's name: {e}");
                assert!((tokens as u128) << f_e > 1u128 << (derived - 1), "the refused override would have held tokens 2^f_e");
                refused += 1;
            }
        }
    }
    assert!(shapes > 20, "the grid admitted only {shapes} geometries");
    eprintln!("S40 CS-2 wrho_s: 15 and 16 refused by name at rung-G's geometry, 17 = the derivation, 18 kept and the C-2 input PROVES there (accepted); grid: {shapes} geometries, the derivation admitted and one bit below refused at every one ({refused})");
}

/// **C-2 REPRODUCER (the check's, re-run): an input the builder admits at a
/// shape `Shape::new` admits is proved.** Before stage 40, `Shape::new`
/// admitted `wrho_s = 15` at rung-G's geometry and the C-2 input's honest
/// proof was rejected by the verifier (`s40-before-reproducers.log`). Since
/// ruling CS-2 that shape does not construct, so the property holds by
/// refusal; the control at rung-G (the derived window) still proves.
#[test]
fn c2_reproducer_an_admitted_input_at_an_admitted_shape_proves() {
    let g = Shape::rung_g();
    let (wg, cg, sg, eg, ag, xg) = c2_words(&g);
    let blk_g = statement(&g, &wg, &cg, &sg, &eg, &ag).expect("the rung-G statement");
    let wit_g = witness::build_shaped(&g, blk_g.attention(), blk_g.feed_forward(), &xg).expect("the builder admits at rung-G");
    let og = outcome(&g, &blk_g, wit_g);
    eprintln!("C-2 REPRODUCER control rung-G (wrho_s = 17): {}", og.short());
    assert_eq!(og, Outcome::Accepted, "the control itself does not prove: {}", og.short());
    match rung_g_with_wrho_s(15) {
        Err(e) => {
            eprintln!("C-2 REPRODUCER wrho_s = 15: Shape::new refuses: {e}");
            assert!(e.starts_with(&format!("{CS2_WRHO}15 ")), "refused, but not by ruling CS-2's name: {e}");
        }
        Ok(sh) => {
            let (w, cos, sin, exp, act, x) = c2_words(&sh);
            let blk = statement(&sh, &w, &cos, &sin, &exp, &act).expect("the statement");
            let wit = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &x).expect("the builder admits");
            let o = outcome(&sh, &blk, wit);
            eprintln!("C-2 REPRODUCER wrho_s = 15: {}", o.short());
            assert_eq!(o, Outcome::Accepted, "C-2: an input the builder admits at a shape Shape::new admits was not proved: {}", o.short());
        }
    }
}

/// the smallest norm window that holds the norm denominator for EVERY int16
/// input (`-32768` is legal, so the bound is `32768`, not `Shape::new`'s
/// `32767`): `isqrt(1 + width 32768^2) 2^(tn + 1) <= 2^w`
fn norm_window_needed(width: usize) -> u32 {
    let d = witness::isqrt(1 + width as u64 * 32768 * 32768) as u128;
    let den = d << 12;
    (0u32..128).find(|w| den <= 1u128 << w).expect("a window below 2^128")
}

/// **RULING CS-2, THE NORM WINDOW.** `Shape::new` refuses, by name, a
/// `norm_wrho` override below its derivation — at rung-G's geometry the
/// derivation is 31 and 30 is refused; 31 and 32 are kept. The derivation
/// (`tn + 1 + bits(isqrt(1 + width 32767^2))`, `Shape::new`'s own) equals
/// the smallest window that holds the denominator under the input bound
/// 32768 at every registered shape and over the grid of admitted widths, so
/// "below the derivation" and "below what the 32768 bound needs" are the same
/// refusal there. (Why this is the MILDER case: an undersized norm window
/// makes the norm remainder reachable, and the builder refuses that remainder
/// BY NAME — a data-dependent refusal before any proof, not a proof that
/// fails. MEASURED below while the shape still constructed.)
#[test]
fn s40_cs2_a_norm_window_override_below_its_derivation_is_refused_by_name() {
    let g = Shape::rung_g();
    assert_eq!(g.norm_wrho, 31, "rung-G's derived norm window");
    let registered = [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125(), super::k8_tests::rung_k8()];
    for s in registered.iter() {
        assert_eq!(norm_window_needed(s.width), s.norm_wrho, "{}: the derived norm window is not the smallest that holds the 32768 bound", s.name);
    }
    // every width up to 2^14: the two agree. Above it they can DIFFER, and
    // that is recorded, not asserted away: there the unoverridden derivation
    // itself is one bit short of the 32768 bound (the milder case, outside
    // this ruling, which is about overrides). MEASURED before the fix: the
    // first is width 16,385 (`s40-before-named.log`: 35 needed, 34 derived).
    let derived_of = |width: usize| 12 + (128 - (witness::isqrt(1 + width as u64 * 32767 * 32767) as u128).leading_zeros());
    let mut widths = 0usize;
    for width in 1usize..=16384 {
        assert_eq!(norm_window_needed(width), derived_of(width), "width {width}: the 32767 derivation and the 32768 bound's window differ");
        widths += 1;
    }
    let differing: Vec<usize> = (16385usize..=1 << 20).filter(|w| norm_window_needed(*w) != derived_of(*w)).collect();
    assert_eq!(differing.first(), Some(&16385), "the first width where the derivation is short moved");
    assert!(differing.iter().all(|w| norm_window_needed(*w) == derived_of(*w) + 1), "somewhere the derivation is more than one bit short");
    eprintln!(
        "S40 CS-2 norm: widths 1..=16384 — the 32767 derivation IS the 32768 bound's window; widths 16385..=2^20 — it is one bit short at {} widths (first {:?}, last {:?}); no registered shape is wider than 768",
        differing.len(),
        differing.first(),
        differing.last()
    );
    match rung_g_with_norm_wrho(30) {
        Err(e) => assert!(e.starts_with(&format!("{CS2_NORM}30 ")), "norm_wrho = 30 refused, but not by ruling CS-2's name: {e}"),
        Ok(_) => panic!("CS-2: Shape::new admitted norm_wrho = 30 at rung-G's geometry (derived 31)"),
    }
    // the milder case, MEASURED on a window set past `Shape::new` (a
    // test-side field edit of rung-G, which no production path can make):
    // the builder refuses the reachable norm remainder BY NAME on a
    // full-scale input and admits a small one — input-dependent, but a
    // refusal before any proof, not a proof that fails
    let mut narrow = Shape::rung_g();
    narrow.norm_wrho = 30;
    let (public, ff, small) = super::dense_tests::dense_case(&narrow);
    let big: Vec<i16> = (0..narrow.tokens * narrow.width).map(|k| if k % 2 == 0 { 32767 } else { -32768 }).collect();
    let norm_refusal = "fixed oracle range refusal: norm quotient/remainder";
    let rb = witness::build_shaped(&narrow, &public, &ff, &big).err();
    assert_eq!(rb.as_deref(), Some(norm_refusal), "the full-scale input at a 30-bit norm window");
    assert!(witness::build_shaped(&narrow, &public, &ff, &small).is_ok(), "the dense recipe's input at a 30-bit norm window");
    let at_g = witness::build_shaped(&g, &public, &ff, &big).err();
    assert_ne!(at_g.as_deref(), Some(norm_refusal), "the full-scale input at rung-G's own 31-bit window is refused at the norm");
    eprintln!("S40 CS-2 norm (the milder case, a 30-bit window set past Shape::new): the full-scale input refused by the builder BY NAME ({norm_refusal}), the dense input admitted; at rung-G's own 31-bit window the full-scale input passes the norm (builder: {at_g:?})");
    for w in [31u32, 32] {
        let s = rung_g_with_norm_wrho(w).unwrap_or_else(|e| panic!("norm_wrho = {w} (at or above the derivation) refused: {e}"));
        assert_eq!(s.norm_wrho, w);
    }
    eprintln!("S40 CS-2 norm_wrho: 30 refused by name at rung-G's geometry (derived 31), 31 and 32 kept; the derivation equals the 32768 bound's window at every registered shape and at every width 1..=16384 ({widths} widths)");
}

// ------------------------------------------------------------------ CS-3

/// the dense rung-G block and its honest witness
fn dense_g() -> (Shape, BlockPublic, Vec<i16>) {
    let g = Shape::rung_g();
    let (public, ff, x) = super::dense_tests::dense_case(&g);
    (g, BlockPublic::new(public, ff), x)
}

/// the three single-miss witnesses: one U8 word, one exp pair, one
/// activation pair, each at a TRUE position of an honest dense witness
fn tampered(which: usize) -> (Shape, BlockPublic, Witness, &'static str) {
    let (g, blk, x) = dense_g();
    let mut w = witness::build_shaped(&g, blk.attention(), blk.feed_forward(), &x).expect("the honest dense witness");
    let ids = Ids::new(&g).expect("the plane map");
    let what = match which {
        0 => {
            // the low byte limb of x + 32768 at the first true position: 256 is not a byte
            let p = ids.at(A_XL0);
            w.planes[p][0] = 256;
            "a byte limb set to 256"
        }
        1 => {
            // one exp value moved off its table row
            let p = ids.at(A_E);
            w.planes[p][0] += 1;
            "an exp value moved by one"
        }
        _ => {
            // one activation value moved off its table row
            let p = ids.at(A_A16);
            w.planes[p][0] += 1;
            "an activation value moved by one"
        }
    };
    (g, blk, w, what)
}

/// **RULING CS-3: a lookup miss is ONE named prover refusal, before the `A`
/// commitment, with nothing drawn or absorbed.** Three witnesses, each the
/// honest dense rung-G witness with ONE looked-up value moved off its table
/// (a U8 word, an exp pair, an activation pair). The misses are counted here
/// independently (from `lookup_values`, `exp_deltas` and `act_indices`),
/// and:
///
/// * the single-block prover refuses each with ruling CS-3's name and those
///   counts;
/// * the shared body `prove_core`, called directly, refuses each with no byte
///   drawn from the generator, no squeeze and the transcript unmoved — while
///   on the HONEST witness it draws, squeezes and absorbs and returns a proof
///   (the control that the observers see a real call).
///
/// Before stage 40 each of these was filed in bucket 0 and PROVED, and only
/// the verifier's LogUp identity caught it (`s40-before-named.log`).
#[test]
fn s40_cs3_a_lookup_miss_is_one_named_prover_refusal_before_anything_is_drawn_or_absorbed() {
    // the control
    let (g, blk, x) = dense_g();
    let honest = witness::build_shaped(&g, blk.attention(), blk.feed_forward(), &x).expect("the honest dense witness");
    assert!(u8_misses(&g, &honest).is_empty() && exp_misses(&g, &blk, &honest).is_empty() && act_misses(&g, blk.feed_forward(), &honest).is_empty(), "the honest witness misses a table");
    let core = direct_prove_core(&g, &blk, honest);
    assert!(core.res.is_ok(), "the honest witness through prove_core: {:?}", core.res);
    assert!(core.consumed > 0 && core.squeezes > 0 && core.state_moved, "the observers saw nothing on an honest call ({} bytes, {} squeezes)", core.consumed, core.squeezes);
    for which in 0..3 {
        let (g, blk, w, what) = tampered(which);
        let counts = (u8_misses(&g, &w).len(), exp_misses(&g, &blk, &w).len(), act_misses(&g, blk.feed_forward(), &w).len());
        let mut want_nonzero = [0usize; 3];
        want_nonzero[which] = 1;
        assert_eq!([counts.0.min(1), counts.1.min(1), counts.2.min(1)], want_nonzero, "{what}: the tamper does not miss exactly its own table");
        let want = cs3(counts.0, counts.1, counts.2);
        let (expected, owners) = endpoints_at(&g, &w);
        let r = prove_inner_at(&g, &blk, w, &expected, owners).map(|_| ());
        assert_eq!(r.err(), Some(want.clone()), "{what}: the prover did not refuse by ruling CS-3's name");
        let (g, blk, w, _) = tampered(which);
        let core = direct_prove_core(&g, &blk, w);
        assert_eq!(core.res.as_ref().err(), Some(&want), "{what}: prove_core did not refuse by ruling CS-3's name");
        assert_eq!((core.consumed, core.squeezes, core.state_moved), (0, 0, false), "{what}: prove_core drew, squeezed or absorbed before the CS-3 refusal");
        // a CHEATING prover skips the refusal (the test-only switch the
        // soundness tests use), and the verifier still rejects its receipt
        let (g, blk, w, _) = tampered(which);
        let o = {
            let _cheat = protocol::CheatingProver::on();
            outcome(&g, &blk, w)
        };
        assert!(matches!(o, Outcome::VerifierRejected(_)), "{what}: past the CS-3 refusal the verifier did not reject: {}", o.short());
        eprintln!("S40 CS-3 {what}: misses (U8, exp, act) = {counts:?}; the prover and prove_core refuse by ruling CS-3's name, 0 bytes drawn, 0 squeezes, transcript unmoved; a cheating prover past it: {}", o.short());
    }
}

// ------------------------------------------------------------------ note C-6

/// SplitMix64, the dense recipe's portable stream
struct Mix(u64);

impl Mix {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    fn pick(&mut self, lo: i64, hi: i64) -> i64 {
        lo + (self.next() % ((hi - lo + 1) as u64)) as i64
    }
    fn nonzero(&mut self, mag: i64) -> i64 {
        let v = self.pick(1, 2 * mag);
        if v <= mag {
            -v
        } else {
            v - mag
        }
    }
}

/// A DENSE statement at a shape whose `width` need not be `q_heads *
/// head_dim`: every true entry nonzero, the head axis (`qw = q_heads *
/// head_dim`) and the width axis kept apart — `Wq` is `(qw, width)`, `Wo` is
/// `(width, qw)` — padded and head-permuted as ruling P-2 wants, with the
/// shape's own exp member and the SiLU member. The bands are the dense
/// recipe's (`dense_tests`).
fn dense_statement_any_width(s: &Shape, exp: &[i64]) -> (BlockPublic, Vec<i16>) {
    use super::dense_tests::{band_down, BAND_ATTN, BAND_GATE, GAIN, INPUT_MAG};
    let (d, f, qw, kvw, dp, fp) = (s.width, s.hidden, s.q_heads * s.head_dim, s.kv_heads * s.head_dim, s.d_pad, s.f_pad);
    let mut r = Mix(0x5400_0040_0000_0001 ^ d as u64);
    let mut mat = |outer: usize, inner: usize, mag: i64| -> Vec<i8> { (0..outer * inner).map(|_| r.nonzero(mag) as i8).collect() };
    let (wq, wk, wv, wo) = (mat(qw, d, BAND_ATTN), mat(kvw, d, BAND_ATTN), mat(kvw, d, BAND_ATTN), mat(d, qw, BAND_ATTN));
    let (wg, wu, wd) = (mat(d, f, BAND_GATE), mat(d, f, BAND_GATE), mat(f, d, band_down(s)));
    let mut rg = Mix(0x5400_0040_0000_0002);
    let ga: Vec<i8> = (0..d).map(|_| rg.pick(GAIN.0, GAIN.1) as i8).collect();
    let gm: Vec<i8> = (0..d).map(|_| rg.pick(GAIN.0, GAIN.1) as i8).collect();
    let id = |i: usize| i;
    let q = |j: usize| super::grow_tests::q_axis_index(s, j);
    let pm = super::grow_tests::pad_matrix;
    let (cos, sin) = crate::tables_attn::rope_tables_generate(s.tokens, s.head_dim, 10000.0, F_RO);
    let att = AttentionPublic::new_shaped(s, &pm(&wq, qw, d, dp, dp, &q, &id), &pm(&wk, kvw, d, kvw, dp, &id, &id), &pm(&wv, kvw, d, kvw, dp, &id, &id), &pm(&wo, d, qw, dp, dp, &id, &q), &pm(&ga, 1, d, 1, dp, &id, &id), &cos, &sin, exp)
        .expect("the dense attention statement");
    let ff = FeedForwardPublic::new_shaped(s, &pm(&gm, 1, d, 1, dp, &id, &id), &pm(&wg, d, f, dp, fp, &id, &id), &pm(&wu, d, f, dp, fp, &id, &id), &pm(&wd, f, d, fp, dp, &id, &id), &silu()).expect("the dense feed-forward statement");
    let mut rx = Mix(0x1DDE_0040_0000_0001);
    let x: Vec<i16> = (0..s.tokens * d).map(|_| rx.nonzero(INPUT_MAG) as i16).collect();
    (BlockPublic::new(att, ff), x)
}

/// **NOTE C-6, `width != q_heads * head_dim`.** `Shape::new` checks only
/// `d_pad == h_pad * head_dim`; the reference kernel refuses such a width
/// (`lib.rs:243`), so the builder and the kernel disagree on every input there
/// — a public-only fact. The question the disposition asks is whether such a
/// shape admits an input whose HONEST proof fails. MEASURED on rung-G's head
/// axis (6 heads of 16 over 2 key-value heads, `d_pad = 128`) at widths 72,
/// 90, 100 and 120 with a DENSE statement (every weight nonzero, heads that
/// differ) and a dense input: each is admitted by `Shape::new`, the builder
/// admits the input, and the proof is ACCEPTED by the verifier. The control
/// width 96 (= 6 x 16, rung-G itself) likewise.
#[test]
fn s40_c6_a_width_other_than_q_heads_times_head_dim_admits_no_failing_honest_proof() {
    let mut lines = Vec::new();
    for width in [72usize, 90, 96, 100, 120] {
        let profile: &'static str = Box::leak(format!("hashline-zk-mr1/s40-width{width}-dev/1").into_boxed_str());
        let sh = Shape::new("stage 40: rung-G head axis, width other than q_heads x head_dim", profile, 24, width, 192, 6, 16, 2, 10, 4, 12, 9, None, None, None, None).unwrap_or_else(|e| panic!("width {width}: Shape::new refused: {e}"));
        let (exp, _) = crate::tables_attn::exp_member(0, sh.head_dim, sh.f_e);
        let (blk, x) = dense_statement_any_width(&sh, &exp);
        let w = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &x).unwrap_or_else(|e| panic!("width {width}: the builder refused the dense input: {e}"));
        assert!(u8_misses(&sh, &w).is_empty() && exp_misses(&sh, &blk, &w).is_empty() && act_misses(&sh, blk.feed_forward(), &w).is_empty(), "width {width}: the honest witness misses a table");
        let o = outcome(&sh, &blk, w);
        lines.push(format!("width {width} (q_heads x head_dim = 96): {}", o.short()));
        assert_eq!(o, Outcome::Accepted, "width {width}: an honest dense proof at a shape Shape::new admits was not accepted: {}", o.short());
    }
    for l in &lines {
        eprintln!("S40 C-6 {l}");
    }
}

/// How far one `f_e` got: the first step that refused, or the verdict.
fn f_e_probe(f_e: u32) -> String {
    let profile: &'static str = Box::leak(format!("hashline-zk-mr1/s40-fe{f_e}-dev/1").into_boxed_str());
    let sh = match std::panic::catch_unwind(|| Shape::new("stage 40: rung-G geometry, f_e probe", profile, 24, 96, 192, 6, 16, 2, 10, 4, f_e, 9, None, None, None, None)) {
        Err(_) => return "Shape::new PANICS".into(),
        Ok(Err(e)) => return format!("Shape::new refuses: {e}"),
        Ok(Ok(s)) => s,
    };
    match std::panic::catch_unwind(|| Layout::for_shape(&sh).map(|_| ())) {
        Err(_) => return format!("wrho_s {} / Layout::for_shape PANICS", sh.wrho_s),
        Ok(Err(e)) => return format!("wrho_s {} / Layout::for_shape refuses: {e}", sh.wrho_s),
        Ok(Ok(())) => {}
    }
    // a legal exp table at this scale: E[0] = 2^f_e (as the constructor
    // computes it), halving per step, non-increasing, in [0, 2^f_e]
    let one_e = 1i64.wrapping_shl(f_e);
    let exp: Vec<i64> = (0..256u32).map(|d| if d < 63 { one_e >> d } else { 0 }).collect();
    let built = std::panic::catch_unwind(|| {
        let (blk, x) = dense_statement_any_width(&sh, &exp);
        (blk, x)
    });
    let (blk, x) = match built {
        Err(_) => {
            // the constructor refused the table (`expect` in the helper)
            let aw = super::grow_tests::pad_attention_weights(&sh, &zero_words(&sh)[0], &zero_words(&sh)[1], &zero_words(&sh)[2], &zero_words(&sh)[3], &zero_words(&sh)[4]);
            let (cos, sin) = identity_rope(&sh);
            let e = AttentionPublic::new_shaped(&sh, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp).err().unwrap_or_else(|| "the dense statement panicked".into());
            return format!("wrho_s {} / the statement refuses: {e}", sh.wrho_s);
        }
        Ok(v) => v,
    };
    let w = match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &x))) {
        Err(_) => return format!("wrho_s {} / the builder PANICS", sh.wrho_s),
        Ok(Err(e)) => return format!("wrho_s {} / the builder refuses: {e}", sh.wrho_s),
        Ok(Ok(w)) => w,
    };
    let misses = (u8_misses(&sh, &w).len(), exp_misses(&sh, &blk, &w).len(), act_misses(&sh, blk.feed_forward(), &w).len());
    match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| outcome(&sh, &blk, w))) {
        Err(_) => format!("wrho_s {} / lookup misses {misses:?} / the prover or verifier PANICS", sh.wrho_s),
        Ok(o) => format!("wrho_s {} / lookup misses {misses:?} / {}", sh.wrho_s, o.short()),
    }
}

/// **NOTE C-6, an unbounded `f_e`: YES, it admitted shapes whose honest
/// proofs fail, and `Shape::new` now refuses `f_e > 31` by name.** MEASURED
/// at rung-G's geometry with a legal exp table at each scale (`E[d] = 2^f_e
/// >> d`) and the dense statement and input. Before stage 40
/// (`s40-before-named.log`): `f_e` 0 and 1 refused by the layout (a
/// structural refusal), 4..=53 ACCEPTED, 54..=62 refused by the builder for
/// every input (its `i64` softmax arithmetic overflows), 63 refused by the
/// statement constructor, and **64, 65, 80, 200 — the constructor's
/// `1i64 << f_e` wraps — admitted by `Shape::new`, the constructor and the
/// builder, and every honest proof REJECTED by the verifier** (slot 17, the
/// softmax zero-check). Since stage 40 every `f_e` above 31 (the reference
/// kernel's own bound) is refused by `Shape::new` with note C-6's name, and
/// for every `f_e` either some step refuses BY NAME before a proof exists or
/// the honest proof is ACCEPTED — never a rejected honest proof, never a
/// panic.
#[test]
fn s40_c6_an_unbounded_f_e_admits_no_failing_honest_proof() {
    let mut bad = Vec::new();
    for f_e in [0u32, 1, 4, 9, 12, 16, 20, 24, 28, 31, 32, 36, 40, 44, 48, 52, 53, 54, 56, 60, 62, 63, 64, 65, 80, 200, u32::MAX - 4, u32::MAX] {
        let v = f_e_probe(f_e);
        eprintln!("S40 C-6 f_e = {f_e}: {v}");
        if v.contains("verifier rejected") || v.contains("PANICS") || v.contains("prover refused") {
            bad.push(format!("f_e = {f_e}: {v}"));
        }
        if f_e > 31 {
            assert!(v.starts_with("Shape::new refuses: private block shape: note C-6 — f_e = "), "f_e = {f_e} is not refused by Shape::new with note C-6's name: {v}");
        } else if f_e >= 4 {
            assert!(v.ends_with("ACCEPTED"), "f_e = {f_e} inside the kernel's range no longer proves: {v}");
        }
    }
    assert!(bad.is_empty(), "C-6: an f_e Shape::new admits yields an honest proof that fails:\n{}", bad.join("\n"));
}
