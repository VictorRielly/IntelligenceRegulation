//! **[A24] THE RESIDENT CLASSIFIER SERVERS** (lane A24, 2026-11-07, the media app's speed lane;
//! `results/zk60_a24_app_20261107/README.md`): `zk60_classify serve` and
//! `zk60_classify check-serve`, the classifier's counterparts of `stack-serve` (A22/A23, D70).
//!
//! `prove` and `verify` each load the export (the digest pass: every layer loaded and its
//! arrays hashed, about 28 s for Shieldstral-3B on the M3 Ultra) and re-derive the tied tables
//! from the pinned checkpoint, then stream every block from disk once more (twice for `prove`).
//! A server does that ONCE and keeps the public model resident; each request then runs the
//! unchanged command path.
//!
//! * **`serve`** (the prover): startup = the digest pass with every block KEPT
//!   (`ExportPublic::load_keeping`; each kept object's digest re-computed and compared with the
//!   pass's record), the tied tables derived once and checked against every admitted policy
//!   (`--policies`, as `prove-batch` checks its three). Each request line names one `prove`'s
//!   private inputs; the request runs `prove_with_public` — `prove`'s own function, every
//!   refusal in its order with its string, its own two fresh OS draws, seal, transcript, run
//!   directory, unverified statement and owner file — over the resident blocks (the sealing
//!   pass and the run read the kept objects; the run's stage checks still re-hash each block
//!   against the statement, CS-6) and, within `--witness-cache-gib`, the sealing pass's own
//!   witnesses (each reused only at the stage shape and input plane it was built from). The
//!   receipt, statement and owner file are `prove`'s format; `verify` accepts them unchanged.
//! * **`check-serve`** (the verifier, its own process): startup = `verify`'s admission checks
//!   (no prover-private entry in the export, the D27 floor, the pinned trained statement
//!   identity) and the same resident load. Each request is ONE category of ONE post: every
//!   chunk run through `verify`'s B-3 door (`door_statement`: the statement re-derived and
//!   re-rendered byte for byte) and verified in full over the resident blocks (the verifier's
//!   CS-6 re-hashes every block it binds, as always), its statement published as `verify`
//!   publishes it, then `input-owner`'s check of the decommitment against the verified input
//!   root, then `label`'s aggregation rule over the chunks with the post's own count. It
//!   emits the same `classified`, `content-checked`, `chunk-verified` and `label` events as
//!   the three commands. Each chunk is verified ONCE in this process, where the three
//!   commands verify it three times in three processes.
//!
//! **Lanes.** `--lanes N` requests run at once, each on its own rayon pool of
//! `--lane-threads T` threads (A11's lesson: concurrent provers must not share one pool),
//! sharing the process's one Metal context as D55's forks do. Requests start in line order;
//! result lines come out as requests finish, one `served` line each, with the request's
//! `id`. A request's event lines go to its own `log` file (owner-only, created new) when the
//! line names one, else into its `served` line.
//!
//! **ONE DATA OWNER PER PROCESS (D73 (5)).** A request's latency shows how long other
//! requests held the machine, so all requests of one server must come from one data owner
//! (in the media app, the platform operator, who holds every post's private opening). The
//! server does not check this; the operator must keep to it. **What a receipt attests** is
//! D73 (3)'s cached-record binding: the model the process loaded and checked at startup.
//! **Fresh randomness per request**: every draw is made inside the request's own
//! `prove_with_public`, as in `prove`. A refused request creates nothing (`prove`'s `Claimed`
//! removes what it made) and the stream carries on. Its detail goes to the owner's private
//! refusal log only (D65(2)); its external line is the constant refusal.
//!
//! **Scope.** No receipt byte, statement byte or protocol step changes: these servers are a
//! process form of the existing commands. NOT a privacy acceptance: D58 accepted the named
//! r16b CPU binary only; this binary and its GPU/server execution are not covered (pending).
//! Nothing here is production (D63).

use super::*;
use super::super::run::KeptResidentBlocks;
use super::super::super::run::fork::KeptBlock;
use std::io::Write as _;

/// a request line's longest form (an argument error beyond it)
const MAX_REQUEST_LINE: usize = 64 * 1024;
const SERVE_FLAGS: [&str; 7] = ["--export", "--tables", "--label", "--policies", "--lanes", "--lane-threads", "--witness-cache-gib"];
const CHECK_FLAGS: [&str; 8] = ["--export", "--tables", "--label", "--policies", "--expect-statement", "--min-bits", "--lanes", "--lane-threads"];

/// the public model a server holds for its life: the digest pass, its blocks (each the object
/// whose digest the pass recorded) and the tied tables. Nothing changes it after startup.
pub(super) struct ResidentClassifier {
    pub export: PathBuf,
    pub tables_dir: PathBuf,
    pub label: String,
    pub p: ExportPublic,
    /// [A26] each block as a `run::fork::KeptBlock`: placed where it lives for the server's
    /// life, with the digest and the CS-1 / CS-4 pass at its own stage shape made on that very
    /// object at startup. Shared by `&` only. The verifier server never reads the records.
    pub blocks: Vec<std::sync::Arc<KeptBlock>>,
    pub bound: super::super::classify_tied::BoundClassifierTables,
    pub policies: Vec<String>,
    pub startup_s: f64,
}

fn policies_of(f: &[(String, String)]) -> Result<Vec<String>, String> {
    let raw = need(f, "--policies")?;
    let list: Vec<String> = raw.split(',').filter(|x| !x.is_empty()).map(str::to_string).collect();
    if list.is_empty() {
        return Err("--policies: no policy".into());
    }
    for (i, a) in list.iter().enumerate() {
        if list[..i].contains(a) {
            return Err(format!("--policies: {a} is named twice"));
        }
        policy_by_id(a)?;
    }
    Ok(list)
}

fn uint_flag(f: &[(String, String)], k: &str, default: usize, lo: usize, hi: usize) -> Result<usize, String> {
    let v: usize = match flag(f, k) {
        Some(s) => s.parse().map_err(|_| format!("{k}: a whole number"))?,
        None => default,
    };
    if v < lo || v > hi {
        return Err(format!("{k} {v} is outside {lo}..={hi}"));
    }
    Ok(v)
}

impl ResidentClassifier {
    /// **The startup**: the digest pass keeping every block, each kept object's digest checked
    /// against the pass's record, the tied tables derived once and bound to every admitted
    /// policy. A failure refuses the start.
    pub(super) fn start(f: &[(String, String)]) -> Result<ResidentClassifier, String> {
        let t0 = Instant::now();
        let export = PathBuf::from(need(f, "--export")?);
        let tables_dir = PathBuf::from(need(f, "--tables")?);
        let label = label_of(f)?.to_string();
        let policies = policies_of(f)?;
        let (p, loaded) = ExportPublic::load_keeping(&export, classify_run_profile_of, true)?;
        if loaded.len() != p.layers.len() {
            return Err("classify server: the digest pass kept a different number of blocks".into());
        }
        // [A26] each kept object moved where it will live (`KeptBlock::new`: its digest computed
        // there, and its CS-1 / CS-4 check run there at its layer's own stage shape), then the
        // digest compared with the pass's record as before
        let mut blocks = Vec::with_capacity(loaded.len());
        for (k, b) in loaded.into_iter().enumerate() {
            let stage = p.model.layers.get(k).and_then(|r| r.shape_at(&p.sh).ok());
            let kb = KeptBlock::new(b, stage.as_slice());
            if kb.digest() != p.digests[k] {
                return Err(format!("classify server: kept block {k} is not the block the digest pass recorded (ruling CS-6)"));
            }
            blocks.push(kb);
        }
        let first = policy_by_id(&policies[0])?;
        let bound = super::super::classify_tied::load_tied_classifier_tables(&p, &export, &tables_dir, &first)?;
        for id in &policies {
            bound.check_for(&p.sh, p.profile, &p.model, &policy_by_id(id)?)?;
        }
        Ok(ResidentClassifier { export, tables_dir, label, p, blocks, bound, policies, startup_s: t0.elapsed().as_secs_f64() })
    }

    fn admitted(&self, policy: &str) -> Result<Policy, String> {
        if !self.policies.iter().any(|p| p == policy) {
            return Err(format!("the policy {policy:?} is not one this server admits ({:?})", self.policies));
        }
        let pol = policy_by_id(policy)?;
        self.bound.check_for(&self.p.sh, self.p.profile, &self.p.model, &pol)?;
        Ok(pol)
    }

    fn start_line(&self, command: &str, lanes: usize, threads: usize, extra: &str) -> String {
        format!(
            "{{\"event\":\"serve-start\",\"command\":{},\"gpu\":{},\"hl_gpu\":{},\"variant\":{},\"run_profile\":{},\"blocks\":{},\"trained_statement_identity\":{},\"policies\":[{}],\"lanes\":{lanes},\"lane_threads\":{threads},\"startup_seconds\":{:.3}{extra},\"scope\":\"a process form of the existing commands: no receipt or statement byte changes; NOT a privacy acceptance (D58 covers the named r16b CPU binary only); not production (D63); one data owner per process (D73)\"}}",
            js(command),
            js(&crate::gpu::label()),
            js(&std::env::var("HL_GPU").unwrap_or_else(|_| "unset".into())),
            js(&self.p.ex.variant),
            js(self.p.profile),
            self.blocks.len(),
            js(&hex(&self.p.model.identity())),
            self.policies.iter().map(|p| js(p)).collect::<Vec<_>>().join(","),
            self.startup_s
        )
    }
}

/// a request line: a JSON object with exactly the fields of `keys` (`optional` may be absent)
fn request_object(line: &str, keys: &[&str], optional: &[&str]) -> Result<J, String> {
    if line.len() > MAX_REQUEST_LINE {
        return Err(format!("the request line is longer than {MAX_REQUEST_LINE} bytes"));
    }
    let j = parse_json(line.as_bytes()).map_err(|e| format!("the request line is not JSON: {e}"))?;
    let kv = j.obj().map_err(|_| "the request line is not a JSON object".to_string())?;
    for (k, _) in kv {
        if !keys.contains(&k.as_str()) && !optional.contains(&k.as_str()) {
            return Err(format!("the request line has an unknown field {}", js(k)));
        }
    }
    for k in keys {
        j.get(k).map_err(|e| format!("{k}: {e}"))?;
    }
    Ok(j)
}

fn abs_path(j: &J, k: &str) -> Result<PathBuf, String> {
    let s = j.get(k).and_then(J::str).map_err(|e| format!("{k}: {e}"))?;
    let p = PathBuf::from(s);
    if !p.is_absolute() || s.contains('\0') {
        return Err(format!("{k}: an absolute path is required (never standard input: it carries the requests)"));
    }
    Ok(p)
}

fn id_of(j: &J) -> Result<Option<String>, String> {
    match j.opt("id") {
        None => Ok(None),
        Some(v) => {
            let s = v.str().map_err(|e| format!("id: {e}"))?;
            if s.len() > 256 {
                return Err("id is longer than 256 bytes".into());
            }
            Ok(Some(s.to_string()))
        }
    }
}

/// a request's event lines into its own new owner-only file
fn write_log(path: &Path, lines: &[String]) -> Result<(), String> {
    let mut body = String::new();
    for l in lines {
        body.push_str(l);
        body.push('\n');
    }
    write_private(path, body.as_bytes())
}

/// **The stream** (both servers): a reader takes the lines (blank lines skipped) in order;
/// `lanes` lane threads each take the next line and run `serve` on their own rayon pool; the
/// calling thread prints each result line as it arrives.
fn serve_lines<F>(lanes: usize, threads: usize, lines: impl Iterator<Item = String> + Send, serve: F, emit: &mut dyn FnMut(&str)) -> Result<(usize, usize), String>
where
    F: Fn(usize, &str, f64, usize) -> (bool, String) + Sync,
{
    let pools: Vec<rayon::ThreadPool> = (0..lanes)
        .map(|i| rayon::ThreadPoolBuilder::new().num_threads(threads).thread_name(move |t| format!("a24-lane{i}-{t}")).build().map_err(|e| format!("lane pool: {e}")))
        .collect::<Result<_, _>>()?;
    let t0 = Instant::now();
    let (req_tx, req_rx) = std::sync::mpsc::sync_channel::<(usize, String, f64)>(lanes);
    let req_rx = std::sync::Mutex::new(req_rx);
    let (out_tx, out_rx) = std::sync::mpsc::channel::<(bool, String)>();
    let (mut n, mut ok) = (0usize, 0usize);
    std::thread::scope(|s| {
        s.spawn(move || {
            let mut q = 0usize;
            for line in lines {
                if line.trim().is_empty() {
                    continue;
                }
                if req_tx.send((q, line, t0.elapsed().as_secs_f64())).is_err() {
                    break;
                }
                q += 1;
            }
        });
        for (i, pool) in pools.iter().enumerate() {
            let (out_tx, req_rx, serve) = (out_tx.clone(), &req_rx, &serve);
            s.spawn(move || loop {
                let next = req_rx.lock().unwrap_or_else(|e| e.into_inner()).recv();
                let Ok((q, line, t_read)) = next else { break };
                let queued = t0.elapsed().as_secs_f64() - t_read;
                let (good, l) = pool.install(|| serve(q, &line, queued, i));
                if out_tx.send((good, l)).is_err() {
                    break;
                }
            });
        }
        drop(out_tx);
        for (good, line) in out_rx {
            n += 1;
            ok += usize::from(good);
            emit(&line);
        }
    });
    Ok((n, ok))
}

fn end_line(command: &str, n: usize, ok: usize, seconds: f64) -> String {
    format!("{{\"event\":\"serve-end\",\"command\":{},\"requests\":{n},\"accepted\":{ok},\"other\":{},\"seconds\":{seconds:.3}}}", js(command), n - ok)
}

fn stdin_lines() -> impl Iterator<Item = String> + Send {
    use std::io::BufRead;
    std::io::BufReader::new(std::io::stdin()).lines().map_while(Result::ok)
}

fn emit_stdout(l: &str) {
    let mut o = std::io::stdout().lock();
    let _ = writeln!(o, "{l}");
    let _ = o.flush();
}

// ------------------------------------------------------------------ the prover server

/// **`zk60_classify serve --export DIR --tables DIR --policies ID,... [--label L] [--lanes N]
/// [--lane-threads T] [--witness-cache-gib G]`**: one request per stdin line,
/// `{"id": TEXT, "content_file": FILE, "policy": ID, "chunk": J, "seq_dir": DIR, "out": DIR,
/// "owner_dir": DIR, "log": FILE}` (`id` and `log` optional; every path absolute), each
/// exactly a `prove --content-file FILE --policy ID --chunk J --seq-dir DIR --out DIR
/// --owner-dir DIR`. Exit 0 at the end of stdin; 1 if the startup is refused; 2 for bad
/// arguments.
pub fn classify_serve_command(args: &[String]) -> i32 {
    if args.iter().any(|a| a == "--content") {
        eprintln!("zk60_classify serve: {CONTENT_ON_COMMAND_LINE}");
        return 2;
    }
    let f = match flags(args, &SERVE_FLAGS, &[]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_classify serve: {e}");
            return 2;
        }
    };
    match serve_inner(&f, stdin_lines(), &mut |l: &str| emit_stdout(l)) {
        Ok(_) => 0,
        Err(e) => crate::private_block::trained_block::refusal::refuse("classify-serve", &e),
    }
}

/// the prover server's settings
struct ProveCfg {
    lanes: usize,
    threads: usize,
    witness_budget: u64,
}

fn prove_cfg_of(f: &[(String, String)]) -> Result<ProveCfg, String> {
    let cores = std::thread::available_parallelism().map(|n| n.get()).unwrap_or(8);
    let lanes = uint_flag(f, "--lanes", 3, 1, 8)?;
    let threads = uint_flag(f, "--lane-threads", (cores / lanes).max(1), 1, 256)?;
    let gib: f64 = match flag(f, "--witness-cache-gib") {
        Some(v) => v.parse().map_err(|_| "--witness-cache-gib is not a number")?,
        None => 0.0,
    };
    if !(0.0..=64.0).contains(&gib) {
        return Err("--witness-cache-gib is outside 0..=64".into());
    }
    Ok(ProveCfg { lanes, threads, witness_budget: (gib * (1u64 << 30) as f64) as u64 })
}

/// one prove request, as `prove`'s flags
struct ProveRequest {
    id: Option<String>,
    flags: Vec<(String, String)>,
    log: Option<PathBuf>,
}

fn prove_request_of(srv: &ResidentClassifier, line: &str) -> Result<ProveRequest, String> {
    let j = request_object(line, &["content_file", "policy", "chunk", "seq_dir", "out", "owner_dir"], &["id", "log"])?;
    let policy = j.get("policy").and_then(J::str).map_err(|e| format!("policy: {e}"))?.to_string();
    let chunk = usize::try_from(j.get("chunk").and_then(J::i64).map_err(|e| format!("chunk: {e}"))?).map_err(|_| "chunk: a chunk index (0, 1, ...)".to_string())?;
    let log = match j.opt("log") {
        None => None,
        Some(_) => Some(abs_path(&j, "log")?),
    };
    let s = |p: PathBuf| p.display().to_string();
    let flags: Vec<(String, String)> = vec![
        ("--export".into(), s(srv.export.clone())),
        ("--tables".into(), s(srv.tables_dir.clone())),
        ("--label".into(), srv.label.clone()),
        ("--policy".into(), policy),
        ("--content-file".into(), s(abs_path(&j, "content_file")?)),
        ("--chunk".into(), chunk.to_string()),
        ("--seq-dir".into(), s(abs_path(&j, "seq_dir")?)),
        ("--out".into(), s(abs_path(&j, "out")?)),
        ("--owner-dir".into(), s(abs_path(&j, "owner_dir")?)),
    ];
    Ok(ProveRequest { id: id_of(&j)?, flags, log })
}

/// **ONE prove request** on the calling thread: the admitted policy, the content (the CLI's
/// own reader: a 0600 regular file), then `prove_with_public` over the resident model; the
/// request's event lines captured
fn prove_one(srv: &ResidentClassifier, cfg: &ProveCfg, req: &ProveRequest) -> (Result<(), String>, Vec<String>) {
    with_captured_events(|| -> Result<(), String> {
        srv.admitted(need(&req.flags, "--policy")?)?;
        let whole = content_of(&req.flags)?;
        prove_with_public(&req.flags, Some(SharedProve { p: &srv.p, bound: &srv.bound, whole: &whole, claim: None, blocks: Some(&srv.blocks), witness_budget: cfg.witness_budget }))
    })
}

/// the result line of one request (`lines`: its events, when it names no log file)
fn served_line(command: &str, q: usize, id: Option<&str>, status: &str, lane: usize, queued: f64, seconds: f64, log: Option<&Path>, lines: &[String], extra: &str) -> String {
    let events = match log {
        Some(p) => format!("\"log\":{}", js(&p.display().to_string())),
        None => format!("\"events\":[{}]", lines.iter().map(|l| js(l)).collect::<Vec<_>>().join(",")),
    };
    format!(
        "{{\"event\":\"served\",\"command\":{},\"request\":{q},\"id\":{},\"status\":{},\"lane\":{lane},\"queued_seconds\":{queued:.3},\"seconds\":{seconds:.3}{extra},{events}}}",
        js(command),
        id.map_or_else(|| "null".to_string(), js),
        js(status)
    )
}

fn serve_inner(f: &[(String, String)], lines: impl Iterator<Item = String> + Send, emit: &mut dyn FnMut(&str)) -> Result<(usize, usize), String> {
    let cfg = prove_cfg_of(f)?;
    let srv = ResidentClassifier::start(f)?;
    emit(&srv.start_line("classify-serve", cfg.lanes, cfg.threads, &format!(",\"witness_cache_bytes\":{}", cfg.witness_budget)));
    let t = Instant::now();
    let (n, ok) = serve_lines(
        cfg.lanes,
        cfg.threads,
        lines,
        |q, line, queued, lane| {
            let t0 = Instant::now();
            let req = match prove_request_of(&srv, line) {
                Ok(r) => r,
                Err(e) => {
                    let l = format!("{{\"event\":\"served\",\"command\":\"classify-serve\",\"request\":{q},\"status\":\"bad-request\",\"error\":{}}}", js(&e));
                    return (false, l);
                }
            };
            let (r, mut events) = prove_one(&srv, &cfg, &req);
            let status = match &r {
                Ok(()) => "proved",
                Err(e) => {
                    // D65(2): one constant external refusal; the detail to the owner's private log
                    if let Some(dir) = crate::private_block::trained_block::refusal::private_log_dir() {
                        let _ = crate::private_block::trained_block::refusal::log_private_at(&dir, "classify-serve", e);
                    }
                    events.push(crate::private_block::trained_block::refusal::external_event("classify-prove"));
                    "refused"
                }
            };
            let logged = match &req.log {
                Some(p) => match write_log(p, &events) {
                    Ok(()) => Some(p.as_path()),
                    Err(_) => None,
                },
                None => None,
            };
            (r.is_ok(), served_line("classify-serve", q, req.id.as_deref(), status, lane, queued, t0.elapsed().as_secs_f64(), logged, &events, ""))
        },
        emit,
    )?;
    emit(&end_line("classify-serve", n, ok, t.elapsed().as_secs_f64()));
    Ok((n, ok))
}

// ------------------------------------------------------------------ the verifier server

/// **`zk60_classify check-serve --export DIR --tables DIR --policies ID,... --expect-statement
/// HEX [--label L] [--min-bits N] [--lanes N] [--lane-threads T]`**: one request per stdin line,
/// `{"id": TEXT, "policy": ID, "expect_total": N, "content_file": FILE, "chunks": [{"artifact":
/// DIR, "decommitment": FILE}, ...], "log": FILE}` (`id` and `log` optional): ONE category of
/// ONE post, `verify` + `input-owner` for every chunk and then `label --expect-total N`, each
/// chunk verified once. Exit 0 at the end of stdin; 1 if the startup is refused; 2 for bad
/// arguments.
pub fn classify_check_serve_command(args: &[String]) -> i32 {
    if args.iter().any(|a| a == "--content") {
        eprintln!("zk60_classify check-serve: {CONTENT_ON_COMMAND_LINE}");
        return 2;
    }
    let f = match flags(args, &CHECK_FLAGS, &[]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_classify check-serve: {e}");
            return 2;
        }
    };
    match check_serve_inner(&f, stdin_lines(), &mut |l: &str| emit_stdout(l)) {
        Ok(_) => 0,
        Err(e) => refused("classify-check-serve", &e),
    }
}

/// the verifier server: the resident model under `verify`'s admission checks
struct CheckServer {
    res: ResidentClassifier,
    min_bits: u32,
    /// the run directories requests of this server are checking now: a second request on a
    /// run in this set is refused (two lanes must never publish one statement at once)
    busy: std::sync::Mutex<std::collections::HashSet<PathBuf>>,
}

/// a request's hold on its run directories, released on every path
struct Busy<'a> {
    set: &'a std::sync::Mutex<std::collections::HashSet<PathBuf>>,
    held: Vec<PathBuf>,
}

impl<'a> Busy<'a> {
    fn take(set: &'a std::sync::Mutex<std::collections::HashSet<PathBuf>>, runs: &[PathBuf]) -> Result<Busy<'a>, String> {
        let mut g = set.lock().unwrap_or_else(|e| e.into_inner());
        let mut seen = std::collections::HashSet::new();
        for r in runs {
            if g.contains(r) || !seen.insert(r.clone()) {
                return Err(format!("{}: this run directory is named twice or is being checked by another request of this server", r.display()));
            }
        }
        g.extend(runs.iter().cloned());
        Ok(Busy { set, held: runs.to_vec() })
    }
}

impl Drop for Busy<'_> {
    fn drop(&mut self) {
        let mut g = self.set.lock().unwrap_or_else(|e| e.into_inner());
        for r in &self.held {
            g.remove(r);
        }
    }
}

fn check_server_start(f: &[(String, String)]) -> Result<CheckServer, String> {
    let export = PathBuf::from(need(f, "--export")?);
    refuse_prover_private_entries(&export)?;
    let min_bits: u32 = flag(f, "--min-bits").unwrap_or("95").parse().map_err(|_| "--min-bits: an integer")?;
    label_of(f)?;
    let want = unhex32(need(f, "--expect-statement")?)?;
    let res = ResidentClassifier::start(f)?;
    // D27: 93 bits only at the development rung; 95 at every other profile
    let floor = super::super::classify_tied::min_bits_floor(res.p.profile);
    if min_bits < floor {
        return Err(format!("--min-bits {min_bits} is below the floor {floor} of the run profile {} (D27: production >= 95; 93 only at the development rung)", res.p.profile));
    }
    if res.p.model.identity() != want {
        return Err(format!("the export's trained statement identity (classifier run profile) is {}, not the pinned one", hex(&res.p.model.identity())));
    }
    Ok(CheckServer { res, min_bits, busy: std::sync::Mutex::new(std::collections::HashSet::new()) })
}

struct CheckRequest {
    id: Option<String>,
    policy: String,
    expect_total: usize,
    content_file: PathBuf,
    chunks: Vec<(PathBuf, PathBuf)>,
    log: Option<PathBuf>,
    /// `label` (default true): end with `label`'s aggregation over the chunks; `false`: the
    /// chunks' `verify` + `input-owner` only (one chunk of a multi-chunk category, or a recheck)
    label: bool,
}

fn check_request_of(line: &str) -> Result<CheckRequest, String> {
    let j = request_object(line, &["policy", "expect_total", "content_file", "chunks"], &["id", "log", "label"])?;
    let label = match j.opt("label") {
        None => true,
        Some(J::Bool(b)) => *b,
        Some(_) => return Err("label: true or false".into()),
    };
    let policy = j.get("policy").and_then(J::str).map_err(|e| format!("policy: {e}"))?.to_string();
    let expect_total = usize::try_from(j.get("expect_total").and_then(J::i64).map_err(|e| format!("expect_total: {e}"))?).map_err(|_| "expect_total: the post's token count".to_string())?;
    if expect_total == 0 {
        return Err("expect_total 0: an empty content has no chunk and no label (n >= 1)".into());
    }
    let arr = j.get("chunks").and_then(J::arr).map_err(|e| format!("chunks: {e}"))?;
    if arr.is_empty() || arr.len() > 64 {
        return Err("chunks: one to 64 chunk runs".into());
    }
    let mut chunks = Vec::with_capacity(arr.len());
    for c in arr {
        let kv = c.obj().map_err(|_| "chunks: each entry is an object".to_string())?;
        if kv.len() != 2 {
            return Err("chunks: each entry has exactly artifact and decommitment".into());
        }
        chunks.push((abs_path(c, "artifact")?, abs_path(c, "decommitment")?));
    }
    let log = match j.opt("log") {
        None => None,
        Some(_) => Some(abs_path(&j, "log")?),
    };
    Ok(CheckRequest { id: id_of(&j)?, policy, expect_total, content_file: abs_path(&j, "content_file")?, chunks, log, label })
}

/// **ONE category of ONE post**: for every chunk run, `verify`'s check (the B-3 door, every
/// segment verified over the resident blocks) and its statement published as `verify` does,
/// then `input-owner`'s check; then `label`'s rule with the post's own count. Each event
/// line is the command's own text.
fn check_one(srv: &CheckServer, req: &CheckRequest) -> Result<f64, String> {
    let r = &srv.res;
    let policy = r.admitted(&req.policy)?;
    let runs: Vec<PathBuf> = req.chunks.iter().map(|(a, _)| a.clone()).collect();
    let _busy = Busy::take(&srv.busy, &runs)?;
    let content_flag = [("--content-file".to_string(), req.content_file.display().to_string())];
    let whole = content_of(&content_flag)?;
    let mut seen: Vec<(ChunkRef, u8, String, Digest)> = Vec::with_capacity(req.chunks.len());
    let mut verify_total = 0.0;
    for (art, decommitment) in &req.chunks {
        // a killed verifier's writing directory (verify's first step)
        clear_stale_writing_dirs(art)?;
        let mut tp = Instant::now();
        let (st, segs, published) = door_statement(&r.p, &r.bound, &policy, &r.label, art, &mut tp)?;
        let t = Instant::now();
        verify_classify_run_with(&st, &mut KeptResidentBlocks(&r.blocks), &r.bound, &segs, VerifierPolicy { min_whole_run_bits: srv.min_bits }).map_err(|e| format!("chunk run {}: {e}", art.display()))?;
        let verify_s = t.elapsed().as_secs_f64();
        verify_total += verify_s;
        drop(segs);
        if !published {
            // publish the verifier's own statement (written aside, renamed in), then retire
            // the prover's unverified one (verify's steps)
            let stmt = render(&r.p, &st, &r.label, Writer::Verifier)?;
            publish_statement_dir(art, &[("statement.json", stmt.as_bytes())])?;
            let unverified = sibling(art, ".unverified-statement");
            check_statement_dir(&unverified, &["statement.json"])?;
            std::fs::remove_dir_all(&unverified).map_err(|e| format!("{}: {e}", unverified.display()))?;
        }
        event(format!(
            "{{\"event\":\"classified\",\"verdict\":{},\"chunk\":{},\"chunks\":{},\"policy\":{},\"trained_statement_identity\":{},\"input_token_endpoint_root\":{},\"verify_seconds\":{:.3},\"whole_run_floor_bits\":{},\"published_by\":{}}}",
            js(verdict_text(st.verdict())),
            st.chunk().index,
            st.chunk().count,
            js(&st.cp.policy.id),
            js(&hex(&st.model_identity())),
            js(&hex(&st.in_root())),
            verify_s,
            st.whole_run().floor_bits,
            js(if published { "an earlier verifier (re-checked byte for byte)" } else { "this verifier" })
        ));
        // input-owner: the decommitment against the verified input root, the owner's content
        let dec = Decommitment::from_bytes(&read_regular_file_bounded(decommitment, MAX_DECOMMITMENT_BYTES, false)?)?;
        let ch = st.chunk();
        if whole.len() != ch.total {
            return Err(format!("the content holds {} ids; the verified statement's item holds {}", whole.len(), ch.total));
        }
        owner_check_input(&st, &dec, &whole[ch.a..ch.b])?;
        event(format!("{{\"event\":\"content-checked\",\"content_total\":{},\"chunk\":{},\"range\":[{}, {}],\"verdict\":{},\"checked_against\":\"the verified statement's input root, re-verified against every segment in this process\"}}", ch.total, ch.index, ch.a, ch.b, js(verdict_text(st.verdict()))));
        event(format!("{{\"event\":\"chunk-verified\",\"run\":{},\"chunk\":{},\"range\":[{}, {}],\"verdict\":{}}}", js(&art.display().to_string()), ch.index, ch.a, ch.b, js(verdict_text(st.verdict()))));
        seen.push((ch, st.verdict(), st.cp.policy.id.clone(), st.model_identity()));
    }
    if !req.label {
        // verify + input-owner only; still the post's own count for every chunk
        if let Some(c) = seen.iter().find(|s| s.0.total != req.expect_total) {
            return Err(format!("chunk {} covers a content of {} ids, but the post has {} (expect_total)", c.0.index, c.0.total, req.expect_total));
        }
        return Ok(verify_total);
    }
    let label = aggregate_label(&seen, req.expect_total)?;
    let first = seen[0].0;
    let flagged: Vec<String> = seen.iter().filter(|s| s.1 == 1).map(|s| format!("[{}, {}]", s.0.a, s.0.b)).collect();
    event(format!(
        "{{\"event\":\"label\",\"policy\":{},\"label\":{},\"chunks\":{},\"content_total\":{},\"expect_total\":{},\"chunk_size\":{},\"overlap\":{},\"flagged_ranges\":[{}],\"note\":\"the per-chunk verdicts are public: a flagged label shows which ranges triggered it (DESIGN v2.2 13.4); the chunks cover exactly [0, expect_total), the post's own count (round 15, N-r14-1)\"}}",
        js(&seen[0].2),
        js(verdict_text(label)),
        first.count,
        first.total,
        req.expect_total,
        first.size,
        first.overlap,
        flagged.join(", ")
    ));
    Ok(verify_total)
}

fn check_serve_inner(f: &[(String, String)], lines: impl Iterator<Item = String> + Send, emit: &mut dyn FnMut(&str)) -> Result<(usize, usize), String> {
    let cores = std::thread::available_parallelism().map(|n| n.get()).unwrap_or(8);
    let lanes = uint_flag(f, "--lanes", 2, 1, 8)?;
    let threads = uint_flag(f, "--lane-threads", (cores / lanes).max(1), 1, 256)?;
    let srv = check_server_start(f)?;
    emit(&srv.res.start_line("classify-check-serve", lanes, threads, &format!(",\"min_bits\":{}", srv.min_bits)));
    let t = Instant::now();
    let (n, ok) = serve_lines(
        lanes,
        threads,
        lines,
        |q, line, queued, lane| {
            let t0 = Instant::now();
            let req = match check_request_of(line) {
                Ok(r) => r,
                Err(e) => {
                    let l = format!("{{\"event\":\"served\",\"command\":\"classify-check-serve\",\"request\":{q},\"status\":\"bad-request\",\"error\":{}}}", js(&e));
                    return (false, l);
                }
            };
            let (r, mut events) = with_captured_events(|| check_one(&srv, &req));
            let (status, extra) = match &r {
                Ok(v) => ("checked", format!(",\"verify_seconds\":{v:.3}")),
                Err(e) => {
                    // verify's refusal: the reason, then the fail-closed line (D45(4))
                    events.push(format!("{{\"event\":\"refused\",\"command\":\"classify-check-serve\",\"error\":{}}}", js(e)));
                    events.push(FAIL_CLOSED_LINE.to_string());
                    ("refused", String::new())
                }
            };
            let logged = match &req.log {
                Some(p) => match write_log(p, &events) {
                    Ok(()) => Some(p.as_path()),
                    Err(_) => None,
                },
                None => None,
            };
            (r.is_ok(), served_line("classify-check-serve", q, req.id.as_deref(), status, lane, queued, t0.elapsed().as_secs_f64(), logged, &events, &extra))
        },
        emit,
    )?;
    emit(&end_line("classify-check-serve", n, ok, t.elapsed().as_secs_f64()));
    Ok((n, ok))
}

/// TEST BUILDS ONLY: the prover server in process over `lines` (every line it emits)
#[cfg(test)]
pub(crate) fn serve_for_tests(args: &[String], lines: Vec<String>) -> Result<Vec<String>, String> {
    let f = flags(args, &SERVE_FLAGS, &[])?;
    let mut out = Vec::new();
    serve_inner(&f, lines.into_iter(), &mut |l: &str| out.push(l.to_string()))?;
    Ok(out)
}

/// TEST BUILDS ONLY: the verifier server in process over `lines` (every line it emits)
#[cfg(test)]
pub(crate) fn check_serve_for_tests(args: &[String], lines: Vec<String>) -> Result<Vec<String>, String> {
    let f = flags(args, &CHECK_FLAGS, &[])?;
    let mut out = Vec::new();
    check_serve_inner(&f, lines.into_iter(), &mut |l: &str| out.push(l.to_string()))?;
    Ok(out)
}

// [A24] the servers' tests (test code only)
#[cfg(test)]
#[path = "classify_serve_tests.rs"]
mod tests;
