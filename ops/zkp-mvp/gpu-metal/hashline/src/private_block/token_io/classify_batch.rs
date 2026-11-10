//! **`zk60_classify prove-batch`: ONE POST, ONE MODEL LOAD** (A5; Astra's
//! staged candidate, adopted in token round 18 with the review's fixes,
//! `r18/A5_PATCH_REVIEW.md`). One public export / checkpoint pass and one tied
//! table derivation, then the post's proofs one after another, each exactly a
//! single `prove` (`prove_with_public`): its own two fresh operating-system
//! draws (the input endpoint's seal, then the run stream), its own seal,
//! transcript, witness source and streamed block readers, every block reload
//! digest-checked. The batch never verifies a receipt (`verified:false`).
//!
//! * **One post per process** (the coordinator's reading of rule 3, register
//!   "A5 one-load batch"): one `--content-file`, one `--batch-file`; any
//!   repeated flag is refused (exit 2) before anything is read. The tables
//!   and the digest pass are held in memory, immutable, for this post only.
//! * **A failed batch leaves nothing that looks finished** (REVIEW A5 finding
//!   1): each finished job's run directory, unverified statement and owner
//!   directory (its `input.dec`) join the batch's ONE claim ([`BatchClaim`]);
//!   any later refusal removes them all (a `removed` line each) before the
//!   `refused` and fail-closed lines; they are released only just before
//!   `batch-proved`. A kill or an abort skips this: the caller removes every
//!   path its request lists when no `batch-proved` arrives.
//! * D45: the content length is public, and the three moderate D37 policies
//!   are the one fixed list (in that order, every chunk exactly once).
//! * Refusals (TOKEN ROUND 19, REVIEW_R18 R18-4; round 18 said "every refusal
//!   prints the fail-closed line"): a refusal once the arguments are read
//!   prints `refused`, then the fail-closed line, and exits 1. An ARGUMENT
//!   refusal prints neither: `--content` on the command line, an unknown flag
//!   or a repeated one exits 2 with one line on stderr, exactly as a single
//!   `prove` does. The router fails closed on any non-zero exit, so neither
//!   kind leaves an accepted result.
use super::*;
#[path = "classify_batch_plan.rs"]
mod plan;
use plan::{Row, POLICIES};

const BATCH_SCHEMA: &str = "zk60-classify-prove-batch/1";
const BATCH_PROFILE: &str = "hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/2";
const MAX_BATCH_BYTES: u64 = 64 << 10;
const MAX_CONTENT: usize = 336;
const BATCH_FLAGS: [&str; 5] = ["--export", "--tables", "--content-file", "--batch-file", "--label"];

/// `O_NOFOLLOW | O_NONBLOCK` for the request's open (REVIEW A5 note 7). The
/// values differ by target (aarch64 Linux: 0o400000 is `O_LARGEFILE`), so a
/// target without known values refuses every request at run time instead of
/// following a symlink silently; the crate still builds there. Since D60
/// review F4 (2026-11-02) the values are the crate's one table,
/// `run::NOFOLLOW_NONBLOCK`: x86-64 Linux (`0o400000 | 0o4000` = 0x20800, as
/// before), aarch64 Linux and macOS, where this command was refused until then.
const NOFOLLOW_NONBLOCK: Option<i32> = super::super::super::run::NOFOLLOW_NONBLOCK;

/// TOKEN ROUND 18 (a test hook; no behaviour change): the run profile a batch
/// admits, its T and its ONE fixed policy list (D45(2), D37 order). The CLI
/// admits exactly [`SHIELD_T128`]; the round's tests pass the development
/// rung's.
struct Spec {
    profile: &'static str,
    tokens: usize,
    policies: &'static [&'static str],
}

const SHIELD_T128: Spec = Spec { profile: BATCH_PROFILE, tokens: 128, policies: &POLICIES };

/// **THE BATCH'S ONE CLAIM (REVIEW A5 finding 1, token round 18).** Every
/// finished job's run directory, `.unverified-statement` directory and owner
/// directory join it, in job order, BEFORE that job's own claim lets go of
/// them; dropped unreleased (any refusal of a later job or of the batch), it
/// removes all of them, latest first, with a `removed` line each. Released
/// ([`BatchClaim::keep`]) only immediately before `batch-proved`. It also
/// records each finished job's block reloads (REVIEW A5 note 9).
#[derive(Default)]
pub(super) struct BatchClaim {
    dirs: Vec<PathBuf>,
    reloads: Vec<(usize, usize)>,
}

impl BatchClaim {
    /// a finished job's three directories (under their final names) and its
    /// (sealing pass, proving pass) block reloads, each one digest-checked
    pub(super) fn hold(&mut self, dirs: [&Path; 3], reloads: (usize, usize)) {
        self.dirs.extend(dirs.iter().map(|d| d.to_path_buf()));
        self.reloads.push(reloads);
    }
    fn keep(mut self) {
        self.dirs.clear();
    }
}

impl Drop for BatchClaim {
    fn drop(&mut self) {
        for d in self.dirs.iter().rev() {
            match std::fs::remove_dir_all(d) {
                Ok(()) => println!("{{\"event\":\"removed\",\"path\":{},\"why\":\"the batch was refused; this directory was made by a finished job of this batch and is removed with everything in it: no receipt, statement or decommitment of a failed batch is left (REVIEW A5 finding 1)\"}}", js(&d.display().to_string())),
                Err(e) => {
                    let line = format!("{{\"event\":\"REMOVAL-FAILED\",\"path\":{},\"error\":{},\"what_to_do\":\"remove it by hand (rm -r) before anything syncs its parent; never publish it\"}}", js(&d.display().to_string()), js(&e.to_string()));
                    println!("{line}");
                    eprintln!("{line}");
                }
            }
        }
    }
}

fn exact_keys(j: &J, keys: &[&str]) -> Result<(), String> {
    let entries = j.obj()?;
    if entries.len() != keys.len() || entries.iter().any(|(k, _)| !keys.contains(&k.as_str())) {
        return Err("batch: unexpected or missing fields".into());
    }
    Ok(())
}

fn uint(j: &J) -> Result<usize, String> {
    usize::try_from(j.i64()?).map_err(|_| "batch: expected a nonnegative integer".into())
}

fn read_request(path: &Path) -> Result<J, String> {
    use std::io::Read;
    use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
    // O_NOFOLLOW | O_NONBLOCK: refuse symlinks and inspect a FIFO without
    // blocking before its non-regular-file rejection.
    let flags = NOFOLLOW_NONBLOCK.ok_or("batch: O_NOFOLLOW / O_NONBLOCK are not defined for this target; prove-batch is refused here (REVIEW A5 note 7)")?;
    let f = std::fs::OpenOptions::new().read(true).custom_flags(flags).open(path)
        .map_err(|e| format!("batch request: {e}"))?;
    let m = f.metadata().map_err(|e| format!("batch request metadata: {e}"))?;
    if !m.is_file() || m.permissions().mode() & 0o077 != 0 || m.len() > MAX_BATCH_BYTES {
        return Err("batch: request must be an owner-only regular file of at most 64 KiB".into());
    }
    let mut bytes = Vec::new();
    f.take(MAX_BATCH_BYTES + 1).read_to_end(&mut bytes).map_err(|e| format!("batch request read: {e}"))?;
    if bytes.len() as u64 > MAX_BATCH_BYTES { return Err("batch: request grew past 64 KiB".into()); }
    parse_json(&bytes)
}

pub fn classify_prove_batch_command(args: &[String]) -> i32 {
    batch_command(args, &SHIELD_T128)
}

fn batch_command(args: &[String], spec: &Spec) -> i32 {
    if args.iter().any(|a| a == "--content") {
        eprintln!("zk60_classify prove-batch: {CONTENT_ON_COMMAND_LINE}");
        return 2;
    }
    let f = match flags(args, &BATCH_FLAGS, &[]) {
        Ok(f) => f,
        Err(e) => { eprintln!("zk60_classify prove-batch: {e}"); return 2; }
    };
    // one post per process (rule 3's reading): one content, one request, one
    // export; a flag given twice is refused, never silently resolved
    if let Some(k) = BATCH_FLAGS.iter().find(|k| f.iter().filter(|(x, _)| x.as_str() == **k).count() > 1) {
        eprintln!("zk60_classify prove-batch: {k} is given more than once; a batch proves ONE post in ONE process (its tables and digest pass are held for that post only)");
        return 2;
    }
    match batch_inner(&f, spec) {
        Ok(_) => 0,
        // D65(2): one constant external refusal; the detail goes to the owner's private log
        Err(e) => crate::private_block::trained_block::refusal::refuse("classify-prove-batch", &e),
    }
}

/// the batch; on success each job's (sealing pass, proving pass) block reloads
fn batch_inner(f: &[(String, String)], spec: &Spec) -> Result<Vec<(usize, usize)>, String> {
    let t_all = Instant::now();
    let label = label_of(f)?;
    let request = PathBuf::from(need(f, "--batch-file")?);
    let content_path = PathBuf::from(need(f, "--content-file")?);
    if !request.is_absolute() || !content_path.is_absolute() {
        return Err("batch: request/content must be absolute file paths, never stdin".into());
    }
    let j = read_request(&request)?;
    exact_keys(&j, &["schema", "expect_statement", "content_total", "jobs"])?;
    if j.get("schema")?.str()? != BATCH_SCHEMA { return Err("batch: unsupported schema".into()); }
    let expect = unhex32(j.get("expect_statement")?.str()?)?;
    let total = uint(j.get("content_total")?)?;
    if total == 0 || total > MAX_CONTENT { return Err("batch: content_total must be 1..336".into()); }
    let whole = content_of(f)?;
    if whole.len() != total { return Err("batch: whole content differs from the caller's expected total".into()); }
    let jobs = j.get("jobs")?.arr()?;
    if jobs.is_empty() || jobs.len() > plan::MAX_JOBS { return Err("batch: requires 1..24 jobs".into()); }
    let mut rows = Vec::new();
    for job in jobs {
        exact_keys(job, &["name", "policy_id", "chunk_index", "sequence_dir", "out", "owner_dir"])?;
        rows.push(Row {
            name: job.get("name")?.str()?.into(), policy: job.get("policy_id")?.str()?.into(),
            chunk: uint(job.get("chunk_index")?)?, sequence: PathBuf::from(job.get("sequence_dir")?.str()?),
            out: PathBuf::from(job.get("out")?.str()?), owner: PathBuf::from(job.get("owner_dir")?.str()?),
        });
    }
    let mut expected = Vec::new();
    for id in spec.policies {
        let policy = policy_by_id(id)?;
        let size = spec.tokens.checked_sub(policy.prefix.len() + policy.suffix.len()).ok_or("batch: invalid template")?;
        // round 18: the registered overlap of the spec's run profile (the native
        // `chunk_plan` reads the same registry; REVIEW A5 note 5)
        let ch = ChunkRef::derive(total, 0, ChunkPlan { size, overlap: chunk_overlap_of(spec.profile)? })?;
        if ch.count > 8 { return Err("batch: at most eight chunks per category".into()); }
        expected.extend((0..ch.count).map(|i| (id.to_string(), i)));
    }
    plan::check_coverage(&rows, &expected, spec.policies)?;
    let export = PathBuf::from(need(f, "--export")?);
    let tables_path = PathBuf::from(need(f, "--tables")?);
    plan::check_paths(&mut rows, &[export.clone(), tables_path.clone(), request, content_path])?;
    let mut job_flags = Vec::new();
    for row in &rows {
        let mut jf = f.iter().filter(|(k, _)| k != "--batch-file").cloned().collect::<Vec<_>>();
        jf.extend([
            ("--policy".into(), row.policy.clone()), ("--chunk".into(), row.chunk.to_string()),
            ("--seq-dir".into(), row.sequence.to_str().ok_or("batch: non-UTF8 sequence path")?.into()),
            ("--out".into(), row.out.to_str().ok_or("batch: non-UTF8 output path")?.into()),
            ("--owner-dir".into(), row.owner.to_str().ok_or("batch: non-UTF8 owner path")?.into()),
        ]);
        // All owner checks before any model load or proof. Explicit owners
        // make this check side-effect-free (no default directory creation).
        owner_dir_at(&jf, &row.out, None)?;
        job_flags.push(jf);
    }
    // REVIEW A5 note 9: the loads are counted where they happen, not printed as constants
    let (mut model_loads, mut table_loads) = (0usize, 0usize);
    let t_load = Instant::now();
    let p = load_export(&export)?;
    model_loads += 1;
    if p.profile != spec.profile || p.sh.tokens != spec.tokens || p.model.identity() != expect {
        return Err("batch: model identity or T128 classifier profile differs".into());
    }
    let first = policy_by_id(spec.policies.first().ok_or("batch: no policy")?)?;
    let bound = super::super::classify_tied::load_tied_classifier_tables(&p, &export, &tables_path, &first)?;
    table_loads += 1;
    // The same derived table value is reusable only when every registered
    // policy agrees on its tied parameters. Do not clone the embedding.
    for row in &rows {
        let policy = policy_by_id(&row.policy)?;
        bound.check_for(&p.sh, p.profile, &p.model, &policy)?;
        let ch = ChunkRef::derive(total, row.chunk, chunk_plan(&p.sh, &policy, p.profile)?)?;
        let cp = ClassifierProfile::new(&p.sh, bound.tables(), bound.bos(), bound.norm(), &policy, ch.b - ch.a, Tier::R1_MVP)?;
        cp.tokens_of(&whole[ch.a..ch.b])?;
    }
    println!("{{\"event\":\"batch-loaded\",\"jobs\":{},\"model_loads\":{model_loads},\"table_loads\":{table_loads},\"load_seconds\":{:.3},\"trained_statement_identity\":{},\"context_label\":{}}}", rows.len(), t_load.elapsed().as_secs_f64(), js(&hex(&p.model.identity())), js(label));
    // REVIEW A5 finding 1: the batch's ONE claim, released only at `batch-proved`
    let mut claim = BatchClaim::default();
    for (index, (row, jf)) in rows.iter().zip(&job_flags).enumerate() {
        println!("{{\"event\":\"batch-job-start\",\"index\":{index},\"name\":{},\"policy\":{},\"chunk\":{}}}", js(&row.name), js(&row.policy), row.chunk);
        // Each call creates fresh seal/proof randomness and a fresh streamed
        // block reader; every reload still checks its bound layer digest.
        prove_with_public(jf, Some(SharedProve { p: &p, bound: &bound, whole: &whole, claim: Some(&mut claim), blocks: None, witness_budget: 0, run_gate: None }))?;
        let (seal_loads, prove_loads) = *claim.reloads.get(index).ok_or("batch: a finished job did not join the batch's claim")?;
        println!("{{\"event\":\"batch-job-proved\",\"index\":{index},\"name\":{},\"seal_block_loads\":{seal_loads},\"prove_block_loads\":{prove_loads},\"blocks\":{}}}", js(&row.name), p.layers.len());
    }
    let reloads = claim.reloads.clone();
    claim.keep();
    println!("{{\"event\":\"batch-proved\",\"jobs\":{},\"total_seconds\":{:.3},\"verified\":false}}", rows.len(), t_all.elapsed().as_secs_f64());
    Ok(reloads)
}

// TOKEN ROUND 18: the round's tests (test code only), a child of this module so
// that they reach its private items
#[cfg(test)]
#[path = "classify_r18_tests.rs"]
mod r18;
