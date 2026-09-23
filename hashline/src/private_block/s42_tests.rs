//! **STAGE 42 (test-only): rulings CS-6 and CS-7 of the shaped refusal census
//! disposition** (`docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS_DISPOSITION.md`
//! §6, security owner), on stage 41's two measured notes.
//!
//! * **CS-6 (finding S41-N2, statement binding)** — the run absorbs the
//!   STATEMENT's `block_digests[k]` (`pb-run-block`) but proves and verifies
//!   against the `BlockPublic` values it is HANDED, and before this stage
//!   nothing compared the two: a statement naming block X, proved with block
//!   Y, was accepted by a run verifier handed Y. `prove_run`,
//!   `RunVerifier::start` and every path that reads or reconstructs a run
//!   statement from bytes refuse, by name and before anything is absorbed,
//!   unless `blocks.len() == L` and `blocks[k].digest() == st.block_digests[k]`
//!   for every `k`.
//! * **CS-7 (finding S41-N1)** — `RunShape::new` refuses, by name, a run
//!   profile not registered for the block shape it is given: privacy
//!   statements and hash keys (D19a) are per PROFILE, so a profile string
//!   names exactly one shape.
//!
//! FAILING FIRST. The reproducers and the named tests below were written and
//! run at the lane tip `7843f5d` (stage 42's skeleton over `17d10ac`) before
//! any production line moved (`results/zk60_block125m_lane/s42-before-*.log`).
//! The literals of the two rulings' refusal texts are held here so that the
//! tests could be run, and fail, before the production text existed. The
//! one NOTE at the end (S42-N1) was written after the rulings were built: it
//! measured what CS-7, as ruled, did not reach — and was deleted at stage 43,
//! when ruling CS-8 made the struct literal it built stop compiling.
//!
//! **The cheating RUN prover.** To show what the VERIFIER does with the
//! receipt the attack produces, the tests have to produce it — and since
//! CS-6 the honest run prover refuses to. A cheating prover runs none of the
//! honest prover's own checks, and the soundness tests already play one with
//! ruling CS-3's `#[cfg(test)]` switch `protocol::CheatingProver`; the run
//! prover's copy of the CS-6 check honours the same switch (test builds
//! only), so the forged receipt exists here exactly as it did before the
//! ruling and the verifier's refusal is measured on it.
//!
//! Nothing here is a privacy result. Everything proved is PUBLIC SYNTHETIC
//! test data.

use super::layout::*;
use super::protocol;
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::run_sink::{self, DirSink, SegmentSink};
use super::run_statement_file::{self, DENSE_RUN_FIXTURE, TAME_FIXTURE};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use std::path::{Path, PathBuf};

// ---------------------------------------------------------------- the names

/// **RULING CS-6's names**: the run layer's, and the statement file reader's
const CS6: &str = "private run: ruling CS-6 — ";
const CS6_FILE: &str = "run statement: ruling CS-6 — ";
/// **RULING CS-7's name**
const CS7: &str = "private run: ruling CS-7 — ";

fn hex(d: &Digest) -> String {
    d.iter().map(|b| format!("{b:02x}")).collect()
}

fn hex8(d: &Digest) -> String {
    d[..8].iter().map(|b| format!("{b:02x}")).collect()
}

/// block `k` handed to a run is not the one its statement names
fn cs6_block(k: usize, got: &Digest, want: &Digest) -> String {
    format!("{CS6}block {k} handed to the run is not the block the run statement names (its public digest begins {}, the statement's {}); refused before anything is absorbed", hex8(got), hex8(want))
}

/// a run statement for `l` blocks handed `n`
fn cs6_count(l: usize, n: usize) -> String {
    format!("{CS6}the run statement names {l} blocks and {n} public statements were handed")
}

/// the statement file reader: the recipe's block `k` is not the file's
fn cs6_file_block(k: usize) -> String {
    format!("{CS6_FILE}block {k} regenerated from the named weights recipe is not the block the file's statement names (block digest {k} differs); refused before the statement is built")
}

/// the statement file reader: the file names `d` digests for `l` blocks
fn cs6_file_count(d: usize, l: usize) -> String {
    format!("{CS6_FILE}the file's statement names {d} block digests for {l} blocks")
}

/// a registered run profile over a block shape it is not registered for
fn cs7_pair(profile: &str, reg: &Shape, sh: &Shape) -> String {
    format!("{CS7}the run profile {profile:?} is registered for the block shape {:?} ({}), not for {:?} ({})", reg.name, reg.profile, sh.name, sh.profile)
}

/// a run profile this build does not register at all
fn cs7_unregistered(profile: &str, sh: &Shape) -> String {
    format!("{CS7}{profile:?} is not a run profile this build registers, so it names no block shape ({:?} was given)", sh.name)
}

fn ctx() -> Digest {
    *blake3::hash(b"stage 42: rulings CS-6 and CS-7").as_bytes()
}

// ---------------------------------------------------------------- the case

/// Two ADMISSIBLE blocks at the same shape (rung-G): X is the lane's tame
/// public fixture, Y the dense one. Every refusal below is about which of the
/// two a statement NAMES, never about either being malformed.
struct Case {
    g: Shape,
    bx: BlockPublic,
    by: BlockPublic,
    in_x: Vec<i16>,
    in_y: Vec<i16>,
}

fn case() -> Case {
    let g = Shape::rung_g();
    let (att_x, ff_x, in_x) = super::grow_tests::tame_case(&g);
    let (att_y, ff_y, in_y) = super::dense_tests::dense_case(&g);
    let (bx, by) = (BlockPublic::new(att_x, ff_x), BlockPublic::new(att_y, ff_y));
    assert_ne!(bx.digest(), by.digest(), "the two blocks are the same statement");
    Case { g, bx, by, in_x, in_y }
}

fn honest_witness(sh: &Shape, b: &BlockPublic, x: &[i16]) -> Witness {
    witness::build_shaped(sh, b.attention(), b.feed_forward(), x).expect("an honest witness")
}

/// the padded endpoint planes of a witness at `sh`, committed by fresh owners
fn endpoints_with(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[ids.at(p)].iter().map(|v| i16::try_from(*v).expect("an int16 endpoint word")).collect() };
    let spec = IoSpec::new_shaped(sh, ctx(), 0, 0).expect("the endpoint spec");
    prepare_endpoints(spec, &plane(A_X), &plane(A_X2)).expect("the endpoint owner commits")
}

/// a one-block rung-G run statement over `b`
fn one_block_statement(b: &BlockPublic, expected: ExpectedIo) -> RunStatement {
    RunStatement::new(RunShape::rung_g(1).expect("run shape"), ctx(), expected, &[b.clone()], &[(0, 0)]).expect("a one-block run statement")
}

/// A one-block run's witness source that COUNTS what it is asked for: a
/// refusal that fires before stage 0 begins asks for nothing.
struct Counting {
    w: Option<Witness>,
    witness_asked: usize,
    plane_asked: usize,
}

impl Counting {
    fn new(w: Witness) -> Counting {
        Counting { w: Some(w), witness_asked: 0, plane_asked: 0 }
    }
}

impl RunWitnessSource for Counting {
    fn witness(&mut self, _k: usize) -> Result<Witness, String> {
        self.witness_asked += 1;
        self.w.take().ok_or_else(|| "stage 42: the one witness was already handed out".to_string())
    }
    fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
        self.plane_asked += 1;
        Err("stage 42: this source has no boundary plane".into())
    }
}

/// **THE FORGED RECEIPT**: statement `st` proved with block `b` by a CHEATING
/// run prover (ruling CS-3's test-only switch, which the run prover's copy of
/// CS-6 honours), its segments kept
fn forge(st: &RunStatement, b: &BlockPublic, w: Witness, owners: Endpoints) -> Vec<Vec<u8>> {
    let _cheat = protocol::CheatingProver::on();
    let mut segs: Vec<Vec<u8>> = Vec::new();
    run::prove_run(st, &[b.clone()], &mut Counting::new(w), owners, &mut |_, bytes| {
        segs.push(bytes);
        Ok(())
    })
    .expect("the cheating run prover proves the handed block under the statement");
    segs
}

/// the same forged receipt, written to a run directory
fn forge_to_dir(st: &RunStatement, b: &BlockPublic, w: Witness, owners: Endpoints, dir: &Path) {
    let _cheat = protocol::CheatingProver::on();
    let mut disk = DirSink::create(dir, st.rs().l()).expect("the run directory sink");
    run::prove_run(st, &[b.clone()], &mut Counting::new(w), owners, &mut |k, bytes| disk.accept(k, bytes)).expect("the cheating run prover proves the handed block into the directory");
}

/// A temporary run directory under the system temporary directory, removed
/// when the test leaves. Never inside the repository.
struct TempRunDir(PathBuf);

impl TempRunDir {
    fn new(tag: &str) -> TempRunDir {
        let n = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
        let p = std::env::temp_dir().join(format!("hl-private-run-s42-{tag}-{}-{n}", std::process::id()));
        std::fs::create_dir_all(&p).unwrap_or_else(|e| panic!("the test's temporary run directory {}: {e}", p.display()));
        TempRunDir(p)
    }
    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempRunDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

/// An HONEST one-block rung-G run of X, proved into a directory, with its
/// public statement retained beside it (`verify_then_write`, the tame
/// recipe) — the file a fresh reader rebuilds a statement from.
fn honest_x_run_with_statement(tag: &str) -> (TempRunDir, Case) {
    let c = case();
    let tmp = TempRunDir::new(tag);
    let w = honest_witness(&c.g, &c.bx, &c.in_x);
    let (expected, owners) = endpoints_with(&c.g, &w);
    let st = one_block_statement(&c.bx, expected);
    let mut disk = DirSink::create(tmp.path(), 1).expect("the run directory sink");
    run::prove_run(&st, &[c.bx.clone()], &mut Counting::new(w), owners, &mut |k, bytes| disk.accept(k, bytes)).expect("the honest run of X");
    run_statement_file::verify_then_write(&st, &[c.bx.clone()], tmp.path(), &TAME_FIXTURE).expect("the honest run verifies and its statement is retained");
    (tmp, c)
}

/// `s` with its one occurrence of `from` replaced by `to`
fn replace_once(s: &str, from: &str, to: &str) -> String {
    assert_eq!(s.matches(from).count(), 1, "{from:?} does not occur exactly once in the statement file");
    s.replacen(from, to, 1)
}

/// the text of the function whose signature starts at `sig`, up to the first
/// `close` after it (the closing brace at the function's own indentation)
fn fn_body<'a>(text: &'a str, sig: &str, close: &str) -> &'a str {
    let at = text.find(sig).unwrap_or_else(|| panic!("{sig} is not in the source"));
    let end = text[at..].find(close).unwrap_or_else(|| panic!("{sig}'s body does not close")) + at;
    &text[at..end]
}

fn run_source() -> String {
    let p = Path::new(env!("CARGO_MANIFEST_DIR")).join("src/private_block/run.rs");
    std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("{}: {e}", p.display()))
}

// ------------------------------------------------ CS-6: the reproducers (failing first)

/// **S41-N2's REPRODUCER, on the HONEST path** (no cheating switch): a
/// one-block run statement over X, handed Y's public words and Y's witness.
/// Before stage 42 the run prover proved it and the run verifier handed Y
/// ACCEPTED it. Since ruling CS-6 the run prover refuses by name.
#[test]
fn s42_reproducer_cs6_a_run_statement_over_x_proved_and_verified_with_y() {
    let c = case();
    let w = honest_witness(&c.g, &c.by, &c.in_y);
    let (expected, owners) = endpoints_with(&c.g, &w);
    let st = one_block_statement(&c.bx, expected);
    let mut segs: Vec<Vec<u8>> = Vec::new();
    let r = run::prove_run(&st, &[c.by.clone()], &mut Counting::new(w), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    });
    let v = match r {
        Err(e) => format!("the run prover refuses: {e}"),
        Ok(_) => match run::verify_run(&st, &[c.by.clone()], &segs) {
            Ok(()) => "ACCEPTED: the run prover proved Y under the statement over X and the run verifier handed Y accepted it".to_string(),
            Err(e) => format!("the run verifier handed Y rejects: {e}"),
        },
    };
    eprintln!("S42 REPRODUCER CS-6 (a statement over X, the run handed Y, honest path): {v}");
    assert_eq!(v, format!("the run prover refuses: {}", cs6_block(0, &c.by.digest(), &c.bx.digest())), "CS-6: a run statement over X was proved with Y");
}

/// **THE STATEMENT WRITER's reproducer (stage 18's `verify_then_write`).**
/// The writer verifies the run from its directory and then checks the named
/// weights recipe against the blocks it is HANDED — not against the digests
/// the statement holds. Handed a run whose statement names X, proved with Y
/// (the forged receipt), and the dense RUN recipe that regenerates Y, it
/// wrote a statement file that names X's digest beside a recipe that
/// regenerates Y, which a fresh reader then refuses. Since ruling CS-6 the
/// streaming verification inside the writer refuses first and nothing is
/// written.
#[test]
fn s42_reproducer_cs6_the_statement_writer_handed_a_run_over_x_proved_with_y() {
    let g = Shape::rung_g();
    let (att_x, ff_x, _) = super::grow_tests::tame_case(&g);
    let (att_y, ff_y, in_y) = super::dense_tests::dense_run_case(&g);
    let (bx, by) = (BlockPublic::new(att_x, ff_x), BlockPublic::new(att_y, ff_y));
    assert_eq!(run_statement_file::recipe_block(DENSE_RUN_FIXTURE.name, &g).expect("the dense run recipe").digest(), by.digest(), "the dense run recipe does not regenerate Y");
    let w = honest_witness(&g, &by, &in_y);
    let (expected, owners) = endpoints_with(&g, &w);
    let st = one_block_statement(&bx, expected);
    let tmp = TempRunDir::new("writer");
    forge_to_dir(&st, &by, w, owners, tmp.path());
    let v = match run_statement_file::verify_then_write(&st, &[by.clone()], tmp.path(), &DENSE_RUN_FIXTURE) {
        Err(e) => format!("the writer refuses: {e}"),
        Ok(written) => {
            let fresh = run_statement_file::verify_from_disk(tmp.path());
            format!("WRITTEN ({} B): a statement file naming X's digest beside a recipe that regenerates Y; a fresh reader then says {fresh:?}", written.bytes)
        }
    };
    eprintln!("S42 REPRODUCER CS-6 (the statement writer, a run over X proved with Y, the dense run recipe): {v}");
    assert_eq!(v, format!("the writer refuses: {}", cs6_block(0, &by.digest(), &bx.digest())), "CS-6: the statement writer did not refuse a run over X proved with Y");
    assert!(!tmp.path().join(run_sink::STATEMENT_DIR).exists(), "a refused run left a statement directory");
}

// ------------------------------------------------ CS-6: the named refusals

/// **RULING CS-6 at the RUN PROVER.** Handed a block its statement does not
/// name, the run prover refuses by name before stage 0 begins: its witness
/// source is asked for nothing (no witness, no boundary plane) and nothing
/// reaches the sink. The count is CS-6 too, both ways, and in a two-block
/// run the refusal names the block. The control — the statement's own block
/// through the same call — asks for its witness, sinks its segment and
/// verifies.
#[test]
fn s42_cs6_the_run_prover_refuses_blocks_its_statement_does_not_name_before_stage_0_begins() {
    let c = case();
    // 1. one block: the statement over X, handed Y
    let w = honest_witness(&c.g, &c.by, &c.in_y);
    let (expected, owners) = endpoints_with(&c.g, &w);
    let st = one_block_statement(&c.bx, expected);
    let mut src = Counting::new(w);
    let mut sunk = 0usize;
    let r = run::prove_run(&st, &[c.by.clone()], &mut src, owners, &mut |_, _| {
        sunk += 1;
        Ok(())
    });
    assert_eq!(r.err(), Some(cs6_block(0, &c.by.digest(), &c.bx.digest())), "1. the run prover did not refuse Y under a statement over X by ruling CS-6's name");
    assert_eq!((src.witness_asked, src.plane_asked, sunk), (0, 0, 0), "1. the run prover asked for a witness or sank a segment before the CS-6 refusal");
    // 2. the count, both ways
    for handed in [vec![], vec![c.bx.clone(), c.bx.clone()]] {
        let w = honest_witness(&c.g, &c.bx, &c.in_x);
        let (expected, owners) = endpoints_with(&c.g, &w);
        let st = one_block_statement(&c.bx, expected);
        let mut src = Counting::new(w);
        let r = run::prove_run(&st, &handed, &mut src, owners, &mut |_, _| Ok(()));
        assert_eq!(r.err(), Some(cs6_count(1, handed.len())), "2. the run prover did not refuse {} blocks for a one-block statement by ruling CS-6's name", handed.len());
        assert_eq!((src.witness_asked, src.plane_asked), (0, 0), "2. the run prover asked for a witness before the CS-6 refusal");
    }
    // 3. two blocks: the statement over [X, X], handed [X, Y] — block 1 named
    let w = honest_witness(&c.g, &c.bx, &c.in_x);
    let (expected, owners) = endpoints_with(&c.g, &w);
    let st2 = RunStatement::new(RunShape::rung_g(2).expect("run shape"), ctx(), expected, &[c.bx.clone(), c.bx.clone()], &[(0, 0), (0, 0)]).expect("a two-block run statement over X, X");
    let mut src = Counting::new(w);
    let mut sunk = 0usize;
    let r = run::prove_run(&st2, &[c.bx.clone(), c.by.clone()], &mut src, owners, &mut |_, _| {
        sunk += 1;
        Ok(())
    });
    assert_eq!(r.err(), Some(cs6_block(1, &c.by.digest(), &c.bx.digest())), "3. the run prover did not name block 1 by ruling CS-6's name");
    assert_eq!((src.witness_asked, src.plane_asked, sunk), (0, 0, 0), "3. the run prover began stage 0 before the CS-6 refusal of block 1");
    // 4. the control: the statement's own block
    let w = honest_witness(&c.g, &c.bx, &c.in_x);
    let (expected, owners) = endpoints_with(&c.g, &w);
    let st = one_block_statement(&c.bx, expected);
    let mut src = Counting::new(w);
    let mut segs: Vec<Vec<u8>> = Vec::new();
    let r = run::prove_run(&st, &[c.bx.clone()], &mut src, owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    });
    assert!(r.is_ok(), "4. the control run of the statement's own block was refused: {:?}", r.err());
    assert_eq!((src.witness_asked, segs.len()), (1, 1), "4. the control run did not ask for its witness and sink its segment");
    run::verify_run(&st, &[c.bx.clone()], &segs).expect("4. the control run does not verify");
    eprintln!("S42 CS-6 run prover: Y under a statement over X refused by name with 0 witnesses asked, 0 boundary planes asked, 0 segments sunk; the count refused both ways; block 1 of [X, Y] under [X, X] named; the control proves and verifies");
}

/// **WHERE THE CHECK SITS, READ OUT OF `run.rs`.** A run's randomness
/// stream (`ZkRng::from_os`) and its transcript (`st.transcript()`) are
/// created INSIDE `prove_run` and `RunVerifier::start`, so no caller can hold
/// an observer on them; what can be pinned is that the CS-6 check precedes
/// both, and precedes the endpoint owners being opened
/// (`protocol::check_endpoints`) and the first absorb. So when it refuses
/// there is no stream to have drawn from and no transcript to have moved:
/// 0 draws, 0 squeezes, nothing absorbed, by construction.
#[test]
fn s42_cs6_each_run_check_sits_before_the_runs_randomness_and_transcript_exist() {
    let src = run_source();
    let prove = fn_body(&src, "pub(crate) fn prove_run(", "\n}\n");
    let check = prove.find("blocks_are_the_statements(").expect("prove_run does not call the CS-6 check");
    for later in ["protocol::check_endpoints(", "ZkRng::from_os(", "st.transcript()", "tr.absorb"] {
        let at = prove.find(later).unwrap_or_else(|| panic!("prove_run no longer contains {later}"));
        assert!(check < at, "prove_run's CS-6 check comes after {later}");
    }
    let start = fn_body(&src, "    fn start(", "\n    }\n");
    let check = start.find("blocks_are_the_statements(").expect("RunVerifier::start does not call the CS-6 check");
    let at = start.find("st.transcript()").expect("RunVerifier::start no longer builds the run transcript");
    assert!(check < at, "RunVerifier::start's CS-6 check comes after the run transcript");
    for entry in ["pub(crate) fn verify_run(", "pub(crate) fn verify_run_from_dir("] {
        let body = fn_body(&src, entry, "\n}\n");
        let s = body.find("RunVerifier::start(").unwrap_or_else(|| panic!("{entry} no longer goes through RunVerifier::start"));
        assert!(!body[..s].contains(".step("), "{entry} steps a segment before RunVerifier::start");
        assert!(!body[..s].contains("std::fs::read("), "{entry} reads a segment file before RunVerifier::start");
    }
    eprintln!("S42 CS-6 placement: in prove_run the check precedes check_endpoints, ZkRng::from_os, the run transcript and every absorb; in RunVerifier::start it precedes the run transcript; both verifiers reach a segment only through start");
}

/// **RULING CS-6 at the RUN VERIFIER, on the forged receipt.** The receipt
/// the attack produces (a statement over X, proved with Y by a cheating run
/// prover) is refused by name when the verifier is handed Y — ACCEPTED before
/// stage 42 — and is rejected by the arithmetic when it is handed X, the
/// block its statement names. The refusal is a function of the statement and
/// the blocks alone: offered any bytes at all it is the same, so no segment
/// is decoded before it. The count is CS-6's too.
#[test]
fn s42_cs6_the_run_verifier_refuses_blocks_its_statement_does_not_name_before_a_segment_is_read() {
    let c = case();
    let w = honest_witness(&c.g, &c.by, &c.in_y);
    let (expected, owners) = endpoints_with(&c.g, &w);
    let st = one_block_statement(&c.bx, expected);
    let forged = forge(&st, &c.by, w, owners);
    let want = cs6_block(0, &c.by.digest(), &c.bx.digest());
    // 1. the forged receipt, handed Y
    assert_eq!(run::verify_run(&st, &[c.by.clone()], &forged).err(), Some(want.clone()), "1. the run verifier handed Y did not refuse the forged receipt by ruling CS-6's name");
    // 2. handed X, the block its statement names: rejected, and not by CS-6
    let e = run::verify_run(&st, &[c.bx.clone()], &forged).err().expect("2. the run verifier handed X ACCEPTED a receipt proved with Y");
    assert!(!e.starts_with(CS6), "2. the statement's own block was refused by CS-6: {e}");
    // 3. any bytes at all: the same refusal, so no segment is decoded first
    assert_eq!(run::verify_run(&st, &[c.by.clone()], &[vec![0u8; 64]]).err(), Some(want.clone()), "3. the run verifier decoded a segment before the CS-6 refusal");
    // 4. the count
    assert_eq!(run::verify_run(&st, &[c.bx.clone(), c.bx.clone()], &forged).err(), Some(cs6_count(1, 2)), "4. two blocks for a one-block statement were not refused by ruling CS-6's name");
    assert_eq!(run::verify_run(&st, &[], &forged).err(), Some(cs6_count(1, 0)), "4. no blocks for a one-block statement were not refused by ruling CS-6's name");
    eprintln!("S42 CS-6 run verifier: the forged receipt handed Y refused by name (any bytes: the same refusal, before a segment is decoded); handed X rejected by the arithmetic: {e}");
}

/// **RULING CS-6 at the STREAMING verifier (`verify_run_from_dir`)**, on the
/// forged receipt written to a run directory: handed Y it is refused by name
/// (ACCEPTED before stage 42); handed X it is rejected by the arithmetic;
/// with the segment file replaced by 64 zero bytes the refusal is the same,
/// so no segment file is read before it.
#[test]
fn s42_cs6_the_streaming_verifier_refuses_blocks_its_statement_does_not_name_before_a_segment_is_read() {
    let c = case();
    let w = honest_witness(&c.g, &c.by, &c.in_y);
    let (expected, owners) = endpoints_with(&c.g, &w);
    let st = one_block_statement(&c.bx, expected);
    let tmp = TempRunDir::new("stream");
    forge_to_dir(&st, &c.by, w, owners, tmp.path());
    let want = cs6_block(0, &c.by.digest(), &c.bx.digest());
    assert_eq!(run::verify_run_from_dir(&st, &[c.by.clone()], tmp.path()).err(), Some(want.clone()), "the streaming verifier handed Y did not refuse the forged run by ruling CS-6's name");
    let e = run::verify_run_from_dir(&st, &[c.bx.clone()], tmp.path()).err().expect("the streaming verifier handed X ACCEPTED a run proved with Y");
    assert!(!e.starts_with(CS6), "the statement's own block was refused by CS-6: {e}");
    std::fs::write(tmp.path().join(run_sink::segment_file_name(0)), [0u8; 64]).expect("the test overwrites the segment file");
    assert_eq!(run::verify_run_from_dir(&st, &[c.by.clone()], tmp.path()).err(), Some(want), "the streaming verifier read a segment file before the CS-6 refusal");
    assert_eq!(run::verify_run_from_dir(&st, &[], tmp.path()).err(), Some(cs6_count(1, 0)), "no blocks for a one-block statement were not refused by ruling CS-6's name");
    eprintln!("S42 CS-6 streaming verifier: the forged run handed Y refused by name (and with its segment file zeroed: the same refusal); handed X rejected: {e}");
}

/// **RULING CS-6 at the STATEMENT FILE READER** (`run_statement_file::read`,
/// the fresh verifier's path). The reader regenerates the blocks from the
/// file's named recipe and compares them with the digests the file's
/// statement declares BEFORE the statement is built; it refused a mismatch
/// already, under its own name, and now under CS-6's. Three mutations of an
/// honest file: X's digest replaced by Y's (a real other block); the recipe
/// replaced by the dense RUN recipe (which regenerates a real other block);
/// and a second digest declared for a one-block run. The honest file still
/// verifies afterwards.
#[test]
fn s42_cs6_a_statement_file_naming_other_blocks_is_refused_by_name_before_the_statement_is_built() {
    let (tmp, c) = honest_x_run_with_statement("reader");
    run_statement_file::verify_from_disk(tmp.path()).expect("the honest statement verifies");
    let path = run_statement_file::statement_path(tmp.path());
    let good = String::from_utf8(std::fs::read(&path).expect("the statement file reads")).expect("the statement file is ASCII");
    let refuse = |what: &str, bad: String| -> String {
        std::fs::write(&path, bad.as_bytes()).expect("the test writes the statement file");
        let e = run_statement_file::verify_from_disk(tmp.path()).expect_err(&format!("{what} was ACCEPTED"));
        std::fs::write(&path, good.as_bytes()).expect("the test restores the statement file");
        eprintln!("S42 CS-6 statement file, {what}: {e}");
        e
    };
    let x = hex(&c.bx.digest());
    let e = refuse("X's block digest replaced by Y's", replace_once(&good, &format!("[\"{x}\"]"), &format!("[\"{}\"]", hex(&c.by.digest()))));
    assert_eq!(e, cs6_file_block(0), "the file naming Y's digest beside the tame recipe was not refused by ruling CS-6's name");
    let e = refuse("the recipe replaced by the dense run recipe", replace_once(&good, &format!("{:?}", TAME_FIXTURE.name), &format!("{:?}", DENSE_RUN_FIXTURE.name)));
    assert_eq!(e, cs6_file_block(0), "the file naming X's digest beside the dense run recipe was not refused by ruling CS-6's name");
    let e = refuse("a second block digest declared", replace_once(&good, &format!("[\"{x}\"]"), &format!("[\"{x}\",\"{x}\"]")));
    assert_eq!(e, cs6_file_count(2, 1), "a file declaring two digests for one block was not refused by ruling CS-6's name");
    run_statement_file::verify_from_disk(tmp.path()).expect("the restored statement verifies");
}

// ------------------------------------------------------------------ CS-7

/// The run profiles this build registers and the ONE block shape each names:
/// the seven of `run.rs` (stage 24's registry, item 4) and, in test builds,
/// rung-K8's (stage 37, test-only).
fn registered() -> Vec<(&'static str, Shape)> {
    vec![
        (run::RUN_PROFILE_RUNG_G, Shape::rung_g()),
        (run::RUN_PROFILE_RUNG_K4, Shape::rung_k4()),
        (run::RUN_PROFILE_RUNG_P2, Shape::rung_p2()),
        (run::RUN_PROFILE_RUNG_C6, Shape::rung_c6()),
        (run::RUN_PROFILE_RUNG_W14, Shape::rung_w14()),
        (run::RUN_PROFILE_RUNG_E32, Shape::rung_e32()),
        (run::RUN_PROFILE_M125, Shape::m125()),
        (super::k8_tests::K8_RUN_PROFILE, super::k8_tests::rung_k8()),
    ]
}

/// **RULING CS-7: `RunShape::new` refuses, by name, a run profile over a
/// block shape it is not registered for.** Every registered pair constructs
/// (and every `RunShape::rung_*` constructor); every CROSS pair — each
/// registered run profile over each other registered shape and over the two
/// legacy shapes that have no run profile — is refused by name, S41-N1's
/// rung-G profile over rung-K4 among them. A profile string this build does
/// not register is refused, and so is rung-G's run profile over a shape that
/// carries rung-G's BLOCK profile string at another geometry (a profile names
/// one shape, not one string). `L = 0` keeps its own refusal.
#[test]
fn s42_cs7_run_shape_new_refuses_a_run_profile_over_a_block_shape_it_is_not_registered_for() {
    let reg = registered();
    // every registered pair
    for (p, s) in &reg {
        RunShape::new(s.clone(), 1, *p).unwrap_or_else(|e| panic!("CS-7: the registered pair {p} over {} was refused: {e}", s.name));
    }
    for l in [1usize, 3, 12] {
        for (what, r) in [
            ("rung_g", RunShape::rung_g(l)),
            ("rung_k4", RunShape::rung_k4(l)),
            ("rung_p2", RunShape::rung_p2(l)),
            ("rung_c6", RunShape::rung_c6(l)),
            ("rung_w14", RunShape::rung_w14(l)),
            ("rung_e32", RunShape::rung_e32(l)),
            ("m125", RunShape::m125(l)),
        ] {
            r.unwrap_or_else(|e| panic!("CS-7: RunShape::{what}({l}) was refused: {e}"));
        }
    }
    // every cross pair
    let mut shapes: Vec<Shape> = reg.iter().map(|(_, s)| s.clone()).collect();
    shapes.extend([Shape::toy(), Shape::rung()]);
    let (mut refused, mut admitted) = (0usize, Vec::new());
    for (p, own) in &reg {
        for s in &shapes {
            if s == own {
                continue;
            }
            match RunShape::new(s.clone(), 1, *p) {
                Ok(_) => admitted.push(format!("{p} over {}", s.name)),
                Err(e) => {
                    assert_eq!(e, cs7_pair(p, own, s), "CS-7: {p} over {} refused, but not by ruling CS-7's name", s.name);
                    refused += 1;
                }
            }
        }
    }
    eprintln!("S42 CS-7 cross pairs: {refused} refused by name, {} admitted", admitted.len());
    assert!(admitted.is_empty(), "CS-7: {} cross pairs of a registered run profile and another block shape were admitted:\n{}", admitted.len(), admitted.join("\n"));
    assert_eq!(refused, reg.len() * (shapes.len() - 1), "CS-7: the cross pairs were not all tried");
    // S41-N1 exactly
    assert_eq!(RunShape::new(Shape::rung_k4(), 1, run::RUN_PROFILE_RUNG_G).err(), Some(cs7_pair(run::RUN_PROFILE_RUNG_G, &Shape::rung_g(), &Shape::rung_k4())), "S41-N1: rung-G's run profile over rung-K4 was not refused by ruling CS-7's name");
    // a profile string no one registered
    let stray = "hashline-zk-mr1/s42-unregistered-run/1";
    assert_eq!(RunShape::new(Shape::rung_g(), 1, stray).err(), Some(cs7_unregistered(stray, &Shape::rung_g())), "CS-7: an unregistered run profile was not refused by name");
    // rung-G's block profile STRING at another geometry (width 100: note C-6
    // admits it), under rung-G's run profile
    let other = Shape::new("stage 42: rung-G's block profile string at width 100", Shape::rung_g().profile, 24, 100, 192, 6, 16, 2, 10, 4, 12, 9, None, None, None, None).expect("rung-G's head axis at width 100");
    assert_eq!(RunShape::new(other.clone(), 1, run::RUN_PROFILE_RUNG_G).err(), Some(cs7_pair(run::RUN_PROFILE_RUNG_G, &Shape::rung_g(), &other)), "CS-7: rung-G's run profile over another geometry carrying rung-G's block profile string was admitted");
    // L = 0 keeps its own name, before CS-7's
    assert_eq!(RunShape::new(Shape::rung_k4(), 0, run::RUN_PROFILE_RUNG_G).err().as_deref(), Some("private run: a run has at least one block"), "L = 0 is no longer refused by its own name first");
    eprintln!("S42 CS-7: {} registered pairs construct; {refused} cross pairs, an unregistered profile and a same-string other geometry refused by name", reg.len());
}

/// **RULING CS-7 at the STATEMENT FILE READER.** An honest rung-G statement
/// file with its `run_profile` member changed to rung-K4's (a registered run
/// profile, over the file's rung-G block shape) is refused by CS-7's name
/// when the reader builds the run shape — before stage 42 `RunShape::new`
/// admitted it and the reader refused only later, at the run binding.
#[test]
fn s42_cs7_a_statement_file_pairing_a_run_profile_with_another_block_shape_is_refused_by_name() {
    let (tmp, _c) = honest_x_run_with_statement("cs7-reader");
    let path = run_statement_file::statement_path(tmp.path());
    let good = String::from_utf8(std::fs::read(&path).expect("the statement file reads")).expect("the statement file is ASCII");
    let bad = replace_once(&good, &format!("\"run_profile\":{:?}", run::RUN_PROFILE_RUNG_G), &format!("\"run_profile\":{:?}", run::RUN_PROFILE_RUNG_K4));
    std::fs::write(&path, bad.as_bytes()).expect("the test writes the statement file");
    let e = run_statement_file::verify_from_disk(tmp.path()).expect_err("a rung-K4 run profile over a rung-G block profile was ACCEPTED");
    std::fs::write(&path, good.as_bytes()).expect("the test restores the statement file");
    eprintln!("S42 CS-7 statement file, the run profile changed to rung-K4's: {e}");
    assert_eq!(e, cs7_pair(run::RUN_PROFILE_RUNG_K4, &Shape::rung_k4(), &Shape::rung_g()), "the reader did not refuse the cross pairing by ruling CS-7's name");
    run_statement_file::verify_from_disk(tmp.path()).expect("the restored statement verifies");
}

// ------------------------------------------------ note S42-N1: closed by ruling CS-8 (stage 43)

// The note test that stood here, `s42_note_n1_a_run_shape_built_as_a_struct_literal_skips_cs7_and_its_run_verifies`,
// built `RunShape { sh, l, profile }` as a struct literal (rung-G's run
// profile over the rung-K4 shape) and measured the one-block run VERIFY
// (`s42-after-focused.log`, stage 42). Ruling CS-8 made `RunShape`'s fields
// and `RunStatement`'s `rs` private (stage 43), so the literal no longer
// compiles outside `run.rs` and the test was deleted; its last run, with the
// three other routes it stood for, is `s43-before-bypasses.log` (all four
// ACCEPTED), and `s43_tests::s43_cs8_no_field_of_a_sealed_type_is_visible_outside_its_module`
// pins the declarations.
