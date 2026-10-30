//! Explicit R14 prototype descriptors. Deliberately absent from legacy
//! Shape/run registries and release dispatch until native acceptance gates.
use super::layout::{Dom, Layout};
use super::shape::{self, Shape};
use super::split_layout::{Part, SplitLayout};
use crate::merkle::Digest;
use zkp_core::hashtag::HashTag;

pub(crate) const T128: &str =
    "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-split-r14/1";
pub(crate) const T128_DD: &str =
    "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-ddict1-split-r14/1";
pub(crate) const T256: &str =
    "hashline-zk-mr1/private-block-shieldstral-3b-t256-lowh24-split-r14/1";
pub(crate) const T256_DD: &str =
    "hashline-zk-mr1/private-block-shieldstral-3b-t256-lowh24-ddict1-split-r14/1";

pub(crate) struct SplitProfile {
    base: Shape,
    layout: SplitLayout,
    name: &'static str,
    digest: Digest,
}
fn part(p: Part) -> u64 {
    match p {
        Part::Whole => 0,
        Part::Wide => 1,
        Part::Narrow => 2,
    }
}
fn dom(d: Dom) -> u64 {
    match d {
        Dom::T => 0,
        Dom::Ht => 1,
        Dom::L => 2,
        Dom::D => 3,
        Dom::Q => 4,
        Dom::Kv => 5,
        Dom::S => 6,
        Dom::F => 7,
        Dom::Tab => 8,
        Dom::Dd => 9,
    }
}

impl SplitProfile {
    pub(crate) fn new(base: Shape) -> Result<Self, String> {
        base.check_constructed()?;
        let name = match base.profile {
            shape::R13_SHIELD_T128_H24 => T128,
            shape::R13_SHIELD_T128_H24_DD => T128_DD,
            shape::R13_SHIELD_T256_H24 => T256,
            shape::R13_SHIELD_T256_H24_DD => T256_DD,
            _ => return Err("R14 profile: unsupported arithmetic reference".into()),
        };
        if base.endpoint_log_n != base.log_cols {
            return Err(
                "R14 profile: endpoint row width differs from joint piece inventory".into(),
            );
        }
        let layout = SplitLayout::new(&base, [2048, 1024], [8192, 1024])?;
        let digest = descriptor(&base, &layout, name)?;
        Ok(Self {
            base,
            layout,
            name,
            digest,
        })
    }
    pub(crate) fn base(&self) -> &Shape {
        &self.base
    }
    pub(crate) fn layout(&self) -> &SplitLayout {
        &self.layout
    }
    pub(crate) fn name(&self) -> &'static str {
        self.name
    }
    pub(crate) fn digest(&self) -> Digest {
        self.digest
    }
    /// Stable across layer calibrations. The enclosing run context binds all
    /// calibration records; a shared boundary has one geometry and scale.
    pub(crate) fn joint_geometry_digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-block/split-r14/joint-geometry/v1\0");
        h.update(&(self.name.len() as u64).to_le_bytes());
        h.update(self.name.as_bytes());
        let e = &self.layout.endpoint;
        for v in [
            self.base.tokens,
            self.base.width,
            self.base.endpoint_log_n,
            self.base.endpoint_inv_rate,
            self.base.opened_cols,
            self.layout.d[0].start,
            self.layout.d[0].width,
            self.layout.d[1].start,
            self.layout.d[1].width,
            e.piece_offsets[0],
            e.piece_offsets[1],
            e.piece_logs[0],
            e.piece_logs[1],
            e.data_rows,
            e.external_rows,
            e.internal_rows,
        ] {
            h.update(&(v as u64).to_le_bytes());
        }
        *h.finalize().as_bytes()
    }
    pub(crate) fn tag(&self) -> HashTag {
        HashTag::for_profile(self.name)
    }
}

fn descriptor(base: &Shape, s: &SplitLayout, name: &str) -> Result<Digest, String> {
    let mut h = blake3::Hasher::new();
    h.update(b"hashline/private-block/split-r14/descriptor/v1\0");
    h.update(&(name.len() as u64).to_le_bytes());
    h.update(name.as_bytes());
    h.update(&Layout::for_shape(base)?.schedule_digest());
    // The inherited schedule text describes structural windows. Bind the
    // complete arithmetic calibration explicitly as well, including f_e
    // values whose limb counts coincide (for example12 and16).
    for v in [
        base.f_e,
        base.f_p(),
        base.norm_wrho,
        base.wrho_s,
        base.norm_tn,
        base.sh_qkv,
        base.sh_s,
        base.sh_o,
        base.sh_ao,
        base.sh_g,
        base.sh_h,
        base.sh_z,
        base.accuracy_gate_shift,
    ] {
        h.update(&v.to_le_bytes());
    }
    for v in [base.norm_cn_a, base.norm_cn_m, base.norm_ceps] {
        h.update(&v.to_le_bytes());
    }
    h.update(&base.d_max.to_le_bytes());
    let mut put = |v: u64| {
        h.update(&v.to_le_bytes());
    };
    for v in [
        s.tokens,
        s.n,
        s.a_data_rows,
        s.h_data_rows,
        s.a_rows,
        s.h_rows,
        s.m_rows,
    ] {
        put(v as u64);
    }
    for e in s.d.iter().chain(&s.f) {
        put(e.start as u64);
        put(e.width as u64);
    }
    for planes in [&s.a, &s.h] {
        put(planes.len() as u64);
        for p in planes {
            for v in [
                p.parent as u64,
                dom(p.domain),
                part(p.part),
                p.offset as u64,
                p.log as u64,
                p.rows_per_component as u64,
            ] {
                put(v);
            }
        }
    }
    put(s.slots.len() as u64);
    for slot in &s.slots {
        for v in [
            slot.base as u64,
            part(slot.part),
            slot.main as u64,
            slot.ext as u64,
            slot.degree as u64,
            slot.a_sites as u64,
            slot.h_sites as u64,
            slot.endpoint_sites as u64,
        ] {
            put(v);
        }
        for pairs in [&slot.a_pairs, &slot.h_pairs] {
            put(pairs.len() as u64);
            for &p in pairs {
                put(p as u64);
            }
        }
    }
    for v in s
        .endpoint
        .piece_offsets
        .into_iter()
        .chain(s.endpoint.piece_logs)
        .chain([
            s.endpoint.data_rows,
            s.endpoint.external_rows,
            s.endpoint.internal_rows,
        ])
    {
        put(v as u64);
    }
    Ok(*h.finalize().as_bytes())
}

#[cfg(test)]
mod tests {
    use super::super::shape::NormCalibration;
    use super::*;
    #[test]
    fn split_descriptors_bind_geometry_calibration_and_new_hash_domains() {
        let cal = NormCalibration {
            tn: 9,
            cn_a: 100,
            cn_m: 100,
            ceps: 1,
            sh_ao: 7,
            sh_qkv: 8,
            sh_s: 6,
            sh_o: 9,
            sh_g: 8,
            sh_h: 14,
            sh_z: 6,
        };
        let mut digests = Vec::new();
        for p in [
            shape::R13_SHIELD_T128_H24,
            shape::R13_SHIELD_T128_H24_DD,
            shape::R13_SHIELD_T256_H24,
            shape::R13_SHIELD_T256_H24_DD,
        ] {
            for fe in [9, 12, 16] {
                let old = Shape::accuracy_trained(p, &cal, fe, 20).unwrap();
                let s = SplitProfile::new(old.clone()).unwrap();
                assert_ne!(s.tag(), old.hash_tag());
                assert!(shape::accuracy_spec(s.name()).is_none());
                assert!(digests.iter().all(|d| d != &s.digest()));
                digests.push(s.digest());
                let mut moved = cal.clone();
                moved.cn_a += 1;
                let changed =
                    SplitProfile::new(Shape::accuracy_trained(p, &moved, fe, 20).unwrap()).unwrap();
                assert_ne!(s.digest(), changed.digest());
                assert_eq!(s.joint_geometry_digest(), changed.joint_geometry_digest());
                let mut forged = old.clone();
                forged.width -= 1;
                assert!(SplitProfile::new(forged).is_err());
            }
        }
        assert!(SplitProfile::new(Shape::toy()).is_err());
    }
}
