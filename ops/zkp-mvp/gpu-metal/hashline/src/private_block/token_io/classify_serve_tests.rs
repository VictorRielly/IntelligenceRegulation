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
    let _emb_lock = super::classify::classify_emb_test_lock();
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

/// M1 + M2: `classify-serve` under `HL_CLASSIFY_HOST_FAST=1` in BOTH seal-ahead modes
/// (`ahead = false` and `ahead = true`, exercising early `run_turn` release with a lane gate),
/// plus `check-serve` verifying every receipt while `HL_CLASSIFY_HOST_FAST` remains ON.
/// Strict zero-fallback and zero-verifier-hit counter equalities live in the fresh-process gate
/// `classify_host_fast_verifier_isolation_and_serve_gate` (concurrent suite tests share the
/// process-wide override and counters while `ClassifyHostFastGuard` is held).
#[test]
fn classify_host_fast_serve_and_check_serve_both_seal_ahead_modes() {
    let _on = ClassifyHostFastGuard::set(true);
    for ahead in [false, true] {
        let cc = Cc::new(&format!("chf-serve-ahead-{ahead}"));
        let post = Post::new(&cc, "chfs", None);
        let sh0 = classify_host_fast_hits_snapshot();
        let out = serve_for_tests_ahead(&serve_args(&cc, "1", "1"), vec![post.request(0), post.request(1)], ahead).expect("serve starts");
        let sh1 = classify_host_fast_hits_snapshot();
        let j = parsed(&out);
        assert_eq!(j[0].get("event").unwrap().str().unwrap(), "serve-start");
        assert_eq!(j[0].get("seal_ahead").unwrap(), &J::Bool(ahead));
        assert_eq!(j.last().unwrap().get("accepted").unwrap().i64().unwrap(), 2);
        for i in 0..2 {
            assert_eq!(status(served(&j, &format!("c{i}"))), "proved");
        }
        let sdh: [u64; 5] = std::array::from_fn(|i| sh1[i].saturating_sub(sh0[i]));
        assert!(sdh[CHF_C1_DIGESTS] > 0, "serve ahead={ahead}: C1 hits expected > 0, got {sdh:?}");
        assert!(sdh[CHF_C2_ASYNC_SINK] >= 6, "serve ahead={ahead}: C2 hits expected >= 6, got {sdh:?}");
        assert!(sdh[CHF_C3_SEQ_BOUNDARY] > 0, "serve ahead={ahead}: C3 hits expected > 0, got {sdh:?}");
        assert!(sdh[CHF_C4_CS3_SKIP] > 0, "serve ahead={ahead}: C4 hits expected > 0, got {sdh:?}");
        #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
        assert!(sdh[CHF_C5_EMB_FOLD_NEON] > 0, "serve ahead={ahead}: C5 hits expected > 0, got {sdh:?}");

        // M1: verify with check-serve while HL_CLASSIFY_HOST_FAST is STILL ON.
        let req = check_line(&post, &cc, "cat", POLICY_RUNG_DEV, 27, &post.content, &[0, 1]);
        let cout = check_serve_for_tests(&check_args_lanes(&cc, &cc.identity, "1"), vec![req]).expect("check-serve starts");
        let cj = parsed(&cout);
        assert_eq!(status(served(&cj, "cat")), "checked");

        // Refusal in sealing pass followed by honest request on the same lane.
        let cc_ref = Cc::new(&format!("chf-serve-refuse-{ahead}"));
        let bad = Post::new(&cc_ref, "chfr", Some(0));
        let rout = serve_for_tests_ahead(&serve_args(&cc_ref, "1", "1"), vec![bad.request(0), bad.request(1)], ahead).expect("serve starts");
        let rj = parsed(&rout);
        assert_eq!(status(served(&rj, "c0")), "refused");
        assert!(bad.created(0).iter().all(|(_, e)| !*e), "refused request created {:?}", bad.created(0));
        assert_eq!(status(served(&rj, "c1")), "proved");
        assert_eq!(cc_ref.verify(&bad.outs[1], &cc_ref.tables), 0);
    }
    eprintln!("HL_CLASSIFY_HOST_FAST | M1+M2 serve (ahead=false,true) + check-serve verifier isolation verified");
}

/// Fresh-process gate test (run alone with `HL_CLASSIFY_HOST_FAST=1` in the real OS environment):
/// unconditionally asserts strict verifier isolation (`verify`, `input-owner`, and `check-serve`
/// move zero `C1..C5` hit or fallback counters) while `serve` in both seal-ahead modes hits all
/// five components with zero fallbacks.
#[test]
#[ignore = "CLASSIFY-HOST-FAST: fresh-process gate verifying strict verifier isolation and serve in both seal-ahead modes; run alone by name with HL_CLASSIFY_HOST_FAST=1"]
fn classify_host_fast_verifier_isolation_and_serve_gate() {
    assert!(
        classify_host_fast_on(),
        "run this gate test with HL_CLASSIFY_HOST_FAST=1 in the environment"
    );
    for ahead in [false, true] {
        let cc = Cc::new(&format!("chf-gate-ahead-{ahead}"));
        let post = Post::new(&cc, "chfg", None);
        let sh0 = classify_host_fast_hits_snapshot();
        let sf0 = classify_host_fast_fallbacks_snapshot();
        let out = serve_for_tests_ahead(&serve_args(&cc, "1", "1"), vec![post.request(0), post.request(1)], ahead).expect("serve starts");
        let sh1 = classify_host_fast_hits_snapshot();
        let sf1 = classify_host_fast_fallbacks_snapshot();
        let j = parsed(&out);
        assert_eq!(j.last().unwrap().get("accepted").unwrap().i64().unwrap(), 2);
        let sdh: [u64; 5] = std::array::from_fn(|i| sh1[i] - sh0[i]);
        let sdf: [u64; 5] = std::array::from_fn(|i| sf1[i] - sf0[i]);
        assert!(sdh[CHF_C1_DIGESTS] > 0 && sdh[CHF_C2_ASYNC_SINK] >= 6 && sdh[CHF_C3_SEQ_BOUNDARY] > 0 && sdh[CHF_C4_CS3_SKIP] > 0, "serve ahead={ahead}: expected C1..C4 > 0, got {sdh:?}");
        #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
        assert!(sdh[CHF_C5_EMB_FOLD_NEON] > 0, "serve ahead={ahead}: expected C5 > 0, got {sdh:?}");
        assert_eq!(sdf, [0; 5], "serve ahead={ahead}: expected 0 fallbacks, got {sdf:?}");

        // Unconditional M1 check on check-serve (real HL_CLASSIFY_HOST_FAST=1 env, no concurrent tests).
        let req = check_line(&post, &cc, "cat", POLICY_RUNG_DEV, 27, &post.content, &[0, 1]);
        let vh0 = classify_host_fast_hits_snapshot();
        let vf0 = classify_host_fast_fallbacks_snapshot();
        let cout = check_serve_for_tests(&check_args_lanes(&cc, &cc.identity, "1"), vec![req]).expect("check-serve starts");
        let vh1 = classify_host_fast_hits_snapshot();
        let vf1 = classify_host_fast_fallbacks_snapshot();
        assert_eq!(status(served(&parsed(&cout), "cat")), "checked");
        assert_eq!(vh1, vh0, "M1 gate: check-serve ahead={ahead} hit fast path: before={vh0:?} after={vh1:?}");
        assert_eq!(vf1, vf0, "M1 gate: check-serve ahead={ahead} recorded fallback: before={vf0:?} after={vf1:?}");

        // Unconditional M1 check on CLI verify + input-owner.
        let ch0 = classify_host_fast_hits_snapshot();
        let cf0 = classify_host_fast_fallbacks_snapshot();
        for o in &post.outs {
            assert_eq!(cc.verify(o, &cc.tables), 0);
            assert_eq!(cc.input_owner(o, &cc.tables, &post.whole), 0);
        }
        let ch1 = classify_host_fast_hits_snapshot();
        let cf1 = classify_host_fast_fallbacks_snapshot();
        assert_eq!(ch1, ch0, "M1 gate: CLI verify/input-owner ahead={ahead} hit fast path: before={ch0:?} after={ch1:?}");
        assert_eq!(cf1, cf0, "M1 gate: CLI verify/input-owner ahead={ahead} recorded fallback: before={cf0:?} after={cf1:?}");
    }
    eprintln!("HL_CLASSIFY_HOST_FAST | GATE PASS: strict verifier isolation (check-serve + CLI verify/input-owner) and serve (ahead=false,true) all green");
}

/// Fresh-process gate test (run alone with `HL_HOST_FAST=1 HL_CLASSIFY_HOST_FAST=1 HL_HOST_FAST_W2=1`):
/// verifies that resident `classify-serve` under BOTH `HL_CLASSIFY_HOST_FAST=1` and `HL_HOST_FAST_W2=1`
/// hits both `CHF_C1..C5` (including C4 CS-3 skip) AND `HF_W2_SEAL_HIST` (W2-2 ownership-bound
/// `SealedWitness` passed through `seal_chain_keeping_fast` -> `CliSourceFast::witness_sealed` ->
/// `prove_classify_run_loop_fast` -> `prove_core_sealed`) with zero fallbacks in both seal-ahead modes,
/// while `check-serve` moves zero counters on all three host-fast switches.
#[test]
#[ignore = "HOST-FAST-W2 + CLASSIFY-HOST-FAST: fresh-process gate verifying combined classify-serve W2-2 + C1..C5 hits and check-serve verifier isolation; run alone with HL_HOST_FAST=1 HL_CLASSIFY_HOST_FAST=1 HL_HOST_FAST_W2=1"]
fn classify_host_fast_plus_w2_serve_gate() {
    assert!(
        crate::zk::host_fast_on() && classify_host_fast_on() && crate::zk::host_fast_w2_on(),
        "run this gate test with HL_HOST_FAST=1 HL_CLASSIFY_HOST_FAST=1 HL_HOST_FAST_W2=1 in the environment"
    );
    for ahead in [false, true] {
        let cc = Cc::new(&format!("chf-w2-gate-ahead-{ahead}"));
        let post = Post::new(&cc, "chfw2", None);
        let ch0 = classify_host_fast_hits_snapshot();
        let cf0 = classify_host_fast_fallbacks_snapshot();
        let wh0 = crate::zk::host_fast_w2_hits_for_test();
        let wf0 = crate::zk::host_fast_w2_fallbacks_for_test();
        let out = serve_for_tests_ahead(&serve_args(&cc, "1", "1"), vec![post.request(0), post.request(1)], ahead).expect("serve starts");
        let ch1 = classify_host_fast_hits_snapshot();
        let cf1 = classify_host_fast_fallbacks_snapshot();
        let wh1 = crate::zk::host_fast_w2_hits_for_test();
        let wf1 = crate::zk::host_fast_w2_fallbacks_for_test();
        let j = parsed(&out);
        assert_eq!(j.last().unwrap().get("accepted").unwrap().i64().unwrap(), 2);
        let cdh: [u64; 5] = std::array::from_fn(|i| ch1[i] - ch0[i]);
        let cdf: [u64; 5] = std::array::from_fn(|i| cf1[i] - cf0[i]);
        let wdh: [u64; 10] = std::array::from_fn(|i| wh1[i] - wh0[i]);
        let wdf: [u64; 5] = std::array::from_fn(|i| wf1[i] - wf0[i]);
        assert!(cdh[CHF_C1_DIGESTS] > 0 && cdh[CHF_C2_ASYNC_SINK] >= 6 && cdh[CHF_C3_SEQ_BOUNDARY] > 0 && cdh[CHF_C4_CS3_SKIP] > 0, "serve ahead={ahead}: expected C1..C4 > 0, got {cdh:?}");
        #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
        assert!(cdh[CHF_C5_EMB_FOLD_NEON] > 0, "serve ahead={ahead}: expected C5 > 0, got {cdh:?}");
        assert_eq!(cdf, [0; 5], "serve ahead={ahead}: expected 0 classify_host_fast fallbacks, got {cdf:?}");
        assert_eq!(wdh[crate::zk::HF_W2_SEAL_HIST], 2, "serve ahead={ahead}: expected HF_W2_SEAL_HIST == 2 (1 layer x 2 chunks), got {wdh:?}");
        assert!(wdh[crate::zk::HF_W2_TWOTERM_EXP] > 0 && wdh[crate::zk::HF_W2_PAR_OPEN] > 0 && wdh[crate::zk::HF_W2_MASK_EVAL] > 0, "serve ahead={ahead}: expected W2 block hits > 0, got {wdh:?}");
        if std::env::var("HL_HOST_FAST_ASYNC_DROP").as_deref() != Ok("1") {
            assert_eq!(wdh[crate::zk::HF_W2_ASYNC_DROP], 0, "serve ahead={ahead}: default AD must not fire HF_W2_ASYNC_DROP, got {wdh:?}");
        }
        assert_eq!(wdf, [0; 5], "serve ahead={ahead}: expected 0 W2 fallbacks, got {wdf:?}");

        let req = check_line(&post, &cc, "cat", POLICY_RUNG_DEV, 27, &post.content, &[0, 1]);
        let vhf0 = crate::zk::host_fast_hits_for_test();
        let vhff0 = crate::zk::host_fast_fallbacks_for_test();
        let vch0 = classify_host_fast_hits_snapshot();
        let vcf0 = classify_host_fast_fallbacks_snapshot();
        let vwh0 = crate::zk::host_fast_w2_hits_for_test();
        let vwf0 = crate::zk::host_fast_w2_fallbacks_for_test();
        let cout = check_serve_for_tests(&check_args_lanes(&cc, &cc.identity, "1"), vec![req]).expect("check-serve starts");
        let vhf1 = crate::zk::host_fast_hits_for_test();
        let vhff1 = crate::zk::host_fast_fallbacks_for_test();
        let vch1 = classify_host_fast_hits_snapshot();
        let vcf1 = classify_host_fast_fallbacks_snapshot();
        let vwh1 = crate::zk::host_fast_w2_hits_for_test();
        let vwf1 = crate::zk::host_fast_w2_fallbacks_for_test();
        assert_eq!(status(served(&parsed(&cout), "cat")), "checked");
        assert_eq!(vhf1, vhf0, "check-serve ahead={ahead} hit host_fast");
        assert_eq!(vhff1, vhff0, "check-serve ahead={ahead} recorded host_fast fallback");
        assert_eq!(vch1, vch0, "check-serve ahead={ahead} hit classify_host_fast");
        assert_eq!(vcf1, vcf0, "check-serve ahead={ahead} recorded classify_host_fast fallback");
        assert_eq!(vwh1, vwh0, "check-serve ahead={ahead} hit host_fast_w2");
        assert_eq!(vwf1, vwf0, "check-serve ahead={ahead} recorded host_fast_w2 fallback");
    }
    eprintln!("HL_CLASSIFY_HOST_FAST + HL_HOST_FAST_W2 | COMBINED SERVE GATE PASS: both switches hit (including C4 + W2-2 SealedWitness) with 0 fallbacks and strict 3-switch check-serve isolation");
}

/// **[HOST-FAST-W2] Read B M3(1) fresh-process gate: `HL_HOST_FAST_W2=1` ALONE (`HL_CLASSIFY_HOST_FAST` unset)**
/// exercises resident `classify-serve` through `seal_chain_keeping` -> `CliSource::witness_sealed` ->
/// `prove_classify_run_with` -> `prove_core_sealed` (without `classify_host_fast`), asserting
/// `HF_W2_SEAL_HIST == 2` with zero W2 fallbacks, zero `classify_host_fast` counter movement,
/// and `check-serve` acceptance with zero counter movement. (Checks counters and acceptance only;
/// byte-identical classifier proof parity with W2 on vs off is tested in
/// `w16r2_tests::host_fast_w2_all_call_sites_byte_identical`.)
#[test]
#[ignore = "HOST-FAST-W2: fresh-process gate exercising classifier seal_chain_keeping -> CliSource::witness_sealed -> prove_classify_run_with with HL_HOST_FAST_W2=1 alone (HL_CLASSIFY_HOST_FAST unset)"]
fn host_fast_w2_alone_classify_serve_gate() {
    assert!(
        crate::zk::host_fast_w2_on() && !classify_host_fast_on(),
        "run this gate test with HL_HOST_FAST_W2=1 and HL_CLASSIFY_HOST_FAST unset"
    );
    for ahead in [false, true] {
        let cc = Cc::new(&format!("w2-alone-gate-ahead-{ahead}"));
        let post = Post::new(&cc, "w2alone", None);
        let ch0 = classify_host_fast_hits_snapshot();
        let cf0 = classify_host_fast_fallbacks_snapshot();
        let wh0 = crate::zk::host_fast_w2_hits_for_test();
        let wf0 = crate::zk::host_fast_w2_fallbacks_for_test();
        let out = serve_for_tests_ahead(&serve_args(&cc, "1", "1"), vec![post.request(0), post.request(1)], ahead).expect("serve starts");
        let ch1 = classify_host_fast_hits_snapshot();
        let cf1 = classify_host_fast_fallbacks_snapshot();
        let wh1 = crate::zk::host_fast_w2_hits_for_test();
        let wf1 = crate::zk::host_fast_w2_fallbacks_for_test();
        let j = parsed(&out);
        assert_eq!(j.last().unwrap().get("accepted").unwrap().i64().unwrap(), 2);
        let wdh: [u64; 10] = std::array::from_fn(|i| wh1[i] - wh0[i]);
        let wdf: [u64; 5] = std::array::from_fn(|i| wf1[i] - wf0[i]);
        assert_eq!(ch1, ch0, "W2-alone ahead={ahead} must not hit classify_host_fast");
        assert_eq!(cf1, cf0, "W2-alone ahead={ahead} must not record classify_host_fast fallbacks");
        assert_eq!(wdh[crate::zk::HF_W2_SEAL_HIST], 2, "W2-alone ahead={ahead}: expected HF_W2_SEAL_HIST == 2, got {wdh:?}");
        assert!(wdh[crate::zk::HF_W2_PAR_OPEN] > 0 && wdh[crate::zk::HF_W2_MASK_EVAL] > 0, "W2-alone ahead={ahead}: expected W2 hits > 0, got {wdh:?}");
        if std::env::var("HL_HOST_FAST_ASYNC_DROP").as_deref() != Ok("1") {
            assert_eq!(wdh[crate::zk::HF_W2_ASYNC_DROP], 0, "W2-alone ahead={ahead}: default AD must not fire HF_W2_ASYNC_DROP");
        }
        assert_eq!(wdf, [0; 5], "W2-alone ahead={ahead}: expected 0 W2 fallbacks, got {wdf:?}");

        let req = check_line(&post, &cc, "cat", POLICY_RUNG_DEV, 27, &post.content, &[0, 1]);
        let vwh0 = crate::zk::host_fast_w2_hits_for_test();
        let vwf0 = crate::zk::host_fast_w2_fallbacks_for_test();
        let cout = check_serve_for_tests(&check_args_lanes(&cc, &cc.identity, "1"), vec![req]).expect("check-serve starts");
        assert_eq!(status(served(&parsed(&cout), "cat")), "checked");
        assert_eq!(crate::zk::host_fast_w2_hits_for_test(), vwh0, "W2-alone check-serve hit host_fast_w2");
        assert_eq!(crate::zk::host_fast_w2_fallbacks_for_test(), vwf0, "W2-alone check-serve recorded host_fast_w2 fallback");
    }
    eprintln!("HL_HOST_FAST_W2 ALONE | CLASSIFY SERVE GATE PASS: seal_chain_keeping -> CliSource::witness_sealed -> prove_classify_run_with hit HF_W2_SEAL_HIST=2 with 0 fallbacks");
}

/// **[HOST-FAST-W2] Fix-read M2 (sealing passes #1 & #2: `seal_chain_keeping` and
/// `seal_chain_keeping_fast`)**:
/// plants a byte-table lookup miss inside `witness::build_shaped` (via thread-local
/// `ForgeSealByteMissGuard`, leaving `q` and `x_out` unchanged) and drives it through BOTH
/// `seal_chain_keeping` (hits `check_lookup_misses_sealed(..., false)`) and
/// `seal_chain_keeping_fast` (hits `check_lookup_misses_sealed(..., true)`) over resident
/// `KeptResidentBlocks` with `budget = u64::MAX`, for both `HL_HOST_FAST_W2=0` and `=1`,
/// asserting the exact expected wrapped refusal text in every case.
#[test]
fn host_fast_w2_seal_chain_keeping_and_fast_planted_lookup_miss_refusal() {
    use crate::private_block::protocol::LOOKUP_MISS_REFUSAL;
    use crate::private_block::review_d24_tests::ForgeSealByteMissGuard;

    let _hf_lock = crate::zk::host_fast_test_lock();
    struct Reset {
        prev_w2: Option<bool>,
    }
    impl Drop for Reset {
        fn drop(&mut self) {
            crate::zk::set_host_fast_w2_for_test(self.prev_w2);
        }
    }
    let _guard = Reset {
        prev_w2: crate::zk::set_host_fast_w2_for_test(Some(true)),
    };

    let cc = Cc::new("w2-seal-miss");
    let (p, loaded) = ExportPublic::load_keeping(&cc.export, classify_run_profile_of, true).expect("load_keeping");
    let kept_blocks: Vec<std::sync::Arc<KeptBlock>> = loaded
        .into_iter()
        .enumerate()
        .map(|(k, b)| {
            let stage = p.model.layers.get(k).and_then(|r| r.shape_at(&p.sh).ok());
            KeptBlock::new(b, stage.as_slice())
        })
        .collect();
    let seq = SeqIn::InExport("s0".to_string());
    let x_in0 = seq.load(&p.ex, &p.sh, p.layers[0]).expect("x_in0").0;

    // Control: honest sealing passes succeed with W2 on and keep the sealed witness
    {
        let mut rb = KeptResidentBlocks(&kept_blocks);
        let (_, kept) = seal_chain_keeping(&p, &seq, &mut rb, x_in0.clone(), u64::MAX).expect("honest seal_chain_keeping");
        assert!(kept[0].is_some(), "seal_chain_keeping must keep SealedWitness");
    }
    {
        let mut rb = KeptResidentBlocks(&kept_blocks);
        let (_, kept, _) = seal_chain_keeping_fast(&p, &seq, &mut rb, x_in0.clone(), u64::MAX).expect("honest seal_chain_keeping_fast");
        assert!(kept[0].is_some(), "seal_chain_keeping_fast must keep SealedWitness");
    }

    let want = format!(
        "block 0: {LOOKUP_MISS_REFUSAL}; the table family that missed: the byte table (the class of the miss only, never a count — ruling K-2). It is refused before this block's A mask rows are drawn, its A commitment is made or any challenge of it is drawn. What precedes the refusal: in a single block, the transcript header's absorbs; inside a run, the run header, every earlier stage, this stage's header absorbs and, below the last block, the boundary B_k to the next block, drawn from the run's stream, committed and absorbed (ruling M-9). (the sealing pass, before any header)"
    );

    for w2_on in [false, true] {
        crate::zk::set_host_fast_w2_for_test(Some(w2_on));
        {
            let forge = ForgeSealByteMissGuard::on();
            let mut rb = KeptResidentBlocks(&kept_blocks);
            let err = seal_chain_keeping(&p, &seq, &mut rb, x_in0.clone(), u64::MAX)
                .err()
                .unwrap_or_else(|| panic!("seal_chain_keeping (w2={w2_on}) admitted a planted byte-table lookup miss"));
            assert_eq!(forge.count(), 1, "seal_chain_keeping forge count (w2={w2_on})");
            assert_eq!(err, want, "seal_chain_keeping refusal mismatch (w2={w2_on})");
        }
        {
            let forge = ForgeSealByteMissGuard::on();
            let mut rb = KeptResidentBlocks(&kept_blocks);
            let err = seal_chain_keeping_fast(&p, &seq, &mut rb, x_in0.clone(), u64::MAX)
                .err()
                .unwrap_or_else(|| panic!("seal_chain_keeping_fast (w2={w2_on}) admitted a planted byte-table lookup miss"));
            assert_eq!(forge.count(), 1, "seal_chain_keeping_fast forge count (w2={w2_on})");
            assert_eq!(err, want, "seal_chain_keeping_fast refusal mismatch (w2={w2_on})");
        }
    }
}

/// **[HOST-FAST-W2] Fix-read M1 fresh-process gate: R13 accuracy-stack + W16R2 accuracy-stack
/// verifier isolation through the receipt doors (`check-serve`, `verify`, `input-owner`) with ALL
/// THREE switches ON (`HL_HOST_FAST=1 HL_CLASSIFY_HOST_FAST=1 HL_HOST_FAST_W2=1`).**
///
/// Builds an on-disk R13 accuracy-stack (`R13_RUNG_H24`) fixture from `HL_R13_LOADER_FIXTURES/r13-h24-dense`:
/// 1. **Native R13 accuracy stack (`R13_RUNG_H24`)**: proves 2 chunks via `prove_with_public`
///    (resident `KeptBlock` + `SharedProve`), asserting the prover hits `HF_H4_ACC_FOLD > 0`,
///    `HF_W2_FOLD_TILED > 0`, `HF_W2_SEAL_HIST == 2`, and `CHF_C1..C4 > 0` with 0 fallbacks; then
///    verifies the on-disk receipts through `check_one` (the `check-serve` receipt door:
///    `door_statement` B-3 re-render + bounded segment reads + `verify_classify_run_with` +
///    statement publication + `owner_check_input` + `aggregate_label`, plus a second `check_one`
///    re-verifying the published statement byte-for-byte), asserting EXACT ZERO counter movement
///    (hits and fallbacks) across all three switches.
/// 2. **W16R2 accuracy stack (`W16R2_RUNG_H24`, `--dev-w16r2-public-content-only`)** on the same
///    export: proves via `serve_for_tests`, asserting `HF_H4_ACC_FOLD > 0`, `HF_W2_FOLD_TILED > 0`,
///    `HF_W2_SEAL_HIST == 2`, and `CHF_C1..C4 > 0` with 0 fallbacks; then verifies through the
///    public CLI doors `classify_verify_command`, `classify_input_owner_command`, and
///    `check_serve_for_tests`, asserting EXACT ZERO counter movement across all three switches.
#[test]
#[ignore = "HOST-FAST-W2 M1: fresh-process R13 + W16R2 accuracy-stack receipt-door verifier-isolation gate; run alone with HL_HOST_FAST=1 HL_CLASSIFY_HOST_FAST=1 HL_HOST_FAST_W2=1 -- --ignored --exact --test-threads=1"]
fn host_fast_all_three_switches_r13_receipt_door_verifier_isolation_gate() {
    use crate::private_block::layout::{Ids, A_X2};
    use crate::private_block::run::RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST;
    use crate::private_block::shape::R13_RUNG_H24;
    use crate::private_block::token_io::classify_cli_tests::{
        add_classifier_parameters, fixture_root, write_classifier_tables,
    };
    use crate::private_block::token_io::classify_tied::{
        dev_tied_tensor_bytes, load_tied_classifier_tables, recompute_tied_classifier, TiedSource,
        DEV_TIED_TENSOR_FILE,
    };
    use crate::private_block::token_io::tests::{generic_tables, norm};
    use crate::private_block::trained_block::{hex, sha256, TrainedExport};
    use crate::private_block::witness;
    use std::io::Write as _;
    use std::os::unix::fs::OpenOptionsExt as _;

    assert!(
        crate::zk::host_fast_on() && classify_host_fast_on() && crate::zk::host_fast_w2_on(),
        "run this fresh-process gate with HL_HOST_FAST=1 HL_CLASSIFY_HOST_FAST=1 HL_HOST_FAST_W2=1 in the environment"
    );

    type AllSnap = ([u64; 8], [u64; 5], [u64; 5], [u64; 5], [u64; 10], [u64; 5]);
    let snap = || -> AllSnap {
        (
            crate::zk::host_fast_hits_for_test(),
            crate::zk::host_fast_fallbacks_for_test(),
            classify_host_fast_hits_snapshot(),
            classify_host_fast_fallbacks_snapshot(),
            crate::zk::host_fast_w2_hits_for_test(),
            crate::zk::host_fast_w2_fallbacks_for_test(),
        )
    };
    let assert_zero_delta = |label: &str, before: AllSnap, after: AllSnap| {
        assert_eq!(after.0, before.0, "{label}: verifier moved host_fast hits: before={:?} after={:?}", before.0, after.0);
        assert_eq!(after.1, before.1, "{label}: verifier moved host_fast fallbacks: before={:?} after={:?}", before.1, after.1);
        assert_eq!(after.2, before.2, "{label}: verifier moved classify_host_fast hits: before={:?} after={:?}", before.2, after.2);
        assert_eq!(after.3, before.3, "{label}: verifier moved classify_host_fast fallbacks: before={:?} after={:?}", before.3, after.3);
        assert_eq!(after.4, before.4, "{label}: verifier moved host_fast_w2 hits: before={:?} after={:?}", before.4, after.4);
        assert_eq!(after.5, before.5, "{label}: verifier moved host_fast_w2 fallbacks: before={:?} after={:?}", before.5, after.5);
    };

    fn copy_tree(src: &Path, dst: &Path, skip_seq: bool) {
        std::fs::create_dir_all(dst).unwrap();
        for e in std::fs::read_dir(src).unwrap() {
            let e = e.unwrap();
            let name = e.file_name().to_string_lossy().to_string();
            if skip_seq && name.starts_with("seq_") {
                continue;
            }
            let (s, d) = (e.path(), dst.join(&name));
            if e.file_type().unwrap().is_dir() {
                copy_tree(&s, &d, skip_seq);
            } else {
                std::fs::copy(&s, &d).unwrap();
            }
        }
    }

    let r13_src = std::env::var_os("HL_R13_LOADER_FIXTURES")
        .map(PathBuf::from)
        .unwrap_or_else(|| Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures"))
        .join("r13-h24-dense");
    assert!(
        r13_src.join("profile.json").exists(),
        "missing R13 loader fixture {}: set HL_R13_LOADER_FIXTURES",
        r13_src.display()
    );

    let root = fixture_root().join(format!("tio-r13-m1-gate-{}", std::process::id()));
    let owners = fixture_root().join(format!("tio-r13-m1-owners-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    let _ = std::fs::remove_dir_all(&owners);
    std::fs::create_dir_all(&root).unwrap();
    std::fs::create_dir_all(&owners).unwrap();
    struct Cleanup(PathBuf, PathBuf);
    impl Drop for Cleanup {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
            let _ = std::fs::remove_dir_all(&self.1);
        }
    }
    let _cleanup = Cleanup(root.clone(), owners.clone());

    let policy = policy_rung_dev();
    let export = root.join("export");
    copy_tree(&r13_src, &export, false);
    let pj = export.join("profile.json");
    let ptext = std::fs::read_to_string(&pj).unwrap();
    assert_eq!(ptext.matches("\"residual_unit\": 1.0,").count(), 1, "r13-h24-dense residual_unit");
    std::fs::write(&pj, ptext.replace("\"residual_unit\": 1.0,", "\"residual_unit\": 0.0053663705198366135,")).unwrap();
    add_classifier_parameters(&export, 1, norm(), &policy);

    let ex = TrainedExport::load(&export).expect("TrainedExport::load");
    let c = ex.run_constants(&ex.layers).expect("run_constants");
    let sh_seed = ex.shape_for(&c).expect("shape_for");
    assert_eq!(sh_seed.profile, R13_RUNG_H24);

    let tables_dir = root.join("tables");
    std::fs::create_dir_all(&tables_dir).unwrap();
    std::fs::write(tables_dir.join(DEV_TIED_TENSOR_FILE), dev_tied_tensor_bytes()).unwrap();
    let tied = recompute_tied_classifier(
        TiedSource::DevRung,
        &export,
        &tables_dir,
        &policy,
        ex.residual_unit,
        sh_seed.width,
        &ex.profile_sha256,
    )
    .expect("recompute_tied_classifier");
    let emb = tied.emb.clone().expect("dev embedding");
    let g = generic_tables(sh_seed.width, 0x636c_6363);
    let tt = TokenTables::new(g.v, g.d, emb.clone(), g.head, g.mult).unwrap();
    write_classifier_tables(&tables_dir, &tt, &tied.w, tied.bos, tied.norm, &policy);

    let verifier_copy = root.join("verifier-copy");
    copy_tree(&export, &verifier_copy, true);

    let r13_profile_of = |sh: &crate::private_block::shape::Shape| -> Result<&'static str, String> {
        assert_eq!(sh.profile, R13_RUNG_H24);
        Ok(RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST)
    };
    let (p_r13, loaded_r13) = ExportPublic::load_keeping(&export, r13_profile_of, true).expect("R13 load_keeping");
    let blocks_r13: Vec<std::sync::Arc<KeptBlock>> = loaded_r13
        .into_iter()
        .enumerate()
        .map(|(k, b)| {
            let stage = p_r13.model.layers.get(k).and_then(|r| r.shape_at(&p_r13.sh).ok());
            KeptBlock::new(b, stage.as_slice())
        })
        .collect();
    let bound_r13 = load_tied_classifier_tables(&p_r13, &export, &tables_dir, &policy).expect("R13 load_tied_classifier_tables");

    // 27-token post split into 2 chunks ([0, 23) and [4, 27))
    let whole_ids: Vec<u64> = (9..=31).chain([33, 34, 35, 36]).collect();
    assert_eq!(whole_ids.len(), 27);
    let whole_str = whole_ids.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",");
    let content_file = owners.join("content.txt");
    {
        let mut f = std::fs::OpenOptions::new().create_new(true).write(true).mode(0o600).open(&content_file).unwrap();
        f.write_all(whole_str.as_bytes()).unwrap();
    }

    // Write per-chunk seq dirs using the R13 accuracy block builder
    let ssh0 = p_r13.model.layers[0].shape_at(&p_r13.sh).expect("stage 0 shape");
    let ids0 = Ids::new(&ssh0).expect("stage 0 Ids");
    let write_r13_seq = |dir: &Path, tokens: &[u64]| {
        let d = p_r13.sh.width;
        let x_in: Vec<i16> = tokens.iter().flat_map(|id| emb[*id as usize * d..(*id as usize + 1) * d].iter().copied()).collect();
        let w = witness::build_for_block(&ssh0, blocks_r13[0].block(), &x_in).expect("R13 witness");
        let plane = &w.planes[ids0.at(A_X2)];
        let x_out: Vec<i16> = (0..p_r13.sh.tokens)
            .flat_map(|t| (0..p_r13.sh.width).map(move |i| (t, i)))
            .map(|(t, i)| i16::try_from(plane[t * p_r13.sh.d_pad + i]).unwrap())
            .collect();
        let xi: Vec<u8> = x_in.iter().flat_map(|v| v.to_le_bytes()).collect();
        let xo: Vec<u8> = x_out.iter().flat_map(|v| v.to_le_bytes()).collect();
        std::fs::create_dir_all(dir).unwrap();
        std::fs::write(dir.join("x_in_L00.bin"), &xi).unwrap();
        std::fs::write(dir.join("x_out_L00.bin"), &xo).unwrap();
        let arr = |name: &str, b: &[u8]| {
            format!(
                "\"{name}\": {{\"file\": \"{name}.bin\", \"dtype\": \"int16\", \"shape\": [{}, {}], \"sha256\": \"{}\"}}",
                p_r13.sh.tokens,
                p_r13.sh.width,
                hex(&sha256(b))
            )
        };
        std::fs::write(
            dir.join("manifest.json"),
            format!(
                "{{\"kind\": \"sequence\", \"id\": \"s0\", \"T\": {}, \"arrays\": {{{}, {}}}}}\n",
                p_r13.sh.tokens,
                arr("x_in_L00", &xi),
                arr("x_out_L00", &xo)
            ),
        )
        .unwrap();
    };
    let chunks_tokens = [
        item_tokens(&policy, &whole_ids[0..23]),
        item_tokens(&policy, &whole_ids[4..27]),
    ];
    let seq_dirs = [owners.join("seq-c0"), owners.join("seq-c1")];
    for (dir, toks) in seq_dirs.iter().zip(chunks_tokens.iter()) {
        write_r13_seq(dir, toks);
    }

    // ---- 1. Native R13 accuracy stack (R13_RUNG_H24) through prove_with_public -> check-serve (check_one) ----
    {
        let outs = [root.join("r13-c0"), root.join("r13-c1")];
        let odirs = [owners.join("r13-own-c0"), owners.join("r13-own-c1")];
        let pb = snap();
        for ci in 0..2 {
            let args = vec![
                ("--export".to_string(), export.display().to_string()),
                ("--tables".to_string(), tables_dir.display().to_string()),
                ("--policy".to_string(), POLICY_RUNG_DEV.to_string()),
                ("--content-file".to_string(), content_file.display().to_string()),
                ("--chunk".to_string(), ci.to_string()),
                ("--seq-dir".to_string(), seq_dirs[ci].display().to_string()),
                ("--out".to_string(), outs[ci].display().to_string()),
                ("--owner-dir".to_string(), odirs[ci].display().to_string()),
            ];
            let shared = SharedProve {
                p: &p_r13,
                bound: &bound_r13,
                whole: &whole_ids,
                claim: None,
                blocks: Some(&blocks_r13),
                witness_budget: 1u64 << 30,
                run_gate: None,
            };
            prove_with_public(&args, Some(shared)).expect("R13 prove_with_public");
        }
        let pa = snap();
        assert!(pa.0[crate::zk::HF_H4_ACC_FOLD] > pb.0[crate::zk::HF_H4_ACC_FOLD], "R13 prover must hit HF_H4_ACC_FOLD: before={:?} after={:?}", pb.0, pa.0);
        assert!(pa.4[crate::zk::HF_W2_FOLD_TILED] > pb.4[crate::zk::HF_W2_FOLD_TILED], "R13 prover must hit HF_W2_FOLD_TILED: before={:?} after={:?}", pb.4, pa.4);
        assert_eq!(pa.4[crate::zk::HF_W2_SEAL_HIST] - pb.4[crate::zk::HF_W2_SEAL_HIST], 2, "R13 prover must hit HF_W2_SEAL_HIST == 2");
        assert!(pa.2[CHF_C1_DIGESTS] > pb.2[CHF_C1_DIGESTS] && pa.2[CHF_C2_ASYNC_SINK] > pb.2[CHF_C2_ASYNC_SINK] && pa.2[CHF_C3_SEQ_BOUNDARY] > pb.2[CHF_C3_SEQ_BOUNDARY] && pa.2[CHF_C4_CS3_SKIP] > pb.2[CHF_C4_CS3_SKIP], "R13 prover must hit CHF_C1..C4");
        assert_eq!(pa.1, pb.1, "R13 prover W1 fallbacks");
        assert_eq!(pa.3, pb.3, "R13 prover classify_host_fast fallbacks");
        assert_eq!(pa.5, pb.5, "R13 prover W2 fallbacks");

        // Fresh verifier-side ResidentClassifier + CheckServer over verifier_copy
        refuse_prover_private_entries(&verifier_copy).expect("verifier_copy is public-only");
        let (vp, vloaded) = ExportPublic::load_keeping(&verifier_copy, r13_profile_of, true).expect("R13 verifier load_keeping");
        let vblocks: Vec<std::sync::Arc<KeptBlock>> = vloaded
            .into_iter()
            .enumerate()
            .map(|(k, b)| {
                let stage = vp.model.layers.get(k).and_then(|r| r.shape_at(&vp.sh).ok());
                KeptBlock::new(b, stage.as_slice())
            })
            .collect();
        let vbound = load_tied_classifier_tables(&vp, &verifier_copy, &tables_dir, &policy).expect("R13 verifier bound tables");
        let srv = CheckServer {
            res: ResidentClassifier {
                export: verifier_copy.clone(),
                tables_dir: tables_dir.clone(),
                label: crate::private_block::token_io::classify_cli::CLASSIFY_LABELS[0].to_string(),
                p: vp,
                blocks: vblocks,
                bound: vbound,
                policies: vec![POLICY_RUNG_DEV.to_string()],
                startup_s: 0.0,
            },
            min_bits: 95,
            busy: std::sync::Mutex::new(std::collections::HashSet::new()),
        };
        let chunks_json = (0..2)
            .map(|ci| {
                format!(
                    "{{\"artifact\": {}, \"decommitment\": {}}}",
                    js(outs[ci].to_str().unwrap()),
                    js(odirs[ci].join("input.dec").to_str().unwrap())
                )
            })
            .collect::<Vec<_>>()
            .join(", ");
        let req_line = format!(
            "{{\"id\": \"r13-m1\", \"policy\": {}, \"expect_total\": 27, \"content_file\": {}, \"chunks\": [{chunks_json}]}}",
            js(POLICY_RUNG_DEV),
            js(content_file.to_str().unwrap())
        );
        let req = check_request_of(&req_line).expect("check_request_of");

        let vb1 = snap();
        check_one(&srv, &req).expect("R13 check_one (first check + publish)");
        let va1 = snap();
        assert_zero_delta("R13 check-serve (check_one first)", vb1, va1);

        let vb2 = snap();
        check_one(&srv, &req).expect("R13 check_one (published re-check)");
        let va2 = snap();
        assert_zero_delta("R13 check-serve (check_one re-check)", vb2, va2);
    }

    // ---- 2. W16R2 accuracy stack (W16R2_RUNG_H24) through public serve + verify + input-owner + check-serve ----
    {
        let (pw16, _) = super::w16r2::load_export_w16r2(&verifier_copy, false).expect("W16R2 load_export");
        let w16_pin = hex(&pw16.model.identity());
        let outs = [root.join("w16-c0"), root.join("w16-c1")];
        let odirs = [owners.join("w16-own-c0"), owners.join("w16-own-c1")];
        let reqs: Vec<String> = (0..2)
            .map(|ci| {
                format!(
                    "{{\"id\": \"w{ci}\", \"content_file\": {}, \"policy\": {}, \"chunk\": {ci}, \"seq_dir\": {}, \"out\": {}, \"owner_dir\": {}}}",
                    js(content_file.to_str().unwrap()),
                    js(POLICY_RUNG_DEV),
                    js(seq_dirs[ci].to_str().unwrap()),
                    js(outs[ci].to_str().unwrap()),
                    js(odirs[ci].to_str().unwrap())
                )
            })
            .collect();
        let sargs = s(&[
            "--export", export.to_str().unwrap(),
            "--tables", tables_dir.to_str().unwrap(),
            "--policies", POLICY_RUNG_DEV,
            "--lanes", "1",
            "--lane-threads", "2",
            "--witness-cache-gib", "1",
            super::w16r2::DEV_W16R2_SWITCH,
        ]);
        let pb = snap();
        let sout = serve_for_tests(&sargs, reqs).expect("W16R2 serve_for_tests");
        let pa = snap();
        assert_eq!(parsed(&sout).last().unwrap().get("accepted").unwrap().i64().unwrap(), 2);
        assert!(pa.0[crate::zk::HF_H4_ACC_FOLD] > pb.0[crate::zk::HF_H4_ACC_FOLD], "W16R2 serve must hit HF_H4_ACC_FOLD");
        assert!(pa.4[crate::zk::HF_W2_FOLD_TILED] > pb.4[crate::zk::HF_W2_FOLD_TILED], "W16R2 serve must hit HF_W2_FOLD_TILED");
        assert_eq!(pa.4[crate::zk::HF_W2_SEAL_HIST] - pb.4[crate::zk::HF_W2_SEAL_HIST], 2, "W16R2 serve must hit HF_W2_SEAL_HIST == 2");
        assert_eq!(pa.1, pb.1, "W16R2 serve W1 fallbacks");
        assert_eq!(pa.3, pb.3, "W16R2 serve classify_host_fast fallbacks");
        assert_eq!(pa.5, pb.5, "W16R2 serve W2 fallbacks");

        // CLI `verify` and `input-owner` receipt doors on chunk 0
        let vargs = s(&[
            "--export", verifier_copy.to_str().unwrap(),
            "--tables", tables_dir.to_str().unwrap(),
            "--policy", POLICY_RUNG_DEV,
            "--artifact", outs[0].to_str().unwrap(),
            "--expect-statement", &w16_pin,
            "--min-bits", "95",
            super::w16r2::DEV_W16R2_SWITCH,
        ]);
        let vb = snap();
        assert_eq!(classify_verify_command(&vargs), 0, "W16R2 classify_verify_command");
        let va = snap();
        assert_zero_delta("W16R2 classify_verify_command", vb, va);

        let oargs = s(&[
            "--export", verifier_copy.to_str().unwrap(),
            "--tables", tables_dir.to_str().unwrap(),
            "--policy", POLICY_RUNG_DEV,
            "--artifact", outs[0].to_str().unwrap(),
            "--expect-statement", &w16_pin,
            "--min-bits", "95",
            "--decommitment", odirs[0].join("input.dec").to_str().unwrap(),
            "--content-file", content_file.to_str().unwrap(),
            super::w16r2::DEV_W16R2_SWITCH,
        ]);
        let ob = snap();
        assert_eq!(classify_input_owner_command(&oargs), 0, "W16R2 classify_input_owner_command");
        let oa = snap();
        assert_zero_delta("W16R2 classify_input_owner_command", ob, oa);

        // Resident `check-serve` door across both chunks
        let cargs = s(&[
            "--export", verifier_copy.to_str().unwrap(),
            "--tables", tables_dir.to_str().unwrap(),
            "--policies", POLICY_RUNG_DEV,
            "--expect-statement", &w16_pin,
            "--min-bits", "95",
            "--lanes", "1",
            "--lane-threads", "2",
            super::w16r2::DEV_W16R2_SWITCH,
        ]);
        let chunks_json = (0..2)
            .map(|ci| {
                format!(
                    "{{\"artifact\": {}, \"decommitment\": {}}}",
                    js(outs[ci].to_str().unwrap()),
                    js(odirs[ci].join("input.dec").to_str().unwrap())
                )
            })
            .collect::<Vec<_>>()
            .join(", ");
        let creq = format!(
            "{{\"id\": \"w16-m1\", \"policy\": {}, \"expect_total\": 27, \"content_file\": {}, \"chunks\": [{chunks_json}]}}",
            js(POLICY_RUNG_DEV),
            js(content_file.to_str().unwrap())
        );
        let cb = snap();
        let cout = check_serve_for_tests(&cargs, vec![creq]).expect("W16R2 check_serve_for_tests");
        let ca = snap();
        assert_eq!(status(served(&parsed(&cout), "w16-m1")), "checked");
        assert_zero_delta("W16R2 check_serve_for_tests", cb, ca);
    }

    eprintln!("M1 RECEIPT-DOOR VERIFIER ISOLATION GATE PASS: R13_RUNG_H24 (prove_with_public -> check_one x2) + W16R2_RUNG_H24 (serve -> verify + input-owner + check-serve) hit HF_H4_ACC_FOLD & HF_W2_FOLD_TILED on prover with 0 fallbacks and moved 0 counters across all 3 switches on every verifier door");
}

#[test]
fn serve_lines_with_recovers_from_panic_per_lane_1_and_2_with_k2_privacy() {
    for per_lane in [1usize, 2] {
        let lanes = 2usize;
        // 12 requests with 6 panics (> lanes * per_lane = 4) proves DispatchGuard
        // releases `load_r` and notifies `freed_r` on every unwind with zero deadlock.
        let n = 12usize;
        let mut out = Vec::new();
        let (served_n, ok) = serve_lines_with(
            lanes,
            1,
            0,
            per_lane,
            (0..n).map(|q| format!("SECRET_LINE_TOKEN_{q}")),
            |q, line, _queued, lane| {
                if q % 2 == 0 {
                    panic!("SECRET_WITNESS_PAYLOAD_42_req_{q}:{line}");
                }
                (
                    true,
                    format!("{{\"event\":\"served\",\"request\":{q},\"status\":\"ok\",\"lane\":{lane}}}"),
                )
            },
            &mut |l: &str| out.push(l.to_string()),
        )
        .expect("serve_lines_with must not fail or unwind on request panic");

        assert_eq!((served_n, ok), (n, n / 2), "per_lane={per_lane}: expected all {n} served and {} ok", n / 2);
        assert_eq!(out.len(), n, "per_lane={per_lane}: one emitted JSON line per request");

        let mut seen_ok = Vec::new();
        let mut seen_err = Vec::new();
        for raw in &out {
            // K-2 privacy: neither the panic payload nor the input line may ever appear in emitted output.
            assert!(!raw.contains("SECRET_WITNESS"), "K-2 leak of panic payload in: {raw}");
            assert!(!raw.contains("PAYLOAD_42"), "K-2 leak of panic payload in: {raw}");
            assert!(!raw.contains("SECRET_LINE_TOKEN"), "K-2 leak of input line in: {raw}");

            let j = parse_json(raw.as_bytes()).unwrap_or_else(|e| panic!("invalid JSON emitted: {raw}: {e}"));
            assert_eq!(j.get("event").unwrap().str().unwrap(), "served");
            let req = j.get("request").unwrap().i64().unwrap() as usize;
            let st = j.get("status").unwrap().str().unwrap();
            if st == "ok" {
                seen_ok.push(req);
            } else {
                assert_eq!(st, "internal-error", "unexpected status for panicked request: {raw}");
                assert_eq!(j.get("error").unwrap().str().unwrap(), "internal-error", "unexpected error for panicked request: {raw}");
                let lane = j.get("lane").unwrap().i64().unwrap() as usize;
                assert!(lane < lanes, "invalid lane {lane}");
                seen_err.push(req);
            }
        }
        seen_ok.sort_unstable();
        seen_err.sort_unstable();
        assert_eq!(seen_ok, vec![1, 3, 5, 7, 9, 11], "per_lane={per_lane}: all healthy requests must succeed");
        assert_eq!(seen_err, vec![0, 2, 4, 6, 8, 10], "per_lane={per_lane}: all panicked requests must return internal-error");
    }
}

#[test]
fn with_captured_events_clears_tls_on_panic_inside_serve_lines() {
    // 1. Direct unwind clears EVENT_CAPTURE TLS cleanly on the calling thread.
    let direct = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_captured_events(|| {
            event("{\"event\":\"SECRET_DIRECT_LEAK\"}".to_string());
            panic!("SECRET_DIRECT_PANIC");
        })
    }));
    assert!(direct.is_err(), "direct panic expected");
    assert!(
        EVENT_CAPTURE.with(|c| c.borrow().is_none()),
        "EVENT_CAPTURE TLS must be restored to None after panic unwind"
    );

    // 2. Inside `serve_lines_with` (both per_lane=1 and per_lane=2), subsequent requests on the
    //    same Rayon worker threads observe zero leaked events from prior panicked requests.
    for per_lane in [1usize, 2] {
        let n = if per_lane == 1 { 4usize } else { 8usize };
        let panic_cutoff = if per_lane == 1 { 2usize } else { 4usize };
        let mut out = Vec::new();
        let (served_n, ok) = serve_lines_with(
            1,
            1,
            0,
            per_lane,
            (0..n).map(|q| format!("req-{q}")),
            |q, _line, _queued, _lane| {
                let is_panic = if per_lane == 1 { q % 2 == 0 } else { q < panic_cutoff };
                if is_panic {
                    if per_lane == 2 && q < 2 {
                        // Overlap the first two panics so both per-lane worker pools execute a panic.
                        std::thread::sleep(std::time::Duration::from_millis(20));
                    }
                    let _ = with_captured_events(|| -> Result<(), String> {
                        event(format!("{{\"event\":\"SECRET_LEAKED_EVENT_{q}\"}}"));
                        panic!("SECRET_PANIC_777_{q}");
                    });
                    unreachable!()
                }
                let ((), events) = with_captured_events(|| {
                    event("{\"event\":\"clean-ok\"}".to_string());
                });
                assert!(
                    EVENT_CAPTURE.with(|c| c.borrow().is_none()),
                    "EVENT_CAPTURE TLS must be None after with_captured_events returns"
                );
                assert_eq!(
                    events,
                    vec!["{\"event\":\"clean-ok\"}".to_string()],
                    "per_lane={per_lane} req {q}: stale event leaked across panic: {events:?}"
                );
                (true, format!("{{\"event\":\"served\",\"request\":{q},\"status\":\"ok\",\"events\":1}}"))
            },
            &mut |l: &str| out.push(l.to_string()),
        )
        .expect("serve_lines_with must recover cleanly");

        let want_ok = if per_lane == 1 { n / 2 } else { n - panic_cutoff };
        assert_eq!((served_n, ok), (n, want_ok), "per_lane={per_lane}: expected {want_ok} ok of {n}");
        for raw in &out {
            assert!(!raw.contains("SECRET_LEAKED_EVENT"), "K-2 leaked event in output: {raw}");
            assert!(!raw.contains("SECRET_PANIC_777"), "K-2 leaked panic payload in output: {raw}");
            let _ = parse_json(raw.as_bytes()).unwrap_or_else(|e| panic!("invalid JSON: {raw}: {e}"));
        }
    }
}
