//! **STAGE 45: the tests of the STANDALONE SHAPED BLOCK CAPTURE**
//! (`block_capture_shaped.rs`), and its two `#[ignore]`d evidence writers.
//!
//! What they establish, and nothing more: a standalone block receipt at a
//! shaped profile is captured by observing its verifier; the bundle written
//! to disk re-reads to the same verifier view (a fresh verifier accepts the
//! saved receipt and a recapture of it reproduces the three capture files
//! byte for byte); the bundle's values are the decoded receipt's; the hooks
//! change no byte and no verdict; every key is on the allow-list; the
//! per-slot, mask and opening objects carry a run stage file's field names;
//! and the bundle pins every source on the block's path.
//!
//! **A capture is not a gate.** Nothing here says anything about privacy.

use super::block_capture_shaped::{self as bcs, Bundle};
use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::run_capture;
use super::shape::Shape;
use super::witness::{self, Witness};
use super::{prepare_endpoints, verify_bytes_at, AttentionPublic, BlockPublic, ExpectedIo, FeedForwardPublic, IoSpec, Receipt};
use crate::merkle::Digest;
use crate::transcript::Transcript;
use std::path::{Path, PathBuf};

/// The endpoint context every stage-45 block commits under (public).
fn context() -> Digest {
    *blake3::hash(b"stage 45: a standalone shaped block capture").as_bytes()
}

/// The two witnesses a bundle is proved on, by their public recipe tag: the
/// FULLY DENSE run recipe (every public word nonzero, a non-constant hidden
/// input from its own unpublished stream — the GENERIC witness), or the
/// ALL-ZERO hidden input on the tame fixture (the degenerate control).
const RECIPE_DENSE: &str = "dense_run_case";
const RECIPE_TAME: &str = "tame_case";

fn case(sh: &Shape, dense: bool) -> (AttentionPublic, FeedForwardPublic, Vec<i16>) {
    if dense {
        super::dense_tests::dense_run_case(sh)
    } else {
        let (p, f, _) = super::grow_tests::tame_case(sh);
        (p, f, vec![0i16; sh.tokens * sh.width])
    }
}

/// The public statement a recipe tag names — the weights only; a hidden
/// input the generator also returns is dropped on the spot.
fn public_of(sh: &Shape, recipe: &str) -> BlockPublic {
    let (p, f, _) = match recipe {
        RECIPE_DENSE => super::dense_tests::dense_run_case(sh),
        RECIPE_TAME => super::grow_tests::tame_case(sh),
        other => panic!("{other:?} is not a public-weight recipe this build knows"),
    };
    BlockPublic::new(p, f)
}

/// The shapes a bundle may name, by their block profile string.
fn shape_of_profile(profile: &str) -> Shape {
    [Shape::rung_g(), Shape::m125()].into_iter().find(|s| s.profile == profile).unwrap_or_else(|| panic!("{profile:?} is not a block profile this reader knows"))
}

fn plane_of(w: &Witness, p: usize) -> Vec<i16> {
    w.planes[p].iter().map(|v| i16::try_from(*v).expect("an endpoint word outside int16")).collect()
}

/// Prove one honest block at `sh` and encode it: `(statement, policy,
/// frame, prove seconds)`. The witness and the hidden input never leave.
fn prove_block(sh: &Shape, dense: bool) -> (BlockPublic, ExpectedIo, Vec<u8>, f64) {
    let (p, f, x) = case(sh, dense);
    let blk = BlockPublic::new(p, f);
    let w = witness::build_shaped(sh, blk.attention(), blk.feed_forward(), &x).expect("an honest witness");
    drop(x);
    let ids = Ids::new(sh).expect("the shape has a plane map");
    let (pin, pout) = (plane_of(&w, ids.at(A_X)), plane_of(&w, ids.at(A_X2)));
    let spec = IoSpec::new_shaped(sh, context(), 0, 0).expect("the endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &pin, &pout).expect("the endpoint owners");
    drop(pin);
    drop(pout);
    let t0 = std::time::Instant::now();
    let (receipt, _) = prove_inner_at(sh, &blk, w, &expected, owners).expect("the honest prover");
    let prove_s = t0.elapsed().as_secs_f64();
    let bytes = receipt.to_bytes_at(sh, &blk, &expected).expect("the frame encodes");
    (blk, expected, bytes, prove_s)
}

/// Verify `bytes` FROM BYTES with a recorder attached and take the bundle.
/// The verdict is the verifier's; the bundle exists only for an accepted one.
fn capture(sh: &Shape, blk: &BlockPublic, expected: &ExpectedIo, bytes: &[u8], label: &str) -> Result<Bundle, String> {
    let guard = bcs::Recorder::attach(true);
    let verdict = verify_bytes_at(sh, blk, expected, bytes);
    let bundle = bcs::take(label);
    drop(guard);
    verdict?;
    bundle
}

/// `ExpectedIo::from_bytes` builds the TOY spec; this is the same frame read
/// at the bundle's own shape (the policy bytes carry only the context, the
/// two scales and the two roots, and the shape supplies the rest).
fn expected_at(sh: &Shape, b: &[u8]) -> ExpectedIo {
    assert_eq!(b.len(), 112, "an endpoint policy frame is 112 bytes");
    assert_eq!(&b[..8], b"HBLKEXP1", "not an endpoint policy frame");
    let d = |at: usize| -> Digest { b[at..at + 32].try_into().expect("32 bytes") };
    let i = |at: usize| i32::from_le_bytes(b[at..at + 4].try_into().expect("4 bytes"));
    let spec = IoSpec::new_shaped(sh, d(8), i(40), i(44)).expect("the policy's spec at this shape");
    let e = ExpectedIo::from_roots(spec, d(48), d(80));
    assert_eq!(e.to_bytes(), b, "the policy does not round-trip at this shape");
    e
}

fn count(haystack: &[u8], needle: &str) -> usize {
    let n = needle.as_bytes();
    if n.is_empty() || haystack.len() < n.len() {
        return 0;
    }
    haystack.windows(n.len()).filter(|w| *w == n).count()
}

fn contains(haystack: &[u8], needle: &str) -> bool {
    bcs::contains(haystack, needle)
}

struct TempDir(PathBuf);

impl TempDir {
    fn new(tag: &str) -> TempDir {
        let p = std::env::temp_dir().join(format!("zk60-block-capture-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&p);
        TempDir(p)
    }
    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

// ---------------------------------------------------------------- reading a bundle back

/// A string member `"key":"value"` of a writer's JSON (no whitespace, Debug
/// escaping, so a scan is exact for the ASCII values this reads).
fn string_member(bytes: &[u8], key: &str) -> String {
    let pat = format!("\"{key}\":\"");
    let text = std::str::from_utf8(bytes).expect("a bundle's JSON is UTF-8");
    let at = text.find(&pat).unwrap_or_else(|| panic!("no string member {key:?}")) + pat.len();
    text[at..at + text[at..].find('"').expect("a closed string")].to_string()
}

/// Every `{"file":…,"bytes":…,"sha256":…}` entry of a manifest's `files`.
fn manifest_files(manifest: &[u8]) -> Vec<(String, usize, String)> {
    let text = std::str::from_utf8(manifest).expect("the manifest is UTF-8");
    let files = &text[text.find("\"files\":[").expect("a files list")..];
    let mut out = Vec::new();
    let mut rest = files;
    while let Some(i) = rest.find("{\"file\":\"") {
        let body = &rest[i..i + rest[i..].find('}').expect("a closed entry") + 1];
        let name = body["{\"file\":\"".len()..].split('"').next().expect("a name").to_string();
        let bytes: usize = body.split("\"bytes\":").nth(1).expect("bytes").split(',').next().expect("a number").parse().expect("an integer");
        let sha = body.split("\"sha256\":\"").nth(1).expect("sha256").split('"').next().expect("a digest").to_string();
        out.push((name, bytes, sha));
        rest = &rest[i + body.len()..];
    }
    out
}

/// Every `{"file":…,"sha256":…}` entry of a manifest's `source_pins`.
fn manifest_pins(manifest: &[u8]) -> Vec<(String, String)> {
    let text = std::str::from_utf8(manifest).expect("the manifest is UTF-8");
    let start = text.find("\"source_pins\":[").expect("a source_pins list");
    let end = text.find("\"files\":[").expect("a files list");
    let mut out = Vec::new();
    let mut rest = &text[start..end];
    while let Some(i) = rest.find("{\"file\":\"") {
        let body = &rest[i..i + rest[i..].find('}').expect("a closed entry") + 1];
        let name = body["{\"file\":\"".len()..].split('"').next().expect("a name").to_string();
        let sha = body.split("\"sha256\":\"").nth(1).expect("sha256").split('"').next().expect("a digest").to_string();
        out.push((name, sha));
        rest = &rest[i + body.len()..];
    }
    out
}

/// One `{"array":…}` reference.
struct ArrayRef {
    sha: String,
    elem: String,
    len: usize,
    offset: usize,
    bytes: usize,
}

/// Every array reference of a file, in order (the writer's fixed member
/// order and no whitespace make a scan exact).
fn array_refs(bytes: &[u8]) -> Vec<ArrayRef> {
    let text = std::str::from_utf8(bytes).expect("a bundle's JSON is UTF-8");
    let mut out = Vec::new();
    let mut rest = text;
    while let Some(i) = rest.find("{\"array\":\"") {
        let body = &rest[i..i + rest[i..].find('}').expect("a closed reference") + 1];
        let field = |k: &str| -> String {
            let p = format!("\"{k}\":");
            let s = body.find(&p).unwrap_or_else(|| panic!("the reference {body} has no {k}")) + p.len();
            let t = body[s..].trim_start_matches('"');
            t[..t.find(['"', ',', '}']).expect("a terminated field")].to_string()
        };
        out.push(ArrayRef { sha: field("array"), elem: field("elem"), len: field("len").parse().expect("len"), offset: field("offset").parse().expect("offset"), bytes: field("bytes").parse().expect("bytes") });
        rest = &rest[i + body.len()..];
    }
    out
}

/// Resolve every reference of a file against `arrays.bin`: in bounds, the
/// declared width, and the bytes hash to the digest that names them.
fn resolve_all(file: &[u8], blob: &[u8]) -> usize {
    let refs = array_refs(file);
    for r in &refs {
        let w = match r.elem.as_str() {
            "fp" => 8,
            "fp2" => 16,
            other => panic!("an element type this reader does not know: {other:?}"),
        };
        assert_eq!(r.bytes, r.len * w, "the reference {} says {} entries and {} bytes", r.sha, r.len, r.bytes);
        assert!(r.offset + r.bytes <= blob.len(), "the reference {} points past the end of arrays.bin", r.sha);
        assert_eq!(crate::export_v3::sha256_hex(&blob[r.offset..r.offset + r.bytes]), r.sha, "the bytes at offset {} are not the array the reference names", r.offset);
    }
    refs.len()
}

/// **A WRITTEN BUNDLE, READ BACK AND CHECKED AGAINST ITSELF**: every manifest
/// file with its own length and SHA-256 and the manifest's total, the source
/// pins, the schema and profile, every key of every JSON file on the
/// allow-list, and every array reference resolved and re-hashed. Returns the
/// bundle's bytes on disk, the manifest included.
fn check_bundle_on_disk(dir: &Path, profile: &str) -> usize {
    let manifest = std::fs::read(dir.join("manifest.json")).expect("a manifest");
    let files = manifest_files(&manifest);
    let names: Vec<&str> = files.iter().map(|(n, _, _)| n.as_str()).collect();
    assert_eq!(names, [bcs::BLOCK_FILE, bcs::OBSERVATIONS_FILE, bcs::ARRAYS_FILE, bcs::RECEIPT_FILE, bcs::EXPECTED_FILE, "README.md"], "the manifest does not list the bundle's six files in order");
    let mut total = 0usize;
    for (name, len, sha) in &files {
        let bytes = std::fs::read(dir.join(name)).unwrap_or_else(|e| panic!("{name}: {e}"));
        assert_eq!(bytes.len(), *len, "{name} is not its manifest length");
        assert_eq!(&crate::export_v3::sha256_hex(&bytes), sha, "{name} is not its manifest digest");
        total += bytes.len();
    }
    assert!(contains(&manifest, &format!("\"total_bytes\":{total}")), "the manifest's total is not the bytes on disk");
    assert_eq!(manifest_pins(&manifest).len(), bcs::source_files().len(), "the manifest does not pin every source on the block's path");
    let block = std::fs::read(dir.join(bcs::BLOCK_FILE)).expect("block.json");
    let obs = std::fs::read(dir.join(bcs::OBSERVATIONS_FILE)).expect("observations.json");
    let blob = std::fs::read(dir.join(bcs::ARRAYS_FILE)).expect("arrays.bin");
    for (name, bytes) in [("block.json", &block), ("observations.json", &obs), ("manifest.json", &manifest)] {
        assert!(contains(bytes, &format!("\"schema\":\"{}\"", bcs::SCHEMA)), "{name} does not declare {}", bcs::SCHEMA);
        assert!(contains(bytes, &format!("\"profile\":\"{profile}\"")), "{name} does not name the profile {profile}");
    }
    assert_eq!(count(&block, "\"plane_index\":"), 1, "the plane index table belongs in block.json exactly once");
    assert!(!contains(&obs, "\"plane_index\":"), "observations.json carries its own copy of the plane index");
    assert!(contains(&block, "\"hash_tag\":{\"rule\":\"blake3-keyed/1\""), "block.json does not name the keyed hash rule");
    assert_eq!(count(&obs, "\"definition_challenges\":"), N_SLOTS, "observations.json does not carry twenty-three slot transcripts");
    assert!(contains(&obs, "\"opening_order\":[\"M\", \"A\", \"H\", \"Input\", \"Output\"]"), "the opening order is not the block's");
    let allowed = bcs::allowed_keys();
    let mut checked = 0usize;
    for (name, bytes) in [("block.json", &block), ("observations.json", &obs), ("manifest.json", &manifest)] {
        for key in run_capture::keys_of(bytes) {
            assert!(allowed.contains(&key.as_str()), "{name} carries the field {key:?}, which is not on the block capture's allow-list");
            checked += 1;
        }
    }
    assert!(checked > 1000, "only {checked} fields were scanned; the scanner is not reading the bundle");
    let refs = resolve_all(&block, &blob) + resolve_all(&obs, &blob);
    assert!(refs > 0, "no array reference at all: the store is not in use");
    total + manifest.len()
}

/// **THE BUNDLE'S VALUES ARE THE RECEIPT'S.** Independently of the recorder,
/// decode the saved frame and find its public parts in the bundle: the three
/// roots, every slot's published scalar and masked terminals, and — by the
/// content digest of their little-endian bytes — every opened column, group
/// vector and proximity vector of `A` and `H`, and the `M` opening's `q` and
/// `prox`; the endpoints' columns (below the store's threshold) by value.
fn check_values_are_the_receipts(sh: &Shape, blk: &BlockPublic, expected: &ExpectedIo, bytes: &[u8], obs: &[u8]) {
    let r = Receipt::from_bytes_at(sh, blk, expected, bytes).expect("the saved frame decodes");
    for (key, root) in [("a_root", r.a_root), ("h_root", r.h_root), ("mask_root", r.mask_root)] {
        assert!(contains(obs, &format!("\"{key}\":{root:?}")), "{key} is not the receipt's");
    }
    let fp2 = |v: crate::field::Fp2| [v.c0.0, v.c1.0];
    for (s, sp) in r.slots.iter().enumerate() {
        assert!(contains(obs, &format!("\"slot\":{s},")), "slot {s} is missing");
        assert!(contains(obs, &format!("\"scalar\":{:?}", fp2(sp.scalar))), "slot {s}'s scalar is not the receipt's");
        assert!(contains(obs, &format!("\"terminals\":{:?}", sp.terms.iter().map(|t| fp2(*t)).collect::<Vec<_>>())), "slot {s}'s terminals are not the receipt's");
    }
    let refs: std::collections::HashSet<String> = array_refs(obs).into_iter().map(|a| a.sha).collect();
    let fp_sha = |v: &[crate::field::Fp]| crate::export_v3::sha256_hex(&v.iter().flat_map(|x| x.to_bytes()).collect::<Vec<u8>>());
    let fp2_sha = |v: &[crate::field::Fp2]| crate::export_v3::sha256_hex(&v.iter().flat_map(|x| x.to_bytes()).collect::<Vec<u8>>());
    let mut seen = 0usize;
    for (role, o) in [("A", &r.a_open), ("H", &r.h_open)] {
        for (idx, values, salt, _) in &o.columns {
            assert!(refs.contains(&fp_sha(values)), "{role}'s opened column {idx} is not in the bundle");
            assert!(contains(obs, &format!("\"index\":{idx},")), "{role}'s column index {idx} is not in the bundle");
            assert!(contains(obs, &format!("\"salt\":{salt:?}")), "{role}'s column {idx}'s salt is not the receipt's");
            seen += 1;
        }
        for v in &o.group_vecs {
            assert!(refs.contains(&fp2_sha(v)), "a {role} group vector is not in the bundle");
        }
        assert!(refs.contains(&fp2_sha(&o.prox_vec)), "{role}'s proximity vector is not in the bundle");
    }
    for (i, o) in r.io_open.iter().enumerate() {
        for (idx, values, salt, _) in &o.columns {
            let inline = format!("\"index\":{idx},\"values\":{:?}", values.iter().map(|x| x.0).collect::<Vec<u64>>());
            assert!(contains(obs, &inline) || refs.contains(&fp_sha(values)), "endpoint {i}'s column {idx} is not in the bundle");
            assert!(contains(obs, &format!("\"salt\":{salt:?}")), "endpoint {i}'s column {idx}'s salt is not the receipt's");
            seen += 1;
        }
        assert!(refs.contains(&fp2_sha(&o.prox_vec)), "endpoint {i}'s proximity vector is not in the bundle");
    }
    assert!(refs.contains(&fp2_sha(&r.mask_open.q)) && refs.contains(&fp2_sha(&r.mask_open.prox)), "the M opening's q / prox are not in the bundle");
    assert_eq!(seen, 4 * sh.opened_cols, "not every opened column of A, H and the two endpoints was found");
}

/// **A FRESH VERIFIER, AND THE CANONICAL RECAPTURE.** From the files of a
/// written bundle alone plus the public recipe it names: the policy is read
/// at the bundle's shape, the public statement regenerated and checked
/// against the digest the bundle carries, the saved receipt verified FROM
/// BYTES with no recorder, then again with one — and the recapture, rendered
/// under the bundle's own label, must be `block.json`, `observations.json`
/// and `arrays.bin` byte for byte. Returns `(profile, proof_sha256)`.
fn reverify_and_recapture(dir: &Path) -> (String, String, String) {
    let manifest = std::fs::read(dir.join("manifest.json")).expect("a manifest");
    let block = std::fs::read(dir.join(bcs::BLOCK_FILE)).expect("block.json");
    let obs = std::fs::read(dir.join(bcs::OBSERVATIONS_FILE)).expect("observations.json");
    let blob = std::fs::read(dir.join(bcs::ARRAYS_FILE)).expect("arrays.bin");
    let bytes = std::fs::read(dir.join(bcs::RECEIPT_FILE)).expect("receipt.bin");
    let policy = std::fs::read(dir.join(bcs::EXPECTED_FILE)).expect("expected.bin");
    let profile = string_member(&block, "profile");
    let label = string_member(&block, "source_commit");
    let recipe = string_member(&manifest, "recipe");
    let sh = shape_of_profile(&profile);
    let blk = public_of(&sh, &recipe);
    assert!(contains(&block, &format!("\"public_statement_digest\":{:?}", blk.digest())), "the recipe {recipe} does not regenerate the public statement the bundle names");
    let expected = expected_at(&sh, &policy);
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("a fresh verifier refuses the saved receipt");
    let again = capture(&sh, &blk, &expected, &bytes, &label).expect("the saved receipt does not recapture");
    assert!(again.block_json == block, "the recapture's block.json is not the saved one");
    assert!(again.observations == obs, "the recapture's observations.json is not the saved one");
    assert!(again.arrays.blob() == blob.as_slice(), "the recapture's arrays.bin is not the saved one");
    check_values_are_the_receipts(&sh, &blk, &expected, &bytes, &obs);
    (profile, again.proof_sha256, label)
}

fn readme_for(tag: &str, sh: &Shape, dense: bool) -> String {
    format!(
        "# ZK60 standalone shaped block capture — `{tag}`\n\nWhat this is: the VERIFIER'S VIEW of ONE private block receipt at the shaped\nprofile `{}` ({}: {} tokens, width {}, hidden {}, {} query heads of {} over {} key-value heads,\nrow width 2^{}, rate 1/{}, {} opened columns), captured by observing the verifier\n(`hashline/src/private_block/block_capture_shaped.rs`, lane stage 45), schema\n`{}`. A STANDALONE block, not a run stage: its transcript opens\nwith the block's own header (`parameters` is this block profile's line,\n`public-statement` is the block's own digest, no `run-shape` word), it has no\nstage words and no boundary, and it opens BOTH external endpoints in one\nproof. `block.json` carries the transcript program in words.\n\nWitness: {}\n\nFiles: `block.json` (the header: public statement, shape, endpoints, hash rule,\ntranscript labels and program, plane index table), `observations.json` (the\ntwenty-three slot transcripts, the M opening and the A, H, Input and Output\nopenings — a run stage file's field names), `arrays.bin` (the `/5-run` array\nstore: every field-element array of at least 256 entries, little-endian),\n`receipt.bin` (the canonical frame that was verified), `expected.bin` (the\nendpoint policy), and `manifest.json` (every file's length and SHA-256, the\nsource pins, the public-weight recipe tag and the witness tag). A\n`validation.json`, when present, is the record of a FRESH-PROCESS re-verify\nand canonical recapture, written after the manifest and not pinned by it.\n\nWhat this is NOT: a privacy result. No gate has read it. It carries no witness\nvalue, pad, mask coefficient, unopened column, unpublished salt, unmasked\nround or prover randomness; the list is `not_in_a_capture` in `block.json`.\nThe weights are synthetic and public.\n",
        sh.profile,
        sh.name,
        sh.tokens,
        sh.width,
        sh.hidden,
        sh.q_heads,
        sh.head_dim,
        sh.kv_heads,
        sh.log_cols,
        sh.inv_rate,
        sh.opened_cols,
        bcs::SCHEMA,
        if dense {
            "the FULLY DENSE run recipe (`private_block::dense_tests::dense_run_case`, public-weight recipe tag `dense_run_case`): every entry of all nine public words nonzero, a non-constant hidden input from its own unpublished stream — the GENERIC witness"
        } else {
            "the ALL-ZERO hidden input on the lane's synthetic tame fixture (public-weight recipe tag `tame_case`) — the DEGENERATE control"
        }
    )
}

// ---------------------------------------------------------------- the tests that run here

/// **THE CAPTURE ROUND-TRIPS.** A dense generic rung-G block is proved,
/// verified from bytes with a recorder, written, read back and checked
/// against itself; then a fresh verifier accepts the saved receipt and the
/// recapture reproduces the three capture files byte for byte; and the
/// bundle's values are the decoded receipt's.
#[test]
fn a_rung_g_block_is_captured_and_its_bundle_round_trips_through_a_fresh_verifier() {
    let sh = Shape::rung_g();
    let (blk, expected, bytes, _) = prove_block(&sh, true);
    let bundle = capture(&sh, &blk, &expected, &bytes, "uncommitted-test").expect("a bundle for an accepted block");
    assert_eq!((bundle.proof_bytes, bundle.proof_sha256.as_str()), (bytes.len(), crate::export_v3::sha256_hex(&bytes).as_str()), "the recorder's re-encoding is not the frame that was verified");
    let header = super::protocol::transcript(&blk, &expected, &Layout::for_shape(&sh).expect("the rung-G layout")).state();
    assert_eq!(bundle.binding, header, "the bundle's block binding is not the verifier's header state");
    assert!(contains(&bundle.block_json, &format!("\"block_binding\":{header:?}")), "block.json does not carry the block binding");
    assert_eq!(count(&bundle.observations, "{\"kind\":\"public\",\"len\":"), count(&bundle.observations, "\",\"values\":"), "a public table was written without its values although they were asked for");
    let dir = TempDir::new("s45-roundtrip");
    let bdir = dir.path().join("bundle");
    bcs::write_bundle(&bdir, &bundle, &bytes, &expected.to_bytes(), RECIPE_DENSE, "dense", "uncommitted-test", &readme_for("roundtrip", &sh, true)).expect("the bundle is written");
    let total = check_bundle_on_disk(&bdir, sh.profile);
    let (profile, sha, label) = reverify_and_recapture(&bdir);
    assert_eq!((profile.as_str(), sha, label.as_str()), (sh.profile, crate::export_v3::sha256_hex(&bytes), "uncommitted-test"));
    // a second bundle into the same directory is refused, and so is a
    // receipt that is not the one the recorder saw accepted
    let again = bcs::write_bundle(&bdir, &bundle, &bytes, &expected.to_bytes(), RECIPE_DENSE, "dense", "uncommitted-test", "x");
    assert!(again.expect_err("a bundle was written over another").contains("already exists"));
    let mut other = bytes.clone();
    other[bytes.len() / 2] ^= 1;
    let wrong = bcs::write_bundle(&dir.path().join("other"), &bundle, &other, &expected.to_bytes(), RECIPE_DENSE, "dense", "uncommitted-test", "x");
    assert!(wrong.expect_err("a receipt the recorder did not see was written").contains("not the one the recorder saw accepted"));
    eprintln!("S45 rung-G dense block bundle: {total} B on disk, frame {} B, arrays.bin {} B", bytes.len(), bundle.arrays.blob().len());
}

/// **THE HOOKS CHANGE NO BYTE AND NO VERDICT.** One frame, verified in typed
/// form and from bytes with and without a recorder: the same verdict, the
/// same absorb order, the frame untouched; a tampered frame is refused with
/// the same message either way and leaves no bundle; a recorder offered a
/// header that is not the verifier's refuses; and nothing stays attached.
#[test]
fn a_block_verifies_the_same_with_and_without_a_recorder() {
    let sh = Shape::rung_g();
    let (blk, expected, bytes, _) = prove_block(&sh, false);
    let copy = bytes.clone();
    let receipt = Receipt::from_bytes_at(&sh, &blk, &expected, &bytes).expect("the frame decodes");
    let plain = verify_inner_at(&sh, &blk, &expected, &receipt).expect("the honest block verifies");
    let recorded = {
        let guard = bcs::Recorder::attach(false);
        let order = verify_inner_at(&sh, &blk, &expected, &receipt).expect("the honest block verifies under a recorder");
        let b = bcs::take("uncommitted-test").expect("a bundle for the accepted block");
        drop(guard);
        // a public table's values follow its digest (`"sha256":"…","values":`);
        // an opened column's follow its index, so this pattern is the tables'
        assert!(contains(&b.observations, "{\"kind\":\"public\",\"len\":"), "the block has no public table at all");
        assert!(!contains(&b.observations, "\",\"values\":"), "a recorder attached without the public tables wrote their values");
        order
    };
    assert_eq!(plain, recorded, "the absorb order moved under a recorder");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("from bytes, no recorder");
    capture(&sh, &blk, &expected, &bytes, "uncommitted-test").expect("from bytes, a recorder");
    assert_eq!(bytes, copy, "a verification moved a byte of the frame");
    for at in [bytes.len() / 3, bytes.len() / 2, bytes.len() - 1] {
        let mut bad = bytes.clone();
        bad[at] ^= 1;
        let without = verify_bytes_at(&sh, &blk, &expected, &bad).expect_err("a tampered frame was accepted");
        let guard = bcs::Recorder::attach(true);
        let with = verify_bytes_at(&sh, &blk, &expected, &bad).expect_err("a tampered frame was accepted under a recorder");
        let taken = bcs::take("uncommitted-test");
        drop(guard);
        assert_eq!(without, with, "the refusal of byte {at} moved under a recorder");
        assert!(taken.is_err(), "a bundle was taken for a frame the verifier refused (byte {at})");
    }
    // a header that is not the verifier's is refused by the replay
    let lay = Layout::for_shape(&sh).expect("the rung-G layout");
    let guard = bcs::Recorder::attach(true);
    bcs::begin_block(&sh, &lay, &blk, &expected, &receipt, &Transcript::new(b"not this block's header"));
    let refused = bcs::take("uncommitted-test");
    drop(guard);
    assert!(refused.err().expect("a forged header was accepted").contains("replay: the recorder's transcript is not the verifier's at the block header"));
    assert!(!bcs::active(), "a recorder is still attached");
    // no hook fires without a recorder: the checkpoint is `None`
    assert!(bcs::checkpoint(&Transcript::new(b"probe")).is_none());
}

/// **EVERY KEY IS ON THE ALLOW-LIST, AND EVERY BLOCK-ONLY KEY IS EMITTED** —
/// so the block list cannot drift into a wish list.
#[test]
fn every_key_of_a_block_bundle_is_on_the_allow_list_and_every_block_only_key_is_emitted() {
    let sh = Shape::rung_g();
    let (blk, expected, bytes, _) = prove_block(&sh, false);
    let bundle = capture(&sh, &blk, &expected, &bytes, "uncommitted-test").expect("a bundle");
    let dir = TempDir::new("s45-keys");
    let bdir = dir.path().join("bundle");
    bcs::write_bundle(&bdir, &bundle, &bytes, &expected.to_bytes(), RECIPE_TAME, "zero", "uncommitted-test", "keys").expect("written");
    let allowed = bcs::allowed_keys();
    let mut emitted: std::collections::BTreeSet<String> = std::collections::BTreeSet::new();
    for name in [bcs::BLOCK_FILE, bcs::OBSERVATIONS_FILE, "manifest.json"] {
        let b = std::fs::read(bdir.join(name)).expect("a bundle file");
        for key in run_capture::keys_of(&b) {
            assert!(allowed.contains(&key.as_str()), "{name} carries {key:?}, which is not on the allow-list");
            emitted.insert(key);
        }
    }
    for key in bcs::BLOCK_ONLY_KEYS {
        assert!(emitted.contains(key), "the block-only key {key:?} is on the list and is never emitted");
    }
    // the run-only framing is NOT in a block bundle
    for key in ["run_binding", "run_shape_words", "internal_boundaries", "boundary_scales", "stage_lines", "block_digests", "segment_bytes", "segment_sha256", "start_tag", "end_tag", "boundary_committed", "stage_files"] {
        assert!(!emitted.contains(key), "a standalone block bundle carries the run's {key:?}");
    }
}

/// A one-block RUN at rung-G, proved and captured by `run_capture` — the
/// comparison object for the field-name test below.
struct OneBlock {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    x: Vec<i16>,
}

impl RunWitnessSource for OneBlock {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        assert_eq!(k, 0, "a one-block run has one witness");
        witness::build_shaped(&self.sh, &self.public, &self.ff, &self.x)
    }
    fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
        Err("a one-block run has no internal boundary".into())
    }
}

/// The top-level elements of the first `"<key>":[ … ]` array, each as bytes.
fn elements(bytes: &[u8], key: &str) -> Vec<Vec<u8>> {
    let pat = format!("\"{key}\":[");
    let start = bytes.windows(pat.len()).position(|w| w == pat.as_bytes()).unwrap_or_else(|| panic!("no array {key:?}")) + pat.len();
    let (mut depth, mut from, mut out) = (0usize, start, Vec::new());
    let mut j = start;
    loop {
        match bytes[j] {
            b'[' | b'{' => depth += 1,
            b']' if depth == 0 => {
                if j > from {
                    out.push(bytes[from..j].to_vec());
                }
                return out;
            }
            b']' | b'}' => depth -= 1,
            b',' if depth == 0 => {
                out.push(bytes[from..j].to_vec());
                from = j + 1;
            }
            _ => {}
        }
        j += 1;
    }
}

/// The first `"<key>":{ … }` member's object, braces included.
fn member_object(bytes: &[u8], key: &str) -> Vec<u8> {
    let pat = format!("\"{key}\":{{");
    let start = bytes.windows(pat.len()).position(|w| w == pat.as_bytes()).unwrap_or_else(|| panic!("no object {key:?}")) + pat.len() - 1;
    let mut depth = 0usize;
    for (j, b) in bytes.iter().enumerate().skip(start) {
        match b {
            b'{' => depth += 1,
            b'}' => {
                depth -= 1;
                if depth == 0 {
                    return bytes[start..=j].to_vec();
                }
            }
            _ => {}
        }
    }
    panic!("the object {key:?} is not closed")
}

/// **THE PER-PROOF OBJECTS ARE THE RUN CAPTURE'S, FIELD NAME FOR FIELD NAME.**
/// A rung-G block captured by this module and a ONE-block rung-G run
/// captured by `run_capture` (the same dense recipe, both with the array
/// store and the public tables): every slot object, the `M` opening and the
/// four role objects carry the SAME key sequence, and a transcript site
/// differs only by the run's `stage`. So the Python gate's stage readers read
/// a block's objects as they are. The two transcripts differ (another
/// domain, another header, another receipt); the IO tables' `mask_row` —
/// the external endpoint's reserved pair in both, since a one-block run has
/// no internal boundary — is asserted equal and printed.
#[test]
fn the_block_objects_carry_the_run_captures_field_names_object_by_object() {
    let sh = Shape::rung_g();
    let (blk, expected, bytes, _) = prove_block(&sh, true);
    let block = capture(&sh, &blk, &expected, &bytes, "uncommitted-test").expect("a block bundle");
    // the one-block run
    let (public, ff, x) = case(&sh, true);
    let w = witness::build_shaped(&sh, &public, &ff, &x).expect("the run's witness");
    let ids = Ids::new(&sh).expect("a plane map");
    let spec = IoSpec::new_shaped(&sh, context(), 0, 0).expect("the run's spec");
    let (rexp, owners) = prepare_endpoints(spec, &plane_of(&w, ids.at(A_X)), &plane_of(&w, ids.at(A_X2))).expect("the run's owners");
    drop(w);
    let blocks = vec![BlockPublic::new(public.clone(), ff.clone())];
    let st = RunStatement::new(RunShape::rung_g(1).expect("a one-block rung-G run"), context(), rexp, &blocks, &[(0, 0)]).expect("the run statement");
    let mut src = OneBlock { sh: sh.clone(), public, ff, x };
    let mut segs: Vec<Vec<u8>> = Vec::new();
    run::prove_run(&st, &blocks, &mut src, owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the one-block run proves");
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run_with(st.capture_header().expect("the header"), st.binding().expect("the binding"), run_capture::CaptureOpts { arrays: true, public_tables: true });
    run::verify_run(&st, &blocks, &segs).expect("the one-block run verifies");
    let rb = run_capture::take().expect("a run bundle");
    drop(guard);
    let stage = &rb.stages[0];
    let keys = |b: &[u8]| run_capture::keys_of(b);
    let (bs, rs) = (elements(&block.observations, "arguments"), elements(stage, "arguments"));
    assert_eq!((bs.len(), rs.len()), (N_SLOTS, N_SLOTS));
    for s in 0..N_SLOTS {
        assert_eq!(keys(&bs[s]), keys(&rs[s]), "slot {s}'s object carries other field names than a run stage's");
    }
    assert_eq!(keys(&member_object(&block.observations, "mask")), keys(&member_object(stage, "mask")), "the M opening's field names differ");
    let (br, rr) = (elements(&block.observations, "roles"), elements(stage, "roles"));
    assert_eq!((br.len(), rr.len()), (4, 4), "a block and a one-block run each open four roles");
    for i in 0..4 {
        assert_eq!(keys(&br[i]), keys(&rr[i]), "role {i}'s object carries other field names than a run stage's");
    }
    let (bsite, rsite) = (elements(&block.observations, "transcript_sites"), elements(stage, "transcript_sites"));
    assert_eq!(bsite.len(), rsite.len(), "a different number of transcript sites");
    let mut run_site = keys(&rsite[0]);
    run_site.retain(|k| k != "stage");
    assert_eq!(keys(&bsite[0]), run_site, "a transcript site differs by more than the run's stage");
    // the per-proof file carries every stage-file member but the run's framing
    let obs_top = keys(&block.observations);
    for k in ["block_digest", "a_root", "a_rows", "h_root", "h_rows", "mask_root", "log_cols", "logup_challenges", "layout_digest", "opening_order", "header", "arguments", "mask", "roles", "transcript_sites"] {
        assert!(obs_top.iter().any(|o| o == k), "observations.json lacks the stage-file member {k:?}");
    }
    // the documented differences: the transcripts, and the IO mask rows
    assert!(!contains(&block.observations, &String::from_utf8_lossy(&member_object(stage, "header"))), "a block's header is a run stage's");
    let io_rows = |slot: &[u8]| -> String {
        let t = String::from_utf8_lossy(slot).into_owned();
        t.split("\"kind\":\"private\"").skip(1).filter_map(|p| p.split("\"mask_row\":").nth(1).map(|m| m.split(',').next().unwrap_or("").to_string())).collect::<Vec<_>>().join("/")
    };
    assert_eq!((io_rows(&bs[SC_IO_IN]), io_rows(&bs[SC_IO_OUT])), (io_rows(&rs[SC_IO_IN]), io_rows(&rs[SC_IO_OUT])), "the IO tables' reserved pairs differ from a one-block run's external endpoints'");
    eprintln!(
        "S45 FIELD NAMES: 23 slot objects, the M opening and 4 roles carry the run stage file's key sequences; IO mask rows, block vs one-block run: slot 21 {} vs {}, slot 22 {} vs {}",
        io_rows(&bs[SC_IO_IN]),
        io_rows(&rs[SC_IO_IN]),
        io_rows(&bs[SC_IO_OUT]),
        io_rows(&rs[SC_IO_OUT])
    );
}

/// **THE BUNDLE PINS EVERY SOURCE ON THE BLOCK'S PATH.** The block's own
/// production modules plus the run-only ones named with a reason are the
/// whole production module list of `private_block.rs`, never both; every
/// pin resolves and none is listed twice.
#[test]
fn the_block_capture_pins_every_source_on_the_block_path() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let parent = std::fs::read_to_string(root.join("src/private_block.rs")).expect("the parent module");
    let lines: Vec<&str> = parent.lines().collect();
    let mut production: Vec<String> = Vec::new();
    for (i, l) in lines.iter().enumerate() {
        let Some(name) = l.trim().strip_prefix("mod ").and_then(|r| r.strip_suffix(';')) else { continue };
        if i > 0 && lines[i - 1].trim() == "#[cfg(test)]" {
            continue;
        }
        production.push(format!("src/private_block/{name}.rs"));
    }
    assert!(production.len() >= 13, "only {} production modules were read", production.len());
    for m in &production {
        let own = bcs::OWN_SOURCE_FILES.contains(&m.as_str());
        let not = bcs::NOT_ON_THE_BLOCKS_PATH.iter().any(|(f, _)| f == m);
        assert!(own ^ not, "{m} is {} the block's path", if own { "both on and off" } else { "neither on nor declared off" });
    }
    for (f, why) in bcs::NOT_ON_THE_BLOCKS_PATH {
        assert!(production.iter().any(|m| m == f), "{f} is declared off the path and is not a production module");
        assert!(why.len() > 30, "{f} is declared off the path with no reason");
    }
    assert!(bcs::OWN_SOURCE_FILES.contains(&"src/private_block/block_capture_shaped.rs") && bcs::OWN_SOURCE_FILES.contains(&"src/private_block.rs"));
    let files = bcs::source_files();
    let unique: std::collections::BTreeSet<&&str> = files.iter().collect();
    assert_eq!(unique.len(), files.len(), "a source is pinned twice");
    let pins = bcs::source_pins().expect("every pin resolves");
    assert_eq!(pins.len(), bcs::OWN_SOURCE_FILES.len() + run_capture::SHARED_SOURCE_FILES.len());
}

/// **FINDING E32-F1, the writer's half**: a bundle's source label must be the
/// HEAD it is taken at. A wrong label and the default label are refused.
#[test]
fn a_source_label_that_is_not_head_is_refused() {
    let wrong = source_label_is_head("0000000000000000000000000000000000000000");
    assert!(wrong.expect_err("a wrong label was accepted").contains("is not HEAD"));
    let default = source_label_is_head("uncommitted-test");
    assert!(default.is_err(), "the default label was accepted");
}

// ---------------------------------------------------------------- the evidence writers (`#[ignore]`d)

fn git(args: &[&str]) -> Result<String, String> {
    let out = std::process::Command::new("git").arg("--no-pager").arg("-C").arg(env!("CARGO_MANIFEST_DIR")).args(args).output().map_err(|e| format!("git: {e}"))?;
    if !out.status.success() {
        return Err(format!("git {args:?}: {}", String::from_utf8_lossy(&out.stderr)));
    }
    Ok(String::from_utf8_lossy(&out.stdout).trim().to_string())
}

/// The label must be the full HEAD commit, and every pinned source must be
/// committed as it stands (no modified or untracked pinned file), so the
/// label names the tree the bundle was written from.
fn source_label_is_head(label: &str) -> Result<(), String> {
    if label.len() != 40 || !label.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err(format!("the source label {label:?} is not a full commit id (finding E32-F1)"));
    }
    let head = git(&["rev-parse", "HEAD"])?;
    if head != label {
        return Err(format!("the source label {label} is not HEAD ({head}) (finding E32-F1)"));
    }
    let mut args = vec!["status", "--porcelain", "--"];
    let files = bcs::source_files();
    args.extend(files.iter().copied());
    let dirty = git(&args)?;
    if !dirty.is_empty() {
        return Err(format!("a pinned source is not committed as it stands:\n{dirty}"));
    }
    Ok(())
}

/// Peak resident memory of this process in MiB (`VmHWM`).
fn peak_rss_mib() -> f64 {
    std::fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("VmHWM:")).and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<f64>().ok())))
        .map(|kb| kb / 1024.0)
        .unwrap_or(f64::NAN)
}

/// **THE WRITER: one standalone shaped block bundle.** Proves one honest
/// block with the production prover, verifies it FROM BYTES with no recorder
/// (the timed verify), then again with a recorder, writes the bundle only
/// for an accepted block, and reads it back against itself.
///
/// | variable | what |
/// |---|---|
/// | `HL_BLOCK_CAPTURE_SHAPE` | `rung-g` or `m125` |
/// | `HL_PB_INPUT` | `dense` (the generic witness) or `zero` (the all-zero control) |
/// | `HL_BLOCK_CAPTURE_DIR` | the bundle directory: absolute, and must not exist |
/// | `HL_TEST_SOURCE_COMMIT` | the FULL HEAD commit, every pinned source committed (finding E32-F1) |
///
/// The 125M run is heavy (about 10 GiB peak while proving): launch it
/// detached under the heavy lock with `MALLOC_MMAP_THRESHOLD_=131072`.
#[test]
#[ignore = "writes a standalone shaped block bundle; set HL_BLOCK_CAPTURE_SHAPE, HL_PB_INPUT, HL_BLOCK_CAPTURE_DIR and HL_TEST_SOURCE_COMMIT (=HEAD)"]
fn write_a_shaped_block_bundle() {
    let sh = match std::env::var("HL_BLOCK_CAPTURE_SHAPE").as_deref() {
        Ok("rung-g") => Shape::rung_g(),
        Ok("m125") => Shape::m125(),
        other => panic!("HL_BLOCK_CAPTURE_SHAPE={other:?} is not `rung-g` or `m125`"),
    };
    let dense = match std::env::var("HL_PB_INPUT").as_deref() {
        Ok("dense") => true,
        Ok("zero") => false,
        other => panic!("HL_PB_INPUT={other:?} is not `dense` or `zero`"),
    };
    let dir = PathBuf::from(std::env::var("HL_BLOCK_CAPTURE_DIR").expect("HL_BLOCK_CAPTURE_DIR is not set: this test writes a bundle and will not choose a directory"));
    assert!(dir.is_absolute(), "HL_BLOCK_CAPTURE_DIR must be absolute");
    assert!(!dir.exists(), "{} exists; a bundle goes into a fresh directory", dir.display());
    let label = std::env::var("HL_TEST_SOURCE_COMMIT").expect("HL_TEST_SOURCE_COMMIT is not set: the bundle must name the commit it was taken at");
    source_label_is_head(&label).unwrap_or_else(|e| panic!("{e}"));
    assert!(!sh.hashes_under_the_legacy_rule(), "a shaped block bundle is meant to be TAGGED");
    let tag = format!("{}-{}", if sh.profile == Shape::m125().profile { "m125" } else { "rung-g" }, if dense { "dense" } else { "zero" });
    eprintln!("S45 WRITER {tag}: {}", if std::env::var("MALLOC_MMAP_THRESHOLD_").is_ok() { "MALLOC_MMAP_THRESHOLD_ is pinned" } else { "MALLOC_MMAP_THRESHOLD_ is NOT SET" });
    let t_all = std::time::Instant::now();
    let (blk, expected, bytes, prove_s) = prove_block(&sh, dense);
    let peak_prove = peak_rss_mib();
    eprintln!("S45 WRITER {tag}: prove {prove_s:.2} s, frame {} B, peak RSS after proving {peak_prove:.0} MiB ({:.2} GiB)", bytes.len(), peak_prove / 1024.0);
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest block verifies from bytes");
    let verify_s = t1.elapsed().as_secs_f64();
    let t2 = std::time::Instant::now();
    let bundle = capture(&sh, &blk, &expected, &bytes, &label).expect("a bundle for the accepted block");
    let record_s = t2.elapsed().as_secs_f64();
    let (distinct, stored, deduped, inline, blob) = bundle.arrays.stats();
    eprintln!("S45 WRITER {tag}: verify from bytes {verify_s:.2} s (no recorder), verify+record {record_s:.2} s; block.json {} B, observations.json {} B, arrays.bin {blob} B over {distinct} distinct arrays ({stored} references, {deduped} deduplicated, {inline} inline)", bundle.block_json.len(), bundle.observations.len());
    let recipe = if dense { RECIPE_DENSE } else { RECIPE_TAME };
    let total = bcs::write_bundle(&dir, &bundle, &bytes, &expected.to_bytes(), recipe, if dense { "dense" } else { "zero" }, &label, &readme_for(&tag, &sh, dense)).unwrap_or_else(|e| panic!("{tag}: {e}"));
    let on_disk = check_bundle_on_disk(&dir, sh.profile);
    assert_eq!(total, on_disk, "the writer's count is not the bytes on disk");
    let manifest_sha = crate::export_v3::sha256_hex(&std::fs::read(dir.join("manifest.json")).expect("the manifest"));
    eprintln!(
        "S45 WRITER {tag}: {on_disk} B on disk ({:.1} MB) in {}, manifest SHA-256 {manifest_sha}, proof SHA-256 {}, source_commit {label}; self-consistent, every key on the allow-list, every array reference resolved; wall {:.2} s, peak RSS {:.0} MiB ({:.2} GiB)",
        on_disk as f64 / 1e6,
        dir.display(),
        bundle.proof_sha256,
        t_all.elapsed().as_secs_f64(),
        peak_rss_mib(),
        peak_rss_mib() / 1024.0
    );
    assert!(on_disk < 2_000_000_000, "the bundle is {on_disk} B, past the 2 GB runaway ceiling");
}

/// **THE FRESH-PROCESS RE-VERIFY AND CANONICAL RECAPTURE** of a written
/// bundle (`HL_BLOCK_CAPTURE_BUNDLE=<dir>`), in a process that did not prove
/// it: every manifest file and every source pin checked (the verifying code
/// is the code that captured), the saved receipt verified from bytes by a
/// fresh verifier, the recapture compared byte for byte, and the bundle's
/// values checked against the decoded receipt. Writes `validation.json`
/// beside the manifest (never over one).
#[test]
#[ignore = "re-verifies a written block bundle in a fresh process; set HL_BLOCK_CAPTURE_BUNDLE"]
fn reverify_a_shaped_block_bundle() {
    let dir = PathBuf::from(std::env::var("HL_BLOCK_CAPTURE_BUNDLE").expect("HL_BLOCK_CAPTURE_BUNDLE is not set"));
    let manifest = std::fs::read(dir.join("manifest.json")).expect("a manifest");
    let profile = string_member(&manifest, "profile");
    let on_disk = check_bundle_on_disk(&dir, &profile);
    let now = bcs::source_pins().expect("the pins resolve");
    let then = manifest_pins(&manifest);
    assert_eq!(now, then, "a pinned source moved since the bundle was written: this build is not the code that captured it");
    let t0 = std::time::Instant::now();
    let (profile, proof_sha, label) = reverify_and_recapture(&dir);
    let seconds = t0.elapsed().as_secs_f64();
    let exe = std::env::current_exe().expect("the test binary");
    let verifier_sha = crate::export_v3::sha256_hex(&std::fs::read(&exe).expect("the test binary reads"));
    let head = git(&["rev-parse", "HEAD"]).unwrap_or_else(|e| e);
    let validation = format!(
        "{{\n  \"schema\": {:?},\n  \"kind\": \"zk60-block-capture-validation\",\n  \"profile\": {profile:?},\n  \"proof_sha256\": {proof_sha:?},\n  \"slots\": {N_SLOTS},\n  \"source_commit\": {label:?},\n  \"reverified_at_commit\": {head:?},\n  \"manifest_sha256\": {:?},\n  \"bundle_bytes_on_disk\": {on_disk},\n  \"source_pins_match\": true,\n  \"native_reverified\": true,\n  \"canonical_capture_reproduced\": true,\n  \"values_match_the_decoded_receipt\": true,\n  \"fresh_process\": true,\n  \"privacy_review_complete\": false,\n  \"verifier_binary_sha256\": {verifier_sha:?},\n  \"what_this_is\": \"a fresh process that did not prove this block read the saved receipt and policy, regenerated the public statement from the recipe tag, verified the receipt from bytes, recaptured it, and found block.json, observations.json and arrays.bin byte-identical to the saved ones. NOT a privacy result.\"\n}}\n",
        bcs::SCHEMA,
        crate::export_v3::sha256_hex(&manifest)
    );
    let path = dir.join("validation.json");
    let mut f = std::fs::OpenOptions::new().create_new(true).write(true).open(&path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
    std::io::Write::write_all(&mut f, validation.as_bytes()).expect("validation.json is written");
    eprintln!("S45 REVERIFY {}: fresh verifier accepted, canonical capture reproduced, values match the receipt; {seconds:.2} s, peak RSS {:.0} MiB; validation.json {} B", dir.display(), peak_rss_mib(), validation.len());
}
