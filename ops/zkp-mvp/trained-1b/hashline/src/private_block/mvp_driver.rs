//! **THE MVP STACK DRIVER: a repeatable, real multi-block private RUN, with
//! `prove` and `verify` commands.** Production code (no `cfg(test)` module is
//! enabled to build it); the CLI is `examples/zk60_private_stack.rs`.
//!
//! **What it proves.** `L` blocks under ONE transcript through the existing
//! `run::prove_run` / `run::verify_run_from_dir`, with hidden internal
//! boundaries. It is NOT `L` concatenated standalone block proofs, and no
//! protocol byte, kernel or soundness check is touched here.
//!
//! **SCOPE, said in every result.** The model is a PUBLIC SYNTHETIC dense
//! recipe on a registered DEVELOPMENT shape (`rung-p2` or `m125`) and the input
//! is a synthetic hidden input. It is not a trained model and not a trained-8B
//! proof, and a passing verification is a correctness result only: no privacy
//! acceptance is made or implied (the run-level privacy obligations still have
//! no tools).
//!
//! **The trust model of `verify`.** The verifier never adopts anything from
//! the artifact. Everything it checks against comes from a CALLER-TRUSTED
//! policy file (`zk60-mvp-policy/1`, produced by `prove --policy-out` and moved
//! to the verifier by whatever channel it trusts) and optional command-line
//! pins: shape, block count, recipe, context label, calibration, model-digest
//! root and both external endpoint roots. The verifier REBUILDS the run
//! statement from those, regenerates the public weights from the named recipe,
//! and refuses if any of them disagree. The manifest inside the artifact is
//! compared, never trusted.
//!
//! **Artifact directory.** `segment-000.bin` .. `segment-(L-1).bin` and
//! `statement/mvp-manifest.json`, nothing else (`run_sink::segment_paths` is
//! the strict enumerator; the manifest directory is the one entry it allows).
//! Nothing is published until the whole run has verified in the proving
//! process: segments are staged in `<out>.staging`, verified from a statement
//! rebuilt from the policy TEXT alone, and only then is the directory renamed
//! to `<out>` (atomic). A failed attempt leaves a `<out>.failed-<stamp>-<pid>`
//! directory holding a `failed-attempt.json` record and no segments.
//!
//! **Streaming.** Hidden values live only in memory: one current input, one
//! witness, one boundary plane at a time (plus the two sealed endpoint planes
//! until the owners are built). Block `k`'s witness is built once per pass;
//! the sealing pass (needed before the header, ruling H-1) and the proving
//! pass each build every witness, and both are timed separately.
//!
//! **Output.** Machine-readable JSON lines on stdout. Private values never go
//! to stdout, stderr or disk; errors are the existing named-site refusals.

use super::layout::{Ids, A_X, A_X2, F_RO};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::run_sink::{self, DirSink, SegmentSink};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::{prepare_endpoints, AttentionPublic, BlockPublic, ExpectedIo, FeedForwardPublic, IoSpec};
use crate::merkle::Digest;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::Instant;

// ---------------------------------------------------------------- constants

const POLICY_SCHEMA: &str = "zk60-mvp-policy/1";
const MANIFEST_SCHEMA: &str = "zk60-mvp-artifact/1";
const FAILED_SCHEMA: &str = "zk60-mvp-failed-attempt/1";
const MANIFEST_FILE: &str = "mvp-manifest.json";
const FAILED_FILE: &str = "failed-attempt.json";

/// what every result says about itself
const SCOPE: &str = "SYNTHETIC-DIAGNOSTIC: public synthetic dense weights and a synthetic hidden input on a registered development shape; NOT a trained model and NOT a trained-8B proof; endpoints are prover-created (D18); a correctness result, no privacy acceptance made or implied";

/// A run of more blocks than this is refused by the driver before anything is
/// allocated on a caller's say-so (a policy file names `L`). The protocol's own
/// limits (`RunStatement::new`, the T-3 hash-input check) still apply on top.
const MAX_BLOCKS: usize = 64;
const MAX_POLICY_BYTES: u64 = 16 * 1024;
const MAX_MANIFEST_BYTES: u64 = 64 * 1024;
const MAX_LABEL: usize = 64;
const DEFAULT_LABEL: &str = "zk60-mvp-diagnostic";

// ---- the dense public recipe, copied narrowly from `dense_tests.rs` (test-only)
// so that a run's public words are byte for byte the ones the retained run
// statements regenerate. `tests::` below pins each of these against the
// originals.

const DENSE_SEED: u64 = 0xD15E_ED19_0000_0001;
const DENSE_INPUT_SEED: u64 = 0x1DDE_4E17_0000_0001;
const BAND_ATTN: i64 = 56;
const BAND_GATE: i64 = 96;
const GAIN: (i64, i64) = (40, 127);
const INPUT_MAG: i64 = 6_000;
const GOLDEN: u64 = 0x9E37_79B9_7F4A_7C15;

/// SplitMix64, the recipe's own integer stream. No OS randomness.
struct SplitMix(u64);

impl SplitMix {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(GOLDEN);
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

/// The down-projection band a CHAIN can carry at the two shapes this driver
/// supports, MEASURED by `run_tests::first_admissible_dense_run_band` (the
/// pinned `dense_tests::band_down_run`). Any other geometry is refused rather
/// than guessed.
fn band_down_run(sh: &Shape) -> Result<i64, String> {
    match (sh.hidden, sh.kv_heads) {
        (256, 4) => Ok(39),
        (2048, 4) => Ok(1),
        _ => Err(format!("mvp driver: no measured chain band for hidden {} / kv heads {}", sh.hidden, sh.kv_heads)),
    }
}

/// the nine TRUE-sized public words `[Wq, Wk, Wv, Wo, gamma_a, gamma_m, Wg,
/// Wu, Wd]` from `seed`, in the recipe's fixed read order
fn public_words(sh: &Shape, seed: u64) -> Result<[Vec<i8>; 9], String> {
    let (d, f, kvw) = (sh.width, sh.hidden, sh.kv_heads * sh.head_dim);
    let down = band_down_run(sh)?;
    let mut r = SplitMix(seed);
    let mat = |r: &mut SplitMix, outer: usize, inner: usize, mag: i64| -> Vec<i8> { (0..outer * inner).map(|_| r.nonzero(mag) as i8).collect() };
    let gain = |r: &mut SplitMix, n: usize| -> Vec<i8> { (0..n).map(|_| r.pick(GAIN.0, GAIN.1) as i8).collect() };
    Ok([
        mat(&mut r, d, d, BAND_ATTN),
        mat(&mut r, kvw, d, BAND_ATTN),
        mat(&mut r, kvw, d, BAND_ATTN),
        mat(&mut r, d, d, BAND_ATTN),
        gain(&mut r, d),
        gain(&mut r, d),
        mat(&mut r, d, f, BAND_GATE),
        mat(&mut r, d, f, BAND_GATE),
        mat(&mut r, f, d, down),
    ])
}

/// the synthetic hidden input, from its own stream
fn hidden_input(sh: &Shape, seed: u64) -> Vec<i16> {
    let mut r = SplitMix(seed);
    (0..sh.tokens * sh.width).map(|_| r.nonzero(INPUT_MAG) as i16).collect()
}

fn q_axis_index(s: &Shape, j: usize) -> usize {
    s.head_slot(j / s.head_dim) * s.head_dim + j % s.head_dim
}

/// a true `(to, ti)` row-major matrix placed into the padded `(po, pi)` one
/// through the two index maps (ruling P-2)
fn pad_matrix(w: &[i8], to: usize, ti: usize, po: usize, pi: usize, omap: &dyn Fn(usize) -> usize, imap: &dyn Fn(usize) -> usize) -> Vec<i8> {
    let mut out = vec![0i8; po * pi];
    for o in 0..to {
        for i in 0..ti {
            out[omap(o) * pi + imap(i)] = w[o * ti + i];
        }
    }
    out
}

/// one block's public statement from nine words
fn block_of(sh: &Shape, seed: u64) -> Result<BlockPublic, String> {
    let w = public_words(sh, seed)?;
    let (d, f, dp, fp, kvw) = (sh.width, sh.hidden, sh.d_pad, sh.f_pad, sh.kv_heads * sh.head_dim);
    let (cos, sin) = crate::tables_attn::rope_tables_generate(sh.tokens, sh.head_dim, 10000.0, F_RO);
    let (exp, _) = crate::tables_attn::exp_member(0, sh.head_dim, sh.f_e);
    let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).ok_or("mvp driver: the frozen SiLU int16-out member is missing")?;
    let id = |i: usize| i;
    let q = |j: usize| q_axis_index(sh, j);
    let aw = [
        pad_matrix(&w[0], d, d, dp, dp, &q, &id),
        pad_matrix(&w[1], kvw, d, kvw, dp, &id, &id),
        pad_matrix(&w[2], kvw, d, kvw, dp, &id, &id),
        pad_matrix(&w[3], d, d, dp, dp, &id, &q),
        pad_matrix(&w[4], 1, d, 1, dp, &id, &id),
    ];
    let fw = [pad_matrix(&w[5], 1, d, 1, dp, &id, &id), pad_matrix(&w[6], d, f, dp, fp, &id, &id), pad_matrix(&w[7], d, f, dp, fp, &id, &id), pad_matrix(&w[8], f, d, fp, dp, &id, &id)];
    let public = AttentionPublic::new_shaped(sh, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp)?;
    let ff = FeedForwardPublic::new_shaped(sh, &fw[0], &fw[1], &fw[2], &fw[3], &act)?;
    Ok(BlockPublic::new(public, ff))
}

// ---------------------------------------------------------------- shapes and recipes

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum ShapeKind {
    P2,
    M125,
}

impl ShapeKind {
    fn name(self) -> &'static str {
        match self {
            ShapeKind::P2 => "rung-p2",
            ShapeKind::M125 => "m125",
        }
    }
    fn from_canonical(s: &str) -> Result<ShapeKind, String> {
        match s {
            "rung-p2" => Ok(ShapeKind::P2),
            "m125" => Ok(ShapeKind::M125),
            _ => Err(format!("mvp driver: {s:?} is not a shape this driver runs (rung-p2, m125)")),
        }
    }
    fn from_cli(s: &str) -> Result<ShapeKind, String> {
        ShapeKind::from_canonical(if s == "p2" { "rung-p2" } else { s })
    }
    fn shape(self) -> Shape {
        match self {
            ShapeKind::P2 => Shape::rung_p2(),
            ShapeKind::M125 => Shape::m125(),
        }
    }
    fn run_shape(self, l: usize) -> Result<RunShape, String> {
        match self {
            ShapeKind::P2 => RunShape::rung_p2(l),
            ShapeKind::M125 => RunShape::m125(l),
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum Recipe {
    /// the same fully dense public words in every block, at the MEASURED chain
    /// band — exactly `dense_tests::dense_run_case`'s public words, and what
    /// every retained run in this lane used
    DenseRun,
    /// block `k` draws its nine words from `DENSE_SEED + k * GOLDEN` (block 0 is
    /// `DenseRun`'s). The chain band was measured for the SAME-words chain only:
    /// admissibility of this recipe is not measured, and the sealing pass
    /// refuses an inadmissible chain by name before any header exists
    DenseRunVaried,
}

impl Recipe {
    fn name(self) -> &'static str {
        match self {
            Recipe::DenseRun => "zk60-mvp/dense-run/1",
            Recipe::DenseRunVaried => "zk60-mvp/dense-run-varied/1",
        }
    }
    fn from_canonical(s: &str) -> Result<Recipe, String> {
        match s {
            "zk60-mvp/dense-run/1" => Ok(Recipe::DenseRun),
            "zk60-mvp/dense-run-varied/1" => Ok(Recipe::DenseRunVaried),
            _ => Err(format!("mvp driver: {s:?} is not a recipe this build knows")),
        }
    }
    fn from_cli(s: &str) -> Result<Recipe, String> {
        match s {
            "dense-run" => Ok(Recipe::DenseRun),
            "dense-run-varied" => Ok(Recipe::DenseRunVaried),
            other => Recipe::from_canonical(other),
        }
    }
    fn seed(self, k: usize) -> u64 {
        match self {
            Recipe::DenseRun => DENSE_SEED,
            Recipe::DenseRunVaried => DENSE_SEED.wrapping_add((k as u64).wrapping_mul(GOLDEN)),
        }
    }
}

/// the run's `L` public blocks
fn build_model(kind: ShapeKind, recipe: Recipe, l: usize) -> Result<Vec<BlockPublic>, String> {
    let sh = kind.shape();
    match recipe {
        Recipe::DenseRun => {
            let b = block_of(&sh, recipe.seed(0))?;
            Ok((0..l).map(|_| b.clone()).collect())
        }
        Recipe::DenseRunVaried => (0..l).map(|k| block_of(&sh, recipe.seed(k))).collect(),
    }
}

/// `H(block 1's digest || ... || block L's digest)`, the run's public-statement
/// digest (`run.rs`'s own definition, recomputed here)
fn model_root_of(blocks: &[BlockPublic]) -> Digest {
    let mut h = blake3::Hasher::new();
    h.update(b"hashline/private-run-blocks/1");
    for b in blocks {
        h.update(&b.digest());
    }
    *h.finalize().as_bytes()
}

fn context_of(label: &str, run_profile: &str, recipe: &str, l: usize) -> Digest {
    let mut h = blake3::Hasher::new();
    h.update(b"hashline/zk60-mvp-context/1");
    for s in [label, run_profile, recipe] {
        h.update(&(s.len() as u64).to_le_bytes());
        h.update(s.as_bytes());
    }
    h.update(&(l as u64).to_le_bytes());
    *h.finalize().as_bytes()
}

fn label_ok(s: &str) -> Result<(), String> {
    if s.is_empty() || s.len() > MAX_LABEL || !s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'_' || b == b'-') {
        return Err(format!("mvp driver: a context label is 1..={MAX_LABEL} characters of [A-Za-z0-9._-]"));
    }
    Ok(())
}

// ---------------------------------------------------------------- the policy

/// The caller-trusted expected policy. Only these seven fields are primary;
/// everything else in the file is derived from them by this build and compared.
struct Policy {
    kind: ShapeKind,
    blocks: usize,
    recipe: Recipe,
    label: String,
    in_root: Digest,
    out_root: Digest,
    model_root: Digest,
}

const POLICY_KEYS: [&str; 20] = [
    "scope",
    "shape",
    "block_profile",
    "run_profile",
    "blocks",
    "tokens",
    "width",
    "hidden",
    "q_heads",
    "kv_heads",
    "head_dim",
    "recipe",
    "context_label",
    "context",
    "calibration",
    "input_scale",
    "output_scale",
    "block_digests",
    "input_root",
    "output_root",
];

fn hex(d: &[u8]) -> String {
    d.iter().map(|b| format!("{b:02x}")).collect()
}

fn unhex32(s: &str) -> Result<Digest, String> {
    if s.len() != 64 || !s.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)) {
        return Err("mvp driver: a digest is 64 lower-case hex characters".into());
    }
    let mut out = [0u8; 32];
    for (i, o) in out.iter_mut().enumerate() {
        *o = u8::from_str_radix(&s[2 * i..2 * i + 2], 16).map_err(|e| format!("mvp driver: {e}"))?;
    }
    Ok(out)
}

/// The canonical policy text. Deterministic; a parsed policy must re-render to
/// exactly the bytes it was read from.
fn render_policy(p: &Policy) -> Result<String, String> {
    let sh = p.kind.shape();
    let rs = p.kind.run_shape(p.blocks)?;
    let ctx = context_of(&p.label, rs.profile(), p.recipe.name(), p.blocks);
    let values: [String; 20] = [
        SCOPE.to_string(),
        p.kind.name().to_string(),
        sh.profile.to_string(),
        rs.profile().to_string(),
        p.blocks.to_string(),
        sh.tokens.to_string(),
        sh.width.to_string(),
        sh.hidden.to_string(),
        sh.q_heads.to_string(),
        sh.kv_heads.to_string(),
        sh.head_dim.to_string(),
        p.recipe.name().to_string(),
        p.label.clone(),
        hex(&ctx),
        hex(&super::calibration_identity()),
        super::ENDPOINT_SCALES.0.to_string(),
        super::ENDPOINT_SCALES.1.to_string(),
        hex(&p.model_root),
        hex(&p.in_root),
        hex(&p.out_root),
    ];
    let mut s = String::new();
    s.push_str(POLICY_SCHEMA);
    s.push('\n');
    for (k, v) in POLICY_KEYS.iter().zip(values.iter()) {
        s.push_str(k);
        s.push('=');
        s.push_str(v);
        s.push('\n');
    }
    Ok(s)
}

fn kv_get<'a>(kv: &[(&'a str, &'a str)], key: &str) -> &'a str {
    kv.iter().find(|(k, _)| *k == key).map(|(_, v)| *v).unwrap_or("")
}

/// Read a policy. Strict: bounded, printable ASCII, the exact key list in the
/// exact order, and the text must be the canonical rendering of its own primary
/// fields, so a derived line that disagrees with this build (a foreign profile,
/// another calibration, a wrong context) is refused BY NAME.
fn parse_policy(bytes: &[u8]) -> Result<Policy, String> {
    if bytes.len() as u64 > MAX_POLICY_BYTES {
        return Err(format!("policy: larger than the {MAX_POLICY_BYTES}-byte bound"));
    }
    if !bytes.iter().all(|b| (0x20..0x7f).contains(b) || *b == b'\n') || bytes.last() != Some(&b'\n') {
        return Err("policy: not printable ASCII lines ending in a newline".into());
    }
    let text = std::str::from_utf8(bytes).map_err(|_| "policy: not UTF-8".to_string())?;
    let mut lines = text.lines();
    if lines.next() != Some(POLICY_SCHEMA) {
        return Err(format!("policy: the first line is not {POLICY_SCHEMA}"));
    }
    let mut kv: Vec<(&str, &str)> = Vec::with_capacity(POLICY_KEYS.len());
    for line in lines {
        kv.push(line.split_once('=').ok_or("policy: a line has no '='")?);
    }
    if kv.len() != POLICY_KEYS.len() || kv.iter().zip(POLICY_KEYS.iter()).any(|((k, _), want)| k != want) {
        return Err("policy: the keys are not exactly the expected list in order".into());
    }
    let blocks: usize = kv_get(&kv, "blocks").parse().map_err(|_| "policy: blocks is not a number".to_string())?;
    if blocks == 0 || blocks > MAX_BLOCKS {
        return Err(format!("policy: blocks must be 1..={MAX_BLOCKS}"));
    }
    label_ok(kv_get(&kv, "context_label"))?;
    let p = Policy {
        kind: ShapeKind::from_canonical(kv_get(&kv, "shape"))?,
        blocks,
        recipe: Recipe::from_canonical(kv_get(&kv, "recipe"))?,
        label: kv_get(&kv, "context_label").to_string(),
        in_root: unhex32(kv_get(&kv, "input_root"))?,
        out_root: unhex32(kv_get(&kv, "output_root"))?,
        model_root: unhex32(kv_get(&kv, "block_digests"))?,
    };
    let want = render_policy(&p)?;
    for (i, (w, g)) in want.lines().zip(text.lines()).enumerate() {
        if w != g {
            let key = if i == 0 { "schema" } else { POLICY_KEYS[i - 1] };
            return Err(format!("policy: the {key} line disagrees with what this build derives from the pinned fields"));
        }
    }
    if want != text {
        return Err("policy: not the canonical rendering".into());
    }
    Ok(p)
}

/// the verifier's statement and blocks, from the policy ALONE
fn build_verifier(p: &Policy) -> Result<(RunStatement, Vec<BlockPublic>), String> {
    let blocks = build_model(p.kind, p.recipe, p.blocks)?;
    if model_root_of(&blocks) != p.model_root {
        return Err("policy: the named recipe does not reproduce the policy's block digests".into());
    }
    let sh = p.kind.shape();
    let rs = p.kind.run_shape(p.blocks)?;
    let ctx = context_of(&p.label, rs.profile(), p.recipe.name(), p.blocks);
    let spec = IoSpec::new_shaped(&sh, ctx, super::ENDPOINT_SCALES.0, super::ENDPOINT_SCALES.1)?;
    let expected = ExpectedIo::from_roots(spec, p.in_root, p.out_root);
    let st = RunStatement::new(rs, ctx, expected, &blocks, &vec![super::ENDPOINT_SCALES; p.blocks])?;
    Ok((st, blocks))
}

// ---------------------------------------------------------------- the manifest

fn render_manifest(policy_sha256: &str, segs: &[(String, u64, String)]) -> String {
    let files: Vec<String> = segs.iter().map(|(n, b, h)| format!("{{\"file\":{},\"bytes\":{b},\"sha256\":{}}}", js(n), js(h))).collect();
    format!(
        "{{\"schema\":{},\"scope\":{},\"policy_sha256\":{},\"blocks\":{},\"total_bytes\":{},\"segments\":[{}]}}\n",
        js(MANIFEST_SCHEMA),
        js(SCOPE),
        js(policy_sha256),
        segs.len(),
        segs.iter().map(|s| s.1).sum::<u64>(),
        files.join(",")
    )
}

/// the artifact layout, checked strictly, and each segment's length and
/// SHA-256 read ONE FILE AT A TIME
fn scan_artifact(dir: &Path, l: usize) -> Result<Vec<(String, u64, String)>, String> {
    let paths = run_sink::segment_paths(dir, l)?;
    let sdir = dir.join(run_sink::STATEMENT_DIR);
    if !sdir.is_dir() {
        return Err(format!("artifact: {} has no {} directory", dir.display(), run_sink::STATEMENT_DIR));
    }
    let names = run_sink::dir_entry_names(&sdir)?;
    if names != [MANIFEST_FILE.to_string()] {
        return Err(format!("artifact: the {} directory must hold exactly {MANIFEST_FILE}", run_sink::STATEMENT_DIR));
    }
    let mut out = Vec::with_capacity(l);
    for (k, p) in paths.iter().enumerate() {
        let md = std::fs::symlink_metadata(p).map_err(|e| format!("artifact: segment {k}: {e}"))?;
        if !md.file_type().is_file() {
            return Err(format!("artifact: segment {k} is not a regular file"));
        }
        if md.len() > super::wire::MAX_WIRE_BYTES_ANY as u64 {
            return Err(format!("artifact: segment {k} is larger than the {}-byte wire bound", super::wire::MAX_WIRE_BYTES_ANY));
        }
        let bytes = std::fs::read(p).map_err(|e| format!("artifact: segment {k}: {e}"))?;
        out.push((run_sink::segment_file_name(k), bytes.len() as u64, run_sink::digest_hex(&bytes)));
    }
    Ok(out)
}

fn read_bounded(path: &Path, max: u64) -> Result<Vec<u8>, String> {
    let md = std::fs::symlink_metadata(path).map_err(|e| format!("{}: {e}", path.display()))?;
    if !md.file_type().is_file() {
        return Err(format!("{}: not a regular file", path.display()));
    }
    if md.len() > max {
        return Err(format!("{}: larger than the {max}-byte bound", path.display()));
    }
    std::fs::read(path).map_err(|e| format!("{}: {e}", path.display()))
}

// ---------------------------------------------------------------- json lines

fn js(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 2);
    o.push('"');
    for c in s.chars().take(2048) {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            '\r' => o.push_str("\\r"),
            '\t' => o.push_str("\\t"),
            c if (' '..='~').contains(&c) => o.push(c),
            _ => o.push('?'),
        }
    }
    o.push('"');
    o
}

fn jf(x: f64) -> String {
    if x.is_finite() {
        format!("{x:.6}")
    } else {
        "null".into()
    }
}

fn emit(line: &str) {
    let mut out = std::io::stdout().lock();
    let _ = writeln!(out, "{line}");
    let _ = out.flush();
}

fn timings_json(phases: &[(&'static str, f64)]) -> String {
    format!("{{{}}}", phases.iter().map(|(k, v)| format!("{}:{}", js(k), jf(*v))).collect::<Vec<_>>().join(","))
}

// ---------------------------------------------------------------- argument parsing

fn parse_flags(args: &[String], allowed: &[&str]) -> Result<Vec<(String, String)>, String> {
    let mut out: Vec<(String, String)> = Vec::new();
    let mut i = 0;
    while i < args.len() {
        let k = &args[i];
        if !allowed.contains(&k.as_str()) {
            return Err(format!("unknown argument {k:?}; allowed: {}", allowed.join(" ")));
        }
        if out.iter().any(|(e, _)| e == k) {
            return Err(format!("{k} given twice"));
        }
        let v = args.get(i + 1).ok_or_else(|| format!("{k} needs a value"))?;
        out.push((k.clone(), v.clone()));
        i += 2;
    }
    Ok(out)
}

fn flag<'a>(f: &'a [(String, String)], k: &str) -> Option<&'a str> {
    f.iter().find(|(e, _)| e == k).map(|(_, v)| v.as_str())
}

fn need<'a>(f: &'a [(String, String)], k: &str) -> Result<&'a str, String> {
    flag(f, k).ok_or_else(|| format!("{k} is required"))
}

fn parse_u64(s: &str) -> Result<u64, String> {
    match s.strip_prefix("0x") {
        Some(h) => u64::from_str_radix(h, 16),
        None => s.parse::<u64>(),
    }
    .map_err(|_| format!("{s:?} is not an unsigned integer"))
}

fn usage_error(msg: &str) -> i32 {
    emit(&format!("{{\"event\":\"usage_error\",\"error\":{},\"scope\":{}}}", js(msg), js(SCOPE)));
    2
}

/// a path that does not exist yet, whose parent does: returned with its parent
/// canonicalised
fn resolve_new(path: &str) -> Result<PathBuf, String> {
    let p = Path::new(path);
    let name = p.file_name().ok_or_else(|| format!("{path:?} has no file name"))?;
    let parent = match p.parent() {
        Some(x) if !x.as_os_str().is_empty() => x.to_path_buf(),
        _ => PathBuf::from("."),
    };
    let parent = parent.canonicalize().map_err(|e| format!("the parent of {path:?} does not exist: {e}"))?;
    let full = parent.join(name);
    if std::fs::symlink_metadata(&full).is_ok() {
        return Err(format!("{} already exists; this driver never overwrites", full.display()));
    }
    Ok(full)
}

// ---------------------------------------------------------------- the streaming witness source

fn plane_of(w: &Witness, id: usize) -> Result<Vec<i16>, String> {
    w.planes[id].iter().map(|v| i16::try_from(*v).map_err(|_| "private stack: a plane word left int16".to_string())).collect()
}

/// the TRUE `tokens x width` hidden state inside a padded plane
fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

fn plane_digest(p: &[i16]) -> [u8; 32] {
    let mut bytes = Vec::with_capacity(p.len() * 2);
    for v in p {
        bytes.extend_from_slice(&v.to_le_bytes());
    }
    let mut h = blake3::Hasher::new();
    h.update(b"zk60-mvp-seal-check/1");
    h.update(&bytes);
    *h.finalize().as_bytes()
}

/// **THE BOUNDED SOURCE.** Retains ONE current input (`x`) and at most ONE
/// witness (`cached`, between `boundary_plane(k)` and `witness(k)`, which the
/// run prover calls in that order). A pure function of the block statements and
/// the first input (ruling H-1 rule 2); the proving pass compares its final
/// output plane's digest with the sealing pass's, in memory only.
struct StackSource<'a> {
    sh: &'a Shape,
    blocks: &'a [BlockPublic],
    ids: Ids,
    x: Vec<i16>,
    next: usize,
    cached: Option<(usize, Witness)>,
    sealed_out: Option<[u8; 32]>,
    /// seconds spent building witnesses and extracting planes since the last restart
    busy_s: f64,
    builds: usize,
}

impl<'a> StackSource<'a> {
    fn new(sh: &'a Shape, blocks: &'a [BlockPublic], x0: Vec<i16>) -> Result<StackSource<'a>, String> {
        if x0.len() != sh.tokens * sh.width {
            return Err("private stack: the first input is not tokens x width".into());
        }
        Ok(StackSource { sh, blocks, ids: Ids::new(sh)?, x: x0, next: 0, cached: None, sealed_out: None, busy_s: 0.0, builds: 0 })
    }

    fn restart(&mut self, x0: Vec<i16>) -> Result<(), String> {
        if x0.len() != self.sh.tokens * self.sh.width {
            return Err("private stack: the first input is not tokens x width".into());
        }
        self.x = x0;
        self.next = 0;
        self.cached = None;
        self.busy_s = 0.0;
        self.builds = 0;
        Ok(())
    }

    /// build block `k`'s witness from the retained input, keep the NEXT input,
    /// hand back the witness and the padded output plane
    fn advance(&mut self, k: usize) -> Result<(Witness, Vec<i16>), String> {
        if k != self.next || k >= self.blocks.len() {
            return Err(format!("private stack: block {k} was asked for out of order (next is {})", self.next));
        }
        let t = Instant::now();
        let (sh, blocks) = (self.sh, self.blocks);
        let w = witness::build_shaped(sh, blocks[k].attention(), blocks[k].feed_forward(), &self.x)?;
        let out = plane_of(&w, self.ids.at(A_X2))?;
        self.x = true_input(sh, &out);
        self.next = k + 1;
        self.builds += 1;
        self.busy_s += t.elapsed().as_secs_f64();
        Ok((w, out))
    }

    /// **THE SEALING PASS** (ruling H-1 rule 1): the witness builder's own
    /// forward pass over all `L` blocks, one witness at a time, returning the
    /// two external endpoint planes. An inadmissible chain is refused here,
    /// before any header or directory exists.
    fn prepass(&mut self) -> Result<(Vec<i16>, Vec<i16>), String> {
        let l = self.blocks.len();
        let mut first: Option<Vec<i16>> = None;
        let mut last: Option<Vec<i16>> = None;
        for k in 0..l {
            let (w, out) = self.advance(k).map_err(|e| format!("block {k}: {e}"))?;
            if k == 0 {
                first = Some(plane_of(&w, self.ids.at(A_X))?);
            }
            drop(w);
            if k + 1 == l {
                last = Some(out);
            }
        }
        let (first, last) = (first.ok_or("private stack: no first plane")?, last.ok_or("private stack: no last plane")?);
        self.sealed_out = Some(plane_digest(&last));
        Ok((first, last))
    }
}

impl RunWitnessSource for StackSource<'_> {
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        if self.cached.is_some() {
            return Err("private stack: a witness is still cached".into());
        }
        let (w, out) = self.advance(k)?;
        self.cached = Some((k, w));
        Ok(out)
    }

    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        match self.cached.take() {
            Some((j, w)) if j == k => Ok(w),
            Some(_) => Err("private stack: the cached witness is for another block".into()),
            None => {
                let (w, out) = self.advance(k)?;
                if k + 1 == self.blocks.len() {
                    if let Some(d) = self.sealed_out {
                        if plane_digest(&out) != d {
                            return Err("private stack: the proving pass departs from the sealing pass".into());
                        }
                    }
                }
                Ok(w)
            }
        }
    }
}

// ---------------------------------------------------------------- prove

struct ProveArgs {
    kind: ShapeKind,
    blocks: usize,
    recipe: Recipe,
    label: String,
    input_seed: u64,
    input_seed_is_default: bool,
    out: PathBuf,
    staging: PathBuf,
    policy_out: PathBuf,
}

fn parse_prove_args(args: &[String]) -> Result<ProveArgs, String> {
    let f = parse_flags(args, &["--shape", "--blocks", "--recipe", "--out", "--policy-out", "--context-label", "--input-seed"])?;
    let kind = ShapeKind::from_cli(need(&f, "--shape")?)?;
    let blocks: usize = need(&f, "--blocks")?.parse().map_err(|_| "--blocks is not a number".to_string())?;
    if blocks == 0 || blocks > MAX_BLOCKS {
        return Err(format!("--blocks must be 1..={MAX_BLOCKS}"));
    }
    let recipe = Recipe::from_cli(flag(&f, "--recipe").unwrap_or("dense-run"))?;
    let label = flag(&f, "--context-label").unwrap_or(DEFAULT_LABEL).to_string();
    label_ok(&label)?;
    let input_seed = match flag(&f, "--input-seed") {
        Some(s) => parse_u64(s)?,
        None => DENSE_INPUT_SEED,
    };
    let out = resolve_new(need(&f, "--out")?)?;
    let mut sname = out.file_name().ok_or("--out has no file name")?.to_os_string();
    sname.push(".staging");
    let staging = out.with_file_name(sname);
    if std::fs::symlink_metadata(&staging).is_ok() {
        return Err(format!("{} exists (a previous attempt); remove it yourself, this driver will not", staging.display()));
    }
    let policy_out = resolve_new(need(&f, "--policy-out")?)?;
    if policy_out.starts_with(&out) || policy_out.starts_with(&staging) || policy_out == out {
        return Err("--policy-out must be outside the artifact directory".into());
    }
    Ok(ProveArgs { kind, blocks, recipe, label, input_seed, input_seed_is_default: flag(&f, "--input-seed").is_none(), out, staging, policy_out })
}

/// what a failed attempt leaves behind
struct Attempt {
    staging_created: bool,
    segments: Vec<(usize, u64, String)>,
    phases: Vec<(&'static str, f64)>,
}

fn phase(at: &mut Attempt, name: &'static str, secs: f64) {
    at.phases.push((name, secs));
    emit(&format!("{{\"event\":\"phase\",\"name\":{},\"seconds\":{}}}", js(name), jf(secs)));
}

fn write_new_file(path: &Path, bytes: &[u8]) -> Result<(), String> {
    let mut f = std::fs::OpenOptions::new().write(true).create_new(true).open(path).map_err(|e| format!("{}: {e}", path.display()))?;
    f.write_all(bytes).map_err(|e| format!("{}: {e}", path.display()))?;
    f.sync_all().map_err(|e| format!("{}: {e}", path.display()))
}

fn sync_dir(dir: &Path) {
    if let Ok(f) = std::fs::File::open(dir) {
        let _ = f.sync_all();
    }
}

fn is_segment_name(n: &str) -> bool {
    let core = n.strip_suffix(".partial").unwrap_or(n);
    core.len() == 15 && core.starts_with("segment-") && core.ends_with(".bin") && core.as_bytes()[8..11].iter().all(|b| b.is_ascii_digit())
}

/// Delete ONLY the files this driver itself creates (segments, their
/// `.partial` temporaries, the manifest); anything else is left alone.
fn discard_staged(staging: &Path) {
    if let Ok(rd) = std::fs::read_dir(staging) {
        for e in rd.flatten() {
            if is_segment_name(&e.file_name().to_string_lossy()) {
                let _ = std::fs::remove_file(e.path());
            }
        }
    }
    let sdir = staging.join(run_sink::STATEMENT_DIR);
    let _ = std::fs::remove_file(sdir.join(MANIFEST_FILE));
    let _ = std::fs::remove_dir(&sdir);
}

fn record_failure(a: &ProveArgs, at: &Attempt, phase_name: &str, msg: &str, t_total: &Instant) -> Option<PathBuf> {
    let stamp = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    let mut name = a.out.file_name()?.to_os_string();
    name.push(format!(".failed-{stamp}-{}", std::process::id()));
    let dest = a.out.with_file_name(name);
    let dir = if at.staging_created {
        discard_staged(&a.staging);
        a.staging.clone()
    } else {
        std::fs::create_dir(&dest).ok()?;
        dest.clone()
    };
    let segs: Vec<String> = at.segments.iter().map(|(k, n, h)| format!("{{\"index\":{k},\"bytes\":{n},\"sha256\":{}}}", js(h))).collect();
    let rec = format!(
        "{{\"schema\":{},\"scope\":{},\"failed_phase\":{},\"error\":{},\"shape\":{},\"blocks\":{},\"recipe\":{},\"context_label\":{},\"timing_s\":{},\"elapsed_s\":{},\"segments_written_then_discarded\":[{}],\"published\":false,\"note\":\"no accepted artifact was published; staged segments of this attempt were deleted; this file holds no private value\"}}\n",
        js(FAILED_SCHEMA),
        js(SCOPE),
        js(phase_name),
        js(msg),
        js(a.kind.name()),
        a.blocks,
        js(a.recipe.name()),
        js(&a.label),
        timings_json(&at.phases),
        jf(t_total.elapsed().as_secs_f64()),
        segs.join(",")
    );
    write_new_file(&dir.join(FAILED_FILE), rec.as_bytes()).ok()?;
    if at.staging_created {
        std::fs::rename(&a.staging, &dest).ok()?;
    }
    Some(dest)
}

type Fail = (&'static str, String);

fn prove_inner(a: &ProveArgs, at: &mut Attempt, t_total: &Instant) -> Result<(), Fail> {
    let l = a.blocks;
    let sh = a.kind.shape();
    emit(&format!(
        "{{\"event\":\"prove_start\",\"scope\":{},\"shape\":{},\"blocks\":{l},\"recipe\":{},\"context_label\":{},\"artifact_dir\":{},\"policy_out\":{},\"hl_gpu_env\":{}}}",
        js(SCOPE),
        js(a.kind.name()),
        js(a.recipe.name()),
        js(&a.label),
        js(&a.out.display().to_string()),
        js(&a.policy_out.display().to_string()),
        js(&std::env::var("HL_GPU").unwrap_or_else(|_| "unset".into()))
    ));

    // ---- model / setup: public words and the run geometry
    let t = Instant::now();
    let blocks = build_model(a.kind, a.recipe, l).map_err(|e| ("model_setup", e))?;
    let model_root = model_root_of(&blocks);
    let rs = a.kind.run_shape(l).map_err(|e| ("model_setup", e))?;
    let run_profile = rs.profile();
    let ctx = context_of(&a.label, run_profile, a.recipe.name(), l);
    phase(at, "model_setup", t.elapsed().as_secs_f64());

    // ---- chain / sealing pass: L witnesses, one resident at a time
    let t = Instant::now();
    let mut src = StackSource::new(&sh, &blocks, hidden_input(&sh, a.input_seed)).map_err(|e| ("chain_prepass", e))?;
    let (first_plane, last_plane) = src.prepass().map_err(|e| ("chain_prepass", e))?;
    let prepass_builds = src.builds;
    src.restart(hidden_input(&sh, a.input_seed)).map_err(|e| ("chain_prepass", e))?;
    phase(at, "chain_prepass", t.elapsed().as_secs_f64());

    // ---- endpoint preparation: fresh OS randomness inside `prepare_endpoints`
    let t = Instant::now();
    let spec = IoSpec::new_shaped(&sh, ctx, super::ENDPOINT_SCALES.0, super::ENDPOINT_SCALES.1).map_err(|e| ("endpoint_prep", e))?;
    let (expected, owners) = prepare_endpoints(spec, &first_plane, &last_plane).map_err(|e| ("endpoint_prep", e))?;
    drop(first_plane);
    drop(last_plane);
    let (in_root, out_root) = (expected.input_root(), expected.output_root());
    phase(at, "endpoint_prep", t.elapsed().as_secs_f64());

    // ---- the run statement
    let t = Instant::now();
    let st = RunStatement::new(rs, ctx, expected, &blocks, &vec![super::ENDPOINT_SCALES; l]).map_err(|e| ("statement", e))?;
    let policy = Policy { kind: a.kind, blocks: l, recipe: a.recipe, label: a.label.clone(), in_root, out_root, model_root };
    let policy_text = render_policy(&policy).map_err(|e| ("statement", e))?;
    phase(at, "statement", t.elapsed().as_secs_f64());

    // ---- prove_run: witness build (recurring), stage proving (incl. segment encode), staged IO
    std::fs::create_dir(&a.staging).map_err(|e| ("stage", format!("{}: {e}", a.staging.display())))?;
    at.staging_created = true;
    let mut disk = DirSink::create(&a.staging, l).map_err(|e| ("stage", e))?;
    let mut sink_s = 0.0f64;
    let mut segrec: Vec<(usize, u64, String)> = Vec::new();
    let t = Instant::now();
    let res = {
        let mut sink = |k: usize, bytes: Vec<u8>| -> Result<(), String> {
            let ts = Instant::now();
            let n = bytes.len() as u64;
            let r = disk.accept(k, bytes);
            sink_s += ts.elapsed().as_secs_f64();
            if r.is_ok() {
                let h = disk.digests().last().cloned().unwrap_or_default();
                emit(&format!("{{\"event\":\"segment_staged\",\"index\":{k},\"bytes\":{n},\"sha256\":{},\"published\":false}}", js(&h)));
                segrec.push((k, n, h));
            }
            r
        };
        run::prove_run(&st, &blocks, &mut src, owners, &mut sink)
    };
    let prove_wall = t.elapsed().as_secs_f64();
    at.segments = segrec;
    let stats = res.map_err(|e| ("prove_run", e))?;
    let witness_s = src.busy_s;
    let prove_builds = src.builds;
    drop(src);
    drop(st);
    drop(blocks);
    phase(at, "witness_build_recurring", witness_s);
    // `wire::encode_segment` runs INSIDE `prove_run`, so segment serialization is
    // INCLUDED in the first figure and is NOT separately instrumented here;
    // `stage_io` is only the sink (DirSink write + fsync + SHA-256)
    phase(at, "prove_and_serialize_excluding_witness_io", (prove_wall - witness_s - sink_s).max(0.0));
    phase(at, "stage_io", sink_s);
    if stats.segment_bytes.len() != l || disk.lengths().len() != l {
        return Err(("prove_run", format!("{} segments staged for {l} blocks", disk.lengths().len())));
    }

    // ---- in-process verification, from a statement rebuilt from the policy TEXT
    let t = Instant::now();
    let reparsed = parse_policy(policy_text.as_bytes()).map_err(|e| ("inprocess_verify", e))?;
    let (vst, vblocks) = build_verifier(&reparsed).map_err(|e| ("inprocess_verify", e))?;
    phase(at, "verify_setup_inprocess", t.elapsed().as_secs_f64());
    let t = Instant::now();
    run::verify_run_from_dir(&vst, &vblocks, &a.staging).map_err(|e| ("inprocess_verify", e))?;
    phase(at, "verify_inprocess", t.elapsed().as_secs_f64());
    drop(vst);
    drop(vblocks);

    // ---- publish: manifest, policy, atomic rename — only after full verification
    let t = Instant::now();
    let policy_sha = run_sink::digest_hex(policy_text.as_bytes());
    let segs: Vec<(String, u64, String)> = (0..l).map(|k| (run_sink::segment_file_name(k), disk.lengths()[k] as u64, disk.digests()[k].clone())).collect();
    let receipt_bytes = disk.total_bytes();
    let sdir = a.staging.join(run_sink::STATEMENT_DIR);
    std::fs::create_dir(&sdir).map_err(|e| ("publish", format!("{}: {e}", sdir.display())))?;
    write_new_file(&sdir.join(MANIFEST_FILE), render_manifest(&policy_sha, &segs).as_bytes()).map_err(|e| ("publish", e))?;
    sync_dir(&sdir);
    sync_dir(&a.staging);
    write_new_file(&a.policy_out, policy_text.as_bytes()).map_err(|e| ("publish", e))?;
    if let Err(e) = std::fs::rename(&a.staging, &a.out) {
        let _ = std::fs::remove_file(&a.policy_out);
        return Err(("publish", format!("{} -> {}: {e}", a.staging.display(), a.out.display())));
    }
    if let Some(parent) = a.out.parent() {
        sync_dir(parent);
    }
    at.staging_created = false;
    phase(at, "publish", t.elapsed().as_secs_f64());

    let total = t_total.elapsed().as_secs_f64();
    let seg_json: Vec<String> = segs.iter().map(|(n, b, h)| format!("{{\"file\":{},\"bytes\":{b},\"sha256\":{}}}", js(n), js(h))).collect();
    emit(&format!(
        concat!(
            "{{\"event\":\"prove_result\",\"status\":\"accepted_in_process_and_published\",",
            "\"scope\":{},\"synthetic\":true,\"trained_model\":false,\"trained_8b_proof\":false,\"privacy_acceptance\":false,",
            "\"shape\":{},\"shape_name\":{},\"block_profile\":{},\"run_profile\":{},\"one_transcript\":true,",
            "\"layers\":{},\"tokens\":{},\"tokens_counted_once\":{},\"block_token_evaluations\":{},",
            "\"dims\":{{\"width\":{},\"hidden\":{},\"q_heads\":{},\"kv_heads\":{},\"head_dim\":{}}},",
            "\"receipt_bytes\":{},\"segments\":[{}],",
            "\"source\":{{\"kind\":\"synthetic-public-recipe\",\"recipe\":{},\"model_digest\":{},\"input\":\"synthetic hidden input, {} seed, not logged\"}},",
            "\"calibration\":{{\"identity\":{},\"scales\":[{},{}],\"origin\":\"the approved fixed calibration built into this binary\"}},",
            "\"context_label\":{},\"input_root\":{},\"output_root\":{},",
            "\"artifact_dir\":{},\"policy_file\":{},\"policy_sha256\":{},",
            "\"independent_verification\":{{\"available\":true,\"performed_in_this_process\":false,\"in_process_check\":\"passed\",\"command\":{}}},",
            "\"witness_builds\":{{\"sealing_pass\":{},\"proving_pass\":{}}},",
            "\"timing_s\":{},\"driver_wall_s\":{},\"driver_wall_note\":\"wall time of this command from argument parsing to result; excludes process start-up and exit; the root adds process-level totals\",",
            "\"tokens_per_s_over_driver_wall\":{},\"peak_rss_mib\":{}}}"
        ),
        js(SCOPE),
        js(a.kind.name()),
        js(sh.name),
        js(sh.profile),
        js(run_profile),
        l,
        sh.tokens,
        sh.tokens,
        sh.tokens * l,
        sh.width,
        sh.hidden,
        sh.q_heads,
        sh.kv_heads,
        sh.head_dim,
        receipt_bytes,
        seg_json.join(","),
        js(a.recipe.name()),
        js(&hex(&model_root)),
        if a.input_seed_is_default { "default" } else { "caller" },
        js(&hex(&super::calibration_identity())),
        super::ENDPOINT_SCALES.0,
        super::ENDPOINT_SCALES.1,
        js(&a.label),
        js(&hex(&in_root)),
        js(&hex(&out_root)),
        js(&a.out.display().to_string()),
        js(&a.policy_out.display().to_string()),
        js(&policy_sha),
        js(&format!("zk60_private_stack verify --artifact {} --policy {} --policy-sha256 {policy_sha}", a.out.display(), a.policy_out.display())),
        prepass_builds,
        prove_builds,
        timings_json(&at.phases),
        jf(total),
        jf(sh.tokens as f64 / total),
        jf(run::peak_rss_mib())
    ));
    Ok(())
}

/// `prove` command: exit 0 accepted and published, 1 failed (a failure record
/// was left, nothing was published), 2 bad arguments.
pub fn prove_command(args: &[String]) -> i32 {
    let t_total = Instant::now();
    let a = match parse_prove_args(args) {
        Ok(a) => a,
        Err(e) => return usage_error(&e),
    };
    let mut at = Attempt { staging_created: false, segments: Vec::new(), phases: Vec::new() };
    match prove_inner(&a, &mut at, &t_total) {
        Ok(()) => 0,
        Err((ph, msg)) => {
            let rec = record_failure(&a, &at, ph, &msg, &t_total);
            emit(&format!(
                "{{\"event\":\"prove_result\",\"status\":\"failed\",\"published\":false,\"scope\":{},\"failed_phase\":{},\"error\":{},\"failure_record\":{},\"timing_s\":{},\"driver_wall_s\":{}}}",
                js(SCOPE),
                js(ph),
                js(&msg),
                rec.map(|p| js(&p.join(FAILED_FILE).display().to_string())).unwrap_or_else(|| "null".into()),
                timings_json(&at.phases),
                jf(t_total.elapsed().as_secs_f64())
            ));
            1
        }
    }
}

// ---------------------------------------------------------------- verify

fn pin_check(f: &[(String, String)], p: &Policy, policy_sha: &str, run_profile: &str) -> Result<(), String> {
    let same = |flag_name: &str, got: String| -> Result<(), String> {
        match flag(f, flag_name) {
            Some(want) if want != got => Err(format!("pin {flag_name} disagrees with the trusted policy")),
            _ => Ok(()),
        }
    };
    same("--policy-sha256", policy_sha.to_string())?;
    same("--expect-shape", p.kind.name().to_string())?;
    same("--expect-blocks", p.blocks.to_string())?;
    same("--expect-recipe", p.recipe.name().to_string())?;
    same("--expect-context-label", p.label.clone())?;
    same("--expect-run-profile", run_profile.to_string())?;
    same("--expect-calibration", hex(&super::calibration_identity()))?;
    same("--expect-block-digests", hex(&p.model_root))?;
    same("--expect-input-root", hex(&p.in_root))?;
    same("--expect-output-root", hex(&p.out_root))?;
    Ok(())
}

struct Verified {
    policy_sha: String,
    kind: ShapeKind,
    blocks: usize,
    recipe: Recipe,
    run_profile: &'static str,
    block_profile: &'static str,
    receipt_bytes: u64,
    phases: Vec<(&'static str, f64)>,
}

fn verify_inner(f: &[(String, String)]) -> Result<Verified, String> {
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let t = Instant::now();
    let policy_path = Path::new(need(f, "--policy")?);
    let dir = Path::new(need(f, "--artifact")?);
    let bytes = read_bounded(policy_path, MAX_POLICY_BYTES)?;
    let policy_sha = run_sink::digest_hex(&bytes);
    let p = parse_policy(&bytes)?;
    let rs = p.kind.run_shape(p.blocks)?;
    pin_check(f, &p, &policy_sha, rs.profile())?;
    phases.push(("policy_load", t.elapsed().as_secs_f64()));

    let t = Instant::now();
    let (st, blocks) = build_verifier(&p)?;
    phases.push(("model_setup", t.elapsed().as_secs_f64()));

    let t = Instant::now();
    if !dir.is_dir() {
        return Err(format!("artifact: {} is not a directory", dir.display()));
    }
    let segs = scan_artifact(dir, p.blocks)?;
    let want = render_manifest(&policy_sha, &segs);
    let got = read_bounded(&dir.join(run_sink::STATEMENT_DIR).join(MANIFEST_FILE), MAX_MANIFEST_BYTES)?;
    if got != want.as_bytes() {
        return Err("artifact: the manifest is not the one these segments and this policy give".into());
    }
    phases.push(("artifact_scan", t.elapsed().as_secs_f64()));

    let t = Instant::now();
    run::verify_run_from_dir(&st, &blocks, dir)?;
    phases.push(("verify_run", t.elapsed().as_secs_f64()));
    Ok(Verified {
        policy_sha,
        kind: p.kind,
        blocks: p.blocks,
        recipe: p.recipe,
        run_profile: rs.profile(),
        block_profile: p.kind.shape().profile,
        receipt_bytes: segs.iter().map(|s| s.1).sum(),
        phases,
    })
}

/// `verify` command: exit 0 accepted, 1 refused (any reason), 2 bad arguments.
/// Reads only the trusted policy (and pins) and the artifact; builds no
/// witness and sees no private value.
pub fn verify_command(args: &[String]) -> i32 {
    let t_total = Instant::now();
    let f = match parse_flags(
        args,
        &[
            "--artifact",
            "--policy",
            "--policy-sha256",
            "--expect-shape",
            "--expect-blocks",
            "--expect-recipe",
            "--expect-context-label",
            "--expect-run-profile",
            "--expect-calibration",
            "--expect-block-digests",
            "--expect-input-root",
            "--expect-output-root",
        ],
    ) {
        Ok(f) => f,
        Err(e) => return usage_error(&e),
    };
    if flag(&f, "--policy").is_none() || flag(&f, "--artifact").is_none() {
        return usage_error("--artifact and --policy are required");
    }
    match verify_inner(&f) {
        Ok(v) => {
            let sh = v.kind.shape();
            let total = t_total.elapsed().as_secs_f64();
            emit(&format!(
                concat!(
                    "{{\"event\":\"verify_result\",\"status\":\"accepted\",\"fresh_process\":true,\"scope\":{},\"synthetic\":true,\"trained_model\":false,\"trained_8b_proof\":false,\"privacy_acceptance\":false,",
                    "\"shape\":{},\"block_profile\":{},\"run_profile\":{},\"recipe\":{},\"layers\":{},\"tokens\":{},\"receipt_bytes\":{},",
                    "\"policy_sha256\":{},\"trusted_inputs\":\"caller policy file and pins only; nothing adopted from the artifact\",",
                    "\"timing_s\":{},\"driver_wall_s\":{},\"peak_rss_mib\":{}}}"
                ),
                js(SCOPE),
                js(v.kind.name()),
                js(v.block_profile),
                js(v.run_profile),
                js(v.recipe.name()),
                v.blocks,
                sh.tokens,
                v.receipt_bytes,
                js(&v.policy_sha),
                timings_json(&v.phases),
                jf(total),
                jf(run::peak_rss_mib())
            ));
            0
        }
        Err(e) => {
            emit(&format!("{{\"event\":\"verify_result\",\"status\":\"refused\",\"accepted\":false,\"scope\":{},\"reason\":{},\"driver_wall_s\":{}}}", js(SCOPE), js(&e), jf(t_total.elapsed().as_secs_f64())));
            1
        }
    }
}

// ---------------------------------------------------------------- tests

#[cfg(test)]
mod tests {
    use super::*;
    use crate::private_block::dense_tests;

    fn digests(d: u8) -> Policy {
        Policy { kind: ShapeKind::P2, blocks: 3, recipe: Recipe::DenseRun, label: DEFAULT_LABEL.into(), in_root: [1; 32], out_root: [2; 32], model_root: [d; 32] }
    }

    /// the copied recipe is the original's, word for word, at both shapes
    #[test]
    fn the_copied_recipe_is_the_dense_run_recipe_at_both_shapes() {
        for kind in [ShapeKind::P2, ShapeKind::M125] {
            let sh = kind.shape();
            assert_eq!(band_down_run(&sh).unwrap(), dense_tests::band_down_run(&sh), "{}: the chain band", kind.name());
            assert_eq!(hidden_input(&sh, DENSE_INPUT_SEED), dense_tests::dense_hidden_input(&sh, INPUT_MAG), "{}: the input stream", kind.name());
            let (public, ff, _) = dense_tests::dense_run_case(&sh);
            assert_eq!(block_of(&sh, DENSE_SEED).unwrap().digest(), BlockPublic::new(public, ff).digest(), "{}: the public words", kind.name());
        }
    }

    #[test]
    fn the_varied_recipe_starts_at_the_same_block_and_then_differs() {
        let b = build_model(ShapeKind::P2, Recipe::DenseRunVaried, 3).unwrap();
        let same = build_model(ShapeKind::P2, Recipe::DenseRun, 3).unwrap();
        assert_eq!(b[0].digest(), same[0].digest());
        assert_eq!(same[0].digest(), same[2].digest());
        assert_ne!(b[0].digest(), b[1].digest());
        assert_ne!(b[1].digest(), b[2].digest());
    }

    #[test]
    fn a_policy_round_trips_and_every_alteration_is_refused() {
        let p = digests(9);
        let text = render_policy(&p).unwrap();
        let q = parse_policy(text.as_bytes()).unwrap();
        assert_eq!(render_policy(&q).unwrap(), text);
        for (from, to) in [
            ("blocks=3", "blocks=4"),
            ("shape=rung-p2", "shape=m125"),
            ("run_profile=hashline-zk-mr1/private-run-rung-p2-t32-dev/1", "run_profile=hashline-zk-mr1/private-run-m125/1"),
            ("input_scale=0", "input_scale=1"),
            ("recipe=zk60-mvp/dense-run/1", "recipe=zk60-mvp/dense-run-varied/1"),
            ("context_label=zk60-mvp-diagnostic", "context_label=another-label"),
        ] {
            assert!(text.contains(from), "the fixture text no longer contains {from}");
            let bad = text.replacen(from, to, 1);
            assert!(parse_policy(bad.as_bytes()).is_err(), "an altered policy ({from}) was accepted");
        }
        assert!(parse_policy(&text.as_bytes()[..text.len() - 1]).is_err(), "a policy without its final newline was accepted");
        assert!(parse_policy(format!("{text}extra=1\n").as_bytes()).is_err(), "a policy with an extra line was accepted");
        assert!(parse_policy(&vec![b'a'; MAX_POLICY_BYTES as usize + 1]).is_err());
    }

    fn prove_args(blocks: &str, out: &Path, policy: &Path) -> Vec<String> {
        let (o, p) = (out.display().to_string(), policy.display().to_string());
        ["--shape", "p2", "--blocks", blocks, "--out", o.as_str(), "--policy-out", p.as_str()].iter().map(|s| s.to_string()).collect()
    }

    /// **THE END-TO-END SPEC**: prove two blocks at rung-p2, verify from a
    /// fresh statement, then refuse every family the driver promises to refuse.
    #[test]
    fn a_two_block_p2_stack_proves_publishes_and_verifies_and_refusals_hold() {
        let base = std::env::temp_dir().join(format!("zk60_stack_test_{}_{}", std::process::id(), std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()));
        std::fs::create_dir_all(&base).unwrap();
        let s = |p: &Path| p.display().to_string();
        let (art, pol) = (base.join("art"), base.join("policy.txt"));
        assert_eq!(prove_command(&prove_args("2", &art, &pol)), 0);
        assert!(art.is_dir() && !base.join("art.staging").exists(), "the artifact is published and the staging directory is gone");
        let verify = |art: &Path, pol: &Path, extra: &[&str]| {
            let mut a = vec!["--artifact".to_string(), s(art), "--policy".to_string(), s(pol)];
            a.extend(extra.iter().map(|x| x.to_string()));
            verify_command(&a)
        };
        assert_eq!(verify(&art, &pol, &[]), 0, "the fresh verification");
        // pins that disagree with the trusted policy
        assert_eq!(verify(&art, &pol, &["--expect-blocks", "3"]), 1);
        assert_eq!(verify(&art, &pol, &["--expect-shape", "m125"]), 1);
        assert_eq!(verify(&art, &pol, &["--expect-input-root", &"00".repeat(32)]), 1);
        // a modified segment, then restored
        let seg1 = art.join("segment-001.bin");
        let orig = std::fs::read(&seg1).unwrap();
        let mut bad = orig.clone();
        bad[orig.len() / 2] ^= 1;
        std::fs::write(&seg1, &bad).unwrap();
        assert_eq!(verify(&art, &pol, &[]), 1, "a modified segment");
        std::fs::write(&seg1, &orig).unwrap();
        // swapped segments
        let seg0 = art.join("segment-000.bin");
        let o0 = std::fs::read(&seg0).unwrap();
        std::fs::write(&seg0, &orig).unwrap();
        std::fs::write(&seg1, &o0).unwrap();
        assert_eq!(verify(&art, &pol, &[]), 1, "reordered segments");
        std::fs::write(&seg0, &o0).unwrap();
        std::fs::write(&seg1, &orig).unwrap();
        // an extra file and a missing one
        std::fs::write(art.join("extra.bin"), b"x").unwrap();
        assert_eq!(verify(&art, &pol, &[]), 1, "an extra file");
        std::fs::remove_file(art.join("extra.bin")).unwrap();
        std::fs::rename(&seg1, base.join("held.bin")).unwrap();
        assert_eq!(verify(&art, &pol, &[]), 1, "a missing segment");
        std::fs::rename(base.join("held.bin"), &seg1).unwrap();
        assert_eq!(verify(&art, &pol, &[]), 0, "the restored artifact verifies again");
        // another proof's policy (fresh endpoint roots) does not verify this artifact
        let (art2, pol2) = (base.join("art2"), base.join("policy2.txt"));
        assert_eq!(prove_command(&prove_args("2", &art2, &pol2)), 0);
        assert_ne!(std::fs::read(&pol).unwrap(), std::fs::read(&pol2).unwrap(), "endpoint randomness is fresh on every proof");
        assert_eq!(verify(&art, &pol2, &[]), 1, "another run's policy");
        assert_eq!(verify(&art2, &pol2, &[]), 0);
        // a refused prove never overwrites and leaves nothing published
        assert_eq!(prove_command(&prove_args("2", &art, &base.join("p3.txt"))), 2);
        std::fs::remove_dir_all(&base).unwrap();
    }
}
