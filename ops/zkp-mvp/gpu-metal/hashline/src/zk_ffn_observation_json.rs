//! Test-only public observation export for the independent FA2 rank review.
//! No witness, masks, unsampled salts or RNG state enter this writer.
//! Field coordinates are exact JSON integers; consumers must use bigint/u64,
//! not a floating-point JSON number representation.

use super::*;
use std::io::{BufWriter, Write};

fn fp2(v: Fp2) -> [u64; 2] {
    [v.c0.0, v.c1.0]
}

fn fp2s(v: &[Fp2]) -> Vec<[u64; 2]> {
    v.iter().copied().map(fp2).collect()
}

fn write_role(out: &mut impl Write, o: &Observation, ntt: &NttTables, repaired: Option<(&ZkLayoutV3, ZkPrivacy)>) -> std::io::Result<()> {
    let r = replay(o, ntt).expect("export only fully replayed observations");
    let end = o.after.as_ref().unwrap();
    write!(out, "{{\"role\":\"{:?}\",\"params\":{{\"log_cols\":{},\"inv_rate\":{},\"num_col_checks\":{}}},\"commitment\":{{\"root\":{:?},\"rows\":{}}},\"before_state\":{:?},\"before_next_challenge\":{:?},\"after_state\":{:?},\"after_next_challenge\":{:?},\"claims\":[",
        o.role, o.params.log_cols, o.params.inv_rate, o.params.num_col_checks,
        o.commitment.root, o.commitment.rows, o.before.state(),
        fp2(Transcript::clone_state(&o.before).challenge_fp2()), end.state(),
        fp2(Transcript::clone_state(end).challenge_fp2()))?;
    for (i, c) in o.claims.iter().enumerate() {
        if i > 0 {
            write!(out, ",")?;
        }
        write!(out, "{{\"value\":{:?},\"parts\":[", fp2(c.value))?;
        for (j, p) in c.parts.iter().enumerate() {
            if j > 0 {
                write!(out, ",")?;
            }
            write!(
                out,
                "{{\"offset\":{},\"log_size\":{},\"coefficient\":{:?},\"point\":{:?}",
                p.slice.offset,
                p.slice.log_size,
                fp2(p.coef),
                fp2s(&p.point)
            )?;
            if let Some((_, privacy)) = repaired { write!(out, ",\"coefficient_tag\":{:?}", coefficient_tag(o.role, i, j, privacy))?; }
            write!(out, "}}")?;
        }
        write!(out, "]}}")?;
    }
    write!(out, "],\"groups\":[")?;
    for (i, g) in r.groups.iter().enumerate() {
        if i > 0 {
            write!(out, ",")?;
        }
        write!(out, "{{\"members\":{:?},\"lambdas\":{:?},\"key\":{{\"tail\":{:?},\"offset\":{},\"len\":{}}},\"vector\":{:?}}}",
            g.members, fp2s(&g.lambdas), fp2s(&g.key.tail), g.key.offset,
            g.key.len, fp2s(&o.opening.group_vecs[i]))?;
    }
    write!(
        out,
        "],\"proximity_rhos\":{:?},\"proximity_vector\":{:?},\"columns\":[",
        fp2s(&r.proximity_rhos),
        fp2s(&o.opening.prox_vec)
    )?;
    for (i, (index, values, salt, path)) in o.opening.columns.iter().enumerate() {
        if i > 0 {
            write!(out, ",")?;
        }
        write!(
            out,
            "{{\"index\":{},\"values\":{:?},\"salt\":{:?},\"path\":{:?}}}",
            index,
            values.iter().map(|v| v.0).collect::<Vec<_>>(),
            salt,
            path
        )?;
    }
    write!(out, "]")?;
    if let Some((zl, _)) = repaired { write_row_roles(out, o, zl)?; }
    write!(out, "}}")
}

pub(super) fn export_if_requested(
    observed: &VerifiedObservations,
    ntt: &NttTables,
    t: usize,
    privacy: ZkPrivacy,
    proof_sha256: &str,
) {
    let Some(dir) = std::env::var_os("HL_TEST_FFN_OBSERVATIONS") else {
        return;
    };
    let dir = std::path::PathBuf::from(dir);
    std::fs::create_dir_all(&dir).unwrap();
    // The full proof digest gives concurrent tests distinct, reproducible names.
    // Refuse stale files rather than silently replacing another capture.
    let path = dir.join(format!("{proof_sha256}.json"));
    let file = std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(path)
        .unwrap();
    let mut out = BufWriter::new(file);
    write!(out, "{{\"schema\":1,\"kind\":\"zk60-verifier-observations\",\"coverage\":\"ffn-v3-function-1\",\"fully_verified\":true,\"privacy\":\"{privacy:?}\",\"shape\":{{\"t\":{t},\"d\":16,\"f\":16}},\"field_modulus\":{},\"extension_nonresidue\":{},\"proof_sha256\":\"{proof_sha256}\",\"roles\":[",
        crate::field::P, crate::field::NONRESIDUE).unwrap();
    for (i, o) in observed
        .w
        .iter()
        .chain([&observed.a, &observed.h])
        .enumerate()
    {
        if i > 0 {
            write!(out, ",").unwrap();
        }
        write_role(&mut out, o, ntt, None).unwrap();
    }
    writeln!(out, "]}}").unwrap();
    out.flush().unwrap();
}

// Fixed function-1 T32/d16/f16 claim ordering. These labels describe the
// verifier's coefficients; numerical coordinates remain the source of truth.
pub(super) fn coefficient_tag(role: Role, claim: usize, part: usize, privacy: ZkPrivacy) -> String {
    let p3 = privacy == ZkPrivacy::P3;
    let pair = |data: &str, mask: &str, i| match i {
        0 => data.to_string(), 1 => mask.to_string(), _ => format!("({mask})*u"),
    };
    match role {
        Role::A => match claim {
            0..=6 => pair("1-e_f", "e_f", part),
            7..=9 => pair("1-e_dz", "e_dz", part),
            10 => pair(if p3 { "(1-e_gu2)*(1-e_gu)" } else { "1-e_gu" }, if p3 { "(1-e_gu2)*e_gu" } else { "e_gu" }, part),
            11 => pair(if p3 { "(1-e_d2)*(1-e_d)" } else { "1-e_d" }, if p3 { "(1-e_d2)*e_d" } else { "e_d" }, part),
            _ => pair(&format!("(1-e_tab)*ext_{}", claim - 12), &format!("e_tab*ext_{}", claim - 12), part),
        },
        Role::W => if claim < 2 { pair("(1-e_gu2)*(1-e_gu)", "e_gu2", part) }
            else { pair("(1-e_d2)*(1-e_d)", "e_d2", part) },
        Role::H => {
            if claim == 11 { return "public LogUp sum coefficient".into(); }
            let e = match claim { 0..=2 => "e_f", 3 => "e_dz", 4 => "e_zs", _ => "e_tab" };
            let base = if part < 2 { format!("1-{e}") } else { e.to_string() };
            let ext = if claim >= 5 { format!("*ext_{}", claim - 5) } else { String::new() };
            format!("({base}){ext}{}", if part % 2 == 1 { "*u" } else { "" })
        }
    }
}

pub(super) fn write_row_roles(out: &mut impl Write, o: &Observation, zl: &ZkLayoutV3) -> std::io::Result<()> {
    let mut names: Vec<(&str, String)> = (0..o.commitment.rows).map(|r| ("data", format!("{:?}.data[{r}]", o.role))).collect();
    let mut set = |row, kind, name: String| { names[row] = (kind, name); };
    match o.role {
        Role::A => {
            for (site, rows) in [("a_mf", &zl.a_mf), ("a_md", &zl.a_md), ("a_mgu", &zl.a_mgu), ("a_mdd", &zl.a_mdd)] {
                for (i, &r) in rows.iter().enumerate() { set(r, "mask", format!("{site}[{i}].re")); set(r + 1, "mask", format!("{site}[{i}].im")); }
            }
            for (i, t) in zl.tabs.iter().enumerate() {
                for j in 0..t.rows { set(t.a_row + j, "data", format!("tab[{i}].multiplicity[{j}]")); }
                for j in 0..if t.rows == 1 { 2 } else { t.rows } { set(t.a_mask + j, "mask", format!("tab[{i}].a_mask[{j}]")); }
            }
            set(zl.a_prox, "prox", "a_prox.re".into()); set(zl.a_prox + 1, "prox", "a_prox.im".into());
            if let Some(rows) = zl.a_io {
                for (i, row) in rows.into_iter().enumerate() {
                    set(row, "mask", format!("a_io[{i}].re"));
                    set(row + 1, "mask", format!("a_io[{i}].im"));
                }
            }
        }
        Role::H => {
            for (site, rows) in [("h_mf", &zl.h_mf), ("h_md", &zl.h_md)] {
                for (i, &(re, im)) in rows.iter().enumerate() { set(re, "mask", format!("{site}[{i}].re")); set(im, "mask", format!("{site}[{i}].im")); }
            }
            for (site, (re, im)) in [("h_u", zl.h_u), ("h_up", zl.h_up)] { set(re, "mask", format!("{site}.re")); set(im, "mask", format!("{site}.im")); }
            for (i, t) in zl.tabs.iter().enumerate() {
                for (site, row, kind) in [("h_re", t.h_re, "data"), ("h_im", t.h_im, "data"), ("h_mre", t.h_mre, "mask"), ("h_mim", t.h_mim, "mask")] {
                    for j in 0..t.rows { set(row + j, kind, format!("tab[{i}].{site}[{j}]")); }
                }
            }
            set(zl.h_prox, "prox", "h_prox.re".into()); set(zl.h_prox + 1, "prox", "h_prox.im".into());
        }
        Role::W => {
            for (site, rows) in [("w_mgu", &zl.w_mgu), ("w_mdd", &zl.w_mdd)] {
                for (i, &r) in rows.iter().enumerate() { set(r, "mask", format!("{site}[{i}].re")); set(r + 1, "mask", format!("{site}[{i}].im")); }
            }
            set(zl.w_prox, "prox", "w_prox.re".into()); set(zl.w_prox + 1, "prox", "w_prox.im".into());
        }
    }
    write!(out, ",\"q_pad\":256,\"row_roles\":[")?;
    for (row, (kind, site)) in names.iter().enumerate() {
        if row > 0 { write!(out, ",")?; }
        write!(out, "{{\"row\":{row},\"kind\":{kind:?},\"site\":{site:?}}}")?;
    }
    write!(out, "],\"public_linear_constraints\":[")?;
    if o.role == Role::H {
        write!(out, "{{\"rows\":{:?},\"relation\":\"sum over the n message columns = 0\",\"source\":\"zsum sumcheck\"}}", [zl.h_u.0, zl.h_u.1])?;
    }
    write!(out, "]")
}

pub(super) fn export_repaired_if_requested(observed: &VerifiedObservations, ntt: &NttTables, zl: &ZkLayoutV3, privacy: ZkPrivacy, proof_sha256: &str) {
    let Some(dir) = std::env::var_os("HL_TEST_FFN_REPAIRED_OBSERVATIONS") else { return; };
    let source = std::env::var("HL_TEST_SOURCE_COMMIT").expect("capture source commit required");
    assert_eq!(source.len(), 40);
    assert!(source.bytes().all(|c| c.is_ascii_hexdigit()));
    let dir = std::path::PathBuf::from(dir);
    std::fs::create_dir_all(&dir).unwrap();
    let file = std::fs::OpenOptions::new().write(true).create_new(true).open(dir.join(format!("{proof_sha256}.json"))).unwrap();
    let mut out = BufWriter::new(file);
    let description = zl.describe().join("\n");
    let layout_digest = crate::export_v3::sha256_hex(description.as_bytes());
    let profile = std::str::from_utf8(fresh_poc::PROFILE).unwrap();
    write!(out, "{{\"schema\":2,\"kind\":\"zk60-verifier-observations\",\"coverage\":\"ffn-v3-mr1-fresh-poc-function-1\",\"profile\":\"ffn-v3-mr1-fresh-poc/2\",\"transcript_domain\":{profile:?},\"source_commit\":{source:?},\"layout_digest\":{layout_digest:?},\"layout_description\":{description:?},\"fully_verified\":true,\"privacy\":\"{privacy:?}\",\"shape\":{{\"t\":32,\"d\":16,\"f\":16}},\"shifts\":[7,0,14,6],\"weight_policy\":\"fresh-per-proof\",\"slot\":null,\"k\":null,\"field_modulus\":{},\"extension_nonresidue\":{},\"proof_sha256\":{proof_sha256:?},\"proof_digest_encoding\":\"legacy logical payload; experimental profile is bound in transcript\",\"roles\":[", crate::field::P, crate::field::NONRESIDUE).unwrap();
    for (i, o) in observed.w.iter().chain([&observed.a, &observed.h]).enumerate() {
        if i > 0 { write!(out, ",").unwrap(); }
        write_role(&mut out, o, ntt, Some((zl, privacy))).unwrap();
    }
    writeln!(out, "]}}").unwrap();
    out.flush().unwrap();
}
