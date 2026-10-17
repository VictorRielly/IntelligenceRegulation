// Included in the two native modules ONLY under cfg(test). No prover hook,
// witness input, mask coefficients, RNG state or production export surface.
use super::*;
use super::argument::{Acc, Coord, Side, SlotDef, SlotProof, Tab};
use super::layout::*;
use crate::field::{Fp, Fp2};
use crate::mle::eq_table_msb;
use crate::ntt::NttTables;
use crate::pcs::{self, Commitment, OpeningZk, PcsParams, ZClaim, ZPart, ZkOpts};
use crate::sumcheck;
use crate::transcript::Transcript;
use crate::zk::{self, MaskFunctional, MaskOpening};
use std::cell::RefCell;
use std::io::Write;

#[derive(Default)]
struct Pending {
    arguments: Vec<Vec<u8>>,
    definition: Option<Transcript>,
    first: Option<Transcript>,
    cursor: Option<Transcript>,
    mask: Option<Vec<u8>>,
    roles: Vec<Vec<u8>>,
    published: Option<Vec<u8>>,
}
thread_local! {
    static OBSERVER: RefCell<Option<Pending>> = const { RefCell::new(None) };
}
struct Guard;
impl Guard {
    fn new() -> Self {
        OBSERVER.with(|s| { assert!(s.borrow().is_none()); *s.borrow_mut() = Some(Pending::default()); });
        Self
    }
    fn take(&self) -> Option<Vec<u8>> {
        OBSERVER.with(|s| s.borrow_mut().as_mut().unwrap().published.take())
    }
}
impl Drop for Guard {
    fn drop(&mut self) { OBSERVER.with(|s| *s.borrow_mut() = None); }
}

// Reset before EVERY attempt, including byte-parser failures. A rejected
// attempt must never expose a previous success or a partially accepted view.
pub(super) fn begin() {
    OBSERVER.with(|s| { if s.borrow().is_some() { *s.borrow_mut() = Some(Pending::default()); } });
}
pub(super) fn checkpoint(tr: &Transcript) -> Option<Transcript> {
    OBSERVER.with(|s| s.borrow().is_some().then(|| Transcript::clone_state(tr)))
}
fn same_transcript(a: &Transcript, b: &Transcript) -> bool {
    a.state() == b.state() && Transcript::clone_state(a).challenge_fp2() == Transcript::clone_state(b).challenge_fp2()
}
fn join(p: &mut Pending, before: &Transcript, after: &Transcript) {
    if let Some(previous) = &p.cursor { assert!(same_transcript(previous, before), "capture transcript join"); }
    else { p.first = Some(Transcript::clone_state(before)); }
    p.cursor = Some(Transcript::clone_state(after));
}
fn fp2(v: Fp2) -> [u64; 2] { [v.c0.0, v.c1.0] }
fn fp2s(v: &[Fp2]) -> Vec<[u64; 2]> { v.iter().copied().map(fp2).collect() }
fn state(out: &mut impl Write, name: &str, tr: &Transcript) -> std::io::Result<()> {
    write!(out, "{name:?}:{{\"state\":{:?},\"next\":{:?}}}", tr.state(), fp2(Transcript::clone_state(tr).challenge_fp2()))
}
fn columns(out: &mut impl Write, cols: &[(usize, Vec<Fp>, [u8; 32], Vec<[u8; 32]>)]) -> std::io::Result<()> {
    write!(out, "[")?;
    for (i, (index, values, salt, path)) in cols.iter().enumerate() {
        if i > 0 { write!(out, ",")?; }
        write!(out, "{{\"index\":{index},\"values\":{:?},\"salt\":{salt:?},\"path\":{path:?}}}", values.iter().map(|x| x.0).collect::<Vec<_>>())?;
    }
    write!(out, "]")
}
fn array(out: &mut impl Write, records: &[Vec<u8>]) -> std::io::Result<()> {
    write!(out, "[")?;
    for (i, record) in records.iter().enumerate() {
        if i > 0 { write!(out, ",")?; }
        out.write_all(record)?;
    }
    write!(out, "]")
}

// The definition code only draws Fp2 challenges; replay to its exact endpoint.
// This fails closed if a future definition adds another transcript operation.
pub(super) fn start_slot(side: &Side, tr: &Transcript) {
    if matches!(side, Side::Verify { .. }) {
        OBSERVER.with(|s| { if let Some(p) = s.borrow_mut().as_mut() { p.definition = Some(Transcript::clone_state(tr)); } });
    }
}
pub(super) fn slot(
    def: &SlotDef, acc: &Acc, proof: &SlotProof, rho: &[Fp2], c: Fp2,
    mask_eval: Fp2, before: Option<Transcript>, after: &Transcript,
) {
    let Some(before) = before else { return; };
    let before = &before;
    OBSERVER.with(|cell| {
        let mut cell = cell.borrow_mut();
        let Some(p) = cell.as_mut() else { return; };
        let definition = p.definition.take().expect("definition checkpoint");
        let before_definition = &definition;
        let s = def.slot;
        assert_eq!(s, p.arguments.len());
        let mut tr = Transcript::clone_state(before_definition);
        let mut draws = Vec::new();
        while !same_transcript(&tr, before) {
            assert!(draws.len() < 256, "slot definition changed its transcript operations");
            draws.push(tr.challenge_fp2());
        }
        tr.absorb_u64(SLOT_LABEL, s as u64);
        assert_eq!(tr.challenge_fp2(), c);
        tr.absorb_fp2(SCALAR_LABEL, &[proof.scalar]);
        let claimed = def.hosted.iter().fold(proof.scalar, |v, (hs, coef)| v.add(coef.mul(acc.scalars[*hs])));
        let (n, ext, degree) = SLOTS[s];
        let (fin, replay_rho) = sumcheck::verify(claimed, degree, n + ext, &proof.sc, &mut tr).unwrap();
        assert_eq!(rho, replay_rho);
        tr.absorb_fp2(TERM_LABEL, &proof.terms);
        assert!(same_transcript(&tr, after));
        join(p, before_definition, after);
        let mut out = Vec::new();
        write!(out, "{{\"slot\":{s},\"name\":{:?},\"kind\":\"{:?}\",\"main\":{n},\"extension\":{ext},\"degree\":{degree},\"definition_challenges\":{:?},\"c\":{:?},\"scalar\":{:?},\"claimed_sum\":{:?},\"rho\":{:?},\"sumcheck_final\":{:?},\"mask_eval\":{:?},\"terminal_polynomial\":{:?},\"terminals\":{:?},\"rounds\":{:?},\"hosted\":[", SLOT_NAMES[s], SLOT_KINDS[s], fp2s(&draws), fp2(c), fp2(proof.scalar), fp2(claimed), fp2s(rho), fp2(fin), fp2(mask_eval), fp2(fin.sub(c.mul(mask_eval))), fp2s(&proof.terms), proof.sc.rounds.iter().map(|r| fp2s(r)).collect::<Vec<_>>()).unwrap();
        for (i, (hs, coefficient)) in def.hosted.iter().enumerate() {
            if i > 0 { write!(out, ",").unwrap(); }
            write!(out, "{{\"slot\":{hs},\"coefficient\":{:?}}}", fp2(*coefficient)).unwrap();
        }
        write!(out, "],\"tables\":[").unwrap();
        let mut counts = [0usize; 4];
        for t in &def.tabs { if let Tab::Priv(v) = t { counts[v.cm as usize] += 1; } }
        let mut indices = std::array::from_fn::<_, 4, _>(|i| acc.claims[i].len() - counts[i]);
        for (i, table) in def.tabs.iter().enumerate() {
            if i > 0 { write!(out, ",").unwrap(); }
            match table {
                Tab::Eq { point, start } => write!(out, "{{\"kind\":\"eq\",\"start\":{start},\"point\":{:?}}}", fp2s(point)).unwrap(),
                Tab::Pub(v) => write!(out, "{{\"kind\":\"public\",\"values\":{:?}}}", fp2s(v)).unwrap(),
                Tab::Priv(v) => {
                    let role = ["A", "H", "Input", "Output"][v.cm as usize];
                    let ci = &mut indices[v.cm as usize];
                    write!(out, "{{\"kind\":\"private\",\"role\":{role:?},\"claim\":{ci},\"log_size\":{},\"mask_row\":{},\"extension_round\":{},\"slices\":[", v.log, v.mask_row, v.ext_round).unwrap();
                    *ci += 1;
                    for (j, (offset, coefficient)) in v.slices.iter().enumerate() {
                        if j > 0 { write!(out, ",").unwrap(); }
                        write!(out, "{{\"offset\":{offset},\"coefficient\":{:?}}}", fp2(*coefficient)).unwrap();
                    }
                    write!(out, "],\"coordinates\":[").unwrap();
                    for (j, coord) in v.coords.iter().enumerate() {
                        if j > 0 { write!(out, ",").unwrap(); }
                        match coord {
                            Coord::Rho(k) => write!(out, "{{\"rho\":{k}}}").unwrap(),
                            Coord::Flip(k) => write!(out, "{{\"flip\":{k}}}").unwrap(),
                            Coord::Fixed(x) => write!(out, "{{\"fixed\":{:?}}}", fp2(*x)).unwrap(),
                        }
                    }
                    write!(out, "]}}").unwrap();
                }
            }
        }
        write!(out, "],").unwrap();
        state(&mut out, "before_definition", before_definition).unwrap(); write!(out, ",").unwrap();
        state(&mut out, "before", before).unwrap(); write!(out, ",").unwrap();
        state(&mut out, "after", after).unwrap(); write!(out, "}}").unwrap();
        p.arguments.push(out);
    });
}

pub(super) fn mask(root: &[u8; 32], fs: &[MaskFunctional], op: &MaskOpening, before: Option<Transcript>, after: &Transcript) {
    let Some(before) = before else { return; };
    let specs = mask_specs();
    let mut tr = Transcript::clone_state(&before);
    zk::mask_verify(root, &specs, fs, op, &NttTables::new(12), &mut tr).unwrap();
    assert!(same_transcript(&tr, after));
    tr = Transcript::clone_state(&before);
    let theta = tr.challenge_fp2();
    tr.absorb_fp2(b"mask-q", &op.q);
    let rhos = tr.challenge_fp2_vec(2 * specs.len() + 2);
    let mut out = Vec::new();
    write!(out, "{{\"root\":{root:?},\"specs\":{:?},\"theta\":{:?},\"proximity_rhos\":{:?},", specs.iter().map(|&(n,d)| [n,d]).collect::<Vec<_>>(), fp2(theta), fp2s(&rhos)).unwrap();
    state(&mut out, "before", &before).unwrap(); write!(out, ",").unwrap();
    state(&mut out, "after", after).unwrap(); write!(out, ",\"functionals\":[").unwrap();
    for (i, f) in fs.iter().enumerate() {
        if i > 0 { write!(out, ",").unwrap(); }
        write!(out, "{{\"value\":{:?},\"terms\":[", fp2(f.value)).unwrap();
        for (j, (s, weights)) in f.terms.iter().enumerate() {
            if j > 0 { write!(out, ",").unwrap(); }
            write!(out, "{{\"slot\":{s},\"weights\":{:?}}}", fp2s(weights)).unwrap();
        }
        write!(out, "]}}").unwrap();
    }
    write!(out, "],\"q\":{:?},\"prox\":{:?},\"columns\":", fp2s(&op.q), fp2s(&op.prox)).unwrap();
    columns(&mut out, &op.columns).unwrap(); write!(out, "}}").unwrap();
    OBSERVER.with(|s| { let mut s = s.borrow_mut(); let p = s.as_mut().unwrap(); join(p, &before, after); assert!(p.mask.replace(out).is_none()); });
}

pub(super) fn pcs(role: &str, root: [u8; 32], rows: usize, claims: &[ZClaim], opening: &OpeningZk, before: Option<Transcript>, after: &Transcript) {
    let Some(before) = before else { return; };
    let o = Observation { params: protocol::pcs_params(), commitment: Commitment { root, rows, log_cols: 8 }, claims: claims.to_vec(), opening: opening.clone(), before, after: Some(Transcript::clone_state(after)) };
    let replayed = replay(&o, &NttTables::new(12)).unwrap();
    let mut out = Vec::new();
    write_pcs(&mut out, role, &o, &replayed).unwrap();
    OBSERVER.with(|s| { let mut s = s.borrow_mut(); let p = s.as_mut().unwrap(); assert_eq!(role, ["A", "H", "Input", "Output"][p.roles.len()]); join(p, &o.before, after); p.roles.push(out); });
}

pub(super) fn publish(public: &Public, expected: &ExpectedIo, receipt: &Receipt) {
    OBSERVER.with(|s| {
        let mut s = s.borrow_mut(); let Some(p) = s.as_mut() else { return; };
        assert_eq!(p.arguments.len(), N_SLOTS); assert_eq!(p.roles.len(), 4);
        let lay = Layout::new();
        let header = protocol::transcript(public, expected, &lay);
        let mut tr = Transcript::clone_state(&header);
        let absorb = |tr: &mut Transcript, name: &[u8], root: &[u8; 32], rows: usize| { tr.absorb(name, root); tr.absorb_u64(b"rows", rows as u64); tr.absorb_u64(b"log-cols", 8); };
        absorb(&mut tr, b"A", &receipt.a_root, lay.a_rows);
        tr.absorb(b"M", &receipt.mask_root);
        let logup = tr.challenge_fp2_vec(3);
        absorb(&mut tr, b"H", &receipt.h_root, lay.h_rows);
        assert!(same_transcript(&tr, p.first.as_ref().unwrap()));
        let bytes = receipt.to_bytes(public, expected).unwrap();
        let policy = expected.to_bytes();
        let description = lay.describe().join("\n");
        let source = std::env::var("HL_TEST_SOURCE_COMMIT").unwrap_or_else(|_| "uncommitted-test".into());
        let profile = std::str::from_utf8(PROFILE).unwrap();
        let mut out = Vec::new();
        write!(out, "{{\"schema\":3,\"kind\":\"zk60-verifier-observations\",\"coverage\":\"native-all-slots-v1\",\"profile\":{profile:?},\"transcript_domain\":{profile:?},\"source_commit\":{source:?},\"fully_verified\":true,\"privacy\":\"P1\",\"privacy_review_complete\":false,\"weight_policy\":\"public-statement\",\"field_modulus\":{},\"extension_nonresidue\":{},\"proof_sha256\":{:?},\"proof_bytes\":{},\"proof_digest_encoding\":\"complete canonical native receipt\",\"expected_policy\":{policy:?},\"expected_policy_sha256\":{:?},\"public_statement_digest\":{:?},\"layout_description\":{description:?},\"layout_digest\":{:?},\"schedule_digest\":{:?},\"opening_order\":[\"M\",\"A\",\"H\",\"Input\",\"Output\"],\"logup_challenges\":{:?},", crate::field::P, crate::field::NONRESIDUE, crate::export_v3::sha256_hex(&bytes), bytes.len(), crate::export_v3::sha256_hex(&policy), public.digest(), crate::export_v3::sha256_hex(description.as_bytes()), lay.schedule_digest(), fp2s(&logup)).unwrap();
        state(&mut out, "header", &header).unwrap(); write!(out, ",\"arguments\":").unwrap(); array(&mut out, &p.arguments).unwrap();
        write!(out, ",\"mask\":").unwrap(); out.write_all(p.mask.as_ref().unwrap()).unwrap();
        write!(out, ",\"roles\":").unwrap(); array(&mut out, &p.roles).unwrap(); writeln!(out, "}}").unwrap();
        p.published = Some(out);
    });
}

// Replay/grouping helper below is adapted from zk_ffn_mask_diagnostic.rs.
// It does NOT call protocol.rs's refusal/grouping helpers, and pins both
// lambdas and proximity draws against the core verifier's final transcript.

fn write_pcs(out: &mut impl Write, name: &str, o: &Observation, r: &Replayed) -> std::io::Result<()> {
    write!(out, "{{\"role\":{name:?},\"params\":{{\"log_cols\":8,\"inv_rate\":8,\"num_col_checks\":256}},\"commitment\":{{\"root\":{:?},\"rows\":{}}},", o.commitment.root, o.commitment.rows)?;
    state(out, "before", &o.before)?; write!(out, ",")?;
    state(out, "after", o.after.as_ref().unwrap())?;
    write!(out, ",\"claims\":[")?;
    for (i, c) in o.claims.iter().enumerate() {
        if i > 0 { write!(out, ",")?; }
        write!(out, "{{\"value\":{:?},\"parts\":[", fp2(c.value))?;
        for (j, p) in c.parts.iter().enumerate() {
            if j > 0 { write!(out, ",")?; }
            write!(out, "{{\"offset\":{},\"log_size\":{},\"coefficient\":{:?},\"point\":{:?}}}", p.slice.offset, p.slice.log_size, fp2(p.coef), fp2s(&p.point))?;
        }
        write!(out, "]}}")?;
    }
    write!(out, "],\"groups\":[")?;
    for (i, g) in r.groups.iter().enumerate() {
        if i > 0 { write!(out, ",")?; }
        write!(out, "{{\"members\":{:?},\"lambdas\":{:?},\"key\":{{\"tail\":{:?},\"offset\":{},\"len\":{}}},\"vector\":{:?}}}", g.members, fp2s(&g.lambdas), fp2s(&g.key.tail), g.key.offset, g.key.len, fp2s(&o.opening.group_vecs[i]))?;
    }
    write!(out, "],\"proximity_rhos\":{:?},\"proximity_vector\":{:?},\"columns\":", fp2s(&r.proximity_rhos), fp2s(&o.opening.prox_vec))?;
    columns(out, &o.opening.columns)?;
    let lay = Layout::new();
    let (data, prox) = match name { "A" => (lay.a_data_rows, lay.a_prox), "H" => (lay.h_data_rows, lay.h_prox), _ => (2, 4) };
    write!(out, ",\"q_pad\":256,\"row_roles\":[")?;
    for row in 0..o.commitment.rows {
        if row > 0 { write!(out, ",")?; }
        let kind = if name == "H" && lay.h_u_rows().contains(&row) { "mask" } else if row < data { "data" } else if row < prox { "mask" } else { "prox" };
        let site = format!("{name}.{kind}[{row}]");
        write!(out, "{{\"row\":{row},\"kind\":{kind:?},\"site\":{site:?}}}")?;
    }
    write!(out, "],\"public_linear_constraints\":[")?;
    if name == "H" {
        write!(out, "{{\"rows\":{:?},\"relation\":\"sum over the n message columns = 0\",\"source\":\"zsum sumcheck\"}}", lay.h_u_rows())?;
    }
    write!(out, "]}}")
}

fn export(bytes: &[u8], policy: &[u8], json: &[u8]) {
    let Ok(dir) = std::env::var("HL_TEST_NATIVE_CAPTURES") else { return; };
    let source = std::env::var("HL_TEST_SOURCE_COMMIT").expect("capture export requires source pin");
    assert!(source.len() == 40 && source.bytes().all(|b| b.is_ascii_hexdigit()));
    let dir = std::path::Path::new(&dir);
    std::fs::create_dir_all(dir).unwrap();
    let sha = crate::export_v3::sha256_hex(bytes);
    // The JSON is written last: no accepted capture exists if a bundle is incomplete.
    for (suffix, contents) in [("receipt", bytes), ("expected", policy), ("json", json)] {
        let path = dir.join(format!("{sha}.{suffix}"));
        let mut file = std::fs::OpenOptions::new().create_new(true).write(true).open(path).unwrap();
        file.write_all(contents).unwrap();
    }
    eprintln!("NATIVE_CAPTURE profile={} sha256={sha} slots={N_SLOTS} all_openings_replayed=true", std::str::from_utf8(PROFILE).unwrap());
}

#[test]
fn native_capture_roundtrip_and_refusals() {
    let (public, input) = Public::synthetic_fixture();
    let output = compute_output(&public, &input).unwrap();
    let spec = IoSpec::new(*blake3::hash(b"native capture public synthetic fixture").as_bytes(), 0, 0).unwrap();
    let guard = Guard::new();
    for _ in 0..2 {
        begin();
        let (expected, owners) = prepare_endpoints(spec.clone(), &input, &output).unwrap();
        let receipt = prove_with_stats(&public, &input, &expected, owners).unwrap().0;
        assert!(guard.take().is_none(), "prover must never publish observations");
        let bytes = receipt.to_bytes(&public, &expected).unwrap();
        verify_bytes(&public, &expected, &bytes).unwrap();
        let json = guard.take().expect("fully accepted capture");
        verify(&public, &expected, &receipt).unwrap();
        assert_eq!(json, guard.take().unwrap(), "typed/wire capture identity");
        assert_eq!(bytes, receipt.to_bytes(&public, &expected).unwrap());
        export(&bytes, &expected.to_bytes(), &json);
        for at in [0, 40, 40 + 96 + 24, bytes.len() - 1] {
            verify_bytes(&public, &expected, &bytes).unwrap(); // leave a stale success pending
            let mut bad = bytes.clone(); bad[at] ^= 1;
            assert!(verify_bytes(&public, &expected, &bad).is_err());
            assert!(guard.take().is_none(), "rejected attempt published stale/partial capture");
        }
        verify_bytes(&public, &expected, &bytes).unwrap();
        let mut bad = Receipt::from_bytes(&public, &expected, &bytes).unwrap(); bad.mask_open.q[0] = bad.mask_open.q[0].add(Fp2::ONE);
        assert!(verify(&public, &expected, &bad).is_err());
        assert!(guard.take().is_none());
        verify_bytes(&public, &expected, &bytes).unwrap();
        let mut bad = Receipt::from_bytes(&public, &expected, &bytes).unwrap(); bad.io_open[1].prox_vec[0] = bad.io_open[1].prox_vec[0].add(Fp2::ONE);
        assert!(verify(&public, &expected, &bad).is_err());
        assert!(guard.take().is_none());
    }
}

// Fresh-process replay/export of a retained receipt. Never builds a witness,
// computes an output or calls a prover. Public::synthetic_fixture supplies the
// caller's independently reconstructed public statement; discard its input.
#[test]
#[ignore = "requires explicit saved public-fixture receipt and expected policy paths"]
fn native_capture_saved_receipt() {
    let bytes = bounded_read(&std::env::var("HL_TEST_NATIVE_RECEIPT").unwrap(), MAX_WIRE_BYTES);
    let policy = bounded_read(&std::env::var("HL_TEST_NATIVE_EXPECTED").unwrap(), EXPECTED_BYTES);
    let expected = ExpectedIo::from_bytes(&policy).unwrap();
    let (public, _) = Public::synthetic_fixture();
    let guard = Guard::new();
    verify_bytes(&public, &expected, &bytes).unwrap();
    let json = guard.take().unwrap();
    if let Ok(reference) = std::env::var("HL_TEST_NATIVE_COMPARE") {
        // Keep failure output bounded: captures contain megabytes of public data.
        assert!(json == bounded_read(&reference, 64 * 1024 * 1024), "capture differs from verified receipt");
    }
    export(&bytes, &policy, &json);
}

fn bounded_read(path: &str, limit: usize) -> Vec<u8> {
    use std::io::Read;
    let mut out = Vec::new();
    std::fs::File::open(path).unwrap().take(limit as u64 + 1).read_to_end(&mut out).unwrap();
    assert!(out.len() <= limit, "capture input exceeds bound");
    out
}

pub(super) struct Observation {
    params: PcsParams,
    commitment: Commitment,
    claims: Vec<ZClaim>,
    opening: OpeningZk,
    before: Transcript,
    after: Option<Transcript>,
}


#[derive(Clone, Debug, PartialEq)]
struct ColumnKey {
    tail: Vec<Fp2>,
    offset: usize,
    len: usize,
}
#[derive(Debug)]
struct Group {
    key: ColumnKey,
    members: Vec<usize>,
    lambdas: Vec<Fp2>,
}

#[derive(Debug)]
struct Replayed {
    groups: Vec<Group>,
    proximity_rhos: Vec<Fp2>,
}

// Deliberately independent of private PCS grouping helpers. Refuse malformed
// mappings before ordinary PCS verification (which asserts on trusted claims).
fn column_key(p: &ZPart, o: &Observation) -> Result<ColumnKey, String> {
    let n = o.params.cols();
    let len = 1usize
        .checked_shl(p.slice.log_size)
        .ok_or("slice overflow")?;
    let end = p.slice.offset.checked_add(len).ok_or("slice overflow")?;
    let capacity = o
        .commitment
        .rows
        .checked_mul(n)
        .ok_or("capacity overflow")?;
    if end > capacity || (!p.point.is_empty() && p.point.len() != p.slice.log_size as usize) {
        return Err("slice bounds/point arity".into());
    }
    if len >= n {
        if p.slice.offset % n != 0 {
            return Err("unaligned row slice".into());
        }
        let tail = if p.point.is_empty() {
            vec![]
        } else {
            p.point[p.slice.log_size as usize - o.params.log_cols as usize..].to_vec()
        };
        Ok(ColumnKey {
            tail,
            offset: 0,
            len: n,
        })
    } else {
        let offset = p.slice.offset % n;
        if offset + len > n {
            return Err("slice crosses row".into());
        }
        Ok(ColumnKey {
            tail: p.point.clone(),
            offset,
            len,
        })
    }
}

fn replay(o: &Observation, ntt: &NttTables) -> Result<Replayed, String> {
    let n = o.params.cols();
    let q = o.params.num_col_checks;
    let mut groups: Vec<Group> = Vec::new();
    for (ci, c) in o.claims.iter().enumerate() {
        let first = c.parts.first().ok_or("empty claim")?;
        let key = column_key(first, o)?;
        for p in &c.parts[1..] {
            if column_key(p, o)? != key {
                return Err("different column keys".into());
            }
        }
        if let Some(g) = groups.iter_mut().find(|g| g.key == key) {
            g.members.push(ci);
        } else {
            groups.push(Group {
                key,
                members: vec![ci],
                lambdas: vec![],
            });
        }
    }
    if groups.len() != o.opening.group_vecs.len() {
        return Err("group count".into());
    }
    let mut tr = Transcript::clone_state(&o.before);
    for g in &mut groups {
        g.lambdas = tr.challenge_fp2_vec(g.members.len());
    }
    // Actual source order: proximity coefficients BEFORE vector absorption.
    let proximity_rhos = tr.challenge_fp2_vec(o.commitment.rows);
    for (g, v) in groups.iter().zip(&o.opening.group_vecs) {
        if v.len() != n + q {
            return Err("vector length".into());
        }
        let cw = if g.key.tail.is_empty() {
            vec![Fp2::ONE; g.key.len]
        } else {
            eq_table_msb(&g.key.tail)
        };
        let got = v[g.key.offset..g.key.offset + g.key.len]
            .iter()
            .zip(cw)
            .fold(Fp2::ZERO, |a, (v, c)| a.add(v.mul(c)));
        let want = g
            .members
            .iter()
            .zip(&g.lambdas)
            .fold(Fp2::ZERO, |a, (&ci, l)| a.add(l.mul(o.claims[ci].value)));
        if got != want {
            return Err("combined public claim".into());
        }
        tr.absorb_fp2(b"pcs-vec", v);
    }
    if o.opening.prox_vec.len() != n + q {
        return Err("proximity length".into());
    }
    tr.absorb_fp2(b"pcs-prox", &o.opening.prox_vec);
    let indices = tr.challenge_indices(q, o.params.enc_cols());
    if indices != o.opening.columns.iter().map(|c| c.0).collect::<Vec<_>>() {
        return Err("sampled column indices".into());
    }
    if !same_transcript(&tr, o.after.as_ref().ok_or("not fully verified")?) {
        return Err("transcript endpoint".into());
    }
    let mut ordinary = Transcript::clone_state(&o.before);
    pcs::verify_zk(
        &o.params,
        &ZkOpts::standard(&o.params),
        &o.commitment,
        &o.claims,
        &o.opening,
        ntt,
        &mut ordinary,
    )?;
    if !same_transcript(&tr, &ordinary) {
        return Err("ordinary verifier endpoint".into());
    }
    Ok(Replayed {
        groups,
        proximity_rhos,
    })
}
