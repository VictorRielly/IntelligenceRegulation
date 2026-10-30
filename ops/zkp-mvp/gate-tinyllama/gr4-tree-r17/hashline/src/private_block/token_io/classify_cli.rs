//! **THE CLASSIFIER CLI** (round 12, rung R-C1; round 13, rung R-C2; round 14,
//! rung R-C3: short items and the library binding; round 15: the label's
//! whole-post check; DESIGN_CLASSIFIER v2.5):
//!
//! ```text
//! zk60_classify prove        --export DIR --tables DIR --policy ID --content-file FILE|-
//!                            (--seq ID | --seq-dir DIR) --out DIR [--owner-dir DIR] [--label L]
//! zk60_classify verify       --export DIR --tables DIR --policy ID --artifact DIR
//!                            --expect-statement HEX [--label L] [--min-bits N]
//! zk60_classify input-owner  (verify's arguments) --decommitment FILE --content-file FILE|-
//! zk60_classify label        --export DIR --tables DIR --policy ID --runs DIR,DIR,...
//!                            --expect-statement HEX --expect-total N [--label L] [--min-bits N]
//! ```
//!
//! * **D41 (DESIGN v2.2 §13), chunks:** `--content-file` holds the WHOLE
//!   content's ids (N of them); `prove --chunk J` (default 0) proves chunk J
//!   of the profile's public split (size `T - P0 - S`, the registered
//!   overlap, the last chunk end-aligned), sliced by the prover itself. The
//!   statement names the chunk (index, count, range, N, size, overlap), the
//!   transcript absorbs it, and `verify` re-derives the range from (N, J,
//!   the plan). `input-owner` checks the slice of the whole content. `label`
//!   verifies every chunk run of one item and prints the category's label:
//!   the OR of the chunk verdicts, FAIL-CLOSED (a missing, repeated or
//!   refused chunk, or chunks naming different public fields, give
//!   `flagged`).
//! * **Round 14 (DESIGN v2.4 §15), short items:** a content of N ids with
//!   `1 <= N < T - P0 - S` is ONE chunk of its true length `[0, N)`: the item
//!   is the prefix, the content, the suffix, then the policy's PUBLIC pad id
//!   up to T (pinned by the template clause), and stage OUT-C reads the public
//!   verdict row `P0 + N + S - 1`. The prover's activations (`--seq` /
//!   `--seq-dir`) are those of that padded item. N is public (D45(1)).
//! * **Round 15 (REVIEW_R14 N-r14-1), the label's whole-post check:**
//!   `label --expect-total N` is REQUIRED. N is the POST's own token count
//!   (the caller's, from the policy's pinned tokenizer; public by D45(1)),
//!   never a number taken from the proofs. The label is refused (fail-closed)
//!   unless every chunk run's `content_total` is N and their D41 ranges are
//!   exactly the split of `[0, N)`: a proof set of only the first k < N ids
//!   of a post (since round 14 a short item of any k >= 1 is one chunk) is
//!   refused, and so is a label call without the post's count.
//!
//! * `--tables DIR` holds the classifier's public tables: `token_io.json` +
//!   `embedding_int16.bin` (the token run's embedding format) and
//!   `classifier.json` + `margin_int16.bin` (the int16 margin vector `w_Delta`,
//!   `d` words LE; its SHA-256, BOS and the final norm in `classifier.json`).
//! * The content NEVER travels on the command line (PR4-17): `--content-file`
//!   (mode 0600) or `-` (stdin); `--content` is refused (exit 2). The item's
//!   ids are the policy's template prefix, the content, the template suffix
//!   (B-1's split, tokenised by the caller with the policy's canonical
//!   tokenizer, B-2).
//! * `prove` runs the token CLI's sealing pass first (the builder's own chain
//!   for every block, int16, bit-exact parity against the export's `seq_*`,
//!   CS-3), computes the margin and the verdict from the builder's last plane,
//!   seals the ONE input endpoint, proves, and writes `<out>/` (built as
//!   `<out>.incomplete/`), an UNVERIFIED statement and the input owner's
//!   decommitment (`input.dec`, 0600, in the owner directory). The verdict is
//!   PUBLIC: `flagged` (the model answered "yes" with margin above c) or
//!   `not-flagged`; both are normal results (D37 revised).
//! * **R-C2 (round 13):** prove and verify RE-DERIVE the margin row `w` and the
//!   embedding's digest from the pinned tied tensor (the registered policy's
//!   yes / no ids and public scale; `classify_tied`), and BOS / the final norm
//!   from the export's `profile.json.token_io_parameters`; a table file that
//!   disagrees is refused, never trusted. `--min-bits` below the profile's
//!   floor (D27: 93 only at the development rung, else 95) is refused.
//! * `verify` re-derives EVERYTHING from its own inputs (B-3: the margin
//!   vector from the pinned tensor, the yes / no ids, c and the template from the
//!   pre-registered `--policy`, the model from `--export` pinned by
//!   `--expect-statement`), re-renders the canonical statement and refuses
//!   unless the found statement is that text byte for byte, BEFORE any segment
//!   is read; then verifies every segment and writes `<artifact>/statement/`.
//! * **Fail-closed (ruling B-4 = D45(4), Victor 2026-10-29):** every refusal prints
//!   `{"event":"app-outcome","outcome":"flagged",...}`: an item without an
//!   accepted proof is handled as flagged.
//!
//! * **Round 16 (native R13, REVIEW_R13 §10):** the R13 Shieldstral T128 /
//!   T256 LOW + h24 exports load under their classifier run profiles; the
//!   sealing chain and the prover build each block with `build_for_block` at
//!   its layer record's stage shape (`LayerRecord::shape_at`: its own
//!   calibration and gate denominator); the verifier checks every block
//!   against its own stage shape before its header; the loader's one
//!   checkpoint pass also derives the margin row (N-r13-5).
//!
//! SCOPE: the development rung and the R13 Shieldstral classifier profiles;
//! public-row variant (n public, D45(1)); NO privacy acceptance. JSON lines on stdout; exit 0 = done, 1 = refused, 2 =
//! bad arguments. The frozen next-token CLI (`zk60_token_io`) is untouched.

use super::classify::*;
use super::classify_run::*;
use super::cli::{leftover_refusal, owner_dir_at, read_prompt_file};
use super::load::{read_exact_streamed, ExportPublic, ExportTokenBlocks, MAX_MANIFEST_BYTES};
use super::stage_in::StageInWitness;
use super::stage_out_c::StageOutCWitness;
use super::run::{TokenBlocks, VerifierPolicy};
use super::*;
use super::super::layout::{Ids, A_X2};
use super::super::run::{read_regular_file_bounded, RunShape, RUN_PROFILE_CLASSIFY_RUNG_TC};
use super::super::run_sink::{self, SegmentSink};
use super::super::trained_block::{check_statement_dir, clear_stale_writing_dirs, flag, flags, js, need, parse_json, publish_statement_dir, refuse_prover_private_entries, stack_context, unhex32, write_new, TrainedExport, J};
use super::super::witness::Witness;
use super::super::BlockPublic;
use std::path::{Path, PathBuf};
use std::time::Instant;

/// the classifier run's context label (a deployment constant, ruling C-R4's rule)
pub(crate) const CLASSIFY_LABELS: [&str; 1] = ["zk60-classify-verdict"];
const MAX_STATEMENT_BYTES: u64 = 1 << 20;
const MAX_DECOMMITMENT_BYTES: u64 = 16 << 20;
/// ROUND 14: `/3` adds `item_length`, `pad_id`, `pad_positions` and
/// `verdict_row` (short items) and the profile text's new terms; a `/2`
/// statement is refused (its profile digest is not this build's)
pub(crate) const CLASSIFY_STATEMENT_SCHEMA: &str = "zk60-classify-run/3";
const CONTENT_ON_COMMAND_LINE: &str = "--content is not accepted: the hidden content never goes on the command line (it shows in the process list and shell history); give --content-file FILE (mode 0600) or --content-file - (standard input) (PR4-17)";
const FAIL_CLOSED_LINE: &str = "{\"event\":\"app-outcome\",\"outcome\":\"flagged\",\"why\":\"no accepted proof: fail-closed (ruling D45(4), Victor 2026-10-29)\"}";

fn refused(what: &str, e: &str) -> i32 {
    println!("{{\"event\":\"refused\",\"command\":{},\"error\":{}}}", js(what), js(e));
    println!("{FAIL_CLOSED_LINE}");
    1
}

fn label_of<'a>(f: &'a [(String, String)]) -> Result<&'a str, String> {
    let label = flag(f, "--label").unwrap_or(CLASSIFY_LABELS[0]);
    if !CLASSIFY_LABELS.contains(&label) {
        return Err(format!("--label: the classifier run's context label is a deployment constant; this build admits {CLASSIFY_LABELS:?}, not {label:?}"));
    }
    Ok(label)
}

fn sibling(out: &Path, suffix: &str) -> PathBuf {
    let mut s = out.as_os_str().to_owned();
    s.push(suffix);
    PathBuf::from(s)
}

fn write_private(path: &Path, bytes: &[u8]) -> Result<(), String> {
    use std::io::Write;
    use std::os::unix::fs::OpenOptionsExt;
    let mut f = std::fs::OpenOptions::new().write(true).create_new(true).mode(0o600).open(path).map_err(|e| format!("{}: {e}", path.display()))?;
    f.write_all(bytes).and_then(|_| f.sync_all()).map_err(|e| format!("{}: {e}", path.display()))
}

/// the directories THIS prove created, removed (and said so) unless it completes
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
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => Err(leftover_refusal(d, what)),
            Err(e) => Err(format!("{}: {e}", d.display())),
        }
    }
    fn keep(mut self) {
        self.0.clear();
    }
}

impl Drop for Claimed {
    fn drop(&mut self) {
        for d in self.0.iter().rev() {
            match std::fs::remove_dir_all(d) {
                Ok(()) => println!("{{\"event\":\"removed\",\"path\":{},\"why\":\"the prove was refused; this directory was created by this prove and is removed with everything in it\"}}", js(&d.display().to_string())),
                Err(e) => {
                    let line = format!("{{\"event\":\"REMOVAL-FAILED\",\"path\":{},\"error\":{},\"what_to_do\":\"remove it by hand (rm -r) before anything syncs its parent\"}}", js(&d.display().to_string()), js(&e.to_string()));
                    println!("{line}");
                    eprintln!("{line}");
                }
            }
        }
    }
}

/// the export's hidden activations for parity (the token CLI's `SeqIn`)
enum SeqIn {
    InExport(String),
    Dir(PathBuf),
}

impl SeqIn {
    fn of(f: &[(String, String)]) -> Result<SeqIn, String> {
        match (flag(f, "--seq"), flag(f, "--seq-dir")) {
            (Some(s), None) => Ok(SeqIn::InExport(s.to_string())),
            (None, Some(d)) => Ok(SeqIn::Dir(PathBuf::from(d))),
            _ => Err("exactly one of --seq ID (the export's seq_<ID>/) or --seq-dir DIR is required".into()),
        }
    }
    fn load(&self, ex: &TrainedExport, sh: &Shape, layer: u32) -> Result<(Vec<i16>, Vec<i16>), String> {
        match self {
            SeqIn::InExport(s) => ex.load_seq(sh, s, layer),
            SeqIn::Dir(d) => TrainedExport::load_seq_dir(d, sh, layer),
        }
    }
}

fn unpad(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| plane[t * sh.d_pad + i]).collect()
}

fn pad_plane(sh: &Shape, x: &[i16]) -> Vec<i16> {
    let mut p = vec![0i16; sh.t_pad * sh.d_pad];
    for t in 0..sh.tokens {
        p[t * sh.d_pad..t * sh.d_pad + sh.width].copy_from_slice(&x[t * sh.width..(t + 1) * sh.width]);
    }
    p
}

/// the classifier run profile of an export's block shape
pub(crate) fn classify_run_profile_of(sh: &Shape) -> Result<&'static str, String> {
    use super::super::shape::TRAINED_CALIB_RUNG_PROFILE;
    match sh.profile {
        p if p == TRAINED_CALIB_RUNG_PROFILE => Ok(RUN_PROFILE_CLASSIFY_RUNG_TC),
        // ROUND 16: the native R13 Shieldstral LOW + h24 block profiles (T128,
        // T256; non-DD), each its own classifier run profile (D17)
        p => super::super::run::accuracy_classify_run_profile(p).ok_or_else(|| format!("classifier: no classifier run profile is registered for the block profile {p} (round 16 registers the R13 Shieldstral T128 / T256 non-DD profiles and the development rung)")),
    }
}

/// the export's public side (the digest pass) with the trained statement
/// under the CLASSIFIER run profile (round 16: built under it directly, with
/// the export's tied record at a tied model; the rung's statement is the one
/// earlier rounds rebuilt)
pub(crate) fn load_export(path: &Path) -> Result<ExportPublic, String> {
    ExportPublic::load_with(path, classify_run_profile_of)
}

/// D41: the deployment profile's chunk plan for a policy (size `T - P0 - S`)
fn chunk_plan(sh: &Shape, policy: &Policy, run_profile: &str) -> Result<ChunkPlan, String> {
    let size = sh.tokens.checked_sub(policy.prefix.len() + policy.suffix.len()).filter(|n| *n > 0).ok_or("classifier: the policy's template leaves no content position")?;
    Ok(ChunkPlan { size, overlap: chunk_overlap_of(run_profile)? })
}

fn manifest(path: &Path) -> Result<J, String> {
    let b = read_regular_file_bounded(path, MAX_MANIFEST_BYTES, false)?;
    parse_json(&b).map_err(|e| format!("{}: {e}", path.display()))
}

fn sha_hex(s: &str, path: &Path, what: &str) -> Result<String, String> {
    if s.len() != 64 || !s.bytes().all(|c| c.is_ascii_hexdigit()) {
        return Err(format!("{}: {what} is not a 64-hex-digit SHA-256", path.display()));
    }
    Ok(s.to_ascii_lowercase())
}

/// **R-C1'S TABLES READER** (TEST BUILDS ONLY since round 14, REVIEW_R13
/// N-r13-10: no production path trusts the files again): the embedding
/// (token_io.json), the margin vector, BOS and the final norm
/// (classifier.json), each binary table read with its length checked first
/// and its SHA-256 streamed and compared with its own manifest
#[cfg(test)]
pub(crate) fn load_classifier_tables(dir: &Path, d: usize) -> Result<(ClassifierTables, u64, FinalNorm), String> {
    read_classifier_files(dir, d).map(|(t, bos, norm, _)| (t, bos, norm))
}

/// the R-C1 file reader, also returning the embedding file's SHA-256 (the
/// streamed digest, equal to its manifest's): R-C2's
/// [`super::classify_tied::load_tied_classifier_tables`] compares it, the
/// margin row, BOS and the final norm with the pinned tensor's re-derivation
pub(crate) fn read_classifier_files(dir: &Path, d: usize) -> Result<(ClassifierTables, u64, FinalNorm, [u8; 32]), String> {
    let tp = dir.join("token_io.json");
    let cp = dir.join("classifier.json");
    let tio = manifest(&tp)?;
    let cj = manifest(&cp)?;
    let et = tio.get("embedding_table").map_err(|e| format!("{}: {e}", tp.display()))?;
    let emb_sha = sha_hex(et.get("sha256").and_then(J::str).map_err(|e| format!("{}: {e}", tp.display()))?, &tp, "embedding_table.sha256")?;
    let shape = et.get("shape").and_then(J::arr).map_err(|e| format!("{}: embedding_table.shape: {e}", tp.display()))?;
    let uint = |j: &J, what: &str| -> Result<usize, String> { j.i64().ok().and_then(|v| usize::try_from(v).ok()).ok_or_else(|| format!("{what}: not a nonnegative integer")) };
    if shape.len() != 2 {
        return Err(format!("{}: embedding_table.shape is not [V, d]", tp.display()));
    }
    let (v, ed) = (uint(&shape[0], "embedding_table.shape[0]")?, uint(&shape[1], "embedding_table.shape[1]")?);
    if cj.get("schema").and_then(J::str).map_err(|e| format!("{}: {e}", cp.display()))? != "zk60-classifier-tables/1" {
        return Err(format!("{}: not schema zk60-classifier-tables/1", cp.display()));
    }
    let mv = cj.get("margin_vector").map_err(|e| format!("{}: {e}", cp.display()))?;
    let w_sha = sha_hex(mv.get("sha256").and_then(J::str).map_err(|e| format!("{}: margin_vector: {e}", cp.display()))?, &cp, "margin_vector.sha256")?;
    let wd = uint(mv.get("d").map_err(|e| format!("{}: margin_vector: {e}", cp.display()))?, "margin_vector.d")?;
    if ed != d || wd != d {
        return Err(format!("classifier tables: the embedding is {ed} wide and the margin vector {wd}; the block width is {d}"));
    }
    let bos = uint(cj.get("bos").map_err(|e| format!("{}: {e}", cp.display()))?, "bos")? as u64;
    if let Some(b) = tio.opt("bos") {
        if uint(b, "token_io.json bos")? as u64 != bos {
            return Err(format!("{} and {} declare different BOS ids", tp.display(), cp.display()));
        }
    }
    let fnm = cj.get("final_norm").map_err(|e| format!("{}: {e}", cp.display()))?;
    let int = |k: &str| fnm.get(k).and_then(J::i64).map_err(|e| format!("{}: final_norm.{k}: {e}", cp.display()));
    let tn = u32::try_from(int("tn")?).map_err(|_| format!("{}: final_norm.tn is out of range", cp.display()))?;
    let norm = FinalNorm { g0: int("g0")?, cn: int("cn")?, tn, ceps: int("ceps")? };
    let n = v.checked_mul(d).ok_or("classifier tables: V x d overflows")?;
    let mut emb: Vec<i16> = Vec::with_capacity(n);
    read_exact_streamed(&dir.join("embedding_int16.bin"), 2 * n, &emb_sha, |b| emb.extend(b.chunks_exact(2).map(|c| i16::from_le_bytes([c[0], c[1]]))))?;
    let mut w: Vec<i16> = Vec::with_capacity(d);
    read_exact_streamed(&dir.join("margin_int16.bin"), 2 * d, &w_sha, |b| w.extend(b.chunks_exact(2).map(|c| i16::from_le_bytes([c[0], c[1]]))))?;
    Ok((ClassifierTables::new(v, d, emb, w)?, bos, norm, unhex32(&emb_sha)?))
}

/// the content ids: a 0600 file or stdin (never the command line)
fn content_of(f: &[(String, String)]) -> Result<Vec<u64>, String> {
    read_prompt_file(need(f, "--content-file")?).map_err(|e| e.replace("--prompt-file", "--content-file"))
}

fn verdict_text(b: u8) -> &'static str {
    if b == 1 {
        "flagged"
    } else {
        "not-flagged"
    }
}

fn ids_json(v: &[u64]) -> String {
    format!("[{}]", v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(", "))
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum Writer {
    Prover,
    Verifier,
}

impl Writer {
    fn text(self) -> &'static str {
        match self {
            Writer::Prover => "zk60_classify prove, WITHOUT a verification (unverified)",
            Writer::Verifier => "zk60_classify verify, after its fresh-process verification of the run directory, from its own data",
        }
    }
}

/// THE STATEMENT a classifier run directory carries, rendered from the
/// writer's own data (the verifier re-renders and compares: B-3)
fn render(p: &ExportPublic, st: &ClassifyRunStatement, label: &str, writer: Writer) -> Result<String, String> {
    let cp = &st.cp;
    Ok(format!(
        "{{\n \"schema\": {},\n \"scope\": {},\n \"statement_written_by\": {},\n \"run_profile\": {},\n \"block_profile\": {},\n \"blocks\": {},\n \"export_variant\": {},\n \"trained_statement_identity\": {},\n \"policy\": {},\n \"verdict\": {},\n \"verdict_bit\": {},\n \"threshold_c\": {},\n \"yes_id\": {},\n \"no_id\": {},\n \"template_prefix_ids\": {},\n \"template_suffix_ids\": {},\n \"content_length_n\": {},\n \"chunk\": {{\"index\": {}, \"count\": {}, \"range\": [{}, {}], \"content_total\": {}, \"chunk_size\": {}, \"overlap\": {}, \"split\": \"end-aligned (DESIGN v2.2 13.1); a short content is one chunk of its length (v2.4 15)\"}},\n \"T\": {},\n \"item_length\": {},\n \"pad_id\": {},\n \"pad_positions\": {},\n \"verdict_row\": {},\n \"control_ids_below\": {},\n \"tokenizer\": {},\n \"margin_vector_digest\": {},\n \"margin_scale\": {:e},\n \"tied_source\": {},\n \"embedding_digest\": {},\n \"bos\": {},\n \"final_norm\": {{\"g0\": {}, \"cn\": {}, \"tn\": {}, \"ceps\": {}}},\n \"classifier_profile_digest\": {},\n \"rulings\": {},\n \"context_label\": {},\n \"context\": {},\n \"input_token_endpoint_root\": {},\n \"whole_run_floor_bits\": {},\n \"parameter_line\": {}\n}}\n",
        js(CLASSIFY_STATEMENT_SCHEMA),
        js("a classifier proof (DESIGN_CLASSIFIER v2.4, rung R-C3): the approved integer model's verdict on hidden content under a pre-registered policy; the margin row and the embedding re-derived from the pinned tied tensor; one external endpoint; the verdict bit and the content length are public (D45); a short item's trailing positions hold the public pad id; NOT a privacy acceptance"),
        js(writer.text()),
        js(st.profile()),
        js(st.sh().profile),
        st.l(),
        js(&p.ex.variant),
        js(&hex(&st.model_identity())),
        js(&cp.policy.id),
        js(verdict_text(st.verdict())),
        st.verdict(),
        cp.policy.c,
        cp.policy.yes,
        cp.policy.no,
        ids_json(&cp.policy.prefix),
        ids_json(&cp.policy.suffix),
        cp.n,
        st.chunk().index,
        st.chunk().count,
        st.chunk().a,
        st.chunk().b,
        st.chunk().total,
        st.chunk().size,
        st.chunk().overlap,
        cp.tokens,
        cp.item_len(),
        cp.policy.pad,
        cp.pad_positions(),
        cp.verdict_row(),
        cp.policy.num_special,
        js(&cp.policy.tokenizer),
        js(&hex(&cp.w_digest)),
        cp.policy.margin_scale(),
        js(&super::classify_tied::TiedSource::of_run_profile(st.profile())?.describe()),
        js(&hex(&cp.emb_digest)),
        cp.bos,
        cp.norm.g0,
        cp.norm.cn,
        cp.norm.tn,
        cp.norm.ceps,
        js(&hex(&cp.digest_under(st.profile()))),
        js(&rulings_text()),
        js(label),
        js(&hex(&st.context())),
        js(&hex(&st.in_root())),
        st.whole_run().floor_bits,
        js(&st.parameter_line()?)
    ))
}

/// what a found statement names that the verifier cannot re-derive: the
/// verdict, the content length, the context and the root (all checked by
/// the byte-for-byte re-render)
struct Found {
    verdict: u8,
    n: usize,
    chunk_index: usize,
    chunk_total: usize,
    policy: String,
    context: Digest,
    root: Digest,
}

fn found_statement(bytes: &[u8]) -> Result<Found, String> {
    let j = parse_json(bytes).map_err(|e| format!("statement.json: {e}"))?;
    let s = |k: &str| j.get(k).and_then(J::str).map_err(|e| format!("statement.json: {k}: {e}"));
    let i = |k: &str| j.get(k).and_then(J::i64).map_err(|e| format!("statement.json: {k}: {e}"));
    if s("schema")? != CLASSIFY_STATEMENT_SCHEMA {
        return Err(format!("statement.json: not schema {CLASSIFY_STATEMENT_SCHEMA}"));
    }
    let verdict = u8::try_from(i("verdict_bit")?).ok().filter(|b| *b <= 1).ok_or("statement.json: verdict_bit is not 0 or 1")?;
    let n = usize::try_from(i("content_length_n")?).map_err(|_| "statement.json: content_length_n is negative")?;
    let ch = j.get("chunk").map_err(|e| format!("statement.json: chunk: {e}"))?;
    let cu = |k: &str| ch.get(k).and_then(J::i64).map_err(|e| format!("statement.json: chunk.{k}: {e}")).and_then(|v| usize::try_from(v).map_err(|_| format!("statement.json: chunk.{k} is negative")));
    let (chunk_index, chunk_total) = (cu("index")?, cu("content_total")?);
    Ok(Found { verdict, n, chunk_index, chunk_total, policy: s("policy")?.to_string(), context: unhex32(s("context")?)?, root: unhex32(s("input_token_endpoint_root")?)? })
}

/// the CLI's source: the stage witnesses from the sealing pass, the block
/// witnesses rebuilt from the builder's chain (parity re-checked)
struct CliSource<'a> {
    p: &'a ExportPublic,
    seq: &'a SeqIn,
    ids: Ids,
    stage_in: Option<(StageInWitness, Vec<i16>)>,
    stage_out: Option<StageOutCWitness>,
    x: Vec<i16>,
    parity: usize,
    /// the CLI's own sealing pass ([`seal_chain`]) has run the builder, the
    /// int16 check, parity and CS-3 on every block before any header
    sealed: bool,
}

impl ClassifyRunSource for CliSource<'_> {
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String> {
        self.stage_in.take().ok_or_else(|| "classifier run: stage IN-C asked twice".to_string())
    }
    fn witness(&mut self, k: usize, blk: &BlockPublic, ssh: &Shape) -> Result<Witness, String> {
        let sh = &self.p.sh;
        // ROUND 16: the block's own builder (R13 accuracy data at the stage's G)
        let w = super::super::witness::build_for_block(ssh, blk, &self.x)?;
        // ROUND 16: the stage shape's own plane ids (an R13 stage is the run
        // seed at its layer's gate denominator; the plane list is the same)
        let ids = Ids::new(ssh)?;
        if ids.at(A_X2) != self.ids.at(A_X2) {
            return Err(format!("classifier run: block {k}'s stage shape moves the output plane"));
        }
        let out: Vec<i16> = w.planes[ids.at(A_X2)].iter().map(|v| i16::try_from(*v).map_err(|_| "classifier run: a block output outside int16".to_string())).collect::<Result<_, _>>()?;
        let next = unpad(sh, &out);
        if next != self.seq.load(&self.p.ex, sh, self.p.layers[k])?.1 {
            return Err(format!("classifier run: block {k}'s output is not the export's x_out_L{:02} (parity)", self.p.layers[k]));
        }
        self.parity += 1;
        self.x = next;
        Ok(w)
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(pad_plane(&self.p.sh, &self.seq.load(&self.p.ex, &self.p.sh, self.p.layers[k])?.1))
    }
    fn stage_out(&mut self) -> Result<StageOutCWitness, String> {
        self.stage_out.take().ok_or_else(|| "classifier run: stage OUT-C asked twice".to_string())
    }
    /// the CLI's own sealing pass ran the builder, int16, parity and CS-3 on
    /// every block before any header
    fn seal_check(&mut self, k: usize, _blk: &BlockPublic, _ssh: &Shape, _check: &mut dyn FnMut(&Witness) -> Result<(), String>) -> Result<(), String> {
        if self.sealed {
            Ok(())
        } else {
            Err(format!("classifier run: block {k} was not sealed by the CLI's sealing pass"))
        }
    }
}

/// the sealing chain (the token CLI's, PR4-4): every block from the builder's
/// own chain, int16, parity, CS-3; the builder's last plane
fn seal_chain(p: &ExportPublic, seq: &SeqIn, blocks: &mut ExportTokenBlocks, x_in0: Vec<i16>) -> Result<Vec<i16>, String> {
    let sh = &p.sh;
    let mut x = x_in0;
    for (k, r) in p.model.layers.iter().enumerate() {
        // ROUND 16 (REVIEW_R13 §10 item 3): the bound layer record's whole
        // stage context — its own calibration and, at R13, its gate
        // denominator (native `LayerRecord::shape_at`); at a legacy shape this
        // is the token CLI's `cli_stage_shape`
        let ssh = r.shape_at(sh).map_err(|e| format!("block {k}: {e} (the sealing pass, before any header)"))?;
        let ids = Ids::new(&ssh)?;
        let lay = super::super::layout::Layout::for_shape(&ssh)?;
        let blk = blocks.block(k)?;
        let w = super::super::witness::build_for_block(&ssh, &blk, &x).map_err(|e| format!("block {k}: the witness builder refuses: {e} (the sealing pass, before any header)"))?;
        let out: Vec<i16> = w.planes[ids.at(A_X2)].iter().map(|v| i16::try_from(*v).map_err(|_| format!("block {k}: an output outside int16 (the sealing pass, before any header)"))).collect::<Result<_, _>>()?;
        let next = unpad(sh, &out);
        if next != seq.load(&p.ex, sh, p.layers[k])?.1 {
            return Err(format!("block {k}: the builder's output is not the export's x_out_L{:02} (parity, in the sealing pass, before any header)", p.layers[k]));
        }
        super::super::protocol::check_lookup_misses(&ssh, &lay, &blk, &w).map_err(|e| format!("block {k}: {e} (the sealing pass, before any header)"))?;
        x = next;
    }
    Ok(x)
}

/// `zk60_classify prove ...` (see the module text)
pub fn classify_prove_command(args: &[String]) -> i32 {
    if args.iter().any(|a| a == "--content") {
        eprintln!("zk60_classify prove: {CONTENT_ON_COMMAND_LINE}");
        return 2;
    }
    let f = match flags(args, &["--export", "--tables", "--policy", "--content-file", "--chunk", "--seq", "--seq-dir", "--out", "--owner-dir", "--label"], &[]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_classify prove: {e}");
            return 2;
        }
    };
    match prove_inner(&f) {
        Ok(()) => 0,
        Err(e) => refused("classify-prove", &e),
    }
}

fn prove_inner(f: &[(String, String)]) -> Result<(), String> {
    let t_all = Instant::now();
    let out = PathBuf::from(need(f, "--out")?);
    let (incomplete, unverified) = (sibling(&out, ".incomplete"), sibling(&out, ".unverified-statement"));
    if std::fs::symlink_metadata(&out).is_ok() {
        return Err(format!("{} exists; a classifier run's directories must be new", out.display()));
    }
    let home = std::env::var_os("HOME").map(PathBuf::from);
    let owners_dir = owner_dir_at(f, &out, home.as_deref())?;
    let mut claimed = Claimed(Vec::new());
    claimed.dir(&incomplete, false, "a classifier run's directories")?;
    claimed.dir(&unverified, false, "a classifier run's directories")?;
    claimed.dir(&owners_dir, true, "a run's owner directory")?;
    let label = label_of(f)?;
    let seq = SeqIn::of(f)?;
    let export = PathBuf::from(need(f, "--export")?);
    let p = load_export(&export)?;
    let sh = &p.sh;
    // R-C2: the policy first (its yes / no ids and public margin scale), then
    // the tables RE-DERIVED from the pinned tied tensor and compared with the
    // files; the run's margin row is the recomputed one
    let policy = policy_by_id(need(f, "--policy")?)?;
    let bound = super::classify_tied::load_tied_classifier_tables(&p, &export, Path::new(need(f, "--tables")?), &policy)?;
    let tables = bound.tables();
    let whole = content_of(f)?;
    let index: usize = flag(f, "--chunk").unwrap_or("0").parse().map_err(|_| "--chunk: a chunk index (0, 1, ...)")?;
    // round 14: a short content is one chunk of its true length
    let ch = ChunkRef::derive(whole.len(), index, chunk_plan(sh, &policy, p.profile)?)?;
    let content = whole[ch.a..ch.b].to_vec();
    let cp = ClassifierProfile::new(sh, tables, bound.bos(), bound.norm(), &policy, content.len(), Tier::R1_MVP)?;
    let tokens = cp.tokens_of(&content)?;
    println!("{{\"event\":\"loaded\",\"export_variant\":{},\"run_profile\":{},\"blocks\":{},\"trained_statement_identity\":{},\"policy\":{},\"chunk\":{},\"chunks\":{},\"content_length_n\":{}}}", js(&p.ex.variant), js(p.profile), p.layers.len(), js(&hex(&p.model.identity())), js(&policy.id), ch.index, ch.count, cp.n);
    // the honest pipeline's refusals (template, control ids, lengths) fire
    // here, before any header (H-1)
    let (wit_in, b_in, in_plane) = super::stage_in_c::honest_inputs(&cp, tables, &tokens)?;
    let x_in0 = seq.load(&p.ex, sh, p.layers[0])?.0;
    if unpad(sh, &b_in) != x_in0 {
        return Err("classifier run: the embedding table does not embed the item to the export's x_in_L00".into());
    }
    let mut seal_blocks = ExportTokenBlocks::new(&p);
    let x_last = seal_chain(&p, &seq, &mut seal_blocks, x_in0.clone())?;
    drop(seal_blocks);
    // the public verdict row (T - 1, or P0 + n + S - 1 for a short item)
    let vr = cp.verdict_row();
    let mut row = vec![0i64; cp.d_pad];
    for (i, v) in x_last[vr * cp.d..(vr + 1) * cp.d].iter().enumerate() {
        row[i] = i64::from(*v);
    }
    let ov = super::stage_out_c::out_values(&cp, tables, &row, true)?;
    let wout = super::stage_out_c::witness_from_values(&cp, &ov)?;
    let ctx = stack_context(&p.ex.variant, &p.layers, label)?;
    let spec = input_endpoint_spec(sh, ctx, &cp)?;
    let (root, owner) = seal_input(&spec, &in_plane, &sh.hash_tag())?;
    let st = ClassifyRunStatement::new_chunk(RunShape::new(sh.clone(), p.layers.len(), p.profile)?, ctx, p.digests.clone(), &p.model, &bound, &policy, content.len(), Tier::R1_MVP, root, ov.verdict, whole.len(), index)?;
    if st.chunk() != ch {
        return Err("classifier run: the statement's chunk is not the prover's slice".into());
    }
    let mut disk = run_sink::DirSink::create(&incomplete, p.layers.len() + 2)?;
    let mut src = CliSource { p: &p, seq: &seq, ids: Ids::new(sh)?, stage_in: Some((wit_in, b_in)), stage_out: Some(wout), x: x_in0, parity: 0, sealed: true };
    let mut blocks = ExportTokenBlocks::new(&p);
    let t = Instant::now();
    let (_, dec) = prove_classify_run_with(&st, &mut blocks, &bound, &mut src, owner, &mut |k, bytes| {
        let n = bytes.len();
        SegmentSink::accept(&mut disk, k, bytes)?;
        println!("{{\"event\":\"segment\",\"index\":{k},\"bytes\":{n},\"elapsed_seconds\":{:.3}}}", t.elapsed().as_secs_f64());
        Ok(())
    })?;
    let prove_s = t.elapsed().as_secs_f64();
    if src.parity != p.layers.len() {
        return Err(format!("classifier run: parity was checked at {} of {} layers", src.parity, p.layers.len()));
    }
    if disk.lengths() != st.segment_lens()?.as_slice() {
        return Err("classifier run: the written segments are not the counted lengths".into());
    }
    write_private(&owners_dir.join("input.dec"), &dec.to_bytes())?;
    write_new(&unverified.join("statement.json"), render(&p, &st, label, Writer::Prover)?.as_bytes())?;
    std::fs::rename(&incomplete, &out).map_err(|e| format!("{} -> {}: {e}", incomplete.display(), out.display()))?;
    claimed.keep();
    println!(
        "{{\"event\":\"proved\",\"run\":{},\"owner_dir\":{},\"verdict\":{},\"policy\":{},\"chunk\":{},\"chunks\":{},\"segments\":{},\"receipt_bytes\":{},\"prove_seconds\":{prove_s:.3},\"whole_run_floor_bits\":{},\"total_seconds\":{:.3},\"statement\":\"UNVERIFIED until zk60_classify verify publishes <run>/statement/\"}}",
        js(&out.display().to_string()),
        js(&owners_dir.display().to_string()),
        js(verdict_text(st.verdict())),
        js(&policy.id),
        ch.index,
        ch.count,
        disk.lengths().len(),
        disk.total_bytes(),
        st.whole_run().floor_bits,
        t_all.elapsed().as_secs_f64()
    );
    Ok(())
}

/// a run directory CHECKED IN FULL against the verifier's own inputs
struct Checked {
    st: ClassifyRunStatement,
    p: ExportPublic,
    label: String,
    verify_s: f64,
    published: bool,
}

/// **A run directory past the B-3 door**: the statement re-rendered from the
/// verifier's own inputs and found byte for byte, the segments read at their
/// counted lengths; NO segment verified yet. `check_run` verifies them; the
/// gate's CLI-path capture (P-18) verifies them with its recorder attached,
/// so the CLI carries no capture hook.
pub(super) struct DoorPassed {
    pub st: ClassifyRunStatement,
    pub p: ExportPublic,
    pub tables: super::classify_tied::BoundClassifierTables,
    pub segs: Vec<Vec<u8>>,
    pub label: String,
    pub min_bits: u32,
    pub published: bool,
}

/// **verify's check path** (shared with `input-owner`): the B-3 door (the
/// statement re-rendered from the verifier's own inputs, byte for byte),
/// then every segment verified
fn check_run(f: &[(String, String)], art: &Path) -> Result<Checked, String> {
    let d = door(f, art)?;
    let mut blocks = ExportTokenBlocks::new(&d.p);
    let t = Instant::now();
    verify_classify_run_with(&d.st, &mut blocks, &d.tables, &d.segs, VerifierPolicy { min_whole_run_bits: d.min_bits })?;
    let verify_s = t.elapsed().as_secs_f64();
    drop(blocks);
    Ok(Checked { st: d.st, p: d.p, label: d.label, verify_s, published: d.published })
}

/// **the B-3 door and the segment reads** (see [`DoorPassed`])
pub(super) fn door(f: &[(String, String)], art: &Path) -> Result<DoorPassed, String> {
    let export = PathBuf::from(need(f, "--export")?);
    refuse_prover_private_entries(&export)?;
    let art = art.to_path_buf();
    let min_bits: u32 = flag(f, "--min-bits").unwrap_or("95").parse().map_err(|_| "--min-bits: an integer")?;
    let label = label_of(f)?;
    let p = load_export(&export)?;
    // D27: 93 bits only at the development rung; 95 at every other profile
    let floor = super::classify_tied::min_bits_floor(p.profile);
    if min_bits < floor {
        return Err(format!("--min-bits {min_bits} is below the floor {floor} of the run profile {} (D27: production >= 95; 93 only at the development rung)", p.profile));
    }
    let want = unhex32(need(f, "--expect-statement")?)?;
    if p.model.identity() != want {
        return Err(format!("the export's trained statement identity (classifier run profile) is {}, not the pinned one", hex(&p.model.identity())));
    }
    // R-C2: the verifier re-derives the margin row and the embedding digest
    // from the pinned tied tensor with the REGISTERED policy's ids and scale,
    // and BOS / the final norm from the export's token_io_parameters; any
    // table file that disagrees is refused (never trusted)
    let policy = policy_by_id(need(f, "--policy")?)?;
    let tables = super::classify_tied::load_tied_classifier_tables(&p, &export, Path::new(need(f, "--tables")?), &policy)?;
    let published_dir = art.join(run_sink::STATEMENT_DIR);
    let (sdir, writer) = if std::fs::symlink_metadata(&published_dir).is_ok() { (published_dir.clone(), Writer::Verifier) } else { (sibling(&art, ".unverified-statement"), Writer::Prover) };
    check_statement_dir(&sdir, &["statement.json"])?;
    let sbytes = read_regular_file_bounded(&sdir.join("statement.json"), MAX_STATEMENT_BYTES, false)?;
    let found = found_statement(&sbytes)?;
    if found.policy != policy.id {
        return Err(format!("the statement's policy is {:?}, not the one this verifier was given", found.policy));
    }
    let ctx = stack_context(&p.ex.variant, &p.layers, label)?;
    if found.context != ctx {
        return Err("the statement's context is not this export's and label's".into());
    }
    // D41: the chunk's range is re-derived from (N, index, the profile's plan);
    // round 14: n must be its length (a short item's one chunk is [0, N))
    let st = ClassifyRunStatement::new_chunk(RunShape::new(p.sh.clone(), p.layers.len(), p.profile)?, ctx, p.digests.clone(), &p.model, &tables, &policy, found.n, Tier::R1_MVP, found.root, found.verdict, found.chunk_total, found.chunk_index)?;
    // B-3: every field the verifier can derive is derived and compared, by
    // re-rendering the whole canonical statement (margin vector, yes / no,
    // c, template, tokenizer, model, final norm, rulings, parameters)
    if render(&p, &st, label, writer)?.as_bytes() != sbytes.as_slice() {
        return Err(format!("{}: not byte for byte the canonical statement of this run under the verifier's own inputs (B-3: the margin vector, ids, threshold, template and model are re-derived, never taken from the statement)", sdir.join("statement.json").display()));
    }
    let lens = st.segment_lens()?;
    let paths = run_sink::segment_paths(&art, lens.len())?;
    let mut segs = Vec::with_capacity(lens.len());
    for (path, n) in paths.iter().zip(lens.iter()) {
        segs.push(read_regular_file_bounded(path, *n as u64, true)?);
    }
    Ok(DoorPassed { st, p, tables, segs, label: label.to_string(), min_bits, published: writer == Writer::Verifier })
}

/// `zk60_classify verify ...`
pub fn classify_verify_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--tables", "--policy", "--artifact", "--expect-statement", "--label", "--min-bits"], &[]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_classify verify: {e}");
            return 2;
        }
    };
    match verify_inner(&f) {
        Ok(()) => 0,
        Err(e) => refused("classify-verify", &e),
    }
}

fn verify_inner(f: &[(String, String)]) -> Result<(), String> {
    let art = PathBuf::from(need(f, "--artifact")?);
    // a killed verifier's writing directory
    clear_stale_writing_dirs(&art)?;
    let c = check_run(f, &art)?;
    if !c.published {
        // publish the verifier's own statement (written aside, renamed in),
        // then retire the prover's unverified one
        let stmt = render(&c.p, &c.st, &c.label, Writer::Verifier)?;
        publish_statement_dir(&art, &[("statement.json", stmt.as_bytes())])?;
        let unverified = sibling(&art, ".unverified-statement");
        check_statement_dir(&unverified, &["statement.json"])?;
        std::fs::remove_dir_all(&unverified).map_err(|e| format!("{}: {e}", unverified.display()))?;
    }
    println!(
        "{{\"event\":\"classified\",\"verdict\":{},\"chunk\":{},\"chunks\":{},\"policy\":{},\"trained_statement_identity\":{},\"input_token_endpoint_root\":{},\"verify_seconds\":{:.3},\"whole_run_floor_bits\":{},\"published_by\":{}}}",
        js(verdict_text(c.st.verdict())),
        c.st.chunk().index,
        c.st.chunk().count,
        js(&c.st.cp.policy.id),
        js(&hex(&c.st.model_identity())),
        js(&hex(&c.st.in_root())),
        c.verify_s,
        c.st.whole_run().floor_bits,
        js(if c.published { "an earlier verifier (re-checked byte for byte)" } else { "this verifier" })
    );
    Ok(())
}

/// `zk60_classify input-owner ...`: the full check, then the decommitment
/// against the verified input root with the owner's own content
pub fn classify_input_owner_command(args: &[String]) -> i32 {
    if args.iter().any(|a| a == "--content") {
        eprintln!("zk60_classify input-owner: {CONTENT_ON_COMMAND_LINE}");
        return 2;
    }
    let f = match flags(args, &["--export", "--tables", "--policy", "--artifact", "--expect-statement", "--label", "--min-bits", "--decommitment", "--content-file"], &[]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_classify input-owner: {e}");
            return 2;
        }
    };
    let run = || -> Result<(), String> {
        let c = check_run(&f, Path::new(need(&f, "--artifact")?))?;
        let dec = Decommitment::from_bytes(&read_regular_file_bounded(Path::new(need(&f, "--decommitment")?), MAX_DECOMMITMENT_BYTES, false)?)?;
        // D41: the WHOLE content; the chunk's slice at the re-derived range
        let whole = content_of(&f)?;
        let ch = c.st.chunk();
        if whole.len() != ch.total {
            return Err(format!("the content holds {} ids; the verified statement's item holds {}", whole.len(), ch.total));
        }
        owner_check_input(&c.st, &dec, &whole[ch.a..ch.b])?;
        println!("{{\"event\":\"content-checked\",\"content_total\":{},\"chunk\":{},\"range\":[{}, {}],\"verdict\":{},\"checked_against\":\"the verified statement's input root, re-verified against every segment in this process\"}}", ch.total, ch.index, ch.a, ch.b, js(verdict_text(c.st.verdict())));
        Ok(())
    };
    match run() {
        Ok(()) => 0,
        Err(e) => refused("classify-input-owner", &e),
    }
}

/// `zk60_classify label ...`: **D41's label of one item for one category**
/// (§13.4): every chunk run verified in full (`verify`'s check path, the B-3
/// door included), then the OR of the chunk verdicts. FAIL-CLOSED: a run
/// that does not verify, a chunk index missing or repeated, or chunks naming
/// different public fields (policy, model, N, plan) give `flagged` (exit 1,
/// with the reason). **ROUND 15 (N-r14-1):** `--expect-total N`, the post's
/// own token count, is required and is checked against the chunk runs
/// ([`aggregate_label`]) before any label is printed.
pub fn classify_label_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--tables", "--policy", "--runs", "--expect-statement", "--expect-total", "--label", "--min-bits"], &[]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_classify label: {e}");
            return 2;
        }
    };
    match label_inner(&f) {
        Ok(()) => 0,
        Err(e) => refused("classify-label", &e),
    }
}

/// **ROUND 15 (N-r14-1): `--expect-total`**, the post's own token count
/// (required; at least 1)
fn expect_total_of(f: &[(String, String)]) -> Result<usize, String> {
    let raw = flag(f, "--expect-total").ok_or("--expect-total N is required: N is the post's own token count from the policy's pinned tokenizer, counted by the caller (REVIEW_R14 N-r14-1: the proofs cannot tell how long the post is, so a proof set of only its first ids would otherwise label)")?;
    let n: usize = raw.parse().map_err(|_| format!("--expect-total: the post's token count, a positive integer, not {raw:?}"))?;
    if n == 0 {
        return Err("--expect-total 0: an empty content has no chunk and no label (n >= 1)".into());
    }
    Ok(n)
}

fn label_inner(f: &[(String, String)]) -> Result<(), String> {
    // the post's own count first: no run is read without it
    let expect_total = expect_total_of(f)?;
    let runs: Vec<PathBuf> = need(f, "--runs")?.split(',').filter(|x| !x.is_empty()).map(PathBuf::from).collect();
    if runs.is_empty() {
        return Err("--runs: no chunk run".into());
    }
    let mut seen: Vec<(ChunkRef, u8, String, Digest)> = Vec::with_capacity(runs.len());
    for r in &runs {
        let c = check_run(f, r).map_err(|e| format!("chunk run {}: {e}", r.display()))?;
        println!("{{\"event\":\"chunk-verified\",\"run\":{},\"chunk\":{},\"range\":[{}, {}],\"verdict\":{}}}", js(&r.display().to_string()), c.st.chunk().index, c.st.chunk().a, c.st.chunk().b, js(verdict_text(c.st.verdict())));
        seen.push((c.st.chunk(), c.st.verdict(), c.st.cp.policy.id.clone(), c.st.model_identity()));
    }
    let label = aggregate_label(&seen, expect_total)?;
    let first = seen[0].0;
    let flagged: Vec<String> = seen.iter().filter(|s| s.1 == 1).map(|s| format!("[{}, {}]", s.0.a, s.0.b)).collect();
    println!(
        "{{\"event\":\"label\",\"policy\":{},\"label\":{},\"chunks\":{},\"content_total\":{},\"expect_total\":{},\"chunk_size\":{},\"overlap\":{},\"flagged_ranges\":[{}],\"note\":\"the per-chunk verdicts are public: a flagged label shows which ranges triggered it (DESIGN v2.2 13.4); the chunks cover exactly [0, expect_total), the post's own count (round 15, N-r14-1)\"}}",
        js(&seen[0].2),
        js(verdict_text(label)),
        first.count,
        first.total,
        expect_total,
        first.size,
        first.overlap,
        flagged.join(", ")
    );
    Ok(())
}

/// **THE AGGREGATION RULE (§13.4)** over verified chunk runs: the same
/// policy, model, N and plan in every run; every index of the split exactly
/// once; then the OR. Any other set is refused (the caller fails closed).
///
/// **ROUND 15 (REVIEW_R14 N-r14-1): `expect_total` is the POST's own token
/// count** (the caller's, from the pinned tokenizer; never taken from the
/// runs). Refused unless every run's `content_total` is `expect_total`, each
/// run's range is exactly its index's range in the split of
/// `[0, expect_total)` under the runs' plan, and the ranges together cover
/// `[0, expect_total)` with no gap and nothing beyond it. A proof set of only
/// the first k < N ids of an N-id post (a short item of k ids, or a k-id
/// item's full chunks) names `content_total` = k and is refused.
pub(crate) fn aggregate_label(seen: &[(ChunkRef, u8, String, Digest)], expect_total: usize) -> Result<u8, String> {
    let (c0, _, pol, model) = seen.first().ok_or("label: no chunk run")?;
    for (c, _, p, m) in seen {
        if p != pol || m != model || (c.total, c.count, c.size, c.overlap) != (c0.total, c0.count, c0.size, c0.overlap) {
            return Err("label: the chunk runs name different policies, models, totals or plans; they are not one item's chunks".into());
        }
    }
    // N-r14-1: the item is the post; its length is the caller's count
    if c0.total != expect_total {
        return Err(format!(
            "label: the chunk runs cover a content of {} ids, but the post has {expect_total} (--expect-total): a proof set of another length (e.g. only the post's first {} ids) is not the post's label (N-r14-1; fail-closed: handled as flagged)",
            c0.total, c0.total
        ));
    }
    let split = chunk_ranges(expect_total, ChunkPlan { size: c0.size, overlap: c0.overlap }).map_err(|e| format!("label: {e}"))?;
    if c0.count != split.len() {
        return Err(format!("label: the chunk runs name {} chunks; the split of [0, {expect_total}) has {}", c0.count, split.len()));
    }
    for (c, _, _, _) in seen {
        let want = *split.get(c.index).ok_or_else(|| format!("label: chunk {} of a {}-chunk split", c.index, split.len()))?;
        if (c.a, c.b) != want {
            return Err(format!("label: chunk {} names the range [{}, {}); the split of [0, {expect_total}) gives [{}, {})", c.index, c.a, c.b, want.0, want.1));
        }
    }
    let mut have = vec![false; c0.count];
    for (c, _, _, _) in seen {
        if std::mem::replace(&mut have[c.index], true) {
            return Err(format!("label: chunk {} appears twice", c.index));
        }
    }
    if let Some(j) = have.iter().position(|h| !h) {
        return Err(format!("label: chunk {j} of {} has no accepted proof (fail-closed: handled as flagged)", c0.count));
    }
    // and the ranges together cover [0, expect_total) exactly (no gap, nothing beyond)
    let mut ranges: Vec<(usize, usize)> = seen.iter().map(|s| (s.0.a, s.0.b)).collect();
    ranges.sort_unstable();
    let mut end = 0usize;
    for (a, b) in ranges {
        if a > end || b <= a || b > expect_total {
            return Err(format!("label: the chunk ranges leave [{end}, {a}) of [0, {expect_total}) uncovered or reach beyond it"));
        }
        end = end.max(b);
    }
    if end != expect_total {
        return Err(format!("label: the chunk ranges cover [0, {end}) of [0, {expect_total})"));
    }
    Ok(u8::from(seen.iter().any(|s| s.1 == 1)))
}
