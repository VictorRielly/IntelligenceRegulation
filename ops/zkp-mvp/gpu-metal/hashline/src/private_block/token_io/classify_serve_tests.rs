//! **[A24] THE RESIDENT CLASSIFIER SERVERS AT THE DEVELOPMENT RUNG.** TEST CODE ONLY. A child of
//! `classify_serve.rs` (one `#[cfg(test)] #[path]` line at its end), so these tests reach its
//! private items, and, through `classify_cli_tests`, the rung's classifier fixture (`Cc`: the
//! tiny export, L = 1, T = 32, chunk size 23, overlap 4).
//!
//! * `serve` proves a two-chunk rung post on two lanes (with and without the sealing pass's
//!   witnesses kept); each receipt passes the unchanged CLI `verify`, `input-owner` and `label`.
//! * A refused request (an empty activation directory: refused before its header) creates
//!   nothing, prints only the constant refusal, and the stream carries on.
//! * `check-serve` verifies, publishes, owner-checks and labels one category of the post in one
//!   request, with the commands' own event lines; a second check re-checks the published
//!   statement byte for byte.
//! * Negative controls: a tampered segment, the same length with different content, a policy
//!   the server does not admit, the wrong model (a startup pinned to another identity, and a
//!   verifier over another export), the post's prefix only, a missing chunk: each refused,
//!   fail-closed.
//! * `ClassifierTables`' digests: the 1 MiB-piece form equals the word-by-word form.
//! * **[A28]** `serve` with and without seal-ahead (whatever `HL_A28_SEAL_AHEAD` says in the test
//!   process): on ONE lane the second chunk's sealing pass runs beside the first chunk's run and
//!   its run waits at the lane's gate; the receipts pass the unchanged CLI checks; a request
//!   refused in its sealing pass creates nothing and frees its lane. And the reader's dispatch:
//!   an idle lane first, never a third request to a lane, every request served once.

use super::*;
use super::super::super::classify_cli_tests::{Cc, POLICY_RUNG_DEV, POLICY_RUNG_DEV_SWAPPED};
use std::path::{Path, PathBuf};

fn s(v: &[&str]) -> Vec<String> {
    v.iter().map(|x| x.to_string()).collect()
}

fn sib(p: &Path, suffix: &str) -> PathBuf {
    let mut s = p.as_os_str().to_owned();
    s.push(suffix);
    PathBuf::from(s)
}

/// one rung post of 27 ids (two chunks: [0, 23) and [4, 27)) with its activations per chunk
struct Post {
    whole: String,
    content: PathBuf,
    outs: Vec<PathBuf>,
    owners: Vec<PathBuf>,
    seqs: Vec<PathBuf>,
}

impl Post {
    fn new(cc: &Cc, tag: &str, empty_job: Option<usize>) -> Post {
        let whole = format!("{},33,34,35,36", cc.content);
        let p = policy_rung_dev();
        let ids: Vec<u64> = whole.split(',').map(|x| x.parse().unwrap()).collect();
        assert_eq!(ids.len(), 27);
        let items = [item_tokens(&p, &ids[0..23]), item_tokens(&p, &ids[4..27])];
        let content = cc.content_file(&whole);
        let (mut outs, mut owners, mut seqs) = (Vec::new(), Vec::new(), Vec::new());
        for (i, item) in items.iter().enumerate() {
            let out = cc.root.join(format!("{tag}-c{i}"));
            let seq = cc.owners.join(format!("{tag}-seq-c{i}"));
            if empty_job == Some(i) {
                std::fs::create_dir(&seq).unwrap();
            } else {
                cc.write_seq_dir(&seq, item);
            }
            owners.push(cc.owner_dir(&out));
            outs.push(out);
            seqs.push(seq);
        }
        Post { whole, content, outs, owners, seqs }
    }
    fn request(&self, i: usize) -> String {
        format!(
            "{{\"id\": \"c{i}\", \"content_file\": {}, \"policy\": {}, \"chunk\": {i}, \"seq_dir\": {}, \"out\": {}, \"owner_dir\": {}}}",
            js(self.content.to_str().unwrap()),
            js(POLICY_RUNG_DEV),
            js(self.seqs[i].to_str().unwrap()),
            js(self.outs[i].to_str().unwrap()),
            js(self.owners[i].to_str().unwrap())
        )
    }
    /// every path request `i` may create, with whether it exists
    fn created(&self, i: usize) -> Vec<(PathBuf, bool)> {
        let out = &self.outs[i];
        [out.clone(), sib(out, ".incomplete"), sib(out, ".unverified-statement"), self.owners[i].clone()].into_iter().map(|p| {
            let e = std::fs::symlink_metadata(&p).is_ok();
            (p, e)
        }).collect()
    }
}

fn serve_args(cc: &Cc, lanes: &str, gib: &str) -> Vec<String> {
    s(&["--export", cc.export.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policies", POLICY_RUNG_DEV, "--lanes", lanes, "--lane-threads", "2", "--witness-cache-gib", gib])
}

fn check_args(cc: &Cc, pin: &str) -> Vec<String> {
    check_args_lanes(cc, pin, "2")
}

fn check_args_lanes(cc: &Cc, pin: &str, lanes: &str) -> Vec<String> {
    s(&["--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policies", POLICY_RUNG_DEV, "--expect-statement", pin, "--min-bits", "93", "--lanes", lanes, "--lane-threads", "2"])
}

fn parsed(lines: &[String]) -> Vec<J> {
    lines.iter().map(|l| parse_json(l.as_bytes()).unwrap_or_else(|e| panic!("not JSON: {l}: {e}"))).collect()
}

/// the `served` line of request `id`
fn served<'a>(js_: &'a [J], id: &str) -> &'a J {
    js_.iter().find(|j| j.get("event").and_then(J::str).ok() == Some("served") && j.opt("id").and_then(|v| v.str().ok()) == Some(id)).unwrap_or_else(|| panic!("no served line for {id}"))
}

fn status(j: &J) -> String {
    j.get("status").unwrap().str().unwrap().to_string()
}

/// the event names of a served line's events
fn events(j: &J) -> Vec<String> {
    j.get("events").unwrap().arr().unwrap().iter().map(|e| {
        let line = e.str().unwrap();
        parse_json(line.as_bytes()).ok().and_then(|x| x.get("event").ok().and_then(|v| v.str().ok().map(str::to_string))).unwrap_or_else(|| line.to_string())
    }).collect()
}

fn check_line(post: &Post, cc: &Cc, id: &str, policy: &str, total: usize, content: &Path, chunks: &[usize]) -> String {
    let list: Vec<String> = chunks.iter().map(|&i| format!("{{\"artifact\": {}, \"decommitment\": {}}}", js(post.outs[i].to_str().unwrap()), js(cc.owner_dir(&post.outs[i]).join("input.dec").to_str().unwrap()))).collect();
    format!("{{\"id\": {}, \"policy\": {}, \"expect_total\": {total}, \"content_file\": {}, \"chunks\": [{}]}}", js(id), js(policy), js(content.to_str().unwrap()), list.join(", "))
}

/// `serve` proves both chunks of a rung post on two lanes, with the sealing pass's witnesses
/// kept (1 GiB) and without (0); every receipt passes the unchanged CLI verify, input-owner and
/// label; the prover publishes nothing and the owners' files are 0600 in 0700 directories
#[test]
fn a24_serve_proves_a_rung_post_whose_receipts_pass_the_unchanged_cli_checks() {
    use std::os::unix::fs::PermissionsExt;
    for gib in ["1", "0"] {
        let cc = Cc::new(&format!("a24-serve-{gib}"));
        let post = Post::new(&cc, "a24s", None);
        let out = serve_for_tests(&serve_args(&cc, "2", gib), vec![post.request(0), String::new(), post.request(1)]).expect("the server starts");
        let j = parsed(&out);
        assert_eq!(j[0].get("event").unwrap().str().unwrap(), "serve-start");
        assert_eq!(j.last().unwrap().get("event").unwrap().str().unwrap(), "serve-end");
        assert_eq!(j.last().unwrap().get("accepted").unwrap().i64().unwrap(), 2);
        for i in 0..2 {
            let line = served(&j, &format!("c{i}"));
            assert_eq!(status(line), "proved", "{:?}", events(line));
            let ev = events(line);
            assert!(ev.contains(&"loaded".to_string()) && ev.contains(&"proved".to_string()) && ev.iter().filter(|e| *e == "segment").count() == 3, "{ev:?}");
            let o = &post.outs[i];
            assert!(o.is_dir() && !sib(o, ".incomplete").exists() && !o.join("statement").exists(), "the prover publishes nothing");
            assert!(sib(o, ".unverified-statement").join("statement.json").is_file());
            let dec = post.owners[i].join("input.dec");
            assert_eq!(std::fs::metadata(&dec).unwrap().permissions().mode() & 0o777, 0o600);
            assert_eq!(std::fs::metadata(&post.owners[i]).unwrap().permissions().mode() & 0o777, 0o700);
        }
        for o in &post.outs {
            assert_eq!(cc.verify(o, &cc.tables), 0, "{} verifies (the unchanged CLI)", o.display());
            assert_eq!(cc.input_owner(o, &cc.tables, &post.whole), 0, "{}: input-owner on the whole content", o.display());
        }
        assert_eq!(cc.label(&[&post.outs[0], &post.outs[1]], 27), 0, "the unchanged label over both chunks");
        eprintln!("A24 | serve (witness cache {gib} GiB): 2 lanes, both chunks proved; CLI verify, input-owner and label accept them");
    }
}

/// A request refused before its header (an empty activation directory) creates NOTHING, its
/// line is the constant refusal (the detail goes to the private log only), and the stream
/// carries on: the next request proves. A bad request line and an unadmitted policy are
/// refused without effect.
#[test]
fn a24_a_refused_request_creates_nothing_and_the_stream_carries_on() {
    let cc = Cc::new("a24-refuse");
    let post = Post::new(&cc, "a24r", Some(0));
    let unadmitted = post.request(1).replace(&js(POLICY_RUNG_DEV), &js(POLICY_RUNG_DEV_SWAPPED)).replace("\"id\": \"c1\"", "\"id\": \"swapped\"");
    let lines = vec![post.request(0), "{\"out\": 1".to_string(), unadmitted, post.request(1)];
    let out = serve_for_tests(&serve_args(&cc, "1", "1"), lines).expect("the server starts");
    let j = parsed(&out);
    let refused = served(&j, "c0");
    assert_eq!(status(refused), "refused");
    let ev: Vec<String> = refused.get("events").unwrap().arr().unwrap().iter().map(|e| e.str().unwrap().to_string()).collect();
    assert_eq!(ev.last().unwrap(), &crate::private_block::trained_block::refusal::external_event("classify-prove"), "the constant external refusal");
    assert!(ev.iter().all(|l| !l.contains("seq") || l.contains("\"event\":\"removed\"")), "a refusal's detail stays private: {ev:?}");
    assert!(post.created(0).iter().all(|(_, e)| !*e), "a refused request created {:?}", post.created(0));
    assert_eq!(status(served(&j, "swapped")), "refused", "a policy the server does not admit");
    assert!(j.iter().any(|x| x.get("status").and_then(J::str).ok() == Some("bad-request")), "the malformed line");
    assert_eq!(status(served(&j, "c1")), "proved", "the stream carries on after refusals");
    assert_eq!(cc.verify(&post.outs[1], &cc.tables), 0);
    eprintln!("A24 | a refused request created nothing; a bad line and an unadmitted policy refused; the next request proved and verifies");
}

/// `check-serve`: one request verifies both chunk runs, publishes each statement as `verify`
/// does (the unverified one retired), checks each owner's decommitment and labels the category
/// over the post's own count, with the commands' event lines; a second check finds the
/// published statements and re-checks them byte for byte.
#[test]
fn a24_check_serve_verifies_publishes_owner_checks_and_labels_one_category() {
    let cc = Cc::new("a24-check");
    let post = Post::new(&cc, "a24c", None);
    let out = serve_for_tests(&serve_args(&cc, "2", "1"), vec![post.request(0), post.request(1)]).expect("the server starts");
    assert!(parsed(&out).iter().filter(|x| x.get("status").and_then(J::str).ok() == Some("proved")).count() == 2);
    let req = check_line(&post, &cc, "cat", POLICY_RUNG_DEV, 27, &post.content, &[0, 1]);
    let out = check_serve_for_tests(&check_args_lanes(&cc, &cc.identity, "1"), vec![req.clone(), req.replace("\"cat\"", "\"again\"")]).expect("the verifier starts");
    let j = parsed(&out);
    let first = served(&j, "cat");
    assert_eq!(status(first), "checked", "{:?}", events(first));
    let ev = events(first);
    for (name, n) in [("classified", 2), ("content-checked", 2), ("chunk-verified", 2), ("label", 1)] {
        assert_eq!(ev.iter().filter(|e| *e == name).count(), n, "{name}: {ev:?}");
    }
    for o in &post.outs {
        assert!(o.join("statement").join("statement.json").is_file(), "the verifier published {}", o.display());
        assert!(!sib(o, ".unverified-statement").exists(), "the prover's unverified statement is retired");
        assert_eq!(cc.verify(o, &cc.tables), 0, "the CLI verify re-checks the server's published statement");
    }
    let again = served(&j, "again");
    assert_eq!(status(again), "checked");
    assert!(again.get("events").unwrap().arr().unwrap().iter().any(|e| e.str().unwrap().contains("an earlier verifier (re-checked byte for byte)")));
    eprintln!("A24 | check-serve: both chunks verified once each, published, owner-checked, labelled; a second check re-checks the published statements");
}

/// **The negative controls**, each refused fail-closed by `check-serve`: a tampered segment;
/// the same length with different content; a policy the server does not admit; the post's
/// prefix only (`expect_total` 26); a missing chunk; the wrong model, both as a server pinned
/// to another identity (its startup refused) and as a verifier over another export.
#[test]
fn a24_check_serve_refuses_every_negative_control() {
    let cc = Cc::new("a24-neg");
    let post = Post::new(&cc, "a24n", None);
    let out = serve_for_tests(&serve_args(&cc, "2", "1"), vec![post.request(0), post.request(1)]).expect("the server starts");
    assert!(parsed(&out).iter().filter(|x| x.get("status").and_then(J::str).ok() == Some("proved")).count() == 2);
    // a tampered copy of chunk 0's run (one byte of its block segment flipped)
    let tampered = cc.root.join("a24n-tampered-c0");
    std::fs::create_dir(&tampered).unwrap();
    for e in std::fs::read_dir(&post.outs[0]).unwrap() {
        let p = e.unwrap().path();
        std::fs::copy(&p, tampered.join(p.file_name().unwrap())).unwrap();
    }
    let unv = sib(&tampered, ".unverified-statement");
    std::fs::create_dir(&unv).unwrap();
    std::fs::copy(sib(&post.outs[0], ".unverified-statement").join("statement.json"), unv.join("statement.json")).unwrap();
    let seg = tampered.join("segment-001.bin");
    let mut b = std::fs::read(&seg).unwrap();
    let k = b.len() / 2;
    b[k] ^= 1;
    std::fs::write(&seg, &b).unwrap();
    let tampered_line = format!(
        "{{\"id\": \"tampered\", \"policy\": {}, \"expect_total\": 27, \"content_file\": {}, \"chunks\": [{{\"artifact\": {}, \"decommitment\": {}}}, {{\"artifact\": {}, \"decommitment\": {}}}]}}",
        js(POLICY_RUNG_DEV), js(post.content.to_str().unwrap()), js(tampered.to_str().unwrap()), js(cc.owner_dir(&post.outs[0]).join("input.dec").to_str().unwrap()),
        js(post.outs[1].to_str().unwrap()), js(cc.owner_dir(&post.outs[1]).join("input.dec").to_str().unwrap())
    );
    // the same length, one id changed
    let mut other: Vec<String> = post.whole.split(',').map(str::to_string).collect();
    other[5] = if other[5] == "14" { "15".into() } else { "14".into() };
    let other = cc.content_file(&other.join(","));
    let lines = vec![
        tampered_line,
        check_line(&post, &cc, "other-content", POLICY_RUNG_DEV, 27, &other, &[0, 1]),
        check_line(&post, &cc, "unadmitted-policy", POLICY_RUNG_DEV_SWAPPED, 27, &post.content, &[0, 1]),
        check_line(&post, &cc, "prefix-only", POLICY_RUNG_DEV, 26, &post.content, &[0, 1]),
        check_line(&post, &cc, "missing-chunk", POLICY_RUNG_DEV, 27, &post.content, &[1]),
        check_line(&post, &cc, "good", POLICY_RUNG_DEV, 27, &post.content, &[0, 1]),
    ];
    // one lane: the requests in order (two lanes on one run directory are refused by the
    // server's busy set, checked below)
    let j = parsed(&check_serve_for_tests(&check_args_lanes(&cc, &cc.identity, "1"), lines).expect("the verifier starts"));
    for id in ["tampered", "other-content", "unadmitted-policy", "prefix-only", "missing-chunk"] {
        let line = served(&j, id);
        assert_eq!(status(line), "refused", "{id}: {:?}", events(line));
        let ev: Vec<String> = line.get("events").unwrap().arr().unwrap().iter().map(|e| e.str().unwrap().to_string()).collect();
        assert!(ev.last().unwrap().contains("\"outcome\":\"flagged\""), "{id}: fail-closed (D45(4))");
        assert!(!ev.iter().any(|e| e.contains("\"event\":\"label\"")), "{id}: no label");
    }
    assert_eq!(status(served(&j, "good")), "checked", "the honest request after the controls");
    // the wrong model: a server pinned to another identity refuses to start
    assert!(check_serve_for_tests(&check_args(&cc, &cc.identity_neg), vec![]).is_err(), "a verifier pinned to another model starts");
    // ... and a verifier over another export (its own identity) refuses this export's runs
    let neg = s(&["--export", cc.verifier_copy_neg.to_str().unwrap(), "--tables", cc.tables_neg.to_str().unwrap(), "--policies", POLICY_RUNG_DEV_SWAPPED, "--expect-statement", &cc.identity_neg, "--min-bits", "93"]);
    let j = parsed(&check_serve_for_tests(&neg, vec![check_line(&post, &cc, "other-model", POLICY_RUNG_DEV_SWAPPED, 27, &post.content, &[0, 1])]).expect("the other model's verifier starts"));
    assert_eq!(status(served(&j, "other-model")), "refused", "another model's verifier accepted this model's runs");
    eprintln!("A24 | check-serve negative controls: tampered segment, other content of the same length, unadmitted policy, prefix only, missing chunk, wrong model (startup and export): all refused, fail-closed");
}

/// `ClassifierTables`' digests in 1 MiB pieces equal the word-by-word stream they replace
#[test]
fn a24_the_piecewise_table_digests_equal_the_word_by_word_ones() {
    let mut x = 0x9e37_79b9_7f4a_7c15u64;
    let mut next = || {
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        (x >> 16) as i16
    };
    for (v, d) in [(3usize, 5usize), (1 << 10, 600), (2, (1 << 19) + 3)] {
        let emb: Vec<i16> = (0..v * d).map(|_| next()).collect();
        let w: Vec<i16> = (0..d).map(|_| next()).collect();
        let t = ClassifierTables::new(v, d, emb.clone(), w.clone()).unwrap();
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/classify/embedding-int16/v1");
        h.update(&(v as u64).to_le_bytes());
        h.update(&(d as u64).to_le_bytes());
        for e in &emb {
            h.update(&e.to_le_bytes());
        }
        assert_eq!(t.emb_digest(), *h.finalize().as_bytes(), "embedding digest at {v} x {d}");
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/classify/margin-vector-int16/v1");
        h.update(&(d as u64).to_le_bytes());
        for e in &w {
            h.update(&e.to_le_bytes());
        }
        assert_eq!(t.w_digest(), *h.finalize().as_bytes(), "margin digest at d = {d}");
    }
    eprintln!("A24 | the table digests in 1 MiB pieces equal the word-by-word digests (3 sizes, one past a piece boundary)");
}

/// **[A26] the embedding fold in split 32-bit limbs is the per-word field fold**, entry for
/// entry: random int16 tables with `i16::MIN`, `i16::MAX` and zeros, at widths below, at and
/// above a power of two, and eq tables of random points and of points with `p - 1` and zero
/// coordinates (so eq entries take extreme words)
#[test]
fn a26_the_split_limb_embedding_fold_equals_the_field_fold() {
    use super::super::super::classify::A26_EMB_TEST;
    use crate::field::{Fp, Fp2};
    use std::sync::atomic::Ordering::Relaxed;
    let mut x = 0x26a2_6a26_9e37_79b9u64;
    let mut next = || {
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        x
    };
    let pm1 = Fp::ZERO.sub(Fp::ONE);
    for (v, d) in [(5usize, 3usize), (7, 64), (33, 100), (9, 3072)] {
        let emb: Vec<i16> = (0..v * d).map(|i| match i % 11 { 0 => i16::MIN, 1 => i16::MAX, 2 => 0, _ => (next() >> 20) as i16 }).collect();
        let w: Vec<i16> = (0..d).map(|_| (next() >> 40) as i16).collect();
        let t = ClassifierTables::new(v, d, emb, w).unwrap();
        let logd = d.next_power_of_two().trailing_zeros() as usize;
        for kind in 0..3 {
            let r: Vec<Fp2> = (0..logd).map(|i| match kind {
                0 => Fp2::new(Fp::new(next()), Fp::new(next())),
                1 => if i % 2 == 0 { Fp2::new(pm1, pm1) } else { Fp2::new(Fp::new(next()), pm1) },
                _ => if i == 0 { Fp2::ZERO } else { Fp2::new(pm1, Fp::ZERO) },
            }).collect();
            A26_EMB_TEST.store(1, Relaxed);
            let field = t.emb_fold(&r);
            A26_EMB_TEST.store(2, Relaxed);
            let split = t.emb_fold(&r);
            A26_EMB_TEST.store(0, Relaxed);
            assert_eq!(split, field, "{v} x {d}, point kind {kind}");
        }
    }
    eprintln!("A26 | the embedding fold in split 32-bit limbs equals the per-word field fold (4 shapes, 3 point kinds, extreme words)");
}

/// **[A28] `serve` with and without seal-ahead** (`HL_A28_SEAL_AHEAD`; both modes here, whatever
/// the test process's environment says). On ONE lane with seal-ahead the second chunk's sealing
/// pass runs beside the first chunk's run and its run waits at the lane's gate: both chunks are
/// proved, every receipt passes the unchanged CLI verify, input-owner and label, and the start
/// line names the mode. Then a request refused in its sealing pass (an empty activation
/// directory) creates nothing and frees its lane: the request behind it proves.
#[test]
fn a28_serve_with_and_without_seal_ahead_proves_the_post_and_a_refusal_frees_its_lane() {
    for ahead in [true, false] {
        let cc = Cc::new(&format!("a28-ahead-{ahead}"));
        let post = Post::new(&cc, "a28s", None);
        let out = serve_for_tests_ahead(&serve_args(&cc, "1", "1"), vec![post.request(0), post.request(1)], ahead).expect("the server starts");
        let j = parsed(&out);
        assert_eq!(j[0].get("event").unwrap().str().unwrap(), "serve-start");
        assert_eq!(j[0].get("seal_ahead").unwrap(), &J::Bool(ahead), "the start line names the mode");
        assert_eq!(j.last().unwrap().get("accepted").unwrap().i64().unwrap(), 2);
        for i in 0..2 {
            let line = served(&j, &format!("c{i}"));
            assert_eq!(status(line), "proved", "{:?}", events(line));
            assert_eq!(line.get("lane").unwrap().i64().unwrap(), 0, "one lane");
        }
        for o in &post.outs {
            assert_eq!(cc.verify(o, &cc.tables), 0, "{} verifies (the unchanged CLI)", o.display());
            assert_eq!(cc.input_owner(o, &cc.tables, &post.whole), 0, "{}: input-owner on the whole content", o.display());
        }
        assert_eq!(cc.label(&[&post.outs[0], &post.outs[1]], 27), 0, "the unchanged label over both chunks");
        // a refusal in the sealing pass (before the lane's gate is taken), then an honest request
        let cc = Cc::new(&format!("a28-ahead-refuse-{ahead}"));
        let bad = Post::new(&cc, "a28r", Some(0));
        let out = serve_for_tests_ahead(&serve_args(&cc, "1", "1"), vec![bad.request(0), bad.request(1)], ahead).expect("the server starts");
        let j = parsed(&out);
        assert_eq!(status(served(&j, "c0")), "refused");
        assert!(bad.created(0).iter().all(|(_, e)| !*e), "a refused request created {:?}", bad.created(0));
        assert_eq!(status(served(&j, "c1")), "proved", "the lane carries on after a refusal");
        assert_eq!(cc.verify(&bad.outs[1], &cc.tables), 0);
        eprintln!("A28 | serve, seal-ahead {ahead}: one lane, both chunks proved and accepted by the CLI checks; a refused request created nothing and the next proved");
    }
}

/// **[A28] the seal-ahead dispatch** (`serve_lines_with`, two request threads a lane): the reader
/// sends a request to an idle lane first (three requests that arrive together land on three
/// lanes, never two on one while a lane is idle), then to the lane whose request began first,
/// never a third to a lane; a lane does hold two at once; every request is served exactly once
/// with its own line number. With one request thread a lane (as before A28) no lane ever holds two.
#[test]
fn a28_the_seal_ahead_dispatch_fills_idle_lanes_first_and_never_sends_a_third_request_to_a_lane() {
    use std::sync::atomic::{AtomicUsize, Ordering::SeqCst};
    use std::sync::Mutex;
    for per_lane in [2usize, 1] {
        let lanes = 3usize;
        let n = 14usize;
        let inflight: Vec<AtomicUsize> = (0..lanes).map(|_| AtomicUsize::new(0)).collect();
        let peak: Vec<AtomicUsize> = (0..lanes).map(|_| AtomicUsize::new(0)).collect();
        let order: Mutex<Vec<(usize, usize)>> = Mutex::new(Vec::new());
        let mut out = Vec::new();
        let (served_n, ok) = serve_lines_with(
            lanes,
            1,
            0,
            per_lane,
            (0..n).map(|i| format!("r{i}")),
            |q, line, _queued, lane| {
                assert_eq!(line, format!("r{q}"), "a request keeps its line number");
                let now = inflight[lane].fetch_add(1, SeqCst) + 1;
                peak[lane].fetch_max(now, SeqCst);
                order.lock().unwrap().push((q, lane));
                // the first requests stay in flight until all of them have been dispatched
                std::thread::sleep(std::time::Duration::from_millis(if q < lanes * per_lane { 250 } else { 20 }));
                inflight[lane].fetch_sub(1, SeqCst);
                (q % 5 != 4, format!("{q}"))
            },
            &mut |l: &str| out.push(l.to_string()),
        )
        .expect("the pools build");
        assert_eq!((served_n, ok), (n, n - n / 5), "every request served once");
        let mut seen: Vec<usize> = out.iter().map(|l| l.parse().unwrap()).collect();
        seen.sort_unstable();
        assert_eq!(seen, (0..n).collect::<Vec<_>>());
        for l in 0..lanes {
            assert!(peak[l].load(SeqCst) <= per_lane, "lane {l} held {} requests at once", peak[l].load(SeqCst));
        }
        let order = order.into_inner().unwrap();
        let lane_of = |q: usize| order.iter().find(|(x, _)| *x == q).unwrap().1;
        if per_lane == 2 {
            // requests 0..3 arrive together: one per lane (the idle lanes first), in lane order;
            // requests 3..6 are each lane's second (the lane whose request began first)
            assert_eq!((0..3).map(lane_of).collect::<Vec<_>>(), vec![0, 1, 2], "idle lanes first");
            assert_eq!((3..6).map(lane_of).collect::<Vec<_>>(), vec![0, 1, 2], "then the lane whose request began first");
            assert!((0..lanes).all(|l| peak[l].load(SeqCst) == 2), "each lane held two requests at once (seal-ahead)");
        } else {
            let mut first: Vec<usize> = (0..3).map(lane_of).collect();
            first.sort_unstable();
            assert_eq!(first, vec![0, 1, 2], "one request per lane");
        }
    }
    eprintln!("A28 | the seal-ahead dispatch: idle lanes first, then the earliest-begun lane, never three on a lane; every request served once (2 and 1 request threads a lane)");
}
