//! **THE TOKEN-I/O RUN FROM THE COMMAND LINE (2026-10-19).** Prove and verify
//! ONE private next-token run of a calibration export (TinyLlama T32,
//! Llama-3-8B T32, or the trained-calibration development rung) in separate
//! processes, with the native R7 statement-publication rules:
//!
//! ```text
//! zk60_token_io prove   --export DIR --emb DIR --head DIR (--seq ID | --seq-dir DIR)
//!                       [--prompt ID,ID,...] --out DIR [--owner-dir DIR] [--label L]
//! zk60_token_io profile --export DIR --emb DIR --head DIR [--label L]
//! zk60_token_io verify  --export DIR --emb DIR --head DIR --artifact DIR
//!                       --expect-statement HEX --expect-token-profile HEX
//!                       [--label L] [--min-bits N]
//! zk60_token_io owner   (verify's arguments) --decommitment FILE
//! zk60_token_io input-owner (verify's arguments) --decommitment FILE --prompt ID,ID,...
//! ```
//!
//! * `prove` reads the prover-private prompt (`--prompt`, or the sequence
//!   manifest's `token_ids`) and hidden activations (`--seq` / `--seq-dir`,
//!   privacy review P-5), seals the two token endpoints from the export's own
//!   words (B_in = the embedded prompt, which must be the export's x_in_L00;
//!   the next token from its last layer's x_out row T - 1), proves with ONE
//!   block resident, checks every block's output against the export bit for
//!   bit in the proving pass, and writes the segments into `<out>/` (built
//!   as `<out>.incomplete/` and renamed only after the run returns Ok:
//!   review TR3-1's sink contract), an UNVERIFIED statement into
//!   `<out>.unverified-statement/`, and the two owners' decommitments into
//!   the owner directory (below; never part of a published bundle, D21).
//!   It prints no hidden value.
//! * `verify` refuses an export directory that holds `seq_*` (P-5), pins the
//!   trained identity (`--expect-statement`), rebuilds the statement from the
//!   PUBLIC files, requires the prover's statement to be byte for byte the
//!   canonical rendering with an allowed backend (R7 / Q-2), verifies the
//!   run under a minimum whole-run figure (`--min-bits`, default 95: D27's
//!   MVP level), and then WRITES `<out>/statement/` itself from its own data
//!   and the hashes of the bytes it verified, and removes the unverified
//!   statement (rulings M-9 / D12b(1), review r5_A). Run again over a
//!   published statement, it re-checks it byte for byte. A stale
//!   `statement.writing-<pid>` of a killed verifier is removed or refused by
//!   name (N-r6-b).
//! * `owner` is the OUTPUT owner's check (review TR4-1): it first runs
//!   verify's full re-check of the PUBLISHED statement (both pins, the
//!   canonical statement, every segment re-read and verified, `segments.json`
//!   = the verified bytes' hashes); then the decommitment must rebuild the
//!   verified output root and carry one id below V and zero pads; it prints
//!   that id. `input-owner` does the same for the input endpoint and the
//!   owner's own prompt.
//! * the pins (review TR4-2): `--expect-statement` = the trained-model
//!   statement's identity (blocks, calibration, source); `--expect-token-
//!   profile` = the token profile's digest (V, BOS, the final norm, the
//!   embedding and head digests with the multipliers, the tier). `profile`
//!   prints both from an approved export and table set.
//! * the owners' decommitments (review TR4-3, D21) go to `--owner-dir`, by
//!   default `$HOME/zk60-artifacts/token-io/<run>-<key>.owner-private` (key:
//!   12 hex digits of SHA-256 of the run's canonical path, review TR5-1),
//!   never inside the run's parent, created 0700 (files 0600), before the run
//!   is renamed into place (TR4-4). `prove` claims the owner, unverified and
//!   incomplete directories atomically at its start and, on a refusal,
//!   removes only the directories it created (TR5-1).
//!
//! JSON lines on stdout. Exit 0 = done, 1 = refused (a JSON `refused` line),
//! 2 = bad arguments.

use super::load::{load_token_tables, ExportPublic, ExportTokenBlocks, TableFiles, TableManifest};
use super::run::*;
use super::stage_in::{self, StageInWitness};
use super::stage_out::{self, StageOutWitness};
use super::*;
use super::super::layout::{Ids, A_X2};
use super::super::run::{read_regular_file_bounded, RunShape};
use super::super::run_sink::{self, SegmentSink};
use super::super::trained_block::{backend_of_this_process, check_prover_reported, check_statement_dir, clear_stale_writing_dirs, flag, flags, js, need, parse_json, publish_statement_dir, refuse_prover_private_entries, render_segments_json, stack_context, unhex32, write_new, TrainedExport, J};
use super::super::BlockPublic;
use std::path::{Path, PathBuf};
use std::time::Instant;

/// the statement schema of a token-I/O run
pub(crate) const TOKEN_STATEMENT_SCHEMA: &str = "zk60-token-io-run/1";
/// the run context labels this build admits (ruling C-R4: a deployment
/// constant, never request text)
pub(crate) const TOKEN_LABELS: [&str; 1] = ["zk60-token-io-next-token"];
const TOKEN_SCOPE: &str = "ONE private next-token run of the export's model: stage IN (the hidden prompt to the hidden embedded input through the public int16 embedding table, BOS forced), ALL the export's trained blocks (one transcript, hidden internal boundaries), stage OUT (the final norm with a uniform gain, the public per-row int8 head with integer multipliers, the keyed greedy argmax, numpy's first maximum); the prompt and the next token are sealed in the two token endpoints and opened only to their owners; public-row variant (the prompt fills T); NO privacy acceptance (the rank / CFS gates on the token stages are owed)";
const PROVER_REPORTED_WHAT: &str = "the prover's own report of its build and device path; one of the build's names (R7 / Q-2), not verified by the proof";
const UNVERIFIED_TEXT: &[u8] = b"The prover wrote this statement WITHOUT verifying the run. It is not a public statement: only `zk60_token_io verify`, after a fresh-process verification of the run directory passes, writes <run>/statement/ itself (rulings M-9 / D12b(1); review r5_A).\n";
/// the largest statement / decommitment file a reader takes
const MAX_STATEMENT_BYTES: u64 = 1 << 20;
const MAX_DECOMMITMENT_BYTES: u64 = 16 << 20;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Writer {
    Unverified,
    FreshVerify,
}

impl Writer {
    const ALL: [Writer; 2] = [Writer::Unverified, Writer::FreshVerify];
    fn text(self) -> &'static str {
        match self {
            Writer::Unverified => "zk60_token_io prove, WITHOUT a verification (unverified: only zk60_token_io verify publishes a statement for this run)",
            Writer::FreshVerify => "zk60_token_io verify, after its fresh-process verification of the run directory, from its own data and the hashes of the bytes it verified",
        }
    }
}

fn label_of<'a>(f: &'a [(String, String)]) -> Result<&'a str, String> {
    let label = flag(f, "--label").unwrap_or(TOKEN_LABELS[0]);
    if !TOKEN_LABELS.contains(&label) {
        return Err(format!("--label: ruling C-R4 — the run context label is a deployment constant; this build admits {TOKEN_LABELS:?}, not {label:?}"));
    }
    Ok(label)
}

fn table_files(f: &[(String, String)]) -> Result<TableFiles, String> {
    Ok(TableFiles { emb_dir: PathBuf::from(need(f, "--emb")?), head_dir: PathBuf::from(need(f, "--head")?) })
}

fn unverified_dir(out: &Path) -> PathBuf {
    let mut s = out.as_os_str().to_owned();
    s.push(".unverified-statement");
    PathBuf::from(s)
}

fn sibling(out: &Path, suffix: &str) -> PathBuf {
    let mut s = out.as_os_str().to_owned();
    s.push(suffix);
    PathBuf::from(s)
}

/// THE STATEMENT a token-run directory carries, rendered from the verifier's
/// (or the prover's) own data; the only writer of the file
#[allow(clippy::too_many_arguments)]
fn render(p: &ExportPublic, tm: &TableManifest, st: &TokenRunStatement, label: &str, writer: Writer, backend: &str, declines: u64) -> Result<String, String> {
    let own: Vec<String> = p.model.layers.iter().filter_map(|r| r.own[0].map(|v| format!("{{\"layer\": {}, \"sh_s\": {v}}}", r.index))).collect();
    let (ir, or) = st.roots();
    Ok(format!(
        "{{\n \"schema\": {},\n \"scope\": {},\n \"statement_written_by\": {},\n \"prover_reported\": {{\"backend\": {}, \"gpu_declines\": {}, \"what\": {}}},\n \"run_profile\": {},\n \"block_profile\": {},\n \"blocks\": {},\n \"export_variant\": {},\n \"export_profile_sha256\": {},\n \"trained_statement_identity\": {},\n \"layers_with_own_score_shift\": [{}],\n \"tables\": {{\"embedding_int16_sha256\": {}, \"head_int8_perrow_sha256\": {}, \"head_mult12_sha256\": {}, \"V\": {}, \"d\": {}}},\n \"bos\": {},\n \"final_norm\": {{\"g0\": {}, \"cn\": {}, \"tn\": {}, \"ceps\": {}}},\n \"token_profile_digest\": {},\n \"context_label\": {},\n \"context\": {},\n \"input_token_endpoint_root\": {},\n \"output_token_endpoint_root\": {},\n \"whole_run_floor_bits\": {},\n \"parameter_line\": {}\n}}\n",
        js(TOKEN_STATEMENT_SCHEMA),
        js(TOKEN_SCOPE),
        js(writer.text()),
        js(backend),
        declines,
        js(PROVER_REPORTED_WHAT),
        js(p.profile),
        js(p.sh.profile),
        p.layers.len(),
        js(&p.ex.variant),
        js(&hex(&p.ex.profile_sha256)),
        js(&hex(&p.model.identity())),
        own.join(", "),
        js(&tm.emb_sha256),
        js(&tm.head_sha256),
        js(&tm.mult_sha256),
        tm.v,
        tm.d,
        tm.bos,
        tm.norm.g0,
        tm.norm.cn,
        tm.norm.tn,
        tm.norm.ceps,
        js(&hex(&st.tp.digest_under(st.profile()))),
        js(label),
        js(&hex(&st.context())),
        js(&hex(&ir)),
        js(&hex(&or)),
        st.whole_run().floor_bits,
        js(&st.parameter_line()?)
    ))
}

/// what a found statement names: its writer, the prover's claims (checked
/// against the build's names), its label, context and roots
struct Found {
    writer: Writer,
    backend: String,
    declines: u64,
    label: String,
    context: Digest,
    roots: (Digest, Digest),
}

fn found_statement(bytes: &[u8]) -> Result<Found, String> {
    let j = parse_json(bytes).map_err(|e| format!("statement.json: {e}"))?;
    let s = |k: &str| j.get(k).and_then(J::str).map_err(|e| format!("statement.json: {k}: {e}"));
    if s("schema")? != TOKEN_STATEMENT_SCHEMA {
        return Err(format!("statement.json: not schema {TOKEN_STATEMENT_SCHEMA}"));
    }
    let by = s("statement_written_by")?;
    let writer = Writer::ALL.iter().copied().find(|w| w.text() == by).ok_or("statement.json: an unknown writer")?;
    let pr = j.get("prover_reported").map_err(|e| format!("statement.json: {e}"))?;
    let backend = pr.get("backend").and_then(J::str).map_err(|e| format!("statement.json: prover_reported: {e}"))?;
    let d = pr.get("gpu_declines").and_then(J::i64).map_err(|e| format!("statement.json: prover_reported: {e}"))?;
    let declines = u64::try_from(d).map_err(|_| "statement.json: prover_reported.gpu_declines is negative".to_string())?;
    // native R7 (privacy review round 2, Q-2): build constants only
    check_prover_reported(backend, declines).map_err(|e| format!("statement.json: {e}"))?;
    let label = s("context_label")?.to_string();
    if !TOKEN_LABELS.contains(&label.as_str()) {
        return Err("statement.json: the context label is not one this build admits (ruling C-R4)".into());
    }
    let context = unhex32(s("context")?)?;
    let roots = (unhex32(s("input_token_endpoint_root")?)?, unhex32(s("output_token_endpoint_root")?)?);
    Ok(Found { writer, backend: backend.to_string(), declines, label, context, roots })
}

/// the run statement rebuilt from PUBLIC files and a found context / roots
fn statement_of(p: &ExportPublic, tables: &TokenTables, tm: &TableManifest, label: &str, context: Digest, roots: (Digest, Digest)) -> Result<TokenRunStatement, String> {
    let want = stack_context(&p.ex.variant, &p.layers, label)?;
    if context != want {
        return Err("token run: the statement's context is not this export's and label's".into());
    }
    TokenRunStatement::new(RunShape::new(p.sh.clone(), p.layers.len(), p.profile)?, context, p.digests.clone(), &p.model, tables, tm.bos, tm.norm, SelectorVariant::PublicRow, Tier::R1_MVP, roots)
}

fn pad_plane(sh: &Shape, x: &[i16]) -> Vec<i16> {
    let mut p = vec![0i16; sh.t_pad * sh.d_pad];
    for t in 0..sh.tokens {
        p[t * sh.d_pad..t * sh.d_pad + sh.width].copy_from_slice(&x[t * sh.width..(t + 1) * sh.width]);
    }
    p
}

fn unpad(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| plane[t * sh.d_pad + i]).collect()
}

/// the prover-private hidden input and its parity reference (privacy review
/// P-5): the export's `seq_<ID>/` or a private directory
enum SeqIn {
    InExport(String),
    Dir(PathBuf),
}

impl SeqIn {
    fn of(f: &[(String, String)]) -> Result<SeqIn, String> {
        match (flag(f, "--seq"), flag(f, "--seq-dir")) {
            (Some(s), None) => Ok(SeqIn::InExport(s.to_string())),
            (None, Some(d)) => Ok(SeqIn::Dir(PathBuf::from(d))),
            _ => Err("exactly one of --seq ID (the export's seq_<ID>/) or --seq-dir DIR (a prover-private directory) is required".into()),
        }
    }
    fn load(&self, ex: &TrainedExport, sh: &Shape, layer: u32) -> Result<(Vec<i16>, Vec<i16>), String> {
        match self {
            SeqIn::InExport(s) => ex.load_seq(sh, s, layer),
            SeqIn::Dir(d) => TrainedExport::load_seq_dir(d, sh, layer),
        }
    }
    fn dir(&self, ex: &TrainedExport) -> PathBuf {
        match self {
            SeqIn::InExport(s) => ex.dir.join(format!("seq_{s}")),
            SeqIn::Dir(d) => d.clone(),
        }
    }
}

/// the prompt: `--prompt` or the sequence manifest's `token_ids`
fn prompt_of(f: &[(String, String)], seq: &SeqIn, ex: &TrainedExport) -> Result<Vec<u64>, String> {
    if let Some(p) = flag(f, "--prompt") {
        return p.split(',').map(|x| x.trim().parse::<u64>().map_err(|_| "--prompt: a comma-separated list of token ids".to_string())).collect();
    }
    let path = seq.dir(ex).join("manifest.json");
    let j = parse_json(&read_regular_file_bounded(&path, MAX_STATEMENT_BYTES, false)?).map_err(|e| format!("{}: {e}", path.display()))?;
    let ids = j.get("token_ids").and_then(J::arr).map_err(|e| format!("{}: token_ids: {e} (give --prompt)", path.display()))?;
    ids.iter().map(|x| x.i64().and_then(|v| u64::try_from(v).map_err(|_| "a negative token id".to_string())).map_err(|e| format!("{}: token_ids: {e}", path.display()))).collect()
}

/// the prover's witness source: block `k`'s witness built at its stage
/// shape from the previous boundary and checked bit for bit against the
/// export's x_out of its layer before its segment exists; boundary `k + 1`
/// sealed from that x_out
struct CliSource<'a> {
    p: &'a ExportPublic,
    seq: &'a SeqIn,
    ids: Ids,
    stage_in: Option<(StageInWitness, Vec<i16>)>,
    stage_out: Option<StageOutWitness>,
    x: Vec<i16>,
    parity: usize,
    witness_s: f64,
}

impl TokenRunSource for CliSource<'_> {
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String> {
        self.stage_in.take().ok_or_else(|| "token run: stage IN asked twice".to_string())
    }
    fn witness(&mut self, k: usize, blk: &BlockPublic, ssh: &Shape) -> Result<super::super::witness::Witness, String> {
        let t0 = Instant::now();
        let sh = &self.p.sh;
        let w = super::super::witness::build_shaped(ssh, blk.attention(), blk.feed_forward(), &self.x)?;
        let out: Vec<i16> = w.planes[self.ids.at(A_X2)].iter().map(|v| i16::try_from(*v).map_err(|_| "token run: a block output outside int16".to_string())).collect::<Result<_, _>>()?;
        let next = unpad(sh, &out);
        if next != self.seq.load(&self.p.ex, sh, self.p.layers[k])?.1 {
            return Err(format!("token run: block {k}'s native output is not the export's x_out_L{:02} (parity)", self.p.layers[k]));
        }
        self.parity += 1;
        self.x = next;
        self.witness_s += t0.elapsed().as_secs_f64();
        Ok(w)
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(pad_plane(&self.p.sh, &self.seq.load(&self.p.ex, &self.p.sh, self.p.layers[k])?.1))
    }
    fn stage_out(&mut self) -> Result<StageOutWitness, String> {
        self.stage_out.take().ok_or_else(|| "token run: stage OUT asked twice".to_string())
    }
}

/// a file only its owner can read (the owners' decommitments)
fn write_private(path: &Path, bytes: &[u8]) -> Result<(), String> {
    use std::io::Write;
    use std::os::unix::fs::OpenOptionsExt;
    let mut f = std::fs::OpenOptions::new().write(true).create_new(true).mode(0o600).open(path).map_err(|e| format!("{}: {e}", path.display()))?;
    f.write_all(bytes).and_then(|_| f.sync_all()).map_err(|e| format!("{}: {e}", path.display()))
}

fn refused(what: &str, e: &str) -> i32 {
    println!("{{\"event\":\"refused\",\"command\":{},\"error\":{}}}", js(what), js(e));
    1
}

/// `zk60_token_io prove ...` (see the module text)
pub fn token_prove_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--emb", "--head", "--seq", "--seq-dir", "--prompt", "--out", "--label", "--owner-dir"], &[]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_token_io prove: {e}");
            return 2;
        }
    };
    match prove_inner(&f) {
        Ok(()) => 0,
        Err(e) => refused("prove", &e),
    }
}

/// **review TR4-3 (D21): where the owners' decommitments go.** `--owner-dir`,
/// or by default `$HOME/zk60-artifacts/token-io/<run name>-<key>.owner-private`
/// (`default_owner_dir`); never inside the run's parent directory (a
/// directory that is published or snapshotted with the run would carry
/// them); created 0700 by `prove`, which claims it atomically (TR5-1)
fn owner_dir_of(f: &[(String, String)], out: &Path) -> Result<PathBuf, String> {
    let home = std::env::var_os("HOME").map(PathBuf::from);
    owner_dir_at(f, out, home.as_deref())
}

/// [`owner_dir_of`] with `$HOME` given (`None`: unset)
pub(super) fn owner_dir_at(f: &[(String, String)], out: &Path, home: Option<&Path>) -> Result<PathBuf, String> {
    out.file_name().ok_or("--out: names no directory")?;
    let od = match flag(f, "--owner-dir") {
        Some(d) => PathBuf::from(d),
        None => {
            let home = home.ok_or_else(|| "no HOME: give --owner-dir (outside the run's parent)".to_string())?;
            let base = home.join("zk60-artifacts").join("token-io");
            let mut b = std::fs::DirBuilder::new();
            {
                use std::os::unix::fs::DirBuilderExt;
                b.recursive(true).mode(0o700);
            }
            b.create(&base).map_err(|e| format!("{}: {e}", base.display()))?;
            default_owner_dir(&base, out)?
        }
    };
    let canon = |p: &Path| std::fs::canonicalize(p).map_err(|e| format!("{}: {e}", p.display()));
    let run_parent = canon(out.parent().filter(|p| !p.as_os_str().is_empty()).unwrap_or(Path::new(".")))?;
    let od_parent = canon(od.parent().filter(|p| !p.as_os_str().is_empty()).unwrap_or(Path::new(".")))?;
    if od_parent.starts_with(&run_parent) {
        return Err(format!("--owner-dir {}: inside the run's parent directory {}; the owners' decommitments are private (D21) and never sit where the run is published or snapshotted (review TR4-3)", od.display(), run_parent.display()));
    }
    Ok(od)
}

/// the default owner directory of a run under `base` (review TR4-3), keyed by
/// the run's CANONICAL path (review TR5-1), so two runs named alike in
/// different directories never share one: `<name>-<the first 12 hex digits
/// of SHA-256(canonical parent / name)>.owner-private`
pub(super) fn default_owner_dir(base: &Path, out: &Path) -> Result<PathBuf, String> {
    use sha2::Digest as _;
    use std::os::unix::ffi::OsStrExt;
    let name = out.file_name().ok_or("--out: names no directory")?.to_string_lossy().to_string();
    let parent = out.parent().filter(|p| !p.as_os_str().is_empty()).unwrap_or(Path::new("."));
    let run = std::fs::canonicalize(parent).map_err(|e| format!("{}: {e}", parent.display()))?.join(&name);
    let key = sha2::Sha256::digest(run.as_os_str().as_bytes());
    Ok(base.join(format!("{name}-{}.owner-private", hex(&key[..6]))))
}

/// **review TR5-1: the directories THIS prove created**, removed again unless
/// the run completes. Each is claimed atomically (the create fails if it
/// exists) and listed only after this process created it, so the error path
/// never removes a directory a rival prove created, nor that prove's files.
struct Claimed(Vec<PathBuf>);

impl Claimed {
    fn dir(&mut self, d: &Path, private: bool, what: &str) -> Result<(), String> {
        let made = if private {
            use std::os::unix::fs::DirBuilderExt;
            std::fs::DirBuilder::new().mode(0o700).create(d)
        } else {
            std::fs::create_dir(d)
        };
        match made {
            Ok(()) => {
                self.0.push(d.to_path_buf());
                Ok(())
            }
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => Err(format!("{} exists; {what} must be new (review TR5-1: claimed atomically, never removed by a prove that did not create it)", d.display())),
            Err(e) => Err(format!("{}: {e}", d.display())),
        }
    }
    /// the run is complete: keep every claimed directory
    fn keep(mut self) {
        self.0.clear();
    }
}

impl Drop for Claimed {
    fn drop(&mut self) {
        for d in self.0.iter().rev() {
            let _ = std::fs::remove_dir_all(d);
        }
    }
}

/// test seam (review TR5-1): runs just before the owners' files are written,
/// with the owner and unverified-statement directories, so a test can play a
/// second prove racing for them
#[cfg(test)]
pub(super) mod hooks {
    use std::cell::RefCell;
    use std::path::Path;
    thread_local! {
        pub static BEFORE_OWNER_FILES: RefCell<Option<Box<dyn FnMut(&Path, &Path)>>> = RefCell::new(None);
    }
    pub fn before_owner_files(od: &Path, unverified: &Path) {
        BEFORE_OWNER_FILES.with(|h| {
            if let Some(f) = h.borrow_mut().as_mut() {
                f(od, unverified)
            }
        });
    }
}

fn prove_inner(f: &[(String, String)]) -> Result<(), String> {
    let t_all = Instant::now();
    let out = PathBuf::from(need(f, "--out")?);
    let (incomplete, unverified) = (sibling(&out, ".incomplete"), unverified_dir(&out));
    if std::fs::symlink_metadata(&out).is_ok() {
        return Err(format!("{} exists; a token run's directories must be new", out.display()));
    }
    let owners_dir = owner_dir_of(f, &out)?;
    // review TR5-1: every directory the run writes is claimed NOW,
    // atomically; on any refusal below, `claimed` removes exactly these
    let mut claimed = Claimed(Vec::new());
    claimed.dir(&incomplete, false, "a token run's directories")?;
    claimed.dir(&unverified, false, "a token run's directories")?;
    claimed.dir(&owners_dir, true, "a run's owner directory")?;
    let label = label_of(f)?;
    let seq = SeqIn::of(f)?;
    let t = Instant::now();
    let p = ExportPublic::load(Path::new(need(f, "--export")?))?;
    let sh = &p.sh;
    let files = table_files(f)?;
    let (tables, tm) = load_token_tables(&files, super::load::read_manifests(&files)?.v, sh.width)?;
    let load_s = t.elapsed().as_secs_f64();
    println!("{{\"event\":\"loaded\",\"export_variant\":{},\"run_profile\":{},\"blocks\":{},\"trained_statement_identity\":{},\"V\":{},\"seconds\":{load_s:.3}}}", js(&p.ex.variant), js(p.profile), p.layers.len(), js(&hex(&p.model.identity())), tm.v);
    // the prover-private inputs; every refusal of the honest pipeline fires
    // here, before any header (ruling H-1)
    let tokens = prompt_of(f, &seq, &p.ex)?;
    let tp = TokenProfile::new(sh, &tables, tm.bos, tm.norm, SelectorVariant::PublicRow, Tier::R1_MVP)?;
    let (wit_in, b_in, in_plane) = stage_in::honest_inputs(&tp, &tables, &tokens)?;
    let x_in0 = seq.load(&p.ex, sh, p.layers[0])?.0;
    if unpad(sh, &b_in) != x_in0 {
        return Err("token run: the embedding table does not embed the prompt to the export's x_in_L00".into());
    }
    let x_last = seq.load(&p.ex, sh, *p.layers.last().ok_or("token run: no layer")?)?.1;
    let mut row = vec![0i64; tp.d_pad];
    for (i, v) in x_last[(tp.tokens - 1) * tp.d..tp.tokens * tp.d].iter().enumerate() {
        row[i] = i64::from(*v);
    }
    let ov = stage_out::out_values(&tp, &tables, &row, true)?;
    let wout = stage_out::witness_from_values(&tp, &ov)?;
    let out_plane = stage_out::endpoint_plane(&tp, ov.tok as u64);
    let ctx = stack_context(&p.ex.variant, &p.layers, label)?;
    let (ins, outs) = endpoint_specs(sh, ctx, &tp)?;
    let (roots, owners) = seal_endpoints(&ins, &outs, &in_plane, &out_plane, &sh.hash_tag())?;
    let st = TokenRunStatement::new(RunShape::new(sh.clone(), p.layers.len(), p.profile)?, ctx, p.digests.clone(), &p.model, &tables, tm.bos, tm.norm, SelectorVariant::PublicRow, Tier::R1_MVP, roots)?;
    // the prover's claims, checked before anything is written (R7 / Q-2)
    let (backend, declines) = (backend_of_this_process(), crate::gpu::declines() as u64);
    check_prover_reported(backend, declines)?;
    // the run: segments into <out>.incomplete/ (claimed above), renamed only
    // after Ok; every refusal from here on leaves `claimed` to remove it
    let mut disk = run_sink::DirSink::create(&incomplete, p.layers.len() + 2)?;
    let mut src = CliSource { p: &p, seq: &seq, ids: Ids::new(sh)?, stage_in: Some((wit_in, b_in)), stage_out: Some(wout), x: x_in0, parity: 0, witness_s: 0.0 };
    let mut blocks = ExportTokenBlocks::new(&p);
    let t = Instant::now();
    let proved = prove_token_run_with(&st, &mut blocks, &tables, &mut src, owners, &mut |k, bytes| {
        let n = bytes.len();
        SegmentSink::accept(&mut disk, k, bytes)?;
        println!("{{\"event\":\"segment\",\"index\":{k},\"bytes\":{n},\"elapsed_seconds\":{:.3}}}", t.elapsed().as_secs_f64());
        Ok(())
    });
    let (stats, hand) = proved?;
    let prove_s = t.elapsed().as_secs_f64();
    if src.parity != p.layers.len() {
        return Err(format!("token run: parity was checked at {} of {} layers", src.parity, p.layers.len()));
    }
    let lens = st.segment_lens()?;
    if disk.lengths() != lens.as_slice() {
        return Err("token run: the written segments are not the counted lengths".into());
    }
    // review TR4-4: the owners' decommitments (0700 directory, 0600 files)
    // and the unverified statement are written BEFORE the run is renamed into
    // place, so a verifiable run never exists without its owners' answers;
    // both directories were claimed by this process at the start (TR5-1)
    #[cfg(test)]
    hooks::before_owner_files(&owners_dir, &unverified);
    write_private(&owners_dir.join("input.dec"), &hand.input.to_bytes())?;
    write_private(&owners_dir.join("output.dec"), &hand.output.to_bytes())?;
    write_new(&unverified.join("statement.json"), render(&p, &tm, &st, label, Writer::Unverified, backend, declines)?.as_bytes())?;
    write_new(&unverified.join("UNVERIFIED.txt"), UNVERIFIED_TEXT)?;
    std::fs::rename(&incomplete, &out).map_err(|e| format!("{} -> {}: {e}", incomplete.display(), out.display()))?;
    claimed.keep();
    println!(
        "{{\"event\":\"proved\",\"run\":{},\"owner_dir\":{},\"segments\":{},\"receipt_bytes\":{},\"prove_seconds\":{prove_s:.3},\"witness_seconds\":{:.3},\"block_load_seconds\":{:.3},\"parity_layers\":{},\"whole_run_floor_bits\":{},\"trained_statement_identity\":{},\"vmhwm_mib\":{:.0},\"total_seconds\":{:.3},\"backend\":{},\"statement\":\"UNVERIFIED until zk60_token_io verify publishes <run>/statement/\"}}",
        js(&out.display().to_string()),
        js(&owners_dir.display().to_string()),
        lens.len(),
        disk.total_bytes(),
        src.witness_s,
        blocks.load_s,
        src.parity,
        st.whole_run().floor_bits,
        js(&hex(&p.model.identity())),
        stats.hwm_mib.iter().cloned().fold(0.0, f64::max),
        t_all.elapsed().as_secs_f64(),
        js(backend)
    );
    Ok(())
}

/// the public inputs a verifier or an owner rebuilds: the export's public
/// side pinned by `--expect-statement` (the trained blocks, calibration and
/// source) and the tables
fn public_inputs(f: &[(String, String)]) -> Result<(ExportPublic, TokenTables, TableManifest), String> {
    let p = ExportPublic::load(Path::new(need(f, "--export")?))?;
    let want = unhex32(need(f, "--expect-statement")?)?;
    if p.model.identity() != want {
        return Err(format!("the export's trained statement identity is {}, not the pinned one", hex(&p.model.identity())));
    }
    let files = table_files(f)?;
    let (tables, tm) = load_token_tables(&files, super::load::read_manifests(&files)?.v, p.sh.width)?;
    Ok((p, tables, tm))
}

/// **review TR4-2: the token stages are pinned too.** The run's token
/// profile (V, BOS, the final norm's constants, the embedding and head
/// digests with the multipliers, the multiplier class, the derived window,
/// the variant, the tier: `TokenProfile::describe_under`) must be the
/// approved one, `--expect-token-profile`, refused by name otherwise
fn token_profile_is_pinned(f: &[(String, String)], st: &TokenRunStatement) -> Result<(), String> {
    let want = unhex32(need(f, "--expect-token-profile")?)?;
    let got = st.tp.digest_under(st.profile());
    if got != want {
        return Err(format!("the run's token profile digest is {} (its tables, BOS and final norm), not the pinned approved one (review TR4-2)", hex(&got)));
    }
    Ok(())
}

/// a run directory CHECKED IN FULL against public inputs: the statement
/// found, rebuilt, pinned (blocks and token stages), canonical, and every
/// segment re-read and verified under the policy
struct Checked {
    p: ExportPublic,
    tm: TableManifest,
    st: TokenRunStatement,
    found: Found,
    mode: Writer,
    seen: Vec<(u64, String)>,
    verify_s: f64,
    load_s: f64,
}

/// **verify's check path** (shared by `verify`, `owner` and `input-owner`:
/// review TR4-1). `published_only`: the run must carry `<run>/statement/`
/// (a verifier's), whose `segments.json` must then be the hashes of the bytes
/// verified here, before anything is printed or published.
fn check_run(f: &[(String, String)], published_only: bool) -> Result<(Checked, TokenTables), String> {
    let export = PathBuf::from(need(f, "--export")?);
    // privacy review P-5: a verifier's export holds the public files only
    refuse_prover_private_entries(&export)?;
    let art = PathBuf::from(need(f, "--artifact")?);
    let min_bits: u32 = flag(f, "--min-bits").unwrap_or("95").parse().map_err(|_| "--min-bits: an integer")?;
    let label = label_of(f)?;
    let (p, tables, tm) = public_inputs(f)?;
    let published = art.join(run_sink::STATEMENT_DIR);
    let unverified = unverified_dir(&art);
    let (mode, sdir) = if std::fs::symlink_metadata(&published).is_ok() {
        check_statement_dir(&published, &["statement.json", "segments.json"])?;
        (Writer::FreshVerify, published.clone())
    } else if published_only {
        return Err(format!("{}: no statement a verifier published; run `zk60_token_io verify` first", published.display()));
    } else {
        check_statement_dir(&unverified, &["statement.json", "UNVERIFIED.txt"])?;
        (Writer::Unverified, unverified.clone())
    };
    let sbytes = read_regular_file_bounded(&sdir.join("statement.json"), MAX_STATEMENT_BYTES, false)?;
    let found = found_statement(&sbytes)?;
    if found.writer != mode {
        return Err(format!("{}: written by {:?}, which this directory may not hold", sdir.display(), found.writer));
    }
    if found.label != label {
        return Err("the statement's context label is not the one this verifier was given".into());
    }
    let st = statement_of(&p, &tables, &tm, label, found.context, found.roots)?;
    token_profile_is_pinned(f, &st)?;
    if render(&p, &tm, &st, label, mode, &found.backend, found.declines)?.as_bytes() != sbytes.as_slice() {
        return Err(format!("{}: not byte for byte the canonical statement of this run (review r5_A)", sdir.join("statement.json").display()));
    }
    // the segments, each exactly its counted length, hashed from the bytes verified
    let lens = st.segment_lens()?;
    let paths = run_sink::segment_paths(&art, lens.len())?;
    let mut segs = Vec::with_capacity(lens.len());
    let mut seen: Vec<(u64, String)> = Vec::with_capacity(lens.len());
    for (path, n) in paths.iter().zip(lens.iter()) {
        let b = read_regular_file_bounded(path, *n as u64, true)?;
        seen.push((b.len() as u64, run_sink::digest_hex(&b)));
        segs.push(b);
    }
    let mut blocks = ExportTokenBlocks::new(&p);
    let t = Instant::now();
    verify_token_run_with(&st, &mut blocks, &tables, &segs, VerifierPolicy { min_whole_run_bits: min_bits })?;
    let verify_s = t.elapsed().as_secs_f64();
    let load_s = blocks.load_s;
    drop(blocks);
    drop(segs);
    if mode == Writer::FreshVerify {
        let found_segs = read_regular_file_bounded(&published.join("segments.json"), MAX_STATEMENT_BYTES, false)?;
        if found_segs != render_segments_json(&seen).as_bytes() {
            return Err(format!("{}: not the hashes of the bytes this verifier verified (review r5_A)", published.join("segments.json").display()));
        }
    }
    Ok((Checked { p, tm, st, found, mode, seen, verify_s, load_s }, tables))
}

/// `zk60_token_io verify ...` (see the module text)
pub fn token_verify_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--emb", "--head", "--artifact", "--expect-statement", "--expect-token-profile", "--label", "--min-bits"], &[]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_token_io verify: {e}");
            return 2;
        }
    };
    match verify_inner(&f) {
        Ok(()) => 0,
        Err(e) => refused("verify", &e),
    }
}

fn verify_inner(f: &[(String, String)]) -> Result<(), String> {
    let t_all = Instant::now();
    let art = PathBuf::from(need(f, "--artifact")?);
    // review N-r6-b: a killed verifier's writing directory
    clear_stale_writing_dirs(&art)?;
    let (c, _tables) = check_run(f, false)?;
    let label = label_of(f)?;
    let min_bits: u32 = flag(f, "--min-bits").unwrap_or("95").parse().map_err(|_| "--min-bits: an integer")?;
    let published = art.join(run_sink::STATEMENT_DIR);
    match c.mode {
        Writer::Unverified => {
            let unverified = unverified_dir(&art);
            let stmt = render(&c.p, &c.tm, &c.st, label, Writer::FreshVerify, &c.found.backend, c.found.declines)?;
            let segments_json = render_segments_json(&c.seen);
            let target = publish_statement_dir(&art, &[("statement.json", stmt.as_bytes()), ("segments.json", segments_json.as_bytes())])?;
            check_statement_dir(&unverified, &["statement.json", "UNVERIFIED.txt"])?;
            std::fs::remove_dir_all(&unverified).map_err(|e| format!("{}: {e}", unverified.display()))?;
            println!("{{\"event\":\"verified\",\"statement\":{},\"published_by\":\"this verifier\",\"verify_seconds\":{:.3},\"block_load_seconds\":{:.3},\"min_bits\":{min_bits},\"whole_run_floor_bits\":{},\"total_seconds\":{:.3}}}", js(&target.display().to_string()), c.verify_s, c.load_s, c.st.whole_run().floor_bits, t_all.elapsed().as_secs_f64());
        }
        Writer::FreshVerify => {
            println!("{{\"event\":\"statement-checked\",\"statement\":{},\"verify_seconds\":{:.3},\"min_bits\":{min_bits},\"total_seconds\":{:.3}}}", js(&published.display().to_string()), c.verify_s, t_all.elapsed().as_secs_f64());
        }
    }
    Ok(())
}

/// `zk60_token_io owner ...` (see the module text)
pub fn token_owner_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--emb", "--head", "--artifact", "--expect-statement", "--expect-token-profile", "--decommitment", "--label", "--min-bits"], &[]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_token_io owner: {e}");
            return 2;
        }
    };
    match owner_inner(&f) {
        Ok(()) => 0,
        Err(e) => refused("owner", &e),
    }
}

/// **the OUTPUT owner's check (review TR4-1):** verify's full re-check of the
/// PUBLISHED statement against the segments first (pins, canonical
/// statement, every segment verified, `segments.json` = the verified bytes'
/// hashes), then the decommitment against the verified output root; only
/// then is the token printed
fn owner_inner(f: &[(String, String)]) -> Result<(), String> {
    let t_all = Instant::now();
    let (c, _tables) = check_run(f, true)?;
    let dec = Decommitment::from_bytes(&read_regular_file_bounded(Path::new(need(f, "--decommitment")?), MAX_DECOMMITMENT_BYTES, false)?)?;
    let tok = owner_check_output(&c.st, &dec)?;
    println!("{{\"event\":\"next-token\",\"token\":{tok},\"checked_against\":\"the published statement, re-verified against every segment in this process\",\"verify_seconds\":{:.3},\"total_seconds\":{:.3}}}", c.verify_s, t_all.elapsed().as_secs_f64());
    Ok(())
}

/// `zk60_token_io input-owner ...`: the INPUT owner's check (review TR4-4)
pub fn token_input_owner_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--emb", "--head", "--artifact", "--expect-statement", "--expect-token-profile", "--decommitment", "--prompt", "--label", "--min-bits"], &[]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_token_io input-owner: {e}");
            return 2;
        }
    };
    match input_owner_inner(&f) {
        Ok(()) => 0,
        Err(e) => refused("input-owner", &e),
    }
}

/// verify's full re-check, then `owner_check_input`: the decommitment
/// rebuilds the verified input root, BOS at 0, every id below V, zero pads,
/// and the sealed plane is the owner's own `--prompt`
fn input_owner_inner(f: &[(String, String)]) -> Result<(), String> {
    let (c, _tables) = check_run(f, true)?;
    let prompt: Vec<u64> = need(f, "--prompt")?.split(',').map(|x| x.trim().parse::<u64>().map_err(|_| "--prompt: a comma-separated list of token ids".to_string())).collect::<Result<_, _>>()?;
    let dec = Decommitment::from_bytes(&read_regular_file_bounded(Path::new(need(f, "--decommitment")?), MAX_DECOMMITMENT_BYTES, false)?)?;
    owner_check_input(&c.st, &dec, &prompt)?;
    println!("{{\"event\":\"input-checked\",\"prompt_tokens\":{},\"checked_against\":\"the published statement, re-verified against every segment in this process\"}}", prompt.len());
    Ok(())
}

/// `zk60_token_io profile --export DIR --emb DIR --head DIR`: the two pins
/// of an APPROVED export and table set (review TR4-2) — the trained-model
/// statement's identity and the token profile's digest — for a verifier to
/// record once and pass to `verify` / `owner` / `input-owner`
pub fn token_profile_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--emb", "--head"], &[]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_token_io profile: {e}");
            return 2;
        }
    };
    match profile_inner(&f) {
        Ok(()) => 0,
        Err(e) => refused("profile", &e),
    }
}

fn profile_inner(f: &[(String, String)]) -> Result<(), String> {
    let p = ExportPublic::load(Path::new(need(f, "--export")?))?;
    let files = table_files(f)?;
    let (tables, tm) = load_token_tables(&files, super::load::read_manifests(&files)?.v, p.sh.width)?;
    let tp = TokenProfile::new(&p.sh, &tables, tm.bos, tm.norm, SelectorVariant::PublicRow, Tier::R1_MVP)?;
    println!(
        "{{\"event\":\"profile\",\"run_profile\":{},\"export_variant\":{},\"trained_statement_identity\":{},\"token_profile_digest\":{},\"V\":{},\"bos\":{},\"final_norm\":{{\"g0\":{},\"cn\":{},\"tn\":{},\"ceps\":{}}},\"tables\":{{\"embedding_int16_sha256\":{},\"head_int8_perrow_sha256\":{},\"head_mult12_sha256\":{}}}}}",
        js(p.profile),
        js(&p.ex.variant),
        js(&hex(&p.model.identity())),
        js(&hex(&tp.digest_under(p.profile))),
        tm.v,
        tm.bos,
        tm.norm.g0,
        tm.norm.cn,
        tm.norm.tn,
        tm.norm.ceps,
        js(&tm.emb_sha256),
        js(&tm.head_sha256),
        js(&tm.mult_sha256)
    );
    Ok(())
}
