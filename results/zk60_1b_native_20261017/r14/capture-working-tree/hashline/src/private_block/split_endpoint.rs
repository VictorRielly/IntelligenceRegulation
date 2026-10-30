//! One joint hiding commitment per logical R14 endpoint or boundary.
//! Ordered piece row blocks, one scale and one consuming opening owner.
use super::{protocol, split_profile::SplitProfile};
use crate::field::{Fp, P};
use crate::merkle::Digest;
use crate::ntt::NttTables;
use crate::pcs::{self, Commitment, CommittedZk, OpeningZk, PcsParams, ZClaim, ZkOpts};
use crate::transcript::Transcript;
use crate::zk::ZkRng;
use zkp_core::hashtag::HashTag;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Kind {
    Input,
    Output,
    Boundary(u64),
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Use {
    External,
    Outgoing,
    Incoming,
}

#[derive(Clone)]
pub(crate) struct JointSpec {
    profile: Digest,
    context: Digest,
    kind: Kind,
    scale: i32,
    offsets: [usize; 2],
    logs: [usize; 2],
    data_rows: usize,
    rows: usize,
    params: PcsParams,
    tag: HashTag,
}

impl JointSpec {
    pub(crate) fn new(
        p: &SplitProfile,
        context: Digest,
        kind: Kind,
        scale: i32,
    ) -> Result<Self, String> {
        if context == [0; 32] || !(-31..=31).contains(&scale) || matches!(kind, Kind::Boundary(0)) {
            return Err("R14 joint endpoint: invalid context, logical index or scale".into());
        }
        let s = p.layout();
        let e = &s.endpoint;
        let base = p.base();
        Ok(Self {
            profile: p.joint_geometry_digest(),
            context,
            kind,
            scale,
            offsets: e.piece_offsets,
            logs: e.piece_logs,
            data_rows: e.data_rows,
            rows: if matches!(kind, Kind::Boundary(_)) {
                e.internal_rows
            } else {
                e.external_rows
            },
            params: PcsParams {
                log_cols: base.endpoint_log_n as u32,
                inv_rate: base.endpoint_inv_rate,
                num_col_checks: base.opened_cols,
            },
            tag: p.tag(),
        })
    }
    pub(crate) fn source(
        &self,
        p: &SplitProfile,
        usage: Use,
        piece: usize,
    ) -> Result<(usize, usize, usize), String> {
        if p.joint_geometry_digest() != self.profile || piece >= 2 {
            return Err("R14 joint endpoint: profile or piece mismatch".into());
        }
        let first = match (self.kind, usage) {
            (Kind::Input | Kind::Output, Use::External) => 0,
            (Kind::Boundary(_), Use::Outgoing) => 0,
            (Kind::Boundary(_), Use::Incoming) => 2,
            _ => return Err("R14 joint endpoint: wrong logical claim role".into()),
        };
        Ok((
            self.offsets[piece],
            self.logs[piece],
            self.data_rows + 2 * (first + piece),
        ))
    }
    pub(crate) fn kind(&self) -> Kind {
        self.kind
    }
    pub(crate) fn scale(&self) -> i32 {
        self.scale
    }
    pub(crate) fn rows(&self) -> usize {
        self.rows
    }
    pub(crate) fn params(&self) -> PcsParams {
        self.params
    }
    fn sites(&self) -> usize {
        if matches!(self.kind, Kind::Boundary(_)) {
            4
        } else {
            2
        }
    }
    fn site_rows(&self) -> Vec<usize> {
        (self.data_rows..self.data_rows + 2 * self.sites()).collect()
    }
    fn prox(&self) -> usize {
        self.rows - 2
    } // External spare precedes this pair.
    pub(crate) fn digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-block/split-r14/joint-endpoint/v1\0");
        h.update(&self.profile);
        h.update(&self.context);
        h.update(&self.scale.to_le_bytes());
        let (role, index) = match self.kind {
            Kind::Input => (0, 0),
            Kind::Output => (1, 0),
            Kind::Boundary(k) => (2, k),
        };
        for n in [
            role,
            index,
            self.offsets[0] as u64,
            self.offsets[1] as u64,
            self.logs[0] as u64,
            self.logs[1] as u64,
            self.data_rows as u64,
            self.rows as u64,
            self.sites() as u64,
            self.prox() as u64,
            self.params.log_cols as u64,
            self.params.inv_rate as u64,
            self.params.num_col_checks as u64,
        ] {
            h.update(&n.to_le_bytes());
        }
        *h.finalize().as_bytes()
    }
    pub(crate) fn check_opening(&self, claims: &[ZClaim], tr: &Transcript) -> Result<(), String> {
        if claims.len() != self.sites() {
            return Err("R14 joint endpoint: dropped or extra physical claim".into());
        }
        protocol::check_opening(
            claims,
            self.params.log_cols as usize,
            self.rows,
            &self.site_rows(),
            None,
            self.prox(),
            self.sites(),
            tr,
        )
    }
    fn seed_domain(&self) -> Vec<u8> {
        let mut d = b"hashline/private-block/split-r14/joint-endpoint-secret/v1\0".to_vec();
        d.extend_from_slice(&self.digest());
        d
    }
}

/// Caller specifies which logical owner each block side claims. An internal
/// boundary's outgoing/incoming uses reserve different pairs for both pieces.
pub(crate) struct IoSources<'a> {
    pub input: (&'a JointSpec, Use),
    pub output: (&'a JointSpec, Use),
}

pub(crate) struct JointOwner {
    spec: Digest,
    committed: CommittedZk,
}
impl JointOwner {
    pub(crate) fn check_spec(&self, spec: &JointSpec) -> Result<(), String> {
        if self.spec != spec.digest() {
            return Err("R14 joint endpoint: prepared context mismatch".into());
        }
        Ok(())
    }
    pub(crate) fn commitment(&self) -> Commitment {
        self.committed.commitment()
    }
    pub(crate) fn data(&self) -> &[Fp] {
        &self.committed.data
    }
    pub(crate) fn into_opening(
        self,
        spec: &JointSpec,
        claims: &[ZClaim],
        tr: &mut Transcript,
    ) -> Result<OpeningZk, String> {
        if self.spec != spec.digest() {
            return Err("R14 joint endpoint: prepared context mismatch".into());
        }
        spec.check_opening(claims, tr)?;
        Ok(pcs::open_zk(&self.committed, claims, tr))
    }
}

pub(crate) fn prepare(
    spec: &JointSpec,
    pieces: [&[Fp]; 2],
    ntt: &NttTables,
) -> Result<JointOwner, String> {
    let mut rng = ZkRng::from_os(&spec.seed_domain())
        .map_err(|e| format!("R14 joint endpoint entropy: {e}"))?;
    prepare_inner(spec, pieces, ntt, &mut rng)
}

fn prepare_inner(
    spec: &JointSpec,
    pieces: [&[Fp]; 2],
    ntt: &NttTables,
    rng: &mut ZkRng,
) -> Result<JointOwner, String> {
    let need = spec.params.log_cols + spec.params.inv_rate.trailing_zeros();
    if ntt.max_log < need || ntt.max_log > 30 {
        return Err("R14 joint endpoint: short or unsupported NTT".into());
    }
    let half = (1usize << ntt.max_log) / 2;
    if ntt.roots.len() != ntt.max_log as usize + 1
        || ntt.inv_roots.len() != ntt.max_log as usize + 1
        || ntt.twiddle_tables().0.len() != half.max(1)
        || ntt.twiddle_tables().1.len() != half.max(1)
        || (0..=ntt.max_log).any(|k| {
            ntt.roots[k as usize] != Fp::two_adic_root(k)
                || ntt.inv_roots[k as usize] != Fp::two_adic_root(k).inv()
        })
    {
        return Err("R14 joint endpoint: noncanonical NTT".into());
    }
    if pieces
        .iter()
        .zip(spec.logs)
        .any(|(v, log)| v.len() != 1usize << log || v.iter().any(|x| x.0 >= P))
    {
        return Err("R14 joint endpoint: wrong piece length or noncanonical word".into());
    }
    let n = 1usize << spec.params.log_cols;
    let mut data = vec![Fp::ZERO; spec.rows * n];
    for (i, piece) in pieces.into_iter().enumerate() {
        data[spec.offsets[i]..spec.offsets[i] + piece.len()].copy_from_slice(piece);
    }
    for x in &mut data[spec.data_rows * n..] {
        *x = rng.fp();
    }
    let mut committed = pcs::commit_zk_owned_tagged(
        &spec.params,
        data,
        ntt,
        &ZkOpts::standard(&spec.params),
        rng,
        &spec.tag,
    );
    committed.mask_rows = spec.site_rows();
    committed.prox_mask_row = Some(spec.prox());
    Ok(JointOwner {
        spec: spec.digest(),
        committed,
    })
}

pub(crate) fn verify(
    spec: &JointSpec,
    root: &Commitment,
    claims: &[ZClaim],
    opening: &OpeningZk,
    ntt: &NttTables,
    tr: &mut Transcript,
) -> Result<(), String> {
    spec.check_opening(claims, tr)?;
    #[cfg(test)]
    let capture = super::run_capture::split::checkpoint(tr);
    pcs::verify_zk_tagged(
        &spec.params,
        &ZkOpts::standard(&spec.params),
        root,
        claims,
        opening,
        ntt,
        tr,
        &spec.tag,
    )?;
    #[cfg(test)]
    super::run_capture::split::joint_pcs(spec, root.root, claims, opening, ntt, capture, tr);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::field::Fp2;
    use crate::mle::eval_mle_ext;
    use crate::pcs::{Slice, ZPart};
    use crate::private_block::shape::{self, NormCalibration, Shape};
    fn profile() -> SplitProfile {
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
        SplitProfile::new(Shape::accuracy_trained(shape::R13_SHIELD_T128_H24, &cal, 9, 20).unwrap())
            .unwrap()
    }
    fn claim(
        p: &SplitProfile,
        spec: &JointSpec,
        data: &[Fp],
        usage: Use,
        piece: usize,
        seed: usize,
    ) -> ZClaim {
        let (off, log, pair) = spec.source(p, usage, piece).unwrap();
        let ln = spec.params.log_cols as usize;
        let n = 1usize << ln;
        let point = (0..log)
            .map(|i| {
                Fp2::new(
                    Fp::new((seed * 37 + i * 11 + 3) as u64),
                    Fp::new((seed * 13 + i * 17 + 5) as u64),
                )
            })
            .collect::<Vec<_>>();
        let tail = point[log - ln..].to_vec();
        let c = Fp2::new(Fp::new(7), Fp::new((seed + 13) as u64));
        let mut parts = vec![ZPart {
            slice: Slice {
                offset: off,
                log_size: log as u32,
            },
            coef: Fp2::ONE,
            point,
        }];
        for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
            parts.push(ZPart {
                slice: Slice {
                    offset: (pair + k) * n,
                    log_size: ln as u32,
                },
                coef: c.mul(u),
                point: tail.clone(),
            });
        }
        let value = parts.iter().fold(Fp2::ZERO, |a, part| {
            let x = data[part.slice.offset..part.slice.offset + (1usize << part.slice.log_size)]
                .iter()
                .copied()
                .map(Fp2::from_base)
                .collect::<Vec<_>>();
            a.add(part.coef.mul(eval_mle_ext(&x, &part.point)))
        });
        ZClaim { parts, value }
    }
    #[test]
    fn split_joint_one_opening_accepts_two_and_four_piece_claims_and_rejects_mutations() {
        let p = profile();
        let context = [41; 32];
        for kind in [Kind::Input, Kind::Boundary(1)] {
            let spec = JointSpec::new(&p, context, kind, 0).unwrap();
            let ntt = NttTables::new(spec.params.log_cols + spec.params.inv_rate.trailing_zeros());
            let pieces = spec.logs.map(|log| {
                (0..1usize << log)
                    .map(|i| Fp::from_i64((i % 251) as i64 - 125))
                    .collect::<Vec<_>>()
            });
            let mut rng = ZkRng::new(141, b"R14 joint endpoint public fixture only");
            let owner = prepare_inner(&spec, [&pieces[0], &pieces[1]], &ntt, &mut rng).unwrap();
            let root = owner.commitment();
            assert_eq!(root.rows, spec.rows());
            let uses = if kind == Kind::Input {
                vec![Use::External]
            } else {
                vec![Use::Outgoing, Use::Incoming]
            };
            let mut claims = Vec::new();
            for usage in uses {
                for piece in 0..2 {
                    claims.push(claim(
                        &p,
                        &spec,
                        owner.data(),
                        usage,
                        piece,
                        claims.len() + 1,
                    ));
                }
            }
            let transcript = || {
                let mut t = Transcript::new_tagged(
                    b"R14 joint endpoint component",
                    *p.tag().transcript_key().unwrap(),
                );
                t.absorb(b"joint-spec", &spec.digest());
                t.absorb(b"joint-root", &root.root);
                t
            };
            assert!(spec
                .check_opening(&claims[..claims.len() - 1], &transcript())
                .is_err());
            let mut duplicated = claims.clone();
            duplicated[1] = duplicated[0].clone();
            assert!(spec.check_opening(&duplicated, &transcript()).is_err());
            let mut changed = spec.clone();
            changed.scale += 1;
            assert_ne!(changed.digest(), spec.digest());
            assert_ne!(changed.seed_domain(), spec.seed_domain());
            let opening = owner
                .into_opening(&spec, &claims, &mut transcript())
                .unwrap();
            verify(&spec, &root, &claims, &opening, &ntt, &mut transcript()).unwrap();
            for i in 0..claims.len() {
                let mut wrong = claims.clone();
                wrong[i].value = wrong[i].value.add(Fp2::ONE);
                assert!(verify(&spec, &root, &wrong, &opening, &ntt, &mut transcript()).is_err());
            }
            let mut wrong = claims.clone();
            wrong[0].parts[0].slice.offset = spec.offsets[1];
            assert!(verify(&spec, &root, &wrong, &opening, &ntt, &mut transcript()).is_err());
        }
    }
    #[test]
    fn split_joint_descriptor_and_source_roles_refuse_foreign_geometry() {
        let p = profile();
        let mut moved = p.base().norm_calibration();
        moved.cn_a += 1;
        let next = SplitProfile::new(p.base().with_layer_calibration(&moved).unwrap()).unwrap();
        assert_ne!(p.digest(), next.digest());
        let boundary = JointSpec::new(&p, [7; 32], Kind::Boundary(1), -3).unwrap();
        boundary.source(&next, Use::Incoming, 1).unwrap();
        let mut digests = Vec::new();
        for kind in [
            Kind::Input,
            Kind::Output,
            Kind::Boundary(1),
            Kind::Boundary(2),
        ] {
            let s = JointSpec::new(&p, [7; 32], kind, -3).unwrap();
            assert!(!digests.contains(&s.digest()));
            digests.push(s.digest());
            let bad = if matches!(kind, Kind::Boundary(_)) {
                Use::External
            } else {
                Use::Incoming
            };
            assert!(s.source(&p, bad, 0).is_err());
            assert!(s.source(&p, Use::External, 2).is_err());
            assert_eq!(s.scale(), -3);
        }
        assert!(JointSpec::new(&p, [0; 32], Kind::Input, 0).is_err());
        assert!(JointSpec::new(&p, [7; 32], Kind::Boundary(0), 0).is_err());
        assert!(JointSpec::new(&p, [7; 32], Kind::Output, 32).is_err());
    }
}
