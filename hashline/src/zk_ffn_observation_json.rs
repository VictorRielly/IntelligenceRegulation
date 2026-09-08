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

fn write_role(out: &mut impl Write, o: &Observation, ntt: &NttTables) -> std::io::Result<()> {
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
                "{{\"offset\":{},\"log_size\":{},\"coefficient\":{:?},\"point\":{:?}}}",
                p.slice.offset,
                p.slice.log_size,
                fp2(p.coef),
                fp2s(&p.point)
            )?;
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
    write!(out, "]}}")
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
        write_role(&mut out, o, ntt).unwrap();
    }
    writeln!(out, "]}}").unwrap();
    out.flush().unwrap();
}
