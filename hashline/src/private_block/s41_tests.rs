//! **STAGE 41 (test-only): rulings CS-4 and CS-5 of the shaped refusal census
//! disposition** (`docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS_DISPOSITION.md`
//! §5, security owner), on stage 40's two open notes.
//!
//! * **CS-4 (finding S40-N2)** — ruling CS-1 extends to EVERY part of a block
//!   or run statement. The parts a statement is assembled from, enumerated
//!   from the code (census memo §10 has the table): the ATTENTION half (four
//!   weight matrices, the first norm gain `gamma_a`, the two rotary tables and
//!   the exp table — lengths, ruling P-2's support, the table structures, all
//!   keyed on a shape), the feed-forward half (ruling CS-1, stage 40), and the
//!   ENDPOINT POLICY's spec (`IoSpec`: the padded plane, the endpoint
//!   construction, its commitment parameters and its hash tag, all DERIVED
//!   from a shape at construction and never compared with a shape again). The
//!   calibration identity, the pinned endpoint and interior scales and the
//!   context carry no shape. Each shape-keyed part has ONE check against a
//!   shape, called by its constructor and re-run, by name, wherever it meets
//!   the shape it is proved at — the points stage 40 chose — before anything
//!   is absorbed, committed or drawn.
//! * **CS-5 (finding S40-N1)** — `Shape::new` refuses a width above 16,384 by
//!   name: from 16,385 on the norm window it derives from the 32767 bound can
//!   be one bit short of the 32768 input bound.
//!
//! FAILING FIRST. The reproducers and the named tests below were written and
//! run at the lane tip `718ec01` before any production line moved
//! (`results/zk60_block125m_lane/s41-before-*.log`).
//!
//! Two notes were MEASURED here and not built (outside the rulings; lane
//! ledger stage 41): a registered run profile over another block shape, and
//! a run verifier handed blocks other than the ones its statement digests.
//! Stage 42 built rulings CS-7 and CS-6 on them and flipped both tests to
//! the refusals (`s42_tests.rs` has the failing-first evidence).
//!
//! Nothing here is a privacy result. Everything proved is PUBLIC SYNTHETIC
//! test data.

use super::layout::*;
use super::protocol::{self, prove_inner_at, CoreView};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use crate::zk::ZkRng;
use std::panic::{catch_unwind, AssertUnwindSafe};

// ---------------------------------------------------------------- the names

/// **RULING CS-4's names**, held as literals so that the tests could be
/// written, and run failing, before the production text existed: the prefix
/// of the attention half's re-check and of the endpoint policy's
const CS4_ATTENTION: &str = "private block: ruling CS-4 — the attention statement does not fit the shape it is proved at";
const CS4_POLICY: &str = "private block: ruling CS-4 — the endpoint policy does not fit the shape it is proved at";
/// **RULING CS-5's name**, up to the width
const CS5: &str = "private block shape: ruling CS-5 — width ";
/// the constructor's own refusals the CS-4 prefix is put before
const P2_HEAD_SLOT: &str = "private block: a public weight is nonzero at a padded head slot";
const P2_PADDED_WIDTH: &str = "private block: a public weight is nonzero at a padded width index";
const TABLE_SHAPE: &str = "private block: public table shape";
const EXP_STRUCTURE: &str = "private block: exp table structure";
/// the policy re-check's two refusals this file reaches
const POLICY_TAG: &str = "its hash tag is not this shape's (the endpoints were committed under another profile's hashing rule)";
const POLICY_TOY_PLANE: &str = "its padded endpoint plane is (32, 128), this shape's is (32, 16)";

fn cs4_att(inner: &str) -> String {
    format!("{CS4_ATTENTION}: {inner}")
}

fn cs4_att_run(k: usize, inner: &str) -> String {
    format!("private run: block {k}: {}", cs4_att(inner))
}

fn cs4_policy(inner: &str) -> String {
    format!("{CS4_POLICY}: {inner}")
}

fn cs4_policy_run(inner: &str) -> String {
    format!("private run: {}", cs4_policy(inner))
}

fn ctx() -> Digest {
    *blake3::hash(b"stage 41: rulings CS-4 and CS-5").as_bytes()
}

// ---------------------------------------------------------------- the shapes

/// rung-K4's head axis (12 heads of 8 over 4) at 48 tokens: the same padded
/// weight lengths as rung-K4, rotary tables twice as long
fn k4_t48() -> Shape {
    Shape::new("stage 41: rung-K4's head axis at 48 tokens", "hashline-zk-mr1/s41-k4-t48-dev/1", 48, 96, 192, 12, 8, 4, 10, 4, 12, 13, None, None, None, None).expect("the 48-token rung-K4 geometry")
}

/// rung-G's geometry with the exp table at 9 fractional bits instead of 12
fn g_fe9() -> Shape {
    Shape::new("stage 41: rung-G's geometry at f_e = 9", "hashline-zk-mr1/s41-g-fe9-dev/1", 24, 96, 192, 6, 16, 2, 10, 4, 9, 9, None, None, None, None).expect("rung-G's geometry at f_e = 9")
}

/// rung-G's head axis at width 100 (note C-6: a width other than
/// `q_heads x head_dim` proves), so width indices 96..100 are TRUE here and
/// PADDED at rung-G
fn g_w100() -> Shape {
    Shape::new("stage 41: rung-G's head axis at width 100", "hashline-zk-mr1/s41-g-w100-dev/1", 24, 100, 192, 6, 16, 2, 10, 4, 12, 9, None, None, None, None).expect("rung-G's head axis at width 100")
}

// ---------------------------------------------------------------- the cases
//
// Each is `(the shape it is proved at, the cross-shape block, the honest
// block at that shape, the dense input)`.

/// **S40-N2** as stage 40 measured it: the dense rung-G attention half (a
/// `Wq` row at rung-K4's padded head slot 3) in a rung-K4 block with rung-K4's
/// dense feed-forward half
fn n2_case() -> (Shape, BlockPublic, BlockPublic, Vec<i16>) {
    let (g, k4) = (Shape::rung_g(), Shape::rung_k4());
    let (att_g, _, _) = super::dense_tests::dense_case(&g);
    let (att_k4, ff_k4, x) = super::dense_tests::dense_case(&k4);
    (k4, BlockPublic::new(att_g, ff_k4.clone()), BlockPublic::new(att_k4, ff_k4), x)
}

/// **The first norm gain** (ruling P-2 on `gamma_a`): rung-G's dense
/// attention words with `gamma_a` nonzero at width indices 96..100, built at
/// width 100 (true there), in a rung-G block (padded there)
fn gamma_case() -> (Shape, BlockPublic, BlockPublic, Vec<i16>) {
    let (g, w100) = (Shape::rung_g(), g_w100());
    let (att_g, ff_g, x) = super::dense_tests::dense_case(&g);
    let mut gamma = att_g.gamma_a.clone();
    for v in gamma[g.width..w100.width].iter_mut() {
        *v = 64;
    }
    let att = AttentionPublic::new_shaped(&w100, &att_g.wq, &att_g.wk, &att_g.wv, &att_g.wo, &gamma, &att_g.rope_cos, &att_g.rope_sin, &att_g.exp).expect("the gain is on the support at width 100");
    (g, BlockPublic::new(att, ff_g.clone()), BlockPublic::new(att_g, ff_g), x)
}

/// **The rotary tables' length**: rung-K4's dense attention words with the
/// rotary tables of rung-K4's head axis at 48 tokens (192 entries against
/// rung-K4's 96 — whose first 96 ARE rung-K4's own), built at 48 tokens, in a
/// rung-K4 block
fn rope_case() -> (Shape, BlockPublic, BlockPublic, Vec<i16>) {
    let (k4, t48) = (Shape::rung_k4(), k4_t48());
    let (att_k4, ff_k4, x) = super::dense_tests::dense_case(&k4);
    let (cos, sin) = crate::tables_attn::rope_tables_generate(t48.tokens, t48.head_dim, 10000.0, F_RO);
    assert_eq!((&cos[..att_k4.rope_cos.len()], &sin[..att_k4.rope_sin.len()]), (&att_k4.rope_cos[..], &att_k4.rope_sin[..]), "the 48-token tables do not start with rung-K4's own");
    let att = AttentionPublic::new_shaped(&t48, &att_k4.wq, &att_k4.wk, &att_k4.wv, &att_k4.wo, &att_k4.gamma_a, &cos, &sin, &att_k4.exp).expect("the words are legal at 48 tokens");
    (k4, BlockPublic::new(att, ff_k4.clone()), BlockPublic::new(att_k4, ff_k4), x)
}

/// **The exp table's scale, 12 bits in a 9-bit shape**: rung-G's dense
/// attention (its exp table at `2^12`) in a block at rung-G's geometry with
/// `f_e = 9`
fn exp_case() -> (Shape, BlockPublic, BlockPublic, Vec<i16>) {
    let (g, fe9) = (Shape::rung_g(), g_fe9());
    let (att_g, _, _) = super::dense_tests::dense_case(&g);
    let (att9, ff9, x) = super::dense_tests::dense_case(&fe9);
    (fe9, BlockPublic::new(att_g, ff9.clone()), BlockPublic::new(att9, ff9), x)
}

/// **The exp table's scale, 9 bits in a 12-bit shape**: the other direction
fn exp_case_reverse() -> (Shape, BlockPublic, BlockPublic, Vec<i16>) {
    let (g, fe9) = (Shape::rung_g(), g_fe9());
    let (att9, _, _) = super::dense_tests::dense_case(&fe9);
    let (att_g, ff_g, x) = super::dense_tests::dense_case(&g);
    (g, BlockPublic::new(att9, ff_g.clone()), BlockPublic::new(att_g, ff_g), x)
}

// ---------------------------------------------------------------- harness

/// the padded endpoint planes of a witness at `sh`, committed by a fresh owner
/// under the endpoint spec of `spec_at`
fn endpoints_with(spec_at: &Shape, sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[ids.at(p)].iter().map(|v| i16::try_from(*v).expect("an int16 endpoint word")).collect() };
    let spec = IoSpec::new_shaped(spec_at, ctx(), 0, 0).expect("the endpoint spec");
    prepare_endpoints(spec, &plane(A_X), &plane(A_X2)).expect("the endpoint owner commits")
}

/// an honest proof of `blk` at `sh`, to bytes
fn prove_to_bytes(sh: &Shape, blk: &BlockPublic, w: Witness) -> (ExpectedIo, Vec<u8>) {
    let (expected, owners) = endpoints_with(sh, sh, &w);
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners).expect("the honest proof");
    let bytes = receipt.to_bytes_at(sh, blk, &expected).expect("the frame");
    (expected, bytes)
}

/// How far an HONEST attempt got (the witness builder, the honest prover with
/// every refusal on, the verifier from bytes), with the endpoints committed
/// under the spec of `spec_at`: the first refusal, or the verdict.
fn verdict(sh: &Shape, blk: &BlockPublic, x: &[i16], spec_at: &Shape) -> String {
    let w = match catch_unwind(AssertUnwindSafe(|| witness::build_shaped(sh, blk.attention(), blk.feed_forward(), x))) {
        Err(_) => return "the builder PANICS".into(),
        Ok(Err(e)) => return format!("the builder refuses: {e}"),
        Ok(Ok(w)) => w,
    };
    let (expected, owners) = endpoints_with(spec_at, sh, &w);
    let bytes = match catch_unwind(AssertUnwindSafe(|| prove_inner_at(sh, blk, w, &expected, owners).and_then(|(r, _)| r.to_bytes_at(sh, blk, &expected)))) {
        Err(_) => return "the honest prover PANICS".into(),
        Ok(Err(e)) => return format!("the honest prover refuses: {e}"),
        Ok(Ok(b)) => b,
    };
    match catch_unwind(AssertUnwindSafe(|| verify_bytes_at(sh, blk, &expected, &bytes))) {
        Err(_) => "the verifier PANICS".into(),
        Ok(Ok(())) => "ACCEPTED".into(),
        Ok(Err(e)) => format!("verifier rejected: {e}"),
    }
}

/// What a shared body did with the caller's randomness and transcript
/// (`zkp-core`'s read-only stage-36 observers).
struct Core {
    res: Result<(), String>,
    consumed: u64,
    squeezes: u64,
    state_moved: bool,
}

/// Drive `protocol::prove_core` directly — the body the single-block prover
/// and every stage of a run share — with a deterministic public fixture
/// stream and a real transcript header, on real endpoint data.
fn direct_prove_core(sh: &Shape, blk: &BlockPublic, w: Witness) -> Core {
    let (expected, owners) = endpoints_with(sh, sh, &w);
    let [ein, eout] = protocol::check_endpoints(sh, &expected, owners).expect("the endpoint owners");
    let lay = Layout::for_shape(sh).expect("the layout");
    let ntt = crate::ntt::NttTables::new(protocol::ntt_log_at(sh));
    let mut rng = ZkRng::new(41, b"stage 41: a public fixture stream for the direct prove_core call");
    let mut tr = protocol::transcript(blk, &expected, &lay);
    let (before, sq) = (tr.state(), tr.squeezes());
    let mut ph = timing::Phases::start();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let mut tick = std::time::Instant::now();
    let res = protocol::prove_core(sh, &lay, blk, w, [ein.data.as_slice(), eout.data.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).map(|_| ());
    Core { res, consumed: rng.consumed_bytes(), squeezes: tr.squeezes() - sq, state_moved: tr.state() != before }
}

/// Drive `protocol::verify_core` directly — the body the single-block
/// verifier and every stage of the run verifier share — on a real receipt,
/// after the transcript header of `header_blk`.
fn direct_verify_core(sh: &Shape, blk: &BlockPublic, header_blk: &BlockPublic, expected: &ExpectedIo, receipt: &Receipt) -> Core {
    let lay = Layout::for_shape(sh).expect("the layout");
    let ntt = crate::ntt::NttTables::new(protocol::ntt_log_at(sh));
    let mut tr = protocol::transcript(header_blk, expected, &lay);
    let (before, sq) = (tr.state(), tr.squeezes());
    let mut ph = timing::Phases::start();
    let view = CoreView {
        a_root: receipt.a_root,
        h_root: receipt.h_root,
        mask_root: receipt.mask_root,
        slots: &receipt.slots,
        mask_open: &receipt.mask_open,
        a_open: &receipt.a_open,
        h_open: &receipt.h_open,
    };
    let res = protocol::verify_core(sh, &lay, blk, view, &ntt, &mut tr, &mut ph).map(|_| ());
    Core { res, consumed: 0, squeezes: tr.squeezes() - sq, state_moved: tr.state() != before }
}

/// a one-block run's witness source: the one witness it was handed
struct OneWitness(Option<Witness>);

impl RunWitnessSource for OneWitness {
    fn witness(&mut self, _k: usize) -> Result<Witness, String> {
        self.0.take().ok_or_else(|| "stage 41: the one witness was already handed out".to_string())
    }
    fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
        Err("stage 41: a one-block run has no internal boundary".into())
    }
}

/// an honest one-block run of `blk` at `rs`, its segments kept
fn honest_run(rs: RunShape, sh: &Shape, blk: &BlockPublic, x: &[i16]) -> (RunStatement, Vec<Vec<u8>>) {
    let w = witness::build_shaped(sh, blk.attention(), blk.feed_forward(), x).expect("the honest witness");
    let (expected, owners) = endpoints_with(sh, sh, &w);
    let st = RunStatement::new(rs, ctx(), expected, &[blk.clone()], &[(0, 0)]).expect("the honest one-block run statement");
    let mut segs: Vec<Vec<u8>> = Vec::new();
    run::prove_run(&st, &[blk.clone()], &mut OneWitness(Some(w)), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the honest one-block run");
    (st, segs)
}

// ------------------------------------------------ CS-4: the reproducers (failing first)

/// **S40-N2's REPRODUCER, on the HONEST path** (every prover refusal on):
/// before stage 41 the builder admitted the rung-G attention half in a
/// rung-K4 block and the verifier REJECTED the honest proof (slot 15, the Q
/// zero-check). Since ruling CS-4 the builder refuses it by name, so no
/// receipt exists.
#[test]
fn s41_n2_reproducer_a_cross_shape_attention_half_is_refused_before_a_receipt_exists() {
    let (k4, bad, _, x) = n2_case();
    let v = verdict(&k4, &bad, &x, &k4);
    eprintln!("S41 REPRODUCER S40-N2 (rung-G attention, rung-K4 block): {v}");
    assert_eq!(v, format!("the builder refuses: {}", cs4_att(P2_HEAD_SLOT)), "S40-N2: the cross-shape attention half was not refused by ruling CS-4's name before a receipt existed");
}

/// **The first norm gain's reproducer**: `gamma_a` nonzero at width indices
/// that are true at width 100 and padded at rung-G.
#[test]
fn s41_gamma_reproducer_a_cross_shape_norm_gain_is_refused_before_a_receipt_exists() {
    let (g, bad, _, x) = gamma_case();
    let v = verdict(&g, &bad, &x, &g);
    eprintln!("S41 REPRODUCER gamma_a (built at width 100, rung-G block): {v}");
    assert_eq!(v, format!("the builder refuses: {}", cs4_att(P2_PADDED_WIDTH)), "gamma_a: the cross-shape norm gain was not refused by ruling CS-4's name before a receipt existed");
}

/// **The rotary tables' reproducer**: 192-entry tables in a shape that
/// declares 96.
#[test]
fn s41_rope_reproducer_cross_shape_rotary_tables_are_refused_before_a_receipt_exists() {
    let (k4, bad, _, x) = rope_case();
    let v = verdict(&k4, &bad, &x, &k4);
    eprintln!("S41 REPRODUCER rotary tables (48-token tables, rung-K4 block): {v}");
    assert_eq!(v, format!("the builder refuses: {}", cs4_att(TABLE_SHAPE)), "rope: the cross-shape rotary tables were not refused by ruling CS-4's name before a receipt existed");
}

/// **The exp table's reproducer, in both directions and on two inputs**: the
/// dense recipe's input and the all-zero input (every score of a row equal,
/// so a row's softmax denominator is `(t + 1) exp[0]`). A cross-shape table
/// must be refused by ONE name whatever the private input is.
#[test]
fn s41_exp_reproducer_a_cross_shape_exp_table_is_refused_by_one_name_whatever_the_input() {
    let mut lines = Vec::new();
    let mut bad_lines = Vec::new();
    for (dir, (sh, bad, _, x)) in [("a 2^12 table in the f_e = 9 shape", exp_case()), ("a 2^9 table in rung-G (f_e = 12)", exp_case_reverse())] {
        let zero = vec![0i16; sh.tokens * sh.width];
        for (inp, xx) in [("the dense input", &x), ("the all-zero input", &zero)] {
            let v = verdict(&sh, &bad, xx, &sh);
            let line = format!("{dir}, {inp}: {v}");
            if v != format!("the builder refuses: {}", cs4_att(EXP_STRUCTURE)) {
                bad_lines.push(line.clone());
            }
            lines.push(line);
        }
    }
    for l in &lines {
        eprintln!("S41 REPRODUCER exp table: {l}");
    }
    assert!(bad_lines.is_empty(), "exp: a cross-shape exp table was not refused by ruling CS-4's name on every input:\n{}", bad_lines.join("\n"));
}

/// **The endpoint policy's reproducer**: the endpoint owner commits the
/// rung-K4 witness's planes under rung-G's endpoint spec (the same padded
/// plane, construction and commitment parameters; another profile's hash
/// tag), and the rung-K4 block is proved against that policy. Before stage
/// 41 the prover admitted it.
#[test]
fn s41_policy_reproducer_a_cross_shape_endpoint_policy_is_refused_before_a_receipt_exists() {
    let (k4, _, good, x) = n2_case();
    let v = verdict(&k4, &good, &x, &Shape::rung_g());
    eprintln!("S41 REPRODUCER endpoint policy (rung-G spec, rung-K4 block): {v}");
    assert_eq!(v, format!("the honest prover refuses: {}", cs4_policy(POLICY_TAG)), "policy: the cross-shape endpoint policy was not refused by ruling CS-4's name before a receipt existed");
}

// ------------------------------------------------ CS-4: the named refusals

/// **RULING CS-4, END TO END, for the attention half: re-checked against the
/// shape it is proved at and refused BY NAME at every point it meets it** —
/// the points stage 40 chose for the feed-forward half. The S40-N2 block at
/// rung-K4:
///
/// 1. the witness builder refuses it;
/// 2. the single-block prover's entry refuses it (a real witness of the
///    honest rung-K4 block, real endpoint owners);
/// 3. the shared proving body `prove_core`, called directly, refuses it with
///    NOTHING drawn, squeezed or absorbed;
/// 4. the verifier's bytes entry and in-memory entry refuse it, offered an
///    honest receipt of the honest block;
/// 5. the shared verifying body `verify_core`, called directly after a real
///    header, refuses it with nothing squeezed or absorbed;
/// 6. `RunStatement::new`, the run prover (before the sink is called) and
///    the run verifier refuse it.
#[test]
fn s41_cs4_a_cross_shape_attention_statement_is_refused_by_name_wherever_it_meets_the_shape_it_is_proved_at() {
    let (k4, bad, good, x) = n2_case();
    let want = cs4_att(P2_HEAD_SLOT);
    let honest = || witness::build_shaped(&k4, good.attention(), good.feed_forward(), &x).expect("the honest rung-K4 witness");
    // 0. the one function, asked directly (added after the fix: it did not
    //    exist before it) — it refuses the half at rung-K4, admits it at the
    //    shape it was built at, and the block-level check names it first
    assert_eq!(bad.attention().check_for_shape(&k4).err(), Some(want.clone()), "0. AttentionPublic::check_for_shape at rung-K4");
    assert!(bad.attention().check_for_shape(&Shape::rung_g()).is_ok(), "0. the half is refused at the shape it was built at");
    assert_eq!(bad.check_for_shape(&k4).err(), Some(want.clone()), "0. BlockPublic::check_for_shape at rung-K4");
    assert!(good.check_for_shape(&k4).is_ok(), "0. the honest block does not fit its own shape");
    // 1. the builder
    let r = witness::build_shaped(&k4, bad.attention(), bad.feed_forward(), &x);
    assert_eq!(r.err(), Some(want.clone()), "1. the witness builder did not refuse the cross-shape attention half by ruling CS-4's name");
    // 2. the prover's entry
    let w = honest();
    let (expected, owners) = endpoints_with(&k4, &k4, &w);
    assert_eq!(prove_inner_at(&k4, &bad, w, &expected, owners).err(), Some(want.clone()), "2. the prover's entry did not refuse by ruling CS-4's name");
    // 3. the shared proving body: nothing drawn, squeezed or absorbed
    let core = direct_prove_core(&k4, &bad, honest());
    assert_eq!(core.res.as_ref().err(), Some(&want), "3. prove_core did not refuse by ruling CS-4's name");
    assert_eq!((core.consumed, core.squeezes, core.state_moved), (0, 0, false), "3. prove_core drew, squeezed or absorbed before the CS-4 refusal");
    // 4. the verifier's two entries, on an honest receipt of the good block
    let (expected_g, bytes_g) = prove_to_bytes(&k4, &good, honest());
    assert!(verify_bytes_at(&k4, &good, &expected_g, &bytes_g).is_ok(), "the honest control receipt does not verify");
    assert_eq!(verify_bytes_at(&k4, &bad, &expected_g, &bytes_g).err(), Some(want.clone()), "4. the verifier's bytes entry did not refuse by ruling CS-4's name");
    let receipt = Receipt::from_bytes_at(&k4, &good, &expected_g, &bytes_g).expect("the control frame decodes");
    assert_eq!(protocol::verify_inner_at(&k4, &bad, &expected_g, &receipt).map(|_| ()).err(), Some(want.clone()), "4. the verifier's in-memory entry did not refuse by ruling CS-4's name");
    // 5. the shared verifying body: nothing squeezed or absorbed; the control
    //    (the good block through the same call) squeezes and absorbs
    let ok = direct_verify_core(&k4, &good, &good, &expected_g, &receipt);
    assert!(ok.res.is_ok() && ok.squeezes > 0 && ok.state_moved, "the control verify_core call: {:?}, {} squeezes", ok.res, ok.squeezes);
    let vc = direct_verify_core(&k4, &bad, &good, &expected_g, &receipt);
    assert_eq!(vc.res.as_ref().err(), Some(&want), "5. verify_core did not refuse by ruling CS-4's name");
    assert_eq!((vc.squeezes, vc.state_moved), (0, false), "5. verify_core squeezed or absorbed before the CS-4 refusal");
    // 6. the run statement, the run prover, the run verifier
    let w = honest();
    let (expected_r, _o) = endpoints_with(&k4, &k4, &w);
    let r = RunStatement::new(RunShape::rung_k4(1).expect("run shape"), ctx(), expected_r, &[bad.clone()], &[(0, 0)]);
    assert_eq!(r.err(), Some(cs4_att_run(0, P2_HEAD_SLOT)), "6. RunStatement::new did not refuse by ruling CS-4's name");
    let (expected_r, owners) = endpoints_with(&k4, &k4, &w);
    let st = RunStatement::new(RunShape::rung_k4(1).expect("run shape"), ctx(), expected_r, &[good.clone()], &[(0, 0)]).expect("the honest one-block run statement");
    let mut sunk = 0usize;
    let r = run::prove_run(&st, &[bad.clone()], &mut OneWitness(Some(w)), owners, &mut |_, _| {
        sunk += 1;
        Ok(())
    });
    assert_eq!(r.err(), Some(cs4_att_run(0, P2_HEAD_SLOT)), "6. the run prover did not refuse by ruling CS-4's name");
    assert_eq!(sunk, 0, "6. the run prover handed a segment to the sink before refusing");
    let (st, segs) = honest_run(RunShape::rung_k4(1).expect("run shape"), &k4, &good, &x);
    assert!(run::verify_run(&st, &[good.clone()], &segs).is_ok(), "the honest control run does not verify");
    assert_eq!(run::verify_run(&st, &[bad.clone()], &segs).err(), Some(cs4_att_run(0, P2_HEAD_SLOT)), "6. the run verifier did not refuse by ruling CS-4's name");
    eprintln!("S41 CS-4 attention (S40-N2 case): refused by ruling CS-4's name at the builder, the prover's entry, prove_core (0 bytes drawn, 0 squeezes, transcript unmoved), the verifier's two entries, verify_core (0 squeezes, transcript unmoved), RunStatement::new, the run prover (0 segments sunk) and the run verifier");
}

/// **RULING CS-4 carries EVERY shape-keyed rule of the attention half**: the
/// norm gain's support (P-2), the rotary tables' length, and the exp table's
/// scale in both directions — each refused by ruling CS-4's name followed by
/// the constructor's own at the builder, the prover's entry and the
/// verifier's entry. The control for each: the SAME words asked about the
/// shape they are proved at are refused by the constructor's own name.
#[test]
fn s41_cs4_every_shape_keyed_rule_of_the_attention_half_is_re_run_against_the_shape_it_is_proved_at() {
    let cases = [
        ("the norm gain gamma_a (P-2)", gamma_case(), P2_PADDED_WIDTH),
        ("the rotary tables' length", rope_case(), TABLE_SHAPE),
        ("the exp table's scale, 2^12 in f_e = 9", exp_case(), EXP_STRUCTURE),
        ("the exp table's scale, 2^9 in f_e = 12", exp_case_reverse(), EXP_STRUCTURE),
    ];
    for (what, (sh, bad, good, x), inner) in cases {
        let a = bad.attention();
        let own = AttentionPublic::new_shaped(&sh, &a.wq, &a.wk, &a.wv, &a.wo, &a.gamma_a, &a.rope_cos, &a.rope_sin, &a.exp);
        assert_eq!(own.err().as_deref(), Some(inner), "{what}: the constructor at the proving shape no longer refuses the words by its own name");
        let want = cs4_att(inner);
        let honest = || witness::build_shaped(&sh, good.attention(), good.feed_forward(), &x).expect("the honest witness");
        assert_eq!(witness::build_shaped(&sh, bad.attention(), bad.feed_forward(), &x).err(), Some(want.clone()), "{what}: the builder did not refuse by ruling CS-4's name");
        let w = honest();
        let (expected, owners) = endpoints_with(&sh, &sh, &w);
        assert_eq!(prove_inner_at(&sh, &bad, w, &expected, owners).err(), Some(want.clone()), "{what}: the prover's entry did not refuse by ruling CS-4's name");
        let (expected_g, bytes_g) = prove_to_bytes(&sh, &good, honest());
        assert!(verify_bytes_at(&sh, &good, &expected_g, &bytes_g).is_ok(), "{what}: the honest control receipt does not verify");
        assert_eq!(verify_bytes_at(&sh, &bad, &expected_g, &bytes_g).err(), Some(want.clone()), "{what}: the verifier's entry did not refuse by ruling CS-4's name");
        eprintln!("S41 CS-4 {what}: refused by ruling CS-4 + the constructor's name ({inner}) at the builder, the prover's entry and the verifier's entry");
    }
}

/// **RULING CS-4, the endpoint policy.** An `IoSpec` is DERIVED from a shape
/// at construction — the padded plane, the endpoint construction, its
/// commitment parameters and its hash tag — and none of it is absorbed
/// (`ExpectedIo::to_bytes` carries the context, the scales and the two
/// roots only). A rung-G spec in a rung-K4 proof:
///
/// 1. the prover's entry refuses it, before the endpoint owners are opened;
/// 2. the verifier's bytes entry and in-memory entry refuse a policy of the
///    SAME two roots declared for rung-G, offered with an honest rung-K4
///    receipt (its absorbed bytes are identical to the honest policy's);
/// 3. the toy's bytes entry refuses the rung-G policy before the frame is
///    decoded;
/// 4. `RunStatement::new` refuses it;
/// 5. the run prover and the run verifier re-check it: a statement built at
///    rung-G whose run shape is then set to rung-K4 (`RunStatement::rs` is a
///    visible field) is refused by both before anything is sunk or read.
#[test]
fn s41_cs4_a_cross_shape_endpoint_policy_is_refused_by_name_wherever_it_meets_the_shape_it_is_proved_at() {
    let (k4, _, good, x) = n2_case();
    let g = Shape::rung_g();
    let want = cs4_policy(POLICY_TAG);
    let honest = || witness::build_shaped(&k4, good.attention(), good.feed_forward(), &x).expect("the honest rung-K4 witness");
    // 0. the one function, asked directly (added after the fix): every
    //    registered shape's own spec fits it and no other registered shape
    //    of the same padded plane, construction and parameters
    let spec_g = IoSpec::new_shaped(&g, ctx(), 0, 0).expect("the rung-G spec");
    assert_eq!(spec_g.check_for_shape(&k4).err(), Some(want.clone()), "0. IoSpec::check_for_shape at rung-K4");
    assert!(spec_g.check_for_shape(&g).is_ok(), "0. the rung-G spec does not fit rung-G");
    let registered = [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125(), super::k8_tests::rung_k8()];
    for a in registered.iter() {
        let Ok(spec) = IoSpec::new_shaped(a, ctx(), 0, 0) else { continue };
        for b in registered.iter() {
            assert_eq!(spec.check_for_shape(b).is_ok(), a.profile == b.profile, "0. {}'s spec at {}", a.name, b.name);
        }
    }
    // 1. the prover's entry
    let w = honest();
    let (expected_g, owners_g) = endpoints_with(&g, &k4, &w);
    assert_eq!(prove_inner_at(&k4, &good, w, &expected_g, owners_g).err(), Some(want.clone()), "1. the prover's entry did not refuse the cross-shape policy by ruling CS-4's name");
    // 2. the verifier's two entries
    let (expected_k4, bytes) = prove_to_bytes(&k4, &good, honest());
    let twin = ExpectedIo::from_roots(IoSpec::new_shaped(&g, ctx(), 0, 0).expect("the rung-G spec"), expected_k4.input_root(), expected_k4.output_root());
    assert_eq!(twin.to_bytes(), expected_k4.to_bytes(), "the policy's absorbed bytes carry its shape after all");
    assert!(verify_bytes_at(&k4, &good, &expected_k4, &bytes).is_ok(), "the honest control receipt does not verify");
    assert_eq!(verify_bytes_at(&k4, &good, &twin, &bytes).err(), Some(want.clone()), "2. the verifier's bytes entry did not refuse by ruling CS-4's name");
    let receipt = Receipt::from_bytes_at(&k4, &good, &expected_k4, &bytes).expect("the control frame decodes");
    assert_eq!(protocol::verify_inner_at(&k4, &good, &twin, &receipt).map(|_| ()).err(), Some(want.clone()), "2. the verifier's in-memory entry did not refuse by ruling CS-4's name");
    // 3. the toy's bytes entry, before the frame is decoded
    let (toy, _) = BlockPublic::synthetic_fixture();
    assert_eq!(verify_bytes(&toy, &twin, &[0u8; 64]).err(), Some(cs4_policy(POLICY_TOY_PLANE)), "3. the toy's bytes entry did not refuse a rung-G policy by ruling CS-4's name");
    // 4. the run statement
    let r = RunStatement::new(RunShape::rung_k4(1).expect("run shape"), ctx(), twin.clone(), &[good.clone()], &[(0, 0)]);
    assert_eq!(r.err(), Some(cs4_policy_run(POLICY_TAG)), "4. RunStatement::new did not refuse by ruling CS-4's name");
    // 5. the run prover and verifier, on a statement whose run shape moved
    let (att_g, ff_g, _) = super::dense_tests::dense_case(&g);
    let blk_g = BlockPublic::new(att_g, ff_g);
    let w = honest();
    let (expected_g, owners_g) = endpoints_with(&g, &k4, &w);
    let mut st = RunStatement::new(RunShape::rung_g(1).expect("run shape"), ctx(), expected_g, &[blk_g], &[(0, 0)]).expect("a rung-G run statement with a rung-G policy");
    st.rs = RunShape::rung_k4(1).expect("run shape");
    let mut sunk = 0usize;
    let r = run::prove_run(&st, &[good.clone()], &mut OneWitness(Some(w)), owners_g, &mut |_, _| {
        sunk += 1;
        Ok(())
    });
    assert_eq!(r.err(), Some(cs4_policy_run(POLICY_TAG)), "5. the run prover did not refuse by ruling CS-4's name");
    assert_eq!(sunk, 0, "5. the run prover handed a segment to the sink before refusing");
    assert_eq!(run::verify_run(&st, &[good.clone()], &[vec![0u8; 64]]).err(), Some(cs4_policy_run(POLICY_TAG)), "5. the run verifier did not refuse by ruling CS-4's name before reading a segment");
    eprintln!("S41 CS-4 endpoint policy (rung-G spec at rung-K4): refused by ruling CS-4's name at the prover's entry, the verifier's two entries, the toy's bytes entry (padded plane), RunStatement::new, the run prover (0 segments sunk) and the run verifier (before a segment is read)");
}

// ------------------------------------------------------------------ CS-5

/// **RULING CS-5: `Shape::new` refuses a width above 16,384, by name.** At
/// every width up to 16,384 the norm window `Shape::new` derives from the
/// 32767 bound is the one the 32768 input bound needs (stage 40,
/// `s40_cs2_...norm...`); from 16,385 it can be one bit short (S40-N1).
/// Geometries at width 16,384 are admitted; the same kind of geometry at
/// 16,385, 20,000, 32,768 and 65,536 — admitted before this stage
/// (`s41-before-named.log`) — is refused by ruling CS-5's name. Every
/// registered shape is at most 768 wide and constructs.
#[test]
fn s41_cs5_shape_new_refuses_a_width_above_16384_by_name() {
    let mk = |width: usize, q: usize, dh: usize| {
        Shape::new("stage 41: ruling CS-5 probe", "hashline-zk-mr1/s41-cs5-probe/1", 24, width, width, q, dh, 4, 10, 4, 12, 5 + (32 * width.next_power_of_two()).div_ceil(1024), None, None, None, None)
    };
    let mut lines = Vec::new();
    for (width, q, dh) in [(16_384usize, 128usize, 128usize), (16_384, 256, 64)] {
        let s = mk(width, q, dh).unwrap_or_else(|e| panic!("CS-5: width {width} ({q} heads of {dh}) refused: {e}"));
        assert_eq!(s.width, width);
        lines.push(format!("width {width} ({q} heads of {dh}): admitted, norm_wrho {}", s.norm_wrho));
    }
    let mut refused = Vec::new();
    for (width, q, dh) in [(16_385usize, 256usize, 128usize), (20_000, 256, 128), (32_768, 256, 128), (65_536, 512, 128)] {
        match mk(width, q, dh) {
            Ok(s) => lines.push(format!("width {width} ({q} heads of {dh}): ADMITTED, norm_wrho {}", s.norm_wrho)),
            Err(e) => {
                lines.push(format!("width {width} ({q} heads of {dh}): refused: {e}"));
                refused.push((width, e));
            }
        }
    }
    for l in &lines {
        eprintln!("S41 CS-5 {l}");
    }
    assert_eq!(refused.len(), 4, "CS-5: a width above 16,384 was admitted");
    for (width, e) in &refused {
        assert!(e.starts_with(&format!("{CS5}{width} is above 16384")), "width {width} refused, but not by ruling CS-5's name: {e}");
    }
    let registered = [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125(), super::k8_tests::rung_k8()];
    for s in registered.iter() {
        assert!(s.width <= 16_384, "{}: a registered shape is wider than 16,384", s.name);
    }
}

// ------------------------------------------------ the two notes, RULED (stage 42: CS-7 and CS-6)

/// **NOTE S41-N1, ruled by CS-7 (stage 42).** Measured here at stage 41: a
/// REGISTERED run profile over ANOTHER block shape was admitted by
/// `RunShape::new` and its one-block run proved and verified (rung-G's run
/// profile over the rung-K4 shape; `s42-before-notes.log`). Since ruling CS-7
/// `RunShape::new` refuses it by name; `s42_tests` covers every cross pair.
#[test]
fn s41_note_n1_a_registered_run_profile_over_another_block_shape_is_refused_by_ruling_cs7() {
    let r = RunShape::new(Shape::rung_k4(), 1, run::RUN_PROFILE_RUNG_G);
    eprintln!("S41-N1 rung-G's run profile over the rung-K4 block shape: {:?}", r.as_ref().err());
    let e = r.err().expect("S41-N1: rung-G's run profile over the rung-K4 shape is admitted again");
    assert!(e.starts_with("private run: ruling CS-7 — "), "S41-N1 refused, but not by ruling CS-7's name: {e}");
}

/// **NOTE S41-N2, ruled by CS-6 (stage 42).** Measured here at stage 41: a
/// run statement built over block X, proved with block Y's words and
/// witness, was ACCEPTED by the run verifier handed Y (the transcript
/// absorbed X's digest while every slot was checked against Y) and rejected
/// handed X (`s42-before-notes.log`). Since ruling CS-6 the run prover
/// refuses it by name before anything is absorbed, and the run verifier
/// handed Y refuses by name before a segment is read; `s42_tests` measures
/// the verifier on the forged receipt itself.
#[test]
fn s41_note_n2_a_run_statement_over_x_handed_block_y_is_refused_by_ruling_cs6() {
    let g = Shape::rung_g();
    let (att_x, ff_x, _) = super::grow_tests::tame_case(&g);
    let (att_y, ff_y, x_y) = super::dense_tests::dense_case(&g);
    let (bx, by) = (BlockPublic::new(att_x, ff_x), BlockPublic::new(att_y, ff_y));
    assert_ne!(bx.digest(), by.digest(), "the two blocks are the same statement");
    let w = witness::build_shaped(&g, by.attention(), by.feed_forward(), &x_y).expect("Y's honest witness");
    let (expected, owners) = endpoints_with(&g, &g, &w);
    let st = RunStatement::new(RunShape::rung_g(1).expect("run shape"), ctx(), expected, &[bx.clone()], &[(0, 0)]).expect("a run statement over X");
    let mut sunk = 0usize;
    let r = run::prove_run(&st, &[by.clone()], &mut OneWitness(Some(w)), owners, &mut |_, _| {
        sunk += 1;
        Ok(())
    });
    let with_y = run::verify_run(&st, &[by.clone()], &[vec![0u8; 64]]);
    eprintln!("S41-N2 a run statement over X handed Y: the run prover: {:?}; the run verifier: {with_y:?}", r.as_ref().err());
    let e = r.err().expect("S41-N2: the run prover proves Y under a statement over X again");
    assert!(e.starts_with("private run: ruling CS-6 — block 0 "), "S41-N2: the run prover refused, but not by ruling CS-6's name: {e}");
    assert_eq!(sunk, 0, "S41-N2: the run prover handed a segment to the sink before refusing");
    let e = with_y.err().expect("S41-N2: the run verifier handed Y accepted");
    assert!(e.starts_with("private run: ruling CS-6 — block 0 "), "S41-N2: the run verifier refused, but not by ruling CS-6's name: {e}");
}
