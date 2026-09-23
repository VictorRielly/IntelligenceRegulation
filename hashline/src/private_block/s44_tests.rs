//! **STAGE 44 (test-only): rulings K-1, K-2 and CS-9 of the shaped refusal
//! census disposition** (`docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS_DISPOSITION.md`
//! §8, security owner), on the independent adversarial code review of lane
//! stages 39–43 (review branch `zk60-private-block-125m-review` at `dc12f44`,
//! `docs/zkmatrix-poc/ZK60_LANE_S39_S43_CODE_REVIEW.md`; its tests
//! `s39_s43_review_tests.rs` are the source of the K-1 and K-4 reproducers
//! below). Ruling K-3's stronger declaration guard lives in `s43_tests.rs`,
//! beside the pin it extends.
//!
//! * **K-1 + K-2 (errata, text only).** Ruling CS-3's refusal text says
//!   exactly what precedes it — in a single block the transcript header's
//!   absorbs; inside a run the run header, every earlier stage, the stage
//!   header and, below the last block, the boundary `B_k` (drawn, committed,
//!   absorbed, `run.rs:746-757`) — and names the class of the miss only:
//!   which table family missed, never how many (the counts are computed from
//!   the hidden witness).
//! * **CS-9 (from note K-4).** A block-profile registry, as ruling CS-7 is
//!   for runs: `Shape::new` refuses, by name, a registered block profile
//!   string with any shape other than its own and, outside `#[cfg(test)]`, an
//!   unregistered one; rung-K8 registers only under `#[cfg(test)]`.
//!
//! FAILING FIRST. The tests below were written and run at the lane tip
//! `6336377` (stage 44's skeleton over `f486e6f`) with only this file and its
//! mod line added (`results/zk60_block125m_lane/s44-before-*.log`). The
//! literals of the new refusal texts are held here so that the tests could be
//! run, and fail, before the production text existed.
//!
//! Nothing here is a privacy result. Everything proved is PUBLIC SYNTHETIC
//! test data.

use super::layout::*;
use super::protocol::{self, act_indices, exp_deltas, lookup_values, prove_inner_at, CoreView};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::{Shape, TOY_PROFILE};
use super::witness::{self, Witness};
use super::*;
use crate::zk::ZkRng;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;

// ---------------------------------------------------------------- the names

/// **RULING CS-3's name** (unchanged)
const CS3: &str = "private block: ruling CS-3 — the witness looks up a value that is not a row of its table";

/// **RULING CS-3's refusal after errata K-1 and K-2**, for the table
/// families that missed (`"the byte table"`, `"the exp table"`, `"the
/// activation table"`, in that order, comma-separated). No count.
fn cs3(families: &str) -> String {
    format!(
        "{CS3}; the table family that missed: {families} (the class of the miss only, never a count — ruling K-2). It is refused before this block's A mask rows are drawn, its A commitment is made or any challenge of it is drawn. What precedes the refusal: in a single block, the transcript header's absorbs; inside a run, the run header, every earlier stage, this stage's header absorbs and, below the last block, the boundary B_k to the next block, drawn from the run's stream, committed and absorbed (ruling M-9)."
    )
}

/// **RULING CS-9's name**, the prefix of both of its refusals
const CS9: &str = "private block shape: ruling CS-9 — ";

/// ruling CS-8's prefix when `Shape::new` refuses a value's own parameters
fn cs8_refused(s: &Shape, inner: &str) -> String {
    format!("private block shape: ruling CS-8 — {:?} is not a shape Shape::new builds: Shape::new refuses its own parameters ({inner})", s.name)
}

/// the parameters `Shape::new` is handed that differ between two shapes, in
/// its own order — computed HERE, field by field, not by the production code
fn differing_parameters(reg: &Shape, given: &Shape) -> String {
    let mut v: Vec<&str> = Vec::new();
    macro_rules! cmp {
        ($($f:ident),*) => {
            $(
                if reg.$f != given.$f {
                    v.push(stringify!($f));
                }
            )*
        };
    }
    cmp!(name, tokens, width, hidden, q_heads, head_dim, kv_heads, log_cols, inv_rate, f_e, endpoint_rows, endpoint_log_n, endpoint_inv_rate, norm_wrho, wrho_s);
    v.join(", ")
}

/// **CS-9, a registered profile string with another shape**
fn cs9_other(reg: &Shape, given: &Shape) -> String {
    format!("{CS9}the block profile {:?} is registered for exactly one shape, {:?}; the shape handed, {:?}, differs from it in {}", reg.profile, reg.name, given.name, differing_parameters(reg, given))
}

/// **CS-9, an unregistered profile string** (outside `#[cfg(test)]`)
fn cs9_unregistered(given: &Shape) -> String {
    format!("{CS9}{:?} is not a block profile this build registers, so it names no shape ({:?} was handed)", given.profile, given.name)
}

fn ctx() -> Digest {
    *blake3::hash(b"stage 44: rulings K-1, K-2 and CS-9").as_bytes()
}

// ---------------------------------------------------------------- helpers

/// every registered block shape, and the test-only rung-K8
fn registered() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125(), super::k8_tests::rung_k8()]
}

/// `Shape::new` on `geometry`'s own parameters under `profile` (the windows
/// and endpoint parameters passed as the overrides they already are)
fn new_at(name: &'static str, profile: &'static str, g: &Shape) -> Result<Shape, String> {
    Shape::new(name, profile, g.tokens, g.width, g.hidden, g.q_heads, g.head_dim, g.kv_heads, g.log_cols, g.inv_rate, g.f_e, g.endpoint_rows, Some(g.endpoint_log_n), Some(g.endpoint_inv_rate), Some(g.norm_wrho), Some(g.wrho_s))
}

/// the padded endpoint planes of a witness at `sh`, committed by fresh owners
fn endpoints_with(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[ids.at(p)].iter().map(|v| i16::try_from(*v).expect("an int16 endpoint word")).collect() };
    let spec = IoSpec::new_shaped(sh, ctx(), 0, 0).expect("the endpoint spec");
    prepare_endpoints(spec, &plane(A_X), &plane(A_X2)).expect("the endpoint owner commits")
}

/// the dense public block at `sh` and its hidden input
fn dense_block(sh: &Shape) -> (BlockPublic, Vec<i16>) {
    let (att, ff, x) = super::dense_tests::dense_case(sh);
    (BlockPublic::new(att, ff), x)
}

fn honest_witness(sh: &Shape, b: &BlockPublic, x: &[i16]) -> Witness {
    witness::build_shaped(sh, b.attention(), b.feed_forward(), x).expect("an honest witness")
}

/// Drive `protocol::prove_core` directly with a deterministic public fixture
/// stream and the block's own transcript header. Returns the result, the
/// bytes drawn, the squeezes and whether the transcript moved.
fn direct_prove_core(sh: &Shape, lay: &Layout, blk: &BlockPublic, w: Witness, expected: &ExpectedIo, owners: Endpoints) -> (Result<protocol::CoreProof, String>, u64, u64, bool) {
    let [ein, eout] = protocol::check_endpoints(sh, expected, owners).expect("the endpoint owners");
    let ntt = crate::ntt::NttTables::new(protocol::ntt_log_at(sh));
    let mut rng = ZkRng::new(44, b"stage 44: a public fixture stream for the direct prove_core call");
    let mut tr = protocol::transcript(blk, expected, lay);
    let (before, sq) = (tr.state(), tr.squeezes());
    let mut ph = timing::Phases::start();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let mut tick = std::time::Instant::now();
    let res = protocol::prove_core(sh, lay, blk, w, [ein.data.as_slice(), eout.data.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick);
    (res, rng.consumed_bytes(), tr.squeezes() - sq, tr.state() != before)
}

/// Drive `protocol::verify_core` directly on a receipt's view, after the
/// header. Returns the result, the squeezes and whether the transcript moved.
fn direct_verify_core(sh: &Shape, lay: &Layout, blk: &BlockPublic, expected: &ExpectedIo, r: &Receipt) -> (Result<(), String>, u64, bool) {
    let ntt = crate::ntt::NttTables::new(protocol::ntt_log_at(sh));
    let mut tr = protocol::transcript(blk, expected, lay);
    let (before, sq) = (tr.state(), tr.squeezes());
    let mut ph = timing::Phases::start();
    let v = CoreView { a_root: r.a_root, h_root: r.h_root, mask_root: r.mask_root, slots: &r.slots, mask_open: &r.mask_open, a_open: &r.a_open, h_open: &r.h_open };
    let res = protocol::verify_core(sh, lay, blk, v, &ntt, &mut tr, &mut ph).map(|_| ());
    (res, tr.squeezes() - sq, tr.state() != before)
}

fn source(rel: &str) -> String {
    let p = Path::new(env!("CARGO_MANIFEST_DIR")).join(rel);
    std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("{}: {e}", p.display()))
}

// ============================================================ K-1: CS-3's text inside a run

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
/// (a lookup miss). The review's `LoggedChain` (`s39_s43_review_tests.rs`).
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

/// **ERRATUM K-1, the review's reproducer `rv_k1_the_cs3_refusal_text_is_false_in_a_run`
/// brought over as a PASSING test of the corrected text.** A rung-G run of
/// two blocks with one activation word of block `k` moved off its table row,
/// the honest run prover (ruling CS-3 on):
///
/// * block 0 tampered — the prover asks for `boundary_plane(0)` BEFORE
///   `witness(0)` (the stage header is absorbed and `B_0` drawn, committed
///   and absorbed first, `run.rs:746-757`), sinks nothing, and refuses by
///   ruling CS-3's name; the text no longer claims "nothing of this block was
///   drawn, absorbed or committed", and says what precedes it;
/// * block 1 tampered (the LAST block, no outgoing boundary) — stage 0 is
///   proved whole and its segment sunk before the refusal, which is what the
///   text's "every earlier stage" says.
///
/// Before stage 44 the first case refused with the false sentence
/// (`s44-before-named.log`; the review's own `rv-k1-reproducer.log`).
#[test]
fn s44_k1_the_cs3_refusal_text_says_what_precedes_it_in_a_run() {
    let sh = Shape::rung_g();
    let (att, ff, x0) = super::grow_tests::tame_case(&sh);
    let ids = Ids::new(&sh).expect("the plane map");
    let w0 = witness::build_shaped(&sh, &att, &ff, &x0).expect("block 0's honest witness");
    let (p0, p1) = (padded(&w0, ids.at(A_X)), padded(&w0, ids.at(A_X2)));
    let x1 = true_input(&sh, &w0.output().expect("block 0's output"));
    let w1 = witness::build_shaped(&sh, &att, &ff, &x1).expect("block 1's honest witness");
    let p2 = padded(&w1, ids.at(A_X2));
    let blocks = vec![BlockPublic::new(att.clone(), ff.clone()), BlockPublic::new(att.clone(), ff.clone())];
    let want = cs3("the activation table");
    for (tamper_block, want_log, want_sunk) in [(0usize, vec!["boundary_plane(0)", "witness(0)"], 0usize), (1, vec!["boundary_plane(0)", "witness(0)", "witness(1)"], 1)] {
        let spec = IoSpec::new_shaped(&sh, ctx(), 0, 0).expect("the run's endpoint spec");
        let (expected, owners) = prepare_endpoints(spec, &p0, &p2).expect("the external endpoint owners");
        let st = RunStatement::new(RunShape::rung_g(2).expect("the rung-G run shape"), ctx(), expected, &blocks, &[(0, 0), (0, 0)]).expect("the run statement");
        let mut src = LoggedChain { sh: sh.clone(), att: att.clone(), ff: ff.clone(), inputs: vec![x0.clone(), x1.clone()], planes: vec![p0.clone(), p1.clone(), p2.clone()], tamper_block, log: Vec::new() };
        let mut sunk = 0usize;
        let r = run::prove_run(&st, &blocks, &mut src, owners, &mut |_, _| {
            sunk += 1;
            Ok(())
        });
        let e = r.err().expect("the run prover must refuse the tampered block");
        eprintln!("S44 K-1 block {tamper_block} tampered: the run prover asked for {:?}, sank {sunk} segment(s), and refused: {e}", src.log);
        assert!(!e.contains("nothing of this block was drawn, absorbed or committed"), "K-1: the CS-3 refusal still says nothing of the block was drawn, absorbed or committed ({:?} came first)", src.log);
        assert_eq!(e, want, "K-1: the run prover's CS-3 refusal is not the corrected text");
        assert_eq!(src.log, want_log, "the run prover's requests moved");
        assert_eq!(sunk, want_sunk, "the segments sunk before the refusal moved");
    }
}

// ============================================================ K-2: no count in CS-3's text

/// every U8 word the prover would look up that is not a byte (counted here,
/// as `s40_tests` does, from `lookup_values`)
fn u8_miss_count(s: &Shape, w: &Witness) -> usize {
    let lay = Layout::for_shape(s).expect("the layout");
    lay.lookup_doms().iter().map(|d| lookup_values(&lay, w, *d).iter().flatten().filter(|v| !(0..U8_LEN as i64).contains(*v)).count()).sum()
}

/// the exp pairs that are not rows of the statement's exp table
fn exp_miss_count(s: &Shape, blk: &BlockPublic, w: &Witness) -> usize {
    let lay = Layout::for_shape(s).expect("the layout");
    let e = &w.planes[lay.ids().at(A_E)];
    exp_deltas(&lay, w).iter().enumerate().filter(|(x, d)| !((0..U8_LEN as i64).contains(*d) && blk.attention().exp[**d as usize] == e[*x])).count()
}

/// the activation pairs that are not rows of the statement's table
fn act_miss_count(s: &Shape, blk: &BlockPublic, w: &Witness) -> usize {
    let lay = Layout::for_shape(s).expect("the layout");
    let a = &w.planes[lay.ids().at(A_A16)];
    act_indices(&lay, w).iter().enumerate().filter(|(x, i)| !((0..U8_LEN as i64).contains(*i) && i64::from(blk.feed_forward().act[**i as usize]) == a[*x])).count()
}

/// **ERRATUM K-2: ruling CS-3's refusal names WHICH table family missed and
/// never HOW MANY words did.** The honest dense rung-G witness, with `n`
/// looked-up values of one family moved off their table (U8: byte limbs set
/// to 256; exp: exp values moved by one; activation: activation values moved
/// by one) at `n = 1` and `n = 4` positions — the miss counts, measured here
/// independently, differ — and all three families at once. The honest
/// single-block prover refuses each by ruling CS-3's name with a text that
/// is the SAME for both counts and names the family (or families). Before
/// stage 44 the text printed the three counts (`s44-before-named.log`).
#[test]
fn s44_k2_the_cs3_refusal_names_the_table_family_that_missed_and_no_count() {
    let g = Shape::rung_g();
    let (blk, x) = dense_block(&g);
    let ids = Ids::new(&g).expect("the plane map");
    let tamper = |families: &[usize], n: usize| -> Witness {
        let mut w = honest_witness(&g, &blk, &x);
        for f in families {
            for p in 0..n {
                match f {
                    0 => w.planes[ids.at(A_XL0)][p] = 256,
                    1 => w.planes[ids.at(A_E)][p] += 1,
                    _ => w.planes[ids.at(A_A16)][p] += 1,
                }
            }
        }
        w
    };
    let counts = |w: &Witness| (u8_miss_count(&g, w), exp_miss_count(&g, &blk, w), act_miss_count(&g, &blk, w));
    let refusal = |w: Witness| -> String {
        let (expected, owners) = endpoints_with(&g, &w);
        prove_inner_at(&g, &blk, w, &expected, owners).map(|_| ()).err().unwrap_or_else(|| "PROVED".into())
    };
    let names = ["the byte table", "the exp table", "the activation table"];
    for f in 0..3 {
        let (one, four) = (tamper(&[f], 1), tamper(&[f], 4));
        let (c1, c4) = (counts(&one), counts(&four));
        let pick = |c: (usize, usize, usize)| [c.0, c.1, c.2][f];
        assert!(pick(c1) > 0 && pick(c4) > pick(c1), "{}: the two tampers do not miss a different number of words ({c1:?}, {c4:?})", names[f]);
        let (e1, e4) = (refusal(one), refusal(four));
        eprintln!("S44 K-2 {}: misses (U8, exp, act) {c1:?} and {c4:?}; the refusals:\n  {e1}\n  {e4}", names[f]);
        assert_eq!(e1, e4, "K-2: the CS-3 refusal depends on how many words of {} missed", names[f]);
        assert_eq!(e1, cs3(names[f]), "K-2: the CS-3 refusal does not name the family {} alone", names[f]);
    }
    let all = refusal(tamper(&[0, 1, 2], 2));
    assert_eq!(all, cs3("the byte table, the exp table, the activation table"), "K-2: the CS-3 refusal on three families");
    eprintln!("S44 K-2: the refusal names the family that missed, is identical at 1 and 4 misses, and names all three when all three miss");
}

// ============================================================ CS-9: the block profile registry

/// the frozen toy's PROFILE STRING at rung-G's geometry (the review's K-4
/// shape, `s39_s43_review_tests.rs::toy_profile_at_rung_g`)
fn k4_shape() -> Result<Shape, String> {
    Shape::new("review: the toy profile at rung-G geometry", TOY_PROFILE, 24, 96, 192, 6, 16, 2, 10, 4, 12, 9, None, None, None, None)
}

/// **RULING CS-9 on the review's K-4 shape, at construction.** The frozen
/// toy's profile string at rung-G's geometry — before stage 44 admitted by
/// `Shape::new`, by CS-8, by the layout, by CS-1/CS-4 and by the builder,
/// carrying no pad rule while `Dom::F` and `Dom::D` pad and hashing under the
/// legacy rule, and its honest proofs REJECTED by the verifier at slot 2
/// (`s44-before-reproducer.log`) — is refused by `Shape::new`, by name,
/// before any value exists. The text pinned as a literal.
#[test]
fn s44_cs9_the_toy_profile_string_at_rung_g_geometry_is_refused_by_name_at_construction() {
    let r = k4_shape();
    eprintln!("S44 CS-9 the toy profile string at rung-G geometry: {:?}", r.as_ref().map(|s| s.name));
    assert_eq!(
        r.err().as_deref(),
        Some("private block shape: ruling CS-9 — the block profile \"hashline-zk-mr1/private-block-t32-poc/1\" is registered for exactly one shape, \"toy block (T32 / d16 / f16, 2 heads of 8 over 1 KV head)\"; the shape handed, \"review: the toy profile at rung-G geometry\", differs from it in name, tokens, width, hidden, q_heads, head_dim, kv_heads, log_cols, inv_rate, f_e, endpoint_rows, endpoint_log_n, endpoint_inv_rate, norm_wrho, wrho_s"),
        "CS-9: Shape::new did not refuse the toy's profile string at rung-G's geometry by name"
    );
}

/// **RULING CS-9, every registered profile string at every other registered
/// shape.** Nine registered block shapes and the test-only rung-K8 (ten, so
/// ninety ordered pairs): profile `i` handed with shape `j`'s name and
/// parameters is refused by `Shape::new` by CS-9's name, listing the
/// parameters that differ; the same value reached by a FIELD WRITE (shape
/// `j` with its `profile` written to `i`'s) is refused by CS-8's re-check,
/// which runs `Shape::new` and so carries CS-9's refusal. A registered shape
/// with only its NAME changed is refused too: a profile names one shape
/// value, as CS-7 compares a run's block shape whole. Every registered shape
/// with its own profile is admitted by both.
#[test]
fn s44_cs9_every_registered_block_profile_at_every_other_registered_shape_is_refused_by_name() {
    let reg = registered();
    let mut admitted = Vec::new();
    for (i, pi) in reg.iter().enumerate() {
        for (j, sj) in reg.iter().enumerate() {
            if i == j {
                assert_eq!(new_at(sj.name, sj.profile, sj).as_ref(), Ok(sj), "{}: Shape::new does not return the registered shape on its own parameters", sj.name);
                sj.check_constructed().unwrap_or_else(|e| panic!("{}: CS-8 refuses a registered shape: {e}", sj.name));
                continue;
            }
            let handed = Shape { profile: pi.profile, ..sj.clone() };
            let want = cs9_other(pi, &handed);
            match new_at(sj.name, pi.profile, sj) {
                Err(e) => assert_eq!(e, want, "profile {} at the shape of {}: refused, but not by CS-9's name", pi.profile, sj.name),
                Ok(_) => admitted.push(format!("Shape::new: profile {} at the shape of {}", pi.profile, sj.name)),
            }
            match handed.check_constructed() {
                Err(e) => assert_eq!(e, cs8_refused(&handed, &want), "profile {} written on {}: refused, but not by CS-8 carrying CS-9", pi.profile, sj.name),
                Ok(()) => admitted.push(format!("check_constructed: {} with its profile written to {}", sj.name, pi.profile)),
            }
        }
    }
    eprintln!("S44 CS-9 pairs: {} of {} ordered pairs admitted somewhere", admitted.len(), reg.len() * (reg.len() - 1));
    assert!(admitted.is_empty(), "CS-9: a registered block profile string was admitted at another registered shape:\n{}", admitted.join("\n"));
    // the name alone
    let toy = Shape::toy();
    let renamed = Shape { name: "the toy under another name", ..toy.clone() };
    assert_eq!(new_at(renamed.name, TOY_PROFILE, &toy).err(), Some(cs9_other(&toy, &renamed)), "CS-9: the toy's profile with only the name changed was admitted");
    eprintln!("S44 CS-9: the 90 ordered pairs of the ten registered/test shapes refused by CS-9's name at Shape::new and by CS-8 carrying it on a written profile; a renamed toy refused; the ten admitted on their own");
}

/// **RULING CS-9 at the entries: a written profile is refused at every
/// single-block entry and in both shared bodies, first, with nothing drawn
/// or absorbed.** Rung-G with its `profile` field written to the toy's —
/// the review's K-4 shape reached by a field write instead of `Shape::new`,
/// which CS-9 now refuses (stage 43's lesson: `Shape`'s fields are writable
/// across the crate, so what a constructor refuses must be re-checked at the
/// entries, which ruling CS-8 does by running `Shape::new` again). The rung-G
/// control proves and verifies. Before stage 44 the written shape passed
/// every check (`s44-before-named.log`).
#[test]
fn s44_cs9_a_written_profile_is_refused_by_name_at_every_entry_before_anything_is_drawn() {
    let g = Shape::rung_g();
    let written = Shape { profile: TOY_PROFILE, ..g.clone() };
    let want = cs8_refused(&written, &cs9_other(&Shape::toy(), &written));
    let (blk, x) = dense_block(&g);
    // the control
    let wg = honest_witness(&g, &blk, &x);
    let (expected, owners) = endpoints_with(&g, &wg);
    let (receipt, _) = prove_inner_at(&g, &blk, wg, &expected, owners).expect("the control proves at rung-G");
    let bytes = receipt.to_bytes_at(&g, &blk, &expected).expect("the control encodes");
    verify_bytes_at(&g, &blk, &expected, &bytes).expect("the control verifies at rung-G");
    // 1. the prover's entry, with a policy made for the written shape
    let ww = honest_witness(&written, &blk, &x);
    let (expected_w, owners_w) = endpoints_with(&written, &ww);
    let outcome = catch_unwind(AssertUnwindSafe(|| match prove_inner_at(&written, &blk, ww, &expected_w, owners_w) {
        Err(e) => format!("the prover refuses: {e}"),
        Ok((r, _)) => match protocol::verify_inner_at(&written, &blk, &expected_w, &r) {
            Ok(_) => "PROVED and ACCEPTED in memory".to_string(),
            Err(e) => format!("PROVED; the in-memory verifier rejects: {e}"),
        },
    }))
    .unwrap_or_else(|_| "PANICKED".into());
    eprintln!("S44 CS-9 rung-G with its profile written to the toy's, at the prover's entry: {outcome}");
    assert_eq!(outcome, format!("the prover refuses: {want}"), "1. the prover's entry did not refuse the written profile by name");
    // 2. the verifier's two entries
    let vb = verify_bytes_at(&written, &blk, &expected_w, &[0u8; 64]).err().unwrap_or_else(|| "ACCEPTED".into());
    assert_eq!(vb, want, "2. verify_bytes_at did not refuse the written profile by name before decoding");
    let vi = protocol::verify_inner_at(&written, &blk, &expected, &receipt).map(|_| ()).err().unwrap_or_else(|| "ACCEPTED".into());
    assert_eq!(vi, want, "2. verify_inner_at did not refuse the written profile by name");
    // 3. the two shared bodies, handed the written shape and its own layout
    let lay = Layout::for_shape(&written).expect("Layout::for_shape builds a layout for the written shape");
    let ww = honest_witness(&written, &blk, &x);
    let (expected_w, owners_w) = endpoints_with(&written, &ww);
    let (pc, drawn, squeezes, moved) = direct_prove_core(&written, &lay, &blk, ww, &expected_w, owners_w);
    eprintln!("S44 CS-9 prove_core at the written shape: {:?} ({drawn} bytes drawn, {squeezes} squeezes, transcript moved: {moved})", pc.as_ref().map(|_| "PROVED"));
    assert_eq!(pc.err(), Some(want.clone()), "3. prove_core did not refuse the written profile by name");
    assert_eq!((drawn, squeezes, moved), (0, 0, false), "3. prove_core drew, squeezed or absorbed before the CS-9 refusal");
    let (vc, squeezes, moved) = direct_verify_core(&written, &lay, &blk, &expected_w, &receipt);
    assert_eq!(vc.err(), Some(want), "3. verify_core did not refuse the written profile by name");
    assert_eq!((squeezes, moved), (0, false), "3. verify_core squeezed or absorbed before the CS-9 refusal");
    eprintln!("S44 CS-9 entries: the written profile refused by name at prove_inner_at, verify_bytes_at (64 zero bytes), verify_inner_at, prove_core (0 bytes drawn, 0 squeezes, transcript unmoved) and verify_core (0 squeezes, transcript unmoved); the rung-G control proves and verifies");
}

// ------------------------------------------------ CS-9 in the source: ONE registry, ONE way past it

/// the name of the `fn` whose body contains byte `at` of `src` (the nearest
/// signature line above it, indented as a method or a free function)
fn enclosing_fn(src: &str, at: usize) -> String {
    let before = &src[..at];
    let sig = ["\n    pub(crate) fn ", "\n    fn ", "\npub(crate) fn ", "\nfn "].iter().filter_map(|p| before.rfind(p).map(|i| i + p.len())).max().expect("a signature above");
    src[sig..].split(|c: char| !(c.is_alphanumeric() || c == '_')).next().unwrap_or_default().to_string()
}

/// **RULING CS-9's structure, read out of `shape.rs`** (the K-3 lesson: a
/// second way to make a value is what reopens a hole). The unchecked body
/// `Shape::build` is PRIVATE; it is called only by `Shape::new` (which then
/// runs CS-9) and by the registered constructors, which ARE the registry's
/// entries; the registry lists exactly those constructors; it is handed as a
/// function pointer once, to rung-K8's `#[cfg(test)]` registry arm; and every
/// profile literal in `shape.rs` is the profile of a registered shape.
/// Returns the violations.
fn cs9_structure(src: &str) -> Vec<String> {
    let mut out = Vec::new();
    let constructors = ["toy", "rung", "rung_g", "rung_k4", "rung_p2", "rung_c6", "rung_w14", "rung_e32", "m125"];
    match src.find("fn build(") {
        None => out.push("no fn build( in shape.rs".into()),
        Some(at) => {
            let line = &src[src[..at].rfind('\n').map(|i| i + 1).unwrap_or(0)..at];
            if line.trim() != "" {
                out.push(format!("fn build( is not private: {:?}", line.trim()));
            }
        }
    }
    let mut callers: Vec<String> = src.match_indices("Shape::build(").map(|(i, _)| enclosing_fn(src, i)).collect();
    callers.sort();
    let mut want: Vec<String> = constructors.iter().map(|c| c.to_string()).chain(["new".to_string()]).collect();
    want.sort();
    if callers != want {
        out.push(format!("Shape::build( is called from {callers:?}, not exactly from new and the nine registered constructors"));
    }
    let pointer_uses: Vec<usize> = src.match_indices("Shape::build)").map(|(i, _)| i).collect();
    if pointer_uses.len() != 1 {
        out.push(format!("Shape::build is handed as a function pointer {} times (1 expected, rung-K8's registry arm)", pointer_uses.len()));
    } else {
        let at = pointer_uses[0];
        if enclosing_fn(src, at) != "registered_block_shape" {
            out.push(format!("Shape::build is handed as a function pointer inside {}", enclosing_fn(src, at)));
        }
        let arm = &src[src[..at].rfind("#[cfg(test)]").unwrap_or(0)..at];
        if arm.lines().count() > 3 {
            out.push("rung-K8's registry arm is not directly under #[cfg(test)]".into());
        }
    }
    match src.find("const REGISTERED_BLOCK_SHAPES: [fn() -> Shape; 9] = [") {
        None => out.push("no REGISTERED_BLOCK_SHAPES list of nine constructors".into()),
        Some(at) => {
            let list = &src[at..at + src[at..].find("];").expect("the list closes")];
            let mut listed: Vec<String> = list.split("Shape::").skip(1).map(|s| s.split(|c: char| !(c.is_alphanumeric() || c == '_')).next().unwrap_or_default().to_string()).collect();
            listed.sort();
            let mut ctors: Vec<String> = constructors.iter().map(|c| c.to_string()).collect();
            ctors.sort();
            if listed != ctors {
                out.push(format!("the registry lists {listed:?}, not the nine registered constructors"));
            }
        }
    }
    out
}

/// **RULING CS-9's structure, and that the guard catches what would reopen
/// K-4** (in-test mutations of the source text, the review's K-3 approach;
/// no mutation is ever written to disk): (a) the source as it stands passes;
/// (b) a second `pub(crate)` function that returns `Shape::build`'s value
/// without CS-9; (c) `build` made `pub(crate)`; (d) 125M dropped from the
/// registry. Also: the registry's profiles are exactly the block profile
/// literals of `shape.rs`.
#[test]
fn s44_cs9_the_registry_is_one_list_and_build_has_no_other_caller() {
    let src = source("src/private_block/shape.rs");
    assert_eq!(cs9_structure(&src), Vec::<String>::new(), "(a) CS-9's structure fails on the source as it stands");
    let b = src.replacen("impl Shape {\n", "impl Shape {\n    pub(crate) fn from_parts(name: &'static str, profile: &'static str) -> Result<Shape, String> {\n        Shape::build(name, profile, 32, 16, 16, 2, 8, 1, 8, 8, 9, 7, None, None, None, None)\n    }\n", 1);
    assert_ne!(b, src, "(b) the mutation did not apply");
    assert!(!cs9_structure(&b).is_empty(), "(b) the guard missed a second caller of Shape::build");
    let c = src.replacen("    fn build(", "    pub(crate) fn build(", 1);
    assert_ne!(c, src, "(c) the mutation did not apply");
    assert!(!cs9_structure(&c).is_empty(), "(c) the guard missed build made visible");
    let d = src.replacen(", Shape::m125]", "]", 1);
    assert_ne!(d, src, "(d) the mutation did not apply");
    assert!(!cs9_structure(&d).is_empty(), "(d) the guard missed a constructor dropped from the registry");
    // the profile literals of shape.rs are exactly the nine registered profiles
    let mut literals: Vec<String> = Vec::new();
    let mut rest = src.as_str();
    while let Some(i) = rest.find("\"hashline-zk-mr1/") {
        let after = &rest[i + 1..];
        let end = after.find('"').expect("a closing quote");
        literals.push(after[..end].to_string());
        rest = &after[end..];
    }
    literals.sort();
    literals.dedup();
    let mut profiles: Vec<String> = registered().iter().take(9).map(|s| s.profile.to_string()).collect();
    profiles.sort();
    assert_eq!(literals, profiles, "the block profile literals of shape.rs are not the nine registered profiles");
    eprintln!("S44 CS-9 structure: build private, called only by new and the nine registered constructors, handed once to rung-K8's cfg(test) arm; the registry lists the nine; the guard catches a second caller, a visible build and a dropped constructor");
}

// ------------------------------------------------ the review's K-4 reproducer (run failing first, then deleted)

// **MEASURED BEFORE CS-9, AND DELETED BY IT.** The review's ignored
// reproducer `rv_k4_an_admitted_toy_profile_shape_at_another_geometry_fails_its_honest_proofs`
// stood here as `s44_before_k4_reproducer_...` and was run on this lane with
// `--ignored` before any production line moved
// (`results/zk60_block125m_lane/s44-before-reproducer.log`, `.done` = 101):
// at the toy's profile string over rung-G's geometry the builder admitted,
// the honest prover (CS-3 on) PROVED, and the in-memory verifier REJECTED
// the honest proof on the dense input, the tame input and all zeros — each
// at slot 2, the norm squares zero-check ("sumcheck round 0: s(0) + s(1) !=
// claim"). Its first line, `Shape::new` admitting that shape, is what CS-9
// refuses (`s44_cs9_the_toy_profile_string_at_rung_g_geometry_is_refused_by_name_at_construction`),
// so the test cannot stand; the same shape reached by a field write is
// refused at every entry (`s44_cs9_a_written_profile_is_refused_by_name_at_every_entry_before_anything_is_drawn`).

// ------------------------------------------------ CS-9 outside #[cfg(test)] (written after the ruling was built)

/// **RULING CS-9's second half: an unregistered block profile string is
/// refused outside `#[cfg(test)]`.** A test build admits one — every probe
/// and fixture shape of the test files is built under its own string — so
/// what a release build does is shown through the check as a build without
/// `#[cfg(test)]` makes it: the probes are refused by name; every registered
/// shape passes it, and so does rung-K8, whose profile is registered in this
/// (test) build only (in a release build its arm does not exist and its
/// profile is unregistered; `s44-release-lib.log` builds the library without
/// `#[cfg(test)]`). The stage-24 registry is unchanged: the nine profiles.
#[test]
fn s44_cs9_an_unregistered_block_profile_is_refused_outside_cfg_test() {
    for s in registered() {
        s.check_block_profile_as_a_release_build().unwrap_or_else(|e| panic!("{}: the release form of CS-9 refuses a registered shape: {e}", s.name));
    }
    let probes = [
        Shape::new("stage 44: an unregistered probe at the toy's geometry", "hashline-zk-mr1/s44-probe/1", 32, 16, 16, 2, 8, 1, 8, 8, 9, 7, None, None, None, None).expect("a test build admits an unregistered profile string"),
        Shape::new("stage 44: an unregistered probe at rung-G's geometry", "hashline-zk-mr1/s44-probe-g/1", 24, 96, 192, 6, 16, 2, 10, 4, 12, 9, None, None, None, None).expect("a test build admits an unregistered profile string"),
    ];
    for p in &probes {
        p.check_constructed().unwrap_or_else(|e| panic!("{}: CS-8 refuses an unregistered probe in a test build: {e}", p.name));
        assert_eq!(p.check_block_profile_as_a_release_build().err(), Some(cs9_unregistered(p)), "{}: the release form of CS-9 does not refuse an unregistered profile string by name", p.name);
    }
    eprintln!("S44 CS-9 release form: the ten registered/test shapes pass; two unregistered probes (admitted by this test build) refused by name");
}
