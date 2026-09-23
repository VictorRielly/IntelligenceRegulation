//! **ADVERSARIAL CHECK OF THE SHAPED REFUSAL CENSUS (stages 38-39), REVIEW
//! BRANCH ONLY** (`zk60-private-block-125m-review`). Report:
//! `docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS_CHECK.md`.
//!
//! Written by a checker who did not write the census and assumed it wrong
//! until shown otherwise. Test-only; no production line moves. Two findings
//! are reproduced here, each as an ORDINARY test that measures the admitted
//! state (passes today) and an `#[ignore]`d reproducer that asserts the
//! property the census needs and FAILS today:
//!
//! * **C-1** — the S38-F1(a) refusal (and ruling P-2's support check) is
//!   evaluated at construction against a `Shape` that the statement does NOT
//!   carry. `BlockPublic`, `witness::build_shaped`, `protocol::prove_core` and
//!   `run::RunStatement::new` accept a statement built at ANY shape with the
//!   same padded lengths. A feed-forward statement built at rung-P2 (whose
//!   `Dom::F` does not pad) with `act[128] = 1` goes into a rung-K4 block
//!   (whose `Dom::F` pads 3,584 positions): admitted everywhere, every honest
//!   proof rejected by the verifier.
//! * **C-2** — `Shape::new` admits an OVERRIDDEN softmax window `wrho_s`
//!   below `clog2(tokens) + f_e` without checking `tokens 2^f_e <= 2^wrho_s`.
//!   The builder and the kernel check `sigma_s` only; on the LAST token row
//!   no causally masked position exists, so a `rho_s` above the window is
//!   admitted by both, and the prover's `rho_s` top-limb lookups miss. That
//!   failure depends on the PRIVATE input (it is an honest-proof failure on a
//!   legal input), not only on the statement.
//!
//! Nothing here is a privacy result. Everything proved is PUBLIC SYNTHETIC
//! test data with hand-chosen integers.

use super::layout::*;
use super::protocol::{act_indices, lookup_values};
use super::review_tests::{outcome, Outcome};
use super::run::{RunShape, RunStatement};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use private_block_kernel_shaped as kshaped;
use std::collections::BTreeSet;

/// the ruling's refusal text, as a literal (the census file keeps its own)
const S38_F1_REFUSAL: &str = "private block: activation table act[128] must be 0 at a shape whose feed-forward domain pads (ruling S38-F1(a))";

fn check_context() -> Digest {
    *blake3::hash(b"census check (review branch): C-1 / C-2 reproducers").as_bytes()
}

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

fn kernel(s: &Shape, w: &[Vec<i8>; 9], cos: &[i64], sin: &[i64], exp: &[i64], act: &[i16], x: &[i16]) -> Result<Vec<i16>, String> {
    let ksh = kshaped::Shape::new(s.tokens, s.width, s.hidden, s.q_heads, s.kv_heads, s.head_dim, s.f_e, F_P, s.wrho_s, s.norm_wrho);
    let mut scratch = vec![0i64; ksh.scratch_len()];
    let mut out = vec![0i16; ksh.x_len()];
    let wr = kshaped::WeightsRef { wq: &w[0], wk: &w[1], wv: &w[2], wo: &w[3], gamma_a: &w[4], gamma_m: &w[5], wg_t: &w[6], wu_t: &w[7], wd_t: &w[8] };
    let tr = kshaped::TablesRef { rope_cos: cos, rope_sin: sin, exp, act };
    kshaped::run_shaped(&ksh, x, &wr, &tr, &mut scratch, None, &mut out).map_err(|e| format!("{e}"))?;
    Ok(out)
}

/// the builder's block output on the TRUE support, in the kernel's order
fn true_output(s: &Shape, w: &Witness) -> Vec<i16> {
    let out = w.output().expect("int16 output");
    (0..s.tokens).flat_map(|t| out[t * s.d_pad..t * s.d_pad + s.width].to_vec()).collect()
}

/// every U8 word the PROVER would look up that is not a byte, as
/// `(domain, lookup index, position, value)` — `protocol.rs:434-444` files
/// each in bucket 0 and only the LogUp identity notices
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

/// the activation pairs the prover would look up that are not rows of `ff`'s
/// table (`protocol.rs:845-848`), by position
fn act_misses(s: &Shape, ff: &FeedForwardPublic, w: &Witness) -> Vec<usize> {
    let lay = Layout::for_shape(s).expect("the layout");
    let a = &w.planes[lay.ids().at(A_A16)];
    act_indices(&lay, w).iter().enumerate().filter(|(x, i)| !((0..U8_LEN as i64).contains(*i) && i64::from(ff.act[**i as usize]) == a[*x])).map(|(x, _)| x).collect()
}

// ------------------------------------------------------------------ C-1

/// The C-1 case: the attention half built at rung-K4, the feed-forward half's
/// SAME padded words (rung-K4's own zero-padded matrices) built at rung-P2 with
/// `act[128] = 1`, and the all-ones input. Returns what each step answered.
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

/// **C-1, MEASURED (passes today).** The S38-F1(a) refusal fires for the
/// table at the shape it is asked about, and a statement built at a DIFFERENT
/// shape with the same padded lengths carries no memory of it: the builder,
/// the kernel and the run statement all admit the rung-P2-built feed-forward
/// half inside a rung-K4 block, and exactly the 3,584 padded `Dom::F`
/// positions look up `(128, 0)`, which is not a row of that table.
#[test]
#[ignore = "superseded at the merge of lane stage 43 (f486e6f): ruling CS-1 (lane stage 40) closed C-1, so this measurement of the open hole now fails by design; the stage 39-43 review (ZK60_LANE_S39_S43_CODE_REVIEW.md) runs it with --ignored as evidence of the fix"]
fn c1_a_statement_built_at_another_shape_bypasses_the_s38_f1_refusal() {
    let c = c1_case();
    let p2 = Shape::rung_p2();
    assert_eq!((c.k4.d_pad, c.k4.f_pad), (p2.d_pad, p2.f_pad), "the two shapes' feed-forward words have the same padded lengths");
    assert!(c.k4.pads(Dom::F) && !p2.pads(Dom::F), "rung-K4's Dom::F pads and rung-P2's does not");
    // control: asked at rung-K4, the ruling refuses the table by name
    let own = statement(&c.k4, &c.w, &c.cos, &c.sin, &c.exp, &c.act);
    assert_eq!(own.err().as_deref(), Some(S38_F1_REFUSAL), "the ruling no longer refuses act[128] = 1 at rung-K4");
    // the same words, the feed-forward half constructed at rung-P2
    let blk = c1_statement(&c).expect("the cross-shape statement constructs");
    let wit = witness::build_shaped(&c.k4, blk.attention(), blk.feed_forward(), &c.x).expect("the builder admits the cross-shape statement");
    let kout = kernel(&c.k4, &c.w, &c.cos, &c.sin, &c.exp, &c.act, &c.x).expect("the kernel admits the same statement");
    assert_eq!(true_output(&c.k4, &wit), kout, "builder and kernel disagree");
    assert!(u8_misses(&c.k4, &wit).is_empty(), "an unrelated U8 miss");
    let misses = act_misses(&c.k4, blk.feed_forward(), &wit);
    let sup: BTreeSet<usize> = witness::Geom::new(&c.k4).support(Dom::F).into_iter().collect();
    let pads: Vec<usize> = (0..c.k4.size(Dom::F)).filter(|x| !sup.contains(x)).collect();
    assert_eq!(misses, pads, "the misses are not exactly the padded Dom::F positions");
    assert_eq!(misses.len(), 3584, "rung-K4's padded Dom::F count");
    // the run layer binds the statement to nothing but its digest either
    let ids = Ids::new(&c.k4).expect("the plane map");
    let plane = |p: usize| -> Vec<i16> { wit.planes[ids.at(p)].iter().map(|v| i16::try_from(*v).expect("int16")).collect() };
    let spec = IoSpec::new_shaped(&c.k4, check_context(), 0, 0).expect("the rung-K4 endpoint spec");
    let (expected, _owners) = prepare_endpoints(spec, &plane(A_X), &plane(A_X2)).expect("the endpoint owner commits");
    let st = RunStatement::new(RunShape::rung_k4(1).expect("run shape"), check_context(), expected, &[blk.clone()], &[(0, 0)]);
    assert!(st.is_ok(), "the run statement refused the cross-shape block: {:?}", st.err());
    eprintln!(
        "C-1 rung-K4 block with a rung-P2 feed-forward half, act[128] = 1: constructor (at P2) ADMITS, builder ADMITS, kernel ADMITS, RunStatement::new ADMITS; {} of {} Dom::F positions look up (128, 0), not a row",
        misses.len(),
        c.k4.size(Dom::F)
    );
}

/// **C-1 REPRODUCER (fails today).** The property the census needs: a
/// statement the constructors admit never reaches a receipt the verifier
/// rejects. Today the cross-shape statement is proved and REJECTED BY THE
/// VERIFIER. Any fix that refuses before a receipt exists (at construction,
/// in `build_shaped`, or in the prover before the `A` commitment) makes this
/// pass.
#[test]
#[ignore = "reproducer of check finding C-1: the S38-F1(a) refusal is keyed on a shape the statement does not carry; an admitted cross-shape statement yields a receipt the verifier rejects"]
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

// ------------------------------------------------------------------ C-2

/// rung-G's geometry with the softmax window OVERRIDDEN to 15 bits (its own
/// derivation, `clog2(24) + 12`, is 17). `Shape::new` admits it: nothing
/// checks `tokens 2^f_e <= 2^wrho_s` (= 98,304 against 32,768).
fn wrho15() -> Result<Shape, String> {
    Shape::new(
        "census check: rung-G geometry, softmax window overridden to 15 bits (T24 / d96 / f192)",
        "hashline-zk-mr1/census-check-wrho15-dev/1",
        24,
        96,
        192,
        6,
        16,
        2,
        10,
        4,
        12,
        9,
        None,
        None,
        None,
        Some(15),
    )
}

/// The C-2 statement, TRUE-sized, at rung-G's geometry (both shapes share it):
///
/// * the input is one-hot per token with magnitude 1000 (`D = 1000`, `y = 64
///   e_c`): token 0 on column 0, tokens 1..=22 on column 1, token 23 on
///   column 2;
/// * keys: column 0 gives `k = (64, 0, ..)`, columns 1 and 2 give `k = (0, 64,
///   ..)`, in both key-value heads; queries: column 1 gives `q = (2, 0, ..)`,
///   column 2 gives `q = (0, 1, ..)`, in all six heads; identity RoPE;
/// * the exp table is `[4096, 1250, 0, ...]` — `E[0] = 2^f_e`, in range,
///   non-increasing: legal;
/// * values, output projection and the feed-forward are zero.
///
/// So every row `t <= 22` has ONE maximum (score 2 at `j = 0`, the rest 0,
/// `exp[2] = 0`): `Sum = 4096` and every `sigma_s <= 4095`. Row 23 has 23
/// maxima (score 1 at `j >= 1`) and `j = 0` one step below (`exp[1] = 1250`):
/// `Sum = 95,458`, `rho_s = 92,534` (and 67,252 at `j = 0`), `sigma_s =
/// 2,923` (28,205) — every `sigma_s` inside `2^15`, every `rho_s` outside.
fn c2_words(s: &Shape) -> ([Vec<i8>; 9], Vec<i64>, Vec<i64>, Vec<i64>, Vec<i16>, Vec<i16>) {
    let mut w = zero_words(s);
    let (d, dh) = (s.width, s.head_dim);
    for h in 0..s.q_heads {
        w[0][(h * dh) * d + 1] = 3; // q dim 0 = floor((3 + 1) / 2) = 2 on column 1
        w[0][(h * dh + 1) * d + 2] = 1; // q dim 1 = 1 on column 2
    }
    for kv in 0..s.kv_heads {
        w[1][(kv * dh) * d] = 127; // k dim 0 = 64 on column 0
        w[1][(kv * dh + 1) * d + 1] = 127; // k dim 1 = 64 on column 1
        w[1][(kv * dh + 1) * d + 2] = 127; // and on column 2
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

/// **C-2, MEASURED (passes today).** At the overridden shape the builder and
/// the kernel admit the input, the outputs agree, and the prover would look
/// up 288 non-byte words — the `rho_s` top limb (byte and scaled lookups) of
/// every true head at token row 23. At rung-G itself (the derived 17-bit
/// window) the same statement and input are LogUp-clean.
#[test]
#[ignore = "superseded at the merge of lane stage 43 (f486e6f): ruling CS-2 (lane stage 40) closed C-2, so this measurement of the open hole now fails by design; the stage 39-43 review (ZK60_LANE_S39_S43_CODE_REVIEW.md) runs it with --ignored as evidence of the fix"]
fn c2_an_overridden_softmax_window_lets_an_admitted_input_break_the_rho_s_lookups() {
    let sh = wrho15().expect("Shape::new admits the overridden window");
    assert_eq!(sh.wrho_s, 15);
    assert!((sh.tokens as i128) << sh.f_e > 1i128 << sh.wrho_s, "the override no longer undercuts tokens 2^f_e");
    let (w, cos, sin, exp, act, x) = c2_words(&sh);
    let blk = statement(&sh, &w, &cos, &sin, &exp, &act).expect("the statement constructs at the overridden shape");
    let wit = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &x).expect("the builder admits");
    let kout = kernel(&sh, &w, &cos, &sin, &exp, &act, &x).expect("the kernel admits");
    assert_eq!(true_output(&sh, &wit), kout, "builder and kernel disagree");
    assert!(act_misses(&sh, blk.feed_forward(), &wit).is_empty(), "an unrelated activation miss");
    let misses = u8_misses(&sh, &wit);
    assert!(misses.iter().all(|(dom, ..)| *dom == Dom::S), "a miss outside Dom::S");
    // every miss sits at token row 23 of a true head: x = (h * t_pad + 23) * t_pad + j
    let tp = sh.t_pad;
    let rows: BTreeSet<usize> = misses.iter().map(|(_, _, x, _)| (x / tp) % tp).collect();
    assert_eq!(rows, BTreeSet::from([sh.tokens - 1]), "the misses are not all on the last token row");
    let vals: BTreeSet<i64> = misses.iter().map(|(.., v)| *v).collect();
    assert_eq!(misses.len(), sh.q_heads * sh.tokens * 2, "one byte and one scaled miss per (head, j) of the last row");
    eprintln!(
        "C-2 wrho_s = 15 at rung-G's geometry: Shape::new ADMITS, builder ADMITS, kernel ADMITS; {} U8 words outside [0, 256) (values {:?}), all on the rho_s top limb of token row {}",
        misses.len(),
        vals,
        sh.tokens - 1
    );
    // the control: rung-G's own derived window holds the same rho_s
    let g = Shape::rung_g();
    assert_eq!(g.wrho_s, 17);
    let (wg, cg, sg, eg, ag, xg) = c2_words(&g);
    let blk_g = statement(&g, &wg, &cg, &sg, &eg, &ag).expect("the rung-G statement");
    let wit_g = witness::build_shaped(&g, blk_g.attention(), blk_g.feed_forward(), &xg).expect("the builder admits at rung-G");
    assert!(u8_misses(&g, &wit_g).is_empty(), "rung-G's derived window does not hold the case");
    eprintln!("C-2 control rung-G (wrho_s = 17): the same statement and input are LogUp-clean");
}

/// **C-2 REPRODUCER (fails today).** The census's completeness property at a
/// shape `Shape::new` admits: an input the builder admits yields an ACCEPTED
/// proof. The control (rung-G, derived window) is proved and accepted first;
/// at the overridden shape the verifier rejects.
#[test]
#[ignore = "reproducer of check finding C-2: Shape::new admits wrho_s below clog2(tokens) + f_e; the builder and kernel check sigma_s only, so a last-row rho_s above the window is admitted and the honest proof is rejected"]
fn c2_reproducer_an_admitted_input_at_an_admitted_shape_proves() {
    let g = Shape::rung_g();
    let (wg, cg, sg, eg, ag, xg) = c2_words(&g);
    let blk_g = statement(&g, &wg, &cg, &sg, &eg, &ag).expect("the rung-G statement");
    let wit_g = witness::build_shaped(&g, blk_g.attention(), blk_g.feed_forward(), &xg).expect("the builder admits at rung-G");
    let og = outcome(&g, &blk_g, wit_g);
    eprintln!("C-2 REPRODUCER control rung-G (wrho_s = 17): {}", og.short());
    assert_eq!(og, Outcome::Accepted, "the control itself does not prove: {}", og.short());
    let sh = wrho15().expect("Shape::new admits the overridden window");
    let (w, cos, sin, exp, act, x) = c2_words(&sh);
    let blk = statement(&sh, &w, &cos, &sin, &exp, &act).expect("the statement");
    let wit = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &x).expect("the builder admits");
    let o = outcome(&sh, &blk, wit);
    eprintln!("C-2 REPRODUCER wrho_s = 15: {}", o.short());
    assert_eq!(o, Outcome::Accepted, "C-2: an input the builder admits at a shape Shape::new admits was not proved: {}", o.short());
}

// ------------------------------------------------------------------ item 4

/// **The fix's condition, beyond the ten census shapes.** Over a grid of
/// shapes `Shape::new` admits, the positions of `Dom::F` the builder leaves at
/// `(g8, a16) = (0, 0)` — every position of the (lifted) cube off
/// `Geom::support` — are nonempty EXACTLY when `Shape::pads(Dom::F)`, and the
/// support is injective and inside the cube. So `sh.pads(Dom::F)` is exactly
/// "some honest activation pair is `(128, 0)`" at every admitted shape, not
/// only at the registered ones.
#[test]
fn the_s38_f1_condition_is_exactly_the_padded_feed_forward_positions_on_a_grid_of_admitted_shapes() {
    let (mut admitted, mut padded) = (0usize, 0usize);
    for tokens in [16usize, 24, 32, 48, 64] {
        for (q, dh, kv) in [(6usize, 16usize, 2usize), (12, 8, 4), (16, 8, 8), (12, 32, 4), (8, 16, 2), (4, 32, 1)] {
            for hidden in [96usize, 128, 192, 256, 384, 512, 1024] {
                for log_cols in [8usize, 10] {
                    let width = q * dh;
                    let Ok(s) = Shape::new("census check grid", "hashline-zk-mr1/census-check-grid/1", tokens, width, hidden, q, dh, kv, log_cols, 4, 12, 9, None, None, None, None) else { continue };
                    admitted += 1;
                    let sup = witness::Geom::new(&s).support(Dom::F);
                    let set: BTreeSet<usize> = sup.iter().copied().collect();
                    assert_eq!(set.len(), sup.len(), "Dom::F support is not injective at {tokens}/{width}/{hidden}");
                    assert!(sup.iter().all(|x| *x < s.size(Dom::F)), "Dom::F support leaves the cube");
                    let off = s.size(Dom::F) - set.len();
                    assert_eq!(off > 0, s.pads(Dom::F), "pads(Dom::F) disagrees with the off-support count at {tokens}/{width}/{hidden}/{log_cols}");
                    padded += usize::from(off > 0);
                }
            }
        }
    }
    assert!(admitted > 20, "the grid admitted only {admitted} shapes");
    eprintln!("S38-F1 condition grid: {admitted} admitted shapes, {padded} pad Dom::F; pads(Dom::F) == (off-support positions > 0) at every one");
}
