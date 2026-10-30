//! New R14 run binding and streaming boundary schedule. The integer model
//! statement retains R13 arithmetic semantics; the proof layout, transcript,
//! endpoint geometry and segment envelope are explicitly R14.
use super::{
    run::RunShape,
    shape::Shape,
    split_endpoint::{JointSpec, Kind},
    split_profile::SplitProfile,
    trained_statement::TrainedModelStatement,
    BlockPublic,
};
use crate::merkle::Digest;
use crate::transcript::Transcript;

pub(crate) struct Plan {
    stages: Vec<SplitProfile>,
    blocks: Vec<Digest>,
    scales: Vec<(i32, i32)>,
    context: Digest,
    model: Digest,
    digest: Digest,
}

impl Plan {
    pub(crate) fn new(
        base: Shape,
        context: Digest,
        model: &TrainedModelStatement,
        blocks: &[BlockPublic],
        scales: &[(i32, i32)],
    ) -> Result<Self, String> {
        if context == [0; 32]
            || blocks.is_empty()
            || blocks.len() > 128
            || blocks.len() != scales.len()
        {
            return Err("R14 run: context or block/scale count differs".into());
        }
        // Reuse the accepted trained-shape and model admission rules. No
        // synthetic waiver exists here; test-only statements keep the native
        // checker's existing explicit test waiver.
        RunShape::accuracy(base.clone(), blocks.len())?;
        let arithmetic_run = super::run::accuracy_run_profile(base.profile)
            .ok_or("R14 run: no registered arithmetic reference")?;
        let digests = blocks.iter().map(BlockPublic::digest).collect::<Vec<_>>();
        model.check_against(&base, arithmetic_run, &digests, scales)?;
        if scales
            .iter()
            .any(|&(a, b)| !(-31..=31).contains(&a) || !(-31..=31).contains(&b))
            || scales.windows(2).any(|s| s[0].1 != s[1].0)
        {
            return Err("R14 run: one shared logical boundary scale is required".into());
        }
        let mut stages = Vec::with_capacity(blocks.len());
        for (record, block) in model.layers.iter().zip(blocks) {
            let stage = SplitProfile::new(record.shape_at(&base)?)?;
            block.check_for_shape(stage.base())?;
            if stages.first().is_some_and(|first: &SplitProfile| {
                first.joint_geometry_digest() != stage.joint_geometry_digest()
            }) {
                return Err(
                    "R14 run: adjacent stage geometry is not one joint boundary geometry".into(),
                );
            }
            stages.push(stage);
        }
        let identity = model.identity();
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-block/split-r14/run-plan/v1\0");
        h.update(&context);
        h.update(&identity);
        h.update(&(stages.len() as u64).to_le_bytes());
        for ((stage, block), &(input, output)) in stages.iter().zip(&digests).zip(scales) {
            h.update(&stage.digest());
            h.update(block);
            h.update(&input.to_le_bytes());
            h.update(&output.to_le_bytes());
        }
        let digest = *h.finalize().as_bytes();
        Ok(Self {
            stages,
            blocks: digests,
            scales: scales.to_vec(),
            context,
            model: identity,
            digest,
        })
    }
    pub(crate) fn len(&self) -> usize {
        self.stages.len()
    }
    pub(crate) fn digest(&self) -> Digest {
        self.digest
    }
    pub(crate) fn stage(&self, k: usize) -> Result<&SplitProfile, String> {
        self.stages
            .get(k)
            .ok_or_else(|| "R14 run: undeclared stage".into())
    }
    pub(crate) fn check_block(&self, k: usize, block: &BlockPublic) -> Result<(), String> {
        let p = self.stage(k)?;
        block.check_for_shape(p.base())?;
        if block.digest() != self.blocks[k] {
            return Err("R14 run: stage public block differs from trained model binding".into());
        }
        Ok(())
    }
    pub(crate) fn endpoint(&self, outgoing: bool) -> Result<JointSpec, String> {
        let k = if outgoing { self.len() - 1 } else { 0 };
        let scale = if outgoing {
            self.scales[k].1
        } else {
            self.scales[k].0
        };
        JointSpec::new(
            self.stage(k)?,
            self.digest,
            if outgoing { Kind::Output } else { Kind::Input },
            scale,
        )
    }
    pub(crate) fn boundary(&self, index: usize) -> Result<JointSpec, String> {
        if index == 0 || index >= self.len() {
            return Err("R14 run: undeclared internal boundary".into());
        }
        JointSpec::new(
            self.stage(index - 1)?,
            self.digest,
            Kind::Boundary(index as u64),
            self.scales[index - 1].1,
        )
    }
    pub(crate) fn bind(self, input: Digest, output: Digest) -> Result<Statement, String> {
        if input == [0; 32] || output == [0; 32] {
            return Err("R14 run: empty expected endpoint root".into());
        }
        if input == output {
            return Err("R14 run: repeated commitment root".into());
        }
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-block/split-r14/run-binding/v1\0");
        h.update(&self.digest);
        h.update(&input);
        h.update(&output);
        let binding = *h.finalize().as_bytes();
        Ok(Statement {
            plan: self,
            input,
            output,
            binding,
        })
    }
}

pub(crate) struct Statement {
    plan: Plan,
    input: Digest,
    output: Digest,
    binding: Digest,
}
impl Statement {
    pub(crate) fn plan(&self) -> &Plan {
        &self.plan
    }
    pub(crate) fn binding(&self) -> Digest {
        self.binding
    }
    #[cfg(test)]
    pub(crate) fn capture_header(&self) -> Result<super::run_capture::split::Header, String> {
        Ok(super::run_capture::split::Header {
            profiles: self
                .plan
                .stages
                .iter()
                .map(|p| SplitProfile::new(p.base().clone()))
                .collect::<Result<Vec<_>, _>>()?,
            block_digests: self.plan.blocks.clone(),
            plan: self.plan.digest,
            model: self.plan.model,
            context: self.plan.context,
            binding: self.binding,
            input: self.input,
            output: self.output,
            scales: self.plan.scales.clone(),
        })
    }
    pub(crate) fn input(&self) -> Digest {
        self.input
    }
    pub(crate) fn output(&self) -> Digest {
        self.output
    }
    pub(crate) fn transcript(&self) -> Transcript {
        let p = &self.plan.stages[0];
        // One R14 hash family for the run, A/H/M and all joint commitments.
        let mut tr = Transcript::new_tagged(
            b"hashline/private-block/split-r14/run/v1",
            *p.tag().transcript_key().expect("R14 keyed profile"),
        );
        tr.absorb(b"R14-run-binding", &self.binding);
        tr.absorb(b"R14-run-plan", &self.plan.digest);
        tr.absorb(b"R14-trained-arithmetic-statement", &self.plan.model);
        tr.absorb(b"R14-public-context", &self.plan.context);
        tr.absorb_u64(b"R14-blocks", self.plan.len() as u64);
        tr.absorb(b"R14-input", &self.input);
        tr.absorb(b"R14-output", &self.output);
        tr
    }
    pub(crate) fn begin_stage(
        &self,
        k: usize,
        block: &BlockPublic,
        tr: &mut Transcript,
    ) -> Result<(), String> {
        self.plan.check_block(k, block)?;
        tr.absorb_u64(b"R14-stage", k as u64);
        tr.absorb(b"R14-stage-profile", &self.plan.stage(k)?.digest());
        tr.absorb(b"R14-stage-block", &self.plan.blocks[k]);
        Ok(())
    }
}

pub(crate) fn position_tag(tr: &Transcript) -> Digest {
    let mut copy = Transcript::clone_state(tr);
    let values = copy.challenge_fp2_vec(2);
    let mut out = [0; 32];
    out[..16].copy_from_slice(&values[0].to_bytes());
    out[16..].copy_from_slice(&values[1].to_bytes());
    out
}

use super::split_endpoint::{self, IoSources, JointOwner, Use};
use super::{protocol, split_protocol, wire};
use crate::field::Fp;
use crate::ntt::NttTables;
use crate::pcs::{Commitment, ZClaim};
use crate::zk::ZkRng;

pub(crate) trait WitnessSource {
    fn witness(&mut self, k: usize) -> Result<super::witness::Witness, String>;
    /// True numeric D pieces in canonical wide/narrow order. Their equality
    /// with both adjacent blocks is proved by four IO claims, opened once.
    fn boundary_pieces(&mut self, index: usize) -> Result<[Vec<Fp>; 2], String>;
}
struct PendingOwner {
    spec: JointSpec,
    owner: JointOwner,
    claims: Vec<ZClaim>,
}
struct PendingView {
    spec: JointSpec,
    root: Commitment,
    claims: Vec<ZClaim>,
}
#[derive(Default)]
struct Roots(Vec<Digest>);
impl Roots {
    fn reserve(&mut self, roots: &[Digest]) -> Result<(), String> {
        for root in roots {
            if self.0.contains(root) {
                return Err("R14 run: repeated commitment root".into());
            }
            self.0.push(*root);
        }
        Ok(())
    }
}
fn root(spec: &JointSpec, digest: Digest) -> Commitment {
    Commitment {
        root: digest,
        rows: spec.rows(),
        log_cols: spec.params().log_cols,
    }
}
fn absorb_boundary(tr: &mut Transcript, index: usize, spec: &JointSpec, root: &Digest) {
    tr.absorb_u64(b"R14-boundary-index", index as u64);
    tr.absorb(b"R14-boundary-spec", &spec.digest());
    protocol::absorb_root(
        tr,
        b"R14-boundary-root",
        root,
        spec.rows(),
        spec.params().log_cols as usize,
    );
}

pub(crate) fn prove(
    st: &Statement,
    blocks: &[BlockPublic],
    source: &mut dyn WitnessSource,
    owners: [JointOwner; 2],
    emit: &mut dyn FnMut(usize, Vec<u8>) -> Result<(), String>,
) -> Result<(), String> {
    let plan = st.plan();
    if blocks.len() != plan.len() {
        return Err("R14 run: public block count differs".into());
    }
    let [ein, eout] = owners;
    let in_spec = plan.endpoint(false)?;
    let out_spec = plan.endpoint(true)?;
    ein.check_spec(&in_spec)?;
    eout.check_spec(&out_spec)?;
    if ein.commitment().root != st.input || eout.commitment().root != st.output {
        return Err("R14 run: prepared expected endpoint root differs".into());
    }
    let ntt = NttTables::new(protocol::ntt_log_at(plan.stage(0)?.base()));
    let mut domain = b"hashline/private-block/split-r14/run-prover-secret/v1\0".to_vec();
    domain.extend_from_slice(&st.binding);
    let mut rng = ZkRng::from_os(&domain).map_err(|e| format!("R14 run entropy: {e}"))?;
    let mut tr = st.transcript();
    let mut roots = Roots::default();
    roots.reserve(&[st.input, st.output])?;
    let mut incoming = Some(PendingOwner {
        spec: in_spec,
        owner: ein,
        claims: vec![],
    });
    let mut output = Some(eout);
    for (k, block) in blocks.iter().enumerate() {
        let p = plan.stage(k)?;
        let start = position_tag(&tr);
        st.begin_stage(k, block, &mut tr)?;
        let outgoing = if k + 1 < plan.len() {
            let spec = plan.boundary(k + 1)?;
            let values = source.boundary_pieces(k + 1)?;
            let owner = split_endpoint::prepare(&spec, [&values[0], &values[1]], &ntt)?;
            absorb_boundary(&mut tr, k + 1, &spec, &owner.commitment().root);
            Some((spec, owner))
        } else {
            None
        };
        let previous = incoming.take().ok_or("R14 run: absent incoming owner")?;
        let in_use = if k == 0 { Use::External } else { Use::Incoming };
        let (out_spec, out_use, out_data) = if let Some((spec, owner)) = &outgoing {
            (spec, Use::Outgoing, owner.data())
        } else {
            (
                &out_spec,
                Use::External,
                output
                    .as_ref()
                    .ok_or("R14 run: missing output owner")?
                    .data(),
            )
        };
        let sources = IoSources {
            input: (&previous.spec, in_use),
            output: (out_spec, out_use),
        };
        let core = split_protocol::prove_core(
            p,
            block,
            source.witness(k)?,
            &sources,
            [previous.owner.data(), out_data],
            &ntt,
            &mut rng,
            &mut tr,
        )?;
        roots.reserve(&[core.a_root, core.h_root, core.mask_root])?;
        if let Some((_, owner)) = &outgoing {
            roots.reserve(&[owner.commitment().root])?;
        }
        let [ic, oc] = core.io_claims;
        let mut in_claims = previous.claims;
        in_claims.extend(ic);
        let in_open = previous
            .owner
            .into_opening(&previous.spec, &in_claims, &mut tr)?;
        let out_open = if k + 1 == plan.len() {
            Some(
                output
                    .take()
                    .ok_or("R14 run: output already consumed")?
                    .into_opening(out_spec, &oc, &mut tr)?,
            )
        } else {
            None
        };
        let b_root = outgoing.as_ref().map(|(_, owner)| owner.commitment().root);
        if let Some((spec, owner)) = outgoing {
            incoming = Some(PendingOwner {
                spec,
                owner,
                claims: oc,
            });
        }
        let segment = wire::Segment {
            b_root,
            a_root: core.a_root,
            h_root: core.h_root,
            mask_root: core.mask_root,
            slots: core.slots,
            mask_open: core.mask_open,
            a_open: core.a_open,
            h_open: core.h_open,
            in_open,
            out_open,
        };
        let geom = wire::split::Geometry::new(p, plan.len(), k)?;
        let end = position_tag(&tr);
        emit(
            k,
            wire::split::encode(&segment, &geom, &st.binding, &start, &end)?,
        )?;
    }
    if incoming.is_some() || output.is_some() {
        return Err("R14 run: unconsumed commitment owner".into());
    }
    Ok(())
}

pub(crate) struct Verifier<'a> {
    st: &'a Statement,
    blocks: &'a [BlockPublic],
    tr: Transcript,
    ntt: NttTables,
    k: usize,
    failed: bool,
    pending: Option<PendingView>,
    roots: Roots,
}
impl<'a> Verifier<'a> {
    pub(crate) fn new(st: &'a Statement, blocks: &'a [BlockPublic]) -> Result<Self, String> {
        if blocks.len() != st.plan.len() {
            return Err("R14 run: verifier public block count differs".into());
        }
        let spec = st.plan.endpoint(false)?;
        let mut roots = Roots::default();
        roots.reserve(&[st.input, st.output])?;
        let pending = Some(PendingView {
            root: root(&spec, st.input),
            spec,
            claims: vec![],
        });
        Ok(Self {
            st,
            blocks,
            tr: st.transcript(),
            ntt: NttTables::new(protocol::ntt_log_at(st.plan.stage(0)?.base())),
            k: 0,
            failed: false,
            pending,
            roots,
        })
    }
    pub(crate) fn verify_next(&mut self, bytes: &[u8]) -> Result<(), String> {
        if self.failed || self.k >= self.st.plan.len() {
            return Err("R14 run: failed or finished verifier".into());
        }
        self.failed = true;
        self.next_inner(bytes)?;
        self.failed = false;
        Ok(())
    }
    fn next_inner(&mut self, bytes: &[u8]) -> Result<(), String> {
        let k = self.k;
        let plan = &self.st.plan;
        let p = plan.stage(k)?;
        let geom = wire::split::Geometry::new(p, plan.len(), k)?;
        let start = position_tag(&self.tr);
        let (seg, end) = wire::split::decode(bytes, &geom, &self.st.binding, &start)?;
        self.roots
            .reserve(&[seg.a_root, seg.h_root, seg.mask_root])?;
        if let Some(root) = seg.b_root {
            self.roots.reserve(&[root])?;
        }
        #[cfg(test)]
        super::run_capture::split::stage_begin(k, seg.b_root, &self.tr);
        self.st.begin_stage(k, &self.blocks[k], &mut self.tr)?;
        let outgoing = if let Some(digest) = seg.b_root {
            let spec = plan.boundary(k + 1)?;
            absorb_boundary(&mut self.tr, k + 1, &spec, &digest);
            Some((spec, digest))
        } else {
            None
        };
        let previous = self
            .pending
            .take()
            .ok_or("R14 run: missing pending input commitment")?;
        let final_spec = plan.endpoint(true)?;
        let (out_spec, out_use) = if let Some((spec, _)) = &outgoing {
            (spec, Use::Outgoing)
        } else {
            (&final_spec, Use::External)
        };
        let sources = IoSources {
            input: (
                &previous.spec,
                if k == 0 { Use::External } else { Use::Incoming },
            ),
            output: (out_spec, out_use),
        };
        let view = protocol::CoreView {
            a_root: seg.a_root,
            h_root: seg.h_root,
            mask_root: seg.mask_root,
            slots: &seg.slots,
            mask_open: &seg.mask_open,
            a_open: &seg.a_open,
            h_open: &seg.h_open,
        };
        let [ic, oc] = split_protocol::verify_core(
            p,
            &self.blocks[k],
            &sources,
            view,
            &self.ntt,
            &mut self.tr,
        )?;
        let mut incoming = previous.claims;
        incoming.extend(ic);
        split_endpoint::verify(
            &previous.spec,
            &previous.root,
            &incoming,
            &seg.in_open,
            &self.ntt,
            &mut self.tr,
        )?;
        if let Some(opening) = seg.out_open {
            split_endpoint::verify(
                &final_spec,
                &root(&final_spec, self.st.output),
                &oc,
                &opening,
                &self.ntt,
                &mut self.tr,
            )?;
        }
        if position_tag(&self.tr) != end {
            return Err("R14 run: segment end is not the verifier transcript position".into());
        }
        self.pending = outgoing.map(|(spec, digest)| PendingView {
            root: root(&spec, digest),
            spec,
            claims: oc,
        });
        #[cfg(test)]
        super::run_capture::split::stage_end(k, end, &self.tr, bytes);
        self.k += 1;
        Ok(())
    }
    pub(crate) fn finish(self) -> Result<(), String> {
        if self.failed || self.k != self.st.plan.len() || self.pending.is_some() {
            return Err("R14 run: incomplete or failed proof stream".into());
        }
        #[cfg(test)]
        super::run_capture::split::run_accepted();
        Ok(())
    }
}

#[cfg(test)]
mod root_tests {
    use super::*;
    #[test]
    fn split_run_repeated_root_audit_covers_endpoint_block_mask_and_boundary_roles() {
        let mut roots = Roots::default();
        roots.reserve(&[[1; 32], [2; 32]]).unwrap();
        roots
            .reserve(&[[3; 32], [4; 32], [5; 32], [6; 32]])
            .unwrap();
        for role in 1..=6 {
            assert!(roots
                .reserve(&[[role; 32]])
                .unwrap_err()
                .contains("repeated commitment root"));
        }
        assert!(Roots::default().reserve(&[[7; 32], [7; 32]]).is_err());
    }
}
