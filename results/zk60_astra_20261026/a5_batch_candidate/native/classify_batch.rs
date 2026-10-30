//! A5 candidate: one public export/checkpoint load and one tied table value,
//! followed by independent sequential proofs. This never verifies a receipt.
use super::*;
#[path = "classify_batch_plan.rs"]
mod plan;
use plan::{Row, POLICIES};

const BATCH_SCHEMA: &str = "zk60-classify-prove-batch/1";
const BATCH_PROFILE: &str = "hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/1";
const MAX_BATCH_BYTES: u64 = 64 << 10;
const MAX_CONTENT: usize = 336;

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
    // Linux O_NOFOLLOW | O_NONBLOCK: refuse symlinks and inspect a FIFO
    // without blocking before its non-regular-file rejection.
    let f = std::fs::OpenOptions::new().read(true).custom_flags(0x20800).open(path)
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
    if args.iter().any(|a| a == "--content") {
        eprintln!("zk60_classify prove-batch: {CONTENT_ON_COMMAND_LINE}");
        return 2;
    }
    let f = match flags(args, &["--export", "--tables", "--content-file", "--batch-file", "--label"], &[]) {
        Ok(f) => f,
        Err(e) => { eprintln!("zk60_classify prove-batch: {e}"); return 2; }
    };
    match batch_inner(&f) {
        Ok(()) => 0,
        Err(e) => refused("classify-prove-batch", &e),
    }
}

fn batch_inner(f: &[(String, String)]) -> Result<(), String> {
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
    for id in POLICIES {
        let policy = policy_by_id(id)?;
        let size = 128usize.checked_sub(policy.prefix.len() + policy.suffix.len()).ok_or("batch: invalid template")?;
        let ch = ChunkRef::derive(total, 0, ChunkPlan { size, overlap: 8 })?;
        if ch.count > 8 { return Err("batch: at most eight chunks per category".into()); }
        expected.extend((0..ch.count).map(|i| (id.to_string(), i)));
    }
    plan::check_coverage(&rows, &expected)?;
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
    let t_load = Instant::now();
    let p = load_export(&export)?;
    if p.profile != BATCH_PROFILE || p.sh.tokens != 128 || p.model.identity() != expect {
        return Err("batch: model identity or T128 classifier profile differs".into());
    }
    let first = policy_by_id(POLICIES[0])?;
    let bound = super::super::classify_tied::load_tied_classifier_tables(&p, &export, &tables_path, &first)?;
    // The same derived table value is reusable only when every registered
    // policy agrees on its tied parameters. Do not clone the embedding.
    for row in &rows {
        let policy = policy_by_id(&row.policy)?;
        bound.check_for(&p.sh, p.profile, &p.model, &policy)?;
        let ch = ChunkRef::derive(total, row.chunk, chunk_plan(&p.sh, &policy, p.profile)?)?;
        let cp = ClassifierProfile::new(&p.sh, bound.tables(), bound.bos(), bound.norm(), &policy, ch.b - ch.a, Tier::R1_MVP)?;
        cp.tokens_of(&whole[ch.a..ch.b])?;
    }
    println!("{{\"event\":\"batch-loaded\",\"jobs\":{},\"model_loads\":1,\"table_loads\":1,\"load_seconds\":{:.3},\"trained_statement_identity\":{},\"context_label\":{}}}", rows.len(), t_load.elapsed().as_secs_f64(), js(&hex(&p.model.identity())), js(label));
    for (index, (row, jf)) in rows.iter().zip(&job_flags).enumerate() {
        println!("{{\"event\":\"batch-job-start\",\"index\":{index},\"name\":{},\"policy\":{},\"chunk\":{}}}", js(&row.name), js(&row.policy), row.chunk);
        // Each call creates fresh seal/proof randomness and a fresh streamed
        // block reader; every reload still checks its bound layer digest.
        prove_with_public(jf, Some(SharedProve { p: &p, bound: &bound, whole: &whole }))?;
        println!("{{\"event\":\"batch-job-proved\",\"index\":{index},\"name\":{}}}", js(&row.name));
    }
    println!("{{\"event\":\"batch-proved\",\"jobs\":{},\"total_seconds\":{:.3},\"verified\":false}}", rows.len(), t_all.elapsed().as_secs_f64());
    Ok(())
}
