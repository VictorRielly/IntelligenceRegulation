//! Unit-test-only observations of a fully accepted IO receipt. No prover state.
//! This is a separate schema from the archived FFN captures. Capturing an
//! observation does not establish that it is hidden; the analysis owns that.
use super::*;
use std::io::{BufWriter, Write};

struct MaskObservation {
    root: Digest,
    specs: Vec<(usize, usize)>,
    functionals: Vec<MaskFunctional>,
    opening: MaskOpening,
    before: Transcript,
    after: Option<Transcript>,
}

struct PlainObservation {
    params: PcsParams,
    commitment: Commitment,
    claims: Vec<Claim>,
    opening: Opening,
    before: Transcript,
    after: Transcript,
}

struct IoArgument {
    side: usize,
    tau: Vec<Fp2>,
    c: Fp2,
    rho: Vec<Fp2>,
    gamma: Fp2,
    sc: SumcheckProof,
    terminals: [Fp2; 2],
    mask_eval: Fp2,
    before: Transcript,
    after: Transcript,
}

#[derive(Default)]
struct Pending {
    mask: Option<MaskObservation>,
    public_w: Option<PlainObservation>,
    roles: Vec<(&'static str, Observation)>,
    arguments: Vec<IoArgument>,
    verified: Option<Verified>,
}

struct Verified {
    st: StatementV3,
    privacy: ZkPrivacy,
    policy: Vec<u8>,
    receipt: Vec<u8>,
    proof: LayerProofZk,
}

thread_local! {
    static IO_OBSERVER: RefCell<Option<Pending>> = const { RefCell::new(None) };
}

pub(crate) struct CaptureGuard;
impl CaptureGuard {
    pub(crate) fn new() -> Self {
        IO_OBSERVER.with(|s| {
            assert!(s.borrow().is_none(), "nested IO capture");
            *s.borrow_mut() = Some(Pending::default());
        });
        Self
    }

    pub(crate) fn is_published(&self) -> bool {
        IO_OBSERVER.with(|s| s.borrow().as_ref().unwrap().verified.is_some())
    }

    pub(crate) fn check_tamper_controls(&self) {
        IO_OBSERVER.with(|s| {
            let mut s = s.borrow_mut();
            let p = s.as_mut().unwrap();
            check(p).unwrap();
            p.roles.swap(0, 1);
            assert!(check(p).unwrap_err().contains("schedule"));
            p.roles.swap(0, 1);
            p.mask.as_mut().unwrap().opening.columns[0].1[0] = p.mask.as_ref().unwrap().opening.columns[0].1[0].add(Fp::ONE);
            assert!(check(p).is_err());
            p.mask.as_mut().unwrap().opening.columns[0].1[0] = p.mask.as_ref().unwrap().opening.columns[0].1[0].sub(Fp::ONE);
            let last = p.roles.len() - 1;
            let after = Transcript::clone_state(p.roles[last].1.after.as_ref().unwrap());
            p.roles[last].1.after.as_mut().unwrap().challenge_fp2();
            assert!(check(p).unwrap_err().contains("transcript endpoint"));
            p.roles[last].1.after = Some(after);
            let saved = p.roles[last].1.opening.group_vecs[0][0];
            p.roles[last].1.opening.group_vecs[0][0] = saved.add(Fp2::ONE);
            assert!(check(p).is_err());
            p.roles[last].1.opening.group_vecs[0][0] = saved;
            let saved = p.roles[last].1.opening.columns[0].0;
            p.roles[last].1.opening.columns[0].0 ^= 1;
            assert!(check(p).unwrap_err().contains("sampled column indices"));
            p.roles[last].1.opening.columns[0].0 = saved;
            p.arguments[1].rho[0] = p.arguments[1].rho[0].add(Fp2::ONE);
            assert!(check(p).unwrap_err().contains("equality terminal replay"));
            p.arguments[1].rho[0] = p.arguments[1].rho[0].sub(Fp2::ONE);
            check(p).unwrap();
        });
    }

    /// Replays all captured PCS openings and checks their transcript joins.
    /// Export, if requested, contains only accepted receipt bytes and public
    /// verifier inputs/derived challenges. Consumes the publication.
    pub(crate) fn check_and_export(&self) {
        let pending = IO_OBSERVER.with(|s| s.borrow_mut().replace(Pending::default()).unwrap());
        let v = pending.verified.as_ref().expect("no fully accepted IO receipt");
        check(&pending).unwrap();
        if let Some(dir) = std::env::var_os("HL_TEST_FFN_IO_OBSERVATIONS") {
            export(&pending, v, std::path::Path::new(&dir)).unwrap();
        }
    }
}
impl Drop for CaptureGuard {
    fn drop(&mut self) {
        IO_OBSERVER.with(|s| *s.borrow_mut() = None);
    }
}

fn active() -> bool {
    IO_OBSERVER.with(|s| s.borrow().is_some())
}

/// Called before parsing as well as at typed verification entry. A failed
/// subsequent attempt must never expose an earlier successful publication.
pub(crate) fn begin() {
    IO_OBSERVER.with(|s| {
        if s.borrow().is_some() {
            *s.borrow_mut() = Some(Pending::default());
        }
    });
}

pub(crate) fn capture(
    role: Role, params: &PcsParams, commitment: &Commitment,
    claims: &[ZClaim], opening: &OpeningZk, tr: &Transcript,
) -> Option<Observation> {
    active().then(|| Observation {
        role, params: *params, commitment: commitment.clone(), claims: claims.to_vec(),
        opening: opening.clone(), before: Transcript::clone_state(tr), after: None,
    })
}

pub(crate) fn record(name: &'static str, observation: Option<Observation>) {
    if let Some(o) = observation {
        IO_OBSERVER.with(|s| s.borrow_mut().as_mut().unwrap().roles.push((name, o)));
    }
}

pub(crate) fn mask_before(root: &Digest, specs: &[(usize, usize)], fs: &[MaskFunctional], op: &MaskOpening, tr: &Transcript) {
    if active() {
        IO_OBSERVER.with(|s| {
            let mut s = s.borrow_mut();
            let p = s.as_mut().unwrap();
            assert!(p.mask.is_none(), "second IO mask opening");
            p.mask = Some(MaskObservation { root: *root, specs: specs.to_vec(), functionals: fs.to_vec(),
                opening: op.clone(), before: Transcript::clone_state(tr), after: None });
        });
    }
}
pub(crate) fn mask_after(tr: &Transcript) {
    if active() {
        IO_OBSERVER.with(|s| s.borrow_mut().as_mut().unwrap().mask.as_mut().unwrap().after = Some(Transcript::clone_state(tr)));
    }
}

pub(crate) fn public_w(params: &PcsParams, commitment: &Commitment, claims: &[Claim], opening: &Opening, before: &Transcript, after: &Transcript) {
    if active() {
        IO_OBSERVER.with(|s| s.borrow_mut().as_mut().unwrap().public_w = Some(PlainObservation {
            params: *params, commitment: commitment.clone(), claims: claims.to_vec(), opening: opening.clone(),
            before: Transcript::clone_state(before), after: Transcript::clone_state(after),
        }));
    }
}

pub(crate) fn argument(side: usize, tau: &[Fp2], c: Fp2, rho: &[Fp2], gamma: Fp2, sc: &SumcheckProof, terminals: [Fp2; 2], mask_eval: Fp2, before: &Transcript, after: &Transcript) {
    if active() {
        IO_OBSERVER.with(|s| s.borrow_mut().as_mut().unwrap().arguments.push(IoArgument {
            side, tau: tau.to_vec(), c, rho: rho.to_vec(), gamma, sc: sc.clone(), terminals, mask_eval,
            before: Transcript::clone_state(before), after: Transcript::clone_state(after),
        }));
    }
}

pub(crate) fn publish(st: &StatementV3, privacy: ZkPrivacy, policy: Vec<u8>, receipt: Vec<u8>, proof: &LayerProofZk) {
    if active() {
        IO_OBSERVER.with(|s| {
            let mut s = s.borrow_mut();
            let p = s.as_mut().unwrap();
            assert!(p.verified.is_none());
            p.verified = Some(Verified { st: st.clone(), privacy, policy, receipt, proof: proof.clone() });
        });
    }
}

fn check(p: &Pending) -> Result<(), String> {
    let v = p.verified.as_ref().ok_or("IO capture: not verified")?;
    if (v.st.t_rows, v.st.d, v.st.f, v.st.shifts) != (32, 16, 16, (7, 0, 14, 6)) {
        return Err("IO capture: unsupported fixture".into());
    }
    let p3 = v.privacy == ZkPrivacy::P3;
    let names: Vec<_> = p.roles.iter().map(|(name, _)| *name).collect();
    let want = if p3 { vec!["W", "A", "H", "Input", "Output"] } else { vec!["A", "H", "Input", "Output"] };
    if names != want || p.public_w.is_some() == p3 || p.arguments.len() != 2 {
        return Err("IO capture: role/argument schedule".into());
    }
    let ntt = NttTables::new(16);
    let m = p.mask.as_ref().ok_or("IO capture: missing M")?;
    let mut tr = Transcript::clone_state(&m.before);
    mask_verify(&m.root, &m.specs, &m.functionals, &m.opening, &ntt, &mut tr)?;
    if !same_transcript(&tr, m.after.as_ref().ok_or("IO capture: unfinished M")?) {
        return Err("IO capture: M transcript replay".into());
    }
    if m.specs.len() != 8 || m.specs[6..] != [(10, 2); 2] || m.opening.columns.iter().any(|(_, c, _, _)| c.len() != 20) {
        return Err("IO capture: consolidated M shape".into());
    }
    for (i, a) in p.arguments.iter().enumerate() {
        if a.side != i || (i == 1 && !same_transcript(&p.arguments[0].after, &a.before)) {
            return Err("IO capture: equality schedule".into());
        }
        let mut tr = Transcript::clone_state(&a.before);
        tr.absorb_u64(b"io-side", i as u64);
        if tr.challenge_fp2_vec(9) != a.tau || tr.challenge_fp2() != a.c || a.c.is_zero() {
            return Err("IO capture: equality challenge replay".into());
        }
        tr.absorb_fp2(b"io-gamma", &[a.gamma]);
        let (fin, rho) = sumcheck::verify(a.gamma, 2, 10, &a.sc, &mut tr)?;
        if rho != a.rho || rho[9].is_zero() || fin != Fp2::ONE.sub(rho[9]).mul(eq_point(&a.tau, &rho[..9])).mul(a.terminals[0].sub(a.terminals[1])).add(a.c.mul(a.mask_eval)) {
            return Err("IO capture: equality terminal replay".into());
        }
        tr.absorb_fp2(b"io-terminals", &a.terminals);
        tr.absorb_fp2(b"io-mask-eval", &[a.mask_eval]);
        if !same_transcript(&tr, &a.after) {
            return Err("IO capture: equality transcript replay".into());
        }
    }
    if !same_transcript(&p.arguments[1].after, &m.before) {
        return Err("IO capture: equalities/M join".into());
    }
    if let Some(w) = &p.public_w {
        if !same_transcript(&tr, &w.before) { return Err("IO capture: M/public-W join".into()); }
        pcs::verify(&w.params, &w.commitment, &w.claims, &w.opening, &ntt, &mut tr)?;
        if !same_transcript(&tr, &w.after) { return Err("IO capture: public W replay".into()); }
    }
    for (_, o) in &p.roles {
        if !same_transcript(&tr, &o.before) { return Err("IO capture: PCS transcript join".into()); }
        replay(o, &ntt)?;
        tr = Transcript::clone_state(o.after.as_ref().unwrap());
    }
    let a = &p.roles[usize::from(p3)].1;
    if a.commitment.rows != 702 || a.claims.len() != 20 || a.opening.group_vecs.len() != 7 {
        return Err("IO capture: A geometry".into());
    }
    for i in 0..2 {
        let endpoint = &p.roles[p.roles.len() - 2 + i].1;
        let left = &a.claims[18 + i];
        let right = endpoint.claims.first().ok_or("IO capture: endpoint claim")?;
        if endpoint.commitment.rows != 7 || endpoint.claims.len() != 1 || endpoint.opening.group_vecs.len() != 1
            || left.parts[0].slice.offset != [3584, 4096][i] || right.parts[0].slice.offset != 0
            || left.value != p.arguments[i].terminals[0] || right.value != p.arguments[i].terminals[1]
            || left.parts[0].point != right.parts[0].point {
            return Err("IO capture: equality aliases/terminals".into());
        }
    }
    Ok(())
}

fn fp2(v: Fp2) -> [u64; 2] { [v.c0.0, v.c1.0] }
fn fp2s(v: &[Fp2]) -> Vec<[u64; 2]> { v.iter().copied().map(fp2).collect() }
fn state(out: &mut impl Write, name: &str, tr: &Transcript) -> std::io::Result<()> {
    write!(out, "{name:?}:{{\"state\":{:?},\"next\":{:?}}}", tr.state(), fp2(Transcript::clone_state(tr).challenge_fp2()))
}
fn columns(out: &mut impl Write, cols: &[(usize, Vec<Fp>, [u8; 32], Vec<Digest>)]) -> std::io::Result<()> {
    write!(out, "[")?;
    for (i, (index, values, salt, path)) in cols.iter().enumerate() {
        if i > 0 { write!(out, ",")?; }
        write!(out, "{{\"index\":{index},\"values\":{:?},\"salt\":{salt:?},\"path\":{path:?}}}", values.iter().map(|x| x.0).collect::<Vec<_>>())?;
    }
    write!(out, "]")
}
fn rounds(out: &mut impl Write, sc: &SumcheckProof) -> std::io::Result<()> {
    write!(out, "{:?}", sc.rounds.iter().map(|r| fp2s(r)).collect::<Vec<_>>())
}

fn write_pcs(out: &mut impl Write, name: &str, o: &Observation, zl: &ZkLayoutV3, privacy: ZkPrivacy) -> std::io::Result<()> {
    let r = replay(o, &NttTables::new(16)).unwrap();
    write!(out, "{{\"role\":{name:?},\"params\":{{\"log_cols\":{},\"inv_rate\":{},\"num_col_checks\":{}}},\"commitment\":{{\"root\":{:?},\"rows\":{}}},", o.params.log_cols, o.params.inv_rate, o.params.num_col_checks, o.commitment.root, o.commitment.rows)?;
    state(out, "before", &o.before)?; write!(out, ",")?;
    state(out, "after", o.after.as_ref().unwrap())?;
    write!(out, ",\"claims\":[")?;
    for (i, c) in o.claims.iter().enumerate() {
        if i > 0 { write!(out, ",")?; }
        write!(out, "{{\"value\":{:?},\"parts\":[", fp2(c.value))?;
        for (j, p) in c.parts.iter().enumerate() {
            if j > 0 { write!(out, ",")?; }
            let tag = if name == "Input" || name == "Output" || (name == "A" && i >= 18) {
                ["1-e_io", "e_io", "e_io*u"][j].to_string()
            } else { observation_json::coefficient_tag(o.role, i, j, privacy) };
            write!(out, "{{\"offset\":{},\"log_size\":{},\"coefficient\":{:?},\"point\":{:?},\"coefficient_tag\":{tag:?}}}", p.slice.offset, p.slice.log_size, fp2(p.coef), fp2s(&p.point))?;
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
    if name == "Input" || name == "Output" {
        write!(out, ",\"q_pad\":256,\"row_roles\":[")?;
        for row in 0..7 {
            if row > 0 { write!(out, ",")?; }
            let kind = if row < 2 { "data" } else if row < 4 { "mask" } else { "prox" };
            let site = format!("{name}.{kind}[{row}]");
            write!(out, "{{\"row\":{row},\"kind\":{kind:?},\"site\":{site:?}}}")?;
        }
        write!(out, "],\"public_linear_constraints\":[]")?;
    } else { observation_json::write_row_roles(out, o, zl)?; }
    write!(out, "}}")
}

fn export(p: &Pending, v: &Verified, dir: &std::path::Path) -> std::io::Result<()> {
    let source = std::env::var("HL_TEST_SOURCE_COMMIT").expect("IO capture source commit required");
    assert!(source.len() == 40 && source.bytes().all(|b| b.is_ascii_hexdigit()));
    let zl = ZkLayoutV3::with_io(&v.st, &fresh_poc::parameters());
    let description = zl.describe().join("\n");
    let sha = crate::export_v3::sha256_hex(&v.receipt);
    let policy_sha = crate::export_v3::sha256_hex(&v.policy);
    std::fs::create_dir_all(dir)?;
    let new_file = |suffix: &str| std::fs::OpenOptions::new().write(true).create_new(true).open(dir.join(format!("{sha}.{suffix}")));
    new_file("receipt")?.write_all(&v.receipt)?;
    new_file("expected")?.write_all(&v.policy)?;
    let mut out = BufWriter::new(new_file("json")?);
    write!(out, "{{\"schema\":3,\"kind\":\"zk60-verifier-observations\",\"coverage\":\"ffn-v3-mr1-fresh-io-poc-function-1\",\"profile\":\"ffn-v3-mr1-fresh-io-poc/2\",\"transcript_domain\":{:?},\"source_commit\":{source:?},\"fully_verified\":true,\"privacy\":\"{:?}\",\"shape\":{{\"t\":32,\"d\":16,\"f\":16}},\"shifts\":[7,0,14,6],\"field_modulus\":{},\"extension_nonresidue\":{},\"proof_sha256\":{sha:?},\"proof_bytes\":{},\"proof_digest_encoding\":\"complete HFFNIO version 2 receipt\",\"expected_policy_sha256\":{policy_sha:?},\"expected_policy\":{:?},\"layout_description\":{description:?},\"layout_digest\":{:?},\"weight_policy\":\"fresh-per-proof\",\"slot\":null,\"k\":null,\"opening_order\":[\"M\",\"W\",\"A\",\"H\",\"Input\",\"Output\"],\"roles\":[", std::str::from_utf8(fresh_poc::io::PROFILE).unwrap(), v.privacy, crate::field::P, crate::field::NONRESIDUE, v.receipt.len(), v.policy, crate::export_v3::sha256_hex(description.as_bytes()))?;
    for (i, (name, o)) in p.roles.iter().enumerate() {
        if i > 0 { write!(out, ",")?; }
        write_pcs(&mut out, name, o, &zl, v.privacy)?;
    }
    write!(out, "],\"public_w\":")?;
    if let Some(w) = &p.public_w {
        write!(out, "{{\"root\":{:?},\"rows\":{},", w.commitment.root, w.commitment.rows)?;
        state(&mut out, "before", &w.before)?; write!(out, ",")?;
        state(&mut out, "after", &w.after)?;
        write!(out, ",\"opening_in_receipt\":true}}")?;
    } else { write!(out, "null")?; }
    let m = p.mask.as_ref().unwrap();
    let mut tr = Transcript::clone_state(&m.before);
    let theta = tr.challenge_fp2();
    tr.absorb_fp2(b"mask-q", &m.opening.q);
    let rs = tr.challenge_fp2_vec(2 * m.specs.len() + 2);
    write!(out, ",\"mask\":{{\"root\":{:?},\"specs\":{:?},\"theta\":{:?},\"proximity_rhos\":{:?},", m.root, m.specs.iter().map(|&(n, d)| [n, d]).collect::<Vec<_>>(), fp2(theta), fp2s(&rs))?;
    state(&mut out, "before", &m.before)?; write!(out, ",")?;
    state(&mut out, "after", m.after.as_ref().unwrap())?;
    write!(out, ",\"functionals\":[")?;
    for (i, f) in m.functionals.iter().enumerate() {
        if i > 0 { write!(out, ",")?; }
        write!(out, "{{\"value\":{:?},\"terms\":[", fp2(f.value))?;
        for (j, (slot, weights)) in f.terms.iter().enumerate() {
            if j > 0 { write!(out, ",")?; }
            write!(out, "{{\"slot\":{slot},\"weights\":{:?}}}", fp2s(weights))?;
        }
        write!(out, "]}}")?;
    }
    write!(out, "],\"q\":{:?},\"prox\":{:?},\"columns\":", fp2s(&m.opening.q), fp2s(&m.opening.prox))?;
    columns(&mut out, &m.opening.columns)?;
    write!(out, "}},\"io_arguments\":[")?;
    for (i, a) in p.arguments.iter().enumerate() {
        if i > 0 { write!(out, ",")?; }
        write!(out, "{{\"side\":{},\"slot\":{},\"tau\":{:?},\"c\":{:?},\"rho\":{:?},\"gamma\":{:?},\"terminals\":{:?},\"mask_eval\":{:?},\"rounds\":", a.side, 6 + a.side, fp2s(&a.tau), fp2(a.c), fp2s(&a.rho), fp2(a.gamma), fp2s(&a.terminals), fp2(a.mask_eval))?;
        rounds(&mut out, &a.sc)?; write!(out, ",")?;
        state(&mut out, "before", &a.before)?; write!(out, ",")?;
        state(&mut out, "after", &a.after)?;
        write!(out, "}}")?;
    }
    let f = &v.proof;
    write!(out, "],\"ffn_arguments\":[")?;
    for (i, (name, sc, terms)) in [("gu", &f.gu_sc, &f.gu_term[..]), ("d", &f.d_sc, &f.d_term[..]), ("zc20", &f.zc20_sc, &f.zc20_term[..]), ("zc17", &f.zc17_sc, &f.zc17_term[..]), ("tab", &f.tab_sc, &f.tab_term[..]), ("zs", &f.zs_sc, std::slice::from_ref(&f.zs_term))].into_iter().enumerate() {
        if i > 0 { write!(out, ",")?; }
        write!(out, "{{\"name\":{name:?},\"terminals\":{:?},\"rounds\":", fp2s(terms))?;
        rounds(&mut out, sc)?; write!(out, "}}")?;
    }
    writeln!(out, "],\"ffn_matmul_claims\":{:?},\"ffn_gammas\":{:?},\"privacy_review_complete\":false}}", fp2s(&[f.gu_claim, f.d_claim]), fp2s(&[f.gamma20, f.gamma17, f.gamma_tab, f.gamma_zs]))?;
    out.flush()?;
    eprintln!("IO_CAPTURE privacy={:?} receipt_sha256={sha} bytes={} roles={} all_openings_replayed=true", v.privacy, v.receipt.len(), p.roles.len());
    Ok(())
}
