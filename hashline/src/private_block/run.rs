//! **STAGE 12: a private RUN of `L` blocks under ONE transcript.**
//!
//! Block `k`'s hidden output is block `k + 1`'s hidden input, and neither is
//! published. The chaining is carried by an INTERNAL BOUNDARY (`boundary.rs`):
//! one hiding commitment to the padded hidden plane, claimed by block `k`'s
//! output-equality slot and by block `k + 1`'s input-equality slot, opened
//! exactly ONCE — in stage `k + 1`, because its second claim does not exist
//! until then. Transitively `A_k`'s output plane equals `A_{k+1}`'s input
//! plane word for word.
//!
//! **The stage order** (the design's §2.2, checked line by line against
//! `prove_inner_at`): absorb the stage index and the block's public digest;
//! commit `B_k` and absorb its root; then the measured block unchanged — `A`,
//! `M`, the LogUp challenges, `H`, the twenty-three slots, open `M`, `A`,
//! `H` — and then open `B_{k-1}`, whose claim list is now complete. The last
//! stage commits no boundary and closes the run's external output endpoint
//! instead. A stage is the measured block plus two lines, which is the whole
//! value of this construction.
//!
//! **What a run that verifies IS.** A correctness statement: `L` blocks were
//! composed under one Fiat-Shamir chain, each one's hidden output being the
//! next one's hidden input. **What it is NOT**: a privacy result. The
//! obligations a run adds over one block — the joint rank of the boundary
//! plane over ALL THREE commitments that hold it (`A_k`'s output rows, `B_k`,
//! `A_{k+1}`'s input rows) restricted to the reserved mask rows, blinding
//! independence across blocks, the run-wide joint law — have no tools yet and
//! no gate has been run. The run's soundness is about `2^-97.5` for twelve
//! blocks at the 125M geometry (ruling M-2).

use super::boundary::{self, BoundarySpec, PreparedBoundary};
use super::endpoint_g;
use super::layout::Layout;
use super::protocol::{self, CoreView};
use super::run_sink;
use super::shape::Shape;
use super::timing;
use super::wire::{self, SegGeom, Segment};
use super::witness::Witness;
use super::{BlockPublic, Endpoints, ExpectedIo};
use crate::field::Fp;
use crate::merkle::Digest;
use crate::ntt::NttTables;
use crate::pcs::{self, PcsParams, ZClaim, ZkOpts};
use crate::transcript::Transcript;
use crate::zk::ZkRng;

/// An internal boundary is claimed by exactly two slots: block `k`'s slot 22
/// (site 0) and block `k + 1`'s slot 21 (site 1).
pub(crate) const BOUNDARY_SITES: usize = 2;

pub(crate) const RUN_PROFILE_RUNG_G: &str = "hashline-zk-mr1/private-run-rung-g-t24-dev/1";
pub(crate) const RUN_PROFILE_M125: &str = "hashline-zk-mr1/private-run-m125/1";

/// One run's geometry: the per-block shape, how many blocks, and the run's own
/// profile id. A run is a NEW profile under D17 — its own transcript, its own
/// digests — so no byte of any single-block profile moves.
#[derive(Clone, Debug)]
pub(crate) struct RunShape {
    pub sh: Shape,
    pub l: usize,
    pub profile: &'static str,
}

impl RunShape {
    pub(crate) fn new(sh: Shape, l: usize, profile: &'static str) -> Result<RunShape, String> {
        if l == 0 {
            return Err("private run: a run has at least one block".into());
        }
        Ok(RunShape { sh, l, profile })
    }
    pub(crate) fn rung_g(l: usize) -> Result<RunShape, String> {
        RunShape::new(Shape::rung_g(), l, RUN_PROFILE_RUNG_G)
    }
    pub(crate) fn m125(l: usize) -> Result<RunShape, String> {
        RunShape::new(Shape::m125(), l, RUN_PROFILE_M125)
    }
    /// how many rows of an IO commitment carry plane words — the same at an
    /// external endpoint and at an internal boundary, because both commit the
    /// same padded `Dom::D` cube at the same row width
    pub(crate) fn data_rows(&self) -> usize {
        self.sh.endpoint_rows.saturating_sub(endpoint_g::MASK_ROWS)
    }
    /// the NTT domain one run needs: the block's, and the IO commitments'
    fn ntt_log(&self) -> u32 {
        protocol::ntt_log_at(&self.sh).max((self.sh.endpoint_log_n + self.sh.endpoint_inv_rate.trailing_zeros() as usize) as u32)
    }
}

/// The run's public statement. Everything a verifier needs and nothing a
/// prover chooses: the geometry, the two EXTERNAL endpoint roots (D18 seals
/// them before the run), one public digest per block, one scale per boundary
/// and the calibration identity. The `L - 1` boundary ROOTS are deliberately
/// NOT here — an internal boundary is a hidden intermediate, not an endpoint.
pub(crate) struct RunStatement {
    pub rs: RunShape,
    expected: ExpectedIo,
    block_digests: Vec<Digest>,
    context: Digest,
    /// **RULING M-4.** One field per internal boundary, shared by
    /// construction between block `k`'s declared output scale and block
    /// `k + 1`'s declared input scale. There is no second place to declare it.
    boundary_scales: Vec<i32>,
    calibration: Digest,
}

impl RunStatement {
    /// `block_scales[k]` is block `k`'s declared `(input, output)` scale pair.
    /// A run in which block `k + 1` declares a different input scale than
    /// block `k`'s output scale DOES NOT CONSTRUCT: the two are collapsed into
    /// the one field a boundary has, and a disagreement is refused by name
    /// here rather than being carried into a proof (ruling M-4).
    pub(crate) fn new(rs: RunShape, context: Digest, expected: ExpectedIo, blocks: &[BlockPublic], block_scales: &[(i32, i32)]) -> Result<RunStatement, String> {
        if blocks.len() != rs.l || block_scales.len() != rs.l {
            return Err(format!("private run: the statement is for {} blocks, {} public statements and {} scale pairs were given", rs.l, blocks.len(), block_scales.len()));
        }
        if context == [0; 32] {
            return Err("private run: a nonempty context is required".into());
        }
        for k in 0..rs.l - 1 {
            if block_scales[k].1 != block_scales[k + 1].0 {
                return Err(format!(
                    "private run: at boundary {k} block {k} declares output scale {} and block {} declares input scale {}; a boundary has ONE scale",
                    block_scales[k].1,
                    k + 1,
                    block_scales[k + 1].0
                ));
            }
        }
        let (first, last) = (block_scales[0].0, block_scales[rs.l - 1].1);
        if (first, last) != (expected.spec.input_scale(), expected.spec.output_scale()) {
            return Err(format!("private run: the run's external scales ({first}, {last}) are not the endpoint policy's ({}, {})", expected.spec.input_scale(), expected.spec.output_scale()));
        }
        let boundary_scales: Vec<i32> = (0..rs.l - 1).map(|k| block_scales[k].1).collect();
        let st = RunStatement { rs, expected, block_digests: blocks.iter().map(|b| b.digest()).collect(), context, boundary_scales, calibration: super::calibration_identity() };
        // **STAGE 16, ruling T-3.** `Layout::for_shape` has already checked
        // `A`, `H`, `M` and the external endpoint against the BLOCK's set of
        // hash-input lengths. A run absorbs one word no block does — its own
        // `parameters` line, whose length moves with `L` — and it commits one
        // thing no block does, an internal boundary. Both are checked here,
        // against the run's OWN set, before the statement can prove anything.
        // At 125M with twelve blocks the run's line is about 247 bytes, which
        // puts its absorb within a few bytes of the boundary's 304-byte
        // column; that is why this check is at the run and not at the shape.
        let line = st.parameter_line()?;
        let set = super::hash_domain::at_shape_with(&st.rs.sh, Some(line.as_str()));
        let lay = Layout::for_shape(&st.rs.sh)?;
        let mut commitments = vec![("A", lay.a_rows), ("H", lay.h_rows), ("M", super::layout::M_ROWS), ("external endpoint", st.rs.sh.endpoint_rows)];
        if st.rs.l > 1 {
            commitments.push(("internal boundary", st.boundary_spec(0)?.commitment_rows()));
        }
        set.refuse(&commitments)?;
        Ok(st)
    }

    /// TEST ONLY. The run header absorbs ONE calibration identity covering
    /// every block and every boundary (ruling M-4); this is how a test shows
    /// that a receipt made under one calibration is rejected under another.
    #[cfg(test)]
    pub(crate) fn with_calibration(mut self, d: Digest) -> RunStatement {
        self.calibration = d;
        self
    }

    /// The statement of internal boundary `k` (between blocks `k` and
    /// `k + 1`). The declared row count is the SHAPE's own endpoint row count
    /// plus one — an independent path to the same number — and
    /// `BoundarySpec::new` checks it against `data + 2*sites + 2` (ruling
    /// M-1). A shape whose declared `endpoint_rows` disagreed with its own
    /// endpoint parameters would be refused here as well as by `IoSpec`.
    pub(crate) fn boundary_spec(&self, k: usize) -> Result<BoundarySpec, String> {
        let sh = &self.rs.sh;
        let scale = *self.boundary_scales.get(k).ok_or_else(|| format!("private run: boundary {k} is not one of this run's {}", self.rs.l.saturating_sub(1)))?;
        BoundarySpec::new(self.context, sh.t_pad, sh.d_pad, scale, (k + 1) as u64, BOUNDARY_SITES, sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols, sh.endpoint_rows + 1)
    }

    /// `H(block 1's digest || ... || block L's digest)`
    fn public_statement(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-run-blocks/1");
        for d in &self.block_digests {
            h.update(d);
        }
        *h.finalize().as_bytes()
    }

    /// The run parameter line: the block's, plus `L`, the boundary geometry in
    /// the clear and the run's one-transcript claim. Ruling S11b-F4 — a
    /// verifier's geometry inputs must appear in a form a human can read, not
    /// only inside a digest — applies to the boundary exactly as it did to the
    /// endpoint.
    fn parameter_line(&self) -> Result<String, String> {
        let sh = &self.rs.sh;
        let rows = if self.rs.l > 1 { self.boundary_spec(0)?.commitment_rows() } else { 0 };
        Ok(format!(
            "{}/L{}/boundary-log_n{}-rate{}-pad{}-rows{rows}-sites{BOUNDARY_SITES}/external-rows{}/one-run-one-transcript",
            protocol::parameter_line(sh),
            self.rs.l,
            sh.endpoint_log_n,
            sh.endpoint_inv_rate,
            sh.opened_cols,
            sh.endpoint_rows
        ))
    }

    /// What stage `k` commits, which reserved pair each of its two IO tabs
    /// uses, and what it opens. This is the part of the schedule a run adds
    /// over a block, and it is in the run's schedule digest so that a verifier
    /// reads the geometry from its own statement and never from a segment.
    fn stage_line(&self, k: usize) -> Result<String, String> {
        let d = self.rs.data_rows();
        let (l, ins, outs) = (self.rs.l, self.in_site(k)?, self.out_site(k)?);
        Ok(format!(
            "stage {k:02}: commits {}; slot 21 claims {} at pair row {}; slot 22 claims {} at pair row {}; opens M A H then {}{}",
            if k + 1 < l { format!("boundary {k}") } else { "nothing".into() },
            if k == 0 { "the external input endpoint".to_string() } else { format!("boundary {}", k - 1) },
            ins,
            if k + 1 == l { "the external output endpoint".to_string() } else { format!("boundary {k}") },
            outs,
            if k == 0 { "the external input endpoint".to_string() } else { format!("boundary {}", k - 1) },
            if k + 1 == l { ", then the external output endpoint" } else { "" },
        ))
        .map(|s: String| format!("{s}; data rows {d}"))
    }

    /// the reserved pair slot 21 (the INCOMING claim) uses in stage `k`
    fn in_site(&self, k: usize) -> Result<usize, String> {
        if k == 0 {
            Ok(self.rs.data_rows())
        } else {
            self.boundary_spec(k - 1)?.mask_row(1)
        }
    }
    /// the reserved pair slot 22 (the OUTGOING claim) uses in stage `k`
    fn out_site(&self, k: usize) -> Result<usize, String> {
        if k + 1 == self.rs.l {
            Ok(self.rs.data_rows())
        } else {
            self.boundary_spec(k)?.mask_row(0)
        }
    }

    fn schedule_digest(&self) -> Result<Digest, String> {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-run-schedule/1");
        let mut line = |s: &str| {
            h.update(&(s.len() as u64).to_le_bytes());
            h.update(s.as_bytes());
        };
        line(&self.parameter_line()?);
        for s in Layout::for_shape(&self.rs.sh)?.describe() {
            line(&s);
        }
        for k in 0..self.rs.l {
            line(&self.stage_line(k)?);
        }
        Ok(*h.finalize().as_bytes())
    }

    /// The run header, absorbed before any commitment exists. Same shape as a
    /// block's (`protocol::transcript`), with the run's quantities.
    fn transcript(&self) -> Result<Transcript, String> {
        let sh = &self.rs.sh;
        let mut tr = Transcript::new(self.rs.profile.as_bytes());
        let mut shape_bytes = Vec::with_capacity(7 * 8);
        for v in [self.rs.l, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim] {
            shape_bytes.extend_from_slice(&(v as u64).to_le_bytes());
        }
        tr.absorb(b"run-shape", &shape_bytes);
        tr.absorb(b"expected-IO", &self.expected.to_bytes());
        tr.absorb(b"public-statement", &self.public_statement());
        tr.absorb(b"parameters", self.parameter_line()?.as_bytes());
        tr.absorb(b"calibration", &self.calibration);
        tr.absorb(b"schedule", &self.schedule_digest()?);
        Ok(tr)
    }

    /// **STAGE 14.** The run binding — the transcript state after the header
    /// and before any commitment — which is what the run capture compares its
    /// independently rebuilt header against. Test-only.
    #[cfg(test)]
    pub(crate) fn binding(&self) -> Result<Digest, String> {
        Ok(self.transcript()?.state())
    }

    /// **STAGE 14.** The run's public words, copied out for the run capture
    /// (`run_capture.rs` is a sibling module and cannot read these private
    /// fields). Every word the header absorbs is here in absorb order, so the
    /// recorder rebuilds the header transcript from this alone and compares it
    /// with the binding. Test-only, like the capture itself.
    #[cfg(test)]
    pub(crate) fn capture_header(&self) -> Result<super::run_capture::RunHeader, String> {
        let sh = &self.rs.sh;
        let mut boundaries = Vec::new();
        for k in 0..self.rs.l.saturating_sub(1) {
            let spec = self.boundary_spec(k)?;
            boundaries.push(super::run_capture::BoundaryFacts {
                index: (k + 1) as usize,
                scale: spec.scale(),
                sites: spec.sites(),
                data_rows: spec.data_rows(),
                rows: spec.commitment_rows(),
                site_rows: spec.site_rows(),
                prox_row: spec.prox_row(),
                log_n: spec.log_n(),
                inv_rate: sh.endpoint_inv_rate,
                checks: sh.opened_cols,
                digest: spec.digest(),
                plane: (sh.t_pad, sh.d_pad),
            });
        }
        Ok(super::run_capture::RunHeader {
            profile: self.rs.profile,
            l: self.rs.l,
            sh: sh.clone(),
            run_shape_words: [self.rs.l, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim].iter().map(|v| *v as u64).collect(),
            expected_bytes: self.expected.to_bytes(),
            public_statement: self.public_statement(),
            parameter_line: self.parameter_line()?,
            calibration: self.calibration,
            schedule_digest: self.schedule_digest()?,
            context: self.context,
            block_digests: self.block_digests.clone(),
            boundary_scales: self.boundary_scales.clone(),
            external_input_root: self.expected.input,
            external_output_root: self.expected.output,
            external_rows: sh.endpoint_rows,
            external_data_rows: self.rs.data_rows(),
            external_log_n: sh.endpoint_log_n,
            external_inv_rate: sh.endpoint_inv_rate,
            stage_lines: (0..self.rs.l).map(|k| self.stage_line(k)).collect::<Result<Vec<String>, String>>()?,
            layout_description: Layout::for_shape(sh)?.describe(),
            boundaries,
            external_scales: (self.expected.spec.input_scale(), self.expected.spec.output_scale()),
        })
    }

    fn seg_geom(&self, k: usize) -> Result<SegGeom, String> {
        let boundary_rows = if self.rs.l > 1 { self.boundary_spec(0)?.commitment_rows() } else { 0 };
        Ok(SegGeom { l: self.rs.l, k, boundary_rows, sites: BOUNDARY_SITES })
    }

    /// the stage layout: the block's, with the two IO tabs pointed at the
    /// reserved pairs this stage's schedule gives them
    fn stage_layout(&self, k: usize) -> Result<Layout, String> {
        Ok(Layout::for_shape(&self.rs.sh)?.with_io_mask_rows([self.in_site(k)?, self.out_site(k)?]))
    }
}

/// **THE TRANSCRIPT POSITION TAG.** A challenge squeezed from a CLONE of the
/// transcript: a function of the 32-byte state AND the squeeze counter, which
/// together are the whole state (`transcript.rs`'s `clone_state` copies
/// exactly those two). `zkp-core` publishes no counter accessor and is a file
/// this lane does not edit, so this is how a segment's header and trailer
/// compare both in 32 bytes (finding U-3). The clone is discarded, so nothing
/// the caller's transcript will later produce is disturbed — the same device
/// `check_opening` has always used for its challenge replay.
fn position_tag(tr: &Transcript) -> [u8; 32] {
    let mut c = Transcript::clone_state(tr);
    let v = c.challenge_fp2_vec(2);
    let mut out = [0u8; 32];
    out[..16].copy_from_slice(&v[0].to_bytes());
    out[16..].copy_from_slice(&v[1].to_bytes());
    out
}

/// Process resident high-water mark in MiB, from Linux `/proc/self/status`.
/// A whole-process figure on a shared box: it BOUNDS a stage's cost from
/// above and is not a measurement of it. A mark that RISES across stages of a
/// run is the sign of allocator fragmentation (the check's OMITTED CONDITION
/// 3); it is reported, never repaired here.
pub(crate) fn peak_rss_mib() -> f64 {
    std::fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("VmHWM:")).and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<f64>().ok())))
        .map(|kb| kb / 1024.0)
        .unwrap_or(f64::NAN)
}

/// The private inputs of a run, asked for ONE STAGE AT A TIME so that a
/// twelve-block run never holds twelve witnesses. The honest source builds
/// block `k`'s witness from block `k - 1`'s output; a test source may lie
/// about either, which is what the headline negative test needs.
pub(crate) trait RunWitnessSource {
    /// block `k`'s integer witness, built just in time and consumed by the stage
    fn witness(&mut self, k: usize) -> Result<Witness, String>;
    /// the PADDED plane the prover commits at internal boundary `k`
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String>;
}

#[derive(Clone, Debug, Default)]
pub(crate) struct RunStats {
    /// wall seconds of each stage (witness build excluded)
    pub prove_s: Vec<f64>,
    /// the process high-water mark after each stage
    pub hwm_mib: Vec<f64>,
    pub segment_bytes: Vec<usize>,
}

fn words(v: &[i16]) -> Vec<Fp> {
    v.iter().map(|x| Fp::from_i64(i64::from(*x))).collect()
}

/// **THE RUN PROVER.** One transcript, `L` stages, one OS randomness stream,
/// one NTT table, one masking commitment and one LogUp challenge triple PER
/// BLOCK. Each segment is handed to `sink` and DROPPED before the next stage
/// commits anything (ruling M-3: segments are flushed, not held — eleven
/// unflushed segments are 423 MiB at the 125M shape).
///
/// `sink` is called EXACTLY ONCE per finished segment, in order, with the
/// bytes OWNED: after it returns the prover holds nothing of that segment but
/// its length, in `stats`. Where the bytes then go is `run_sink.rs` —
/// `MemorySink` keeps them (the development-rung tests) and `DirSink` writes
/// each to its own file and keeps only a length and a SHA-256 (what a
/// twelve-block 125M run, 484 MB of receipt, must use).
pub(crate) fn prove_run(st: &RunStatement, blocks: &[BlockPublic], src: &mut dyn RunWitnessSource, externals: Endpoints, sink: &mut dyn FnMut(usize, Vec<u8>) -> Result<(), String>) -> Result<RunStats, String> {
    use std::time::Instant;
    let (sh, l) = (&st.rs.sh, st.rs.l);
    if blocks.len() != l {
        return Err(format!("private run: {} public statements for {l} blocks", blocks.len()));
    }
    protocol::fits_the_ntt_tables(sh)?;
    st.expected.spec.validate()?;
    let [ein, eout] = protocol::check_endpoints(sh, &st.expected, externals)?;
    let mut ein = Some(ein);
    let mut eout = Some(eout);
    // ONE OS stream per run; an entropy failure aborts the run, at any stage,
    // before anything of that stage is public.
    let mut rng = ZkRng::from_os(st.rs.profile.as_bytes()).map_err(|e| format!("private run randomness: {e}"))?;
    let ntt = NttTables::new(st.rs.ntt_log());
    let mut tr = st.transcript()?;
    let binding = tr.state();
    let mut stats = RunStats::default();
    // the claim block k-1's slot 22 raised on B_{k-1}, waiting for block k's
    // slot 21 to raise the other one
    let mut pending: Vec<ZClaim> = Vec::new();
    let mut prev: Option<(BoundarySpec, PreparedBoundary)> = None;

    for k in 0..l {
        let t0 = Instant::now();
        let mut ph = timing::Phases::start();
        let mut phases: Vec<(&'static str, f64)> = Vec::new();
        let mut tick = Instant::now();
        let start_tag = position_tag(&tr);
        // step 1: locality — these slots are block k's weights
        tr.absorb_u64(b"pb-run-stage", k as u64);
        tr.absorb(b"pb-run-block", &st.block_digests[k]);
        // step 2: commit the boundary to the NEXT block, before any challenge
        // of either adjacent equality slot
        let cur = if k + 1 < l {
            let spec = st.boundary_spec(k)?;
            let plane = src.boundary_plane(k)?;
            if plane.len() != spec.len() {
                return Err(format!("private run: boundary {k}'s plane is {} words, the padded plane is {}", plane.len(), spec.len()));
            }
            let p = boundary::prepare(&spec, &words(&plane), &ntt, &mut rng)?;
            protocol::absorb_root(&mut tr, b"B", &p.root(), spec.commitment_rows(), spec.log_n());
            Some((spec, p))
        } else {
            None
        };
        // steps 3-8: the measured block, unchanged
        let lay = st.stage_layout(k)?;
        let wit = src.witness(k)?;
        let core = {
            let in_data: &[Fp] = match &prev {
                Some((_, p)) => p.data(),
                None => &ein.as_ref().ok_or("private run: the input endpoint was already consumed")?.data,
            };
            let out_data: &[Fp] = match &cur {
                Some((_, p)) => p.data(),
                None => &eout.as_ref().ok_or("private run: the output endpoint was already consumed")?.data,
            };
            protocol::prove_core(sh, &lay, &blocks[k], wit, [in_data, out_data], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick)?
        };
        let [ic, oc] = core.io_claims;
        // the incoming commitment's claim list is complete NOW, and not before
        let in_open = match prev.take() {
            Some((spec, owner)) => {
                let mut claims = std::mem::take(&mut pending);
                claims.extend(ic);
                owner.into_opening(&spec, &claims, &mut tr)?
            }
            None => {
                let e = ein.take().ok_or("private run: the input endpoint was already consumed")?;
                protocol::check_endpoint_opening(&ic, sh, &tr)?;
                let o = pcs::open_zk(&e, &ic, &mut tr);
                drop(e);
                o
            }
        };
        let out_open = if k + 1 == l {
            let e = eout.take().ok_or("private run: the output endpoint was already consumed")?;
            protocol::check_endpoint_opening(&oc, sh, &tr)?;
            let o = pcs::open_zk(&e, &oc, &mut tr);
            drop(e);
            Some(o)
        } else {
            pending = oc;
            None
        };
        ph.report("prove", st.rs.profile);
        let end_tag = position_tag(&tr);
        let seg = Segment {
            b_root: cur.as_ref().map(|(_, p)| p.root()),
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
        let bytes = wire::encode_segment(&seg, &lay, st.seg_geom(k)?, &binding, &start_tag, &end_tag)?;
        drop(seg);
        stats.segment_bytes.push(bytes.len());
        // RULING M-3: the segment leaves here and is not held
        sink(k, bytes)?;
        prev = cur;
        stats.prove_s.push(t0.elapsed().as_secs_f64());
        stats.hwm_mib.push(peak_rss_mib());
    }
    Ok(stats)
}

/// **THE RUN VERIFIER, one segment at a time.** Everything it carries between
/// segments and nothing else: the transcript, the run binding, the claim the
/// previous stage raised and the boundary that is waiting to be opened. It
/// never holds a segment — [`RunVerifier::step`] is handed one segment's
/// bytes, which the caller is free to drop the moment it returns. That is
/// what lets a twelve-block 125M run (484 MB of receipt) be verified inside a
/// memory ceiling: see [`verify_run_from_dir`].
struct RunVerifier<'a> {
    st: &'a RunStatement,
    blocks: &'a [BlockPublic],
    ntt: NttTables,
    e_params: PcsParams,
    e_zko: ZkOpts,
    tr: Transcript,
    binding: Digest,
    pending: Vec<ZClaim>,
    prev: Option<(BoundarySpec, Digest)>,
}

impl<'a> RunVerifier<'a> {
    /// The run header, absorbed before any segment is looked at. `L` is the
    /// statement's — never a frame's.
    fn start(st: &'a RunStatement, blocks: &'a [BlockPublic]) -> Result<RunVerifier<'a>, String> {
        let (sh, l) = (&st.rs.sh, st.rs.l);
        if blocks.len() != l {
            return Err(format!("private run: {} public statements for {l} blocks", blocks.len()));
        }
        protocol::fits_the_ntt_tables(sh)?;
        st.expected.spec.validate()?;
        let ntt = NttTables::new(st.rs.ntt_log());
        let e_params = protocol::endpoint_pcs_params(sh);
        let e_zko = ZkOpts::standard(&e_params);
        let mut tr = st.transcript()?;
        let binding = tr.state();
        Ok(RunVerifier { st, blocks, ntt, e_params, e_zko, tr, binding, pending: Vec::new(), prev: None })
    }

    /// One stage: it re-derives every geometry from its own statement, and it
    /// COMPUTES each pending boundary claim itself from the slot terminals
    /// rather than reading one from a segment. A segment header's transcript
    /// position is compared and never adopted (ruling M-6), and the header
    /// and trailer are outside the Fiat-Shamir chain.
    fn step(&mut self, k: usize, bytes: &[u8]) -> Result<(), String> {
        let (st, sh, l) = (self.st, &self.st.rs.sh, self.st.rs.l);
        let mut ph = timing::Phases::start();
        let lay = st.stage_layout(k)?;
        let start_tag = position_tag(&self.tr);
        let (seg, end_tag) = wire::decode_segment(bytes, &lay, st.seg_geom(k)?, &self.binding, &start_tag)?;
        // **STAGE 16, ruling T-4.** Every opened column's Merkle path has
        // exactly its commitment's tree depth, checked HERE — before a byte
        // of this stage is hashed — and not left to be an accident of the
        // frame format. `pcs::verify_zk` folds however many siblings it is
        // handed, and a Merkle inner node is the same 64-byte hash as a
        // salted leaf, so a path one entry short is a way to present a node
        // as a leaf. `wire::path_len` is the one source of both numbers.
        super::hash_domain::segment_paths_are_the_tree_depth(&seg, sh)?;
        // STAGE 14: the run capture opens this stage. A no-op unless a
        // recorder is attached; it is handed what the verifier already holds
        // and returns nothing, so no branch below can depend on it.
        #[cfg(test)]
        super::run_capture::stage_begin(k, bytes, start_tag, seg.b_root, seg.a_root, seg.h_root, seg.mask_root, &lay, &self.tr);
        self.tr.absorb_u64(b"pb-run-stage", k as u64);
        self.tr.absorb(b"pb-run-block", &st.block_digests[k]);
        let cur = match (k + 1 < l, seg.b_root) {
            (true, Some(root)) => {
                let spec = st.boundary_spec(k)?;
                protocol::absorb_root(&mut self.tr, b"B", &root, spec.commitment_rows(), spec.log_n());
                Some((spec, root))
            }
            (false, None) => None,
            _ => return Err(format!("private run: segment {k}'s boundary root is not what the run schedule declares")),
        };
        let view = CoreView {
            a_root: seg.a_root,
            h_root: seg.h_root,
            mask_root: seg.mask_root,
            slots: &seg.slots,
            mask_open: &seg.mask_open,
            a_open: &seg.a_open,
            h_open: &seg.h_open,
        };
        let ([ic, oc], _) = protocol::verify_core(sh, &lay, &self.blocks[k], view, &self.ntt, &mut self.tr, &mut ph)?;
        match self.prev.take() {
            Some((spec, root)) => {
                // the verifier's OWN pending claim, computed in stage k-1
                #[cfg(test)]
                let pending = self.pending.len();
                let mut claims = std::mem::take(&mut self.pending);
                #[cfg(test)]
                let incoming = ic.len();
                claims.extend(ic);
                boundary::check_opening(&spec, &claims, &self.tr)?;
                let params = spec.params();
                let cm = protocol::commitment(root, spec.commitment_rows(), spec.log_n());
                #[cfg(test)]
                let rc_before = super::run_capture::checkpoint(&self.tr);
                pcs::verify_zk(&params, &ZkOpts::standard(&params), &cm, &claims, &seg.in_open, &self.ntt, &mut self.tr).map_err(|e| format!("boundary {}: {e}", k - 1))?;
                #[cfg(test)]
                super::run_capture::pcs(
                    super::run_capture::Geom {
                        role: "Input",
                        commitment_kind: "internal-boundary",
                        params,
                        root,
                        rows: spec.commitment_rows(),
                        data_rows: spec.data_rows(),
                        site_rows: spec.site_rows(),
                        sum_rows: None,
                        prox_row: spec.prox_row(),
                        boundary: Some(k - 1),
                        claim_sources: vec![(k - 1, super::layout::SC_IO_OUT, pending), (k, super::layout::SC_IO_IN, incoming)],
                    },
                    &claims,
                    &seg.in_open,
                    &self.ntt,
                    rc_before,
                    &self.tr,
                );
            }
            None => {
                protocol::check_endpoint_opening(&ic, sh, &self.tr)?;
                let cm = protocol::commitment(st.expected.input, sh.endpoint_rows, sh.endpoint_log_n);
                #[cfg(test)]
                let rc_before = super::run_capture::checkpoint(&self.tr);
                #[cfg(test)]
                let incoming = ic.len();
                pcs::verify_zk(&self.e_params, &self.e_zko, &cm, &ic, &seg.in_open, &self.ntt, &mut self.tr).map_err(|e| format!("run input endpoint: {e}"))?;
                #[cfg(test)]
                super::run_capture::pcs(
                    super::run_capture::Geom {
                        role: "Input",
                        commitment_kind: "external-endpoint",
                        params: self.e_params,
                        root: st.expected.input,
                        rows: sh.endpoint_rows,
                        data_rows: st.rs.data_rows(),
                        site_rows: vec![st.rs.data_rows(), st.rs.data_rows() + 1],
                        sum_rows: None,
                        prox_row: st.rs.data_rows() + 2,
                        boundary: None,
                        claim_sources: vec![(k, super::layout::SC_IO_IN, incoming)],
                    },
                    &ic,
                    &seg.in_open,
                    &self.ntt,
                    rc_before,
                    &self.tr,
                );
            }
        }
        if k + 1 == l {
            let o = seg.out_open.as_ref().ok_or("private run: the last segment carries no output-endpoint opening")?;
            protocol::check_endpoint_opening(&oc, sh, &self.tr)?;
            let cm = protocol::commitment(st.expected.output, sh.endpoint_rows, sh.endpoint_log_n);
            #[cfg(test)]
            let rc_before = super::run_capture::checkpoint(&self.tr);
            #[cfg(test)]
            let outgoing = oc.len();
            pcs::verify_zk(&self.e_params, &self.e_zko, &cm, &oc, o, &self.ntt, &mut self.tr).map_err(|e| format!("run output endpoint: {e}"))?;
            #[cfg(test)]
            super::run_capture::pcs(
                super::run_capture::Geom {
                    role: "Output",
                    commitment_kind: "external-endpoint",
                    params: self.e_params,
                    root: st.expected.output,
                    rows: sh.endpoint_rows,
                    data_rows: st.rs.data_rows(),
                    site_rows: vec![st.rs.data_rows(), st.rs.data_rows() + 1],
                    sum_rows: None,
                    prox_row: st.rs.data_rows() + 2,
                    boundary: None,
                    claim_sources: vec![(k, super::layout::SC_IO_OUT, outgoing)],
                },
                &oc,
                o,
                &self.ntt,
                rc_before,
                &self.tr,
            );
        } else {
            self.pending = oc;
            self.prev = cur;
        }
        // the trailer localises a corruption to its own segment; it is
        // COMPARED, never adopted
        if position_tag(&self.tr) != end_tag {
            return Err(format!("private run: segment {k}'s trailer is not the verifier's own transcript position"));
        }
        #[cfg(test)]
        super::run_capture::stage_end(k, end_tag, &self.tr);
        Ok(())
    }

    /// **THE RUN CLOSING CHECK** (the design's §4.3 check 4, in the half that
    /// is real). Every claim the verifier accumulated has been discharged by
    /// an opening, and no commitment it absorbed is still waiting for one. The
    /// check's CORRECTION 8 is right that this is a REGRESSION GUARD ON THE
    /// VERIFIER'S OWN PATH and not a soundness upgrade — the run layout is a
    /// function of the verifier's own statement, so a prover cannot present a
    /// different set of openings without changing a segment length or the
    /// chain — but it is two lines and it fires if this code ever forgets one.
    fn finish(self) -> Result<(), String> {
        if !self.pending.is_empty() || self.prev.is_some() {
            return Err("private run: a boundary claim was left undischarged at the end of the run".into());
        }
        #[cfg(test)]
        super::run_capture::run_accepted();
        Ok(())
    }
}

/// **THE RUN VERIFIER.** It checks exactly `L` segments, `L` being its OWN
/// (from the statement, never from a frame). The segments are the caller's,
/// all of them resident; for a run whose receipt does not fit in memory use
/// [`verify_run_from_dir`], which is the same verifier fed one segment at a
/// time.
pub(crate) fn verify_run(st: &RunStatement, blocks: &[BlockPublic], segments: &[Vec<u8>]) -> Result<(), String> {
    let l = st.rs.l;
    if blocks.len() != l {
        return Err(format!("private run: {} public statements for {l} blocks", blocks.len()));
    }
    if segments.len() != l {
        return Err(format!("private run: {} segments were offered, this run has {l}", segments.len()));
    }
    let mut v = RunVerifier::start(st, blocks)?;
    for (k, bytes) in segments.iter().enumerate() {
        v.step(k, bytes)?;
    }
    v.finish()
}

/// **THE STREAMING RUN VERIFIER: `L` files, read ONE AT A TIME.** Its memory
/// is the verifier's own state plus ONE segment's bytes — 41 MB at the 125M
/// shape, against a receipt of 484 MB — because each segment is read, stepped
/// and dropped before the next is opened.
///
/// The directory must hold exactly the `L` files [`run_sink::segment_paths`]
/// names and NOTHING ELSE, `L` being the verifier's own: a missing file, an
/// extra segment beyond `L`, a leftover temporary or any foreign file is
/// refused before a byte of any segment is read. Everything past that is the
/// ordinary verifier, so a swapped, duplicated, truncated, foreign or altered
/// FILE is caught exactly as the same bytes in memory would be.
pub(crate) fn verify_run_from_dir(st: &RunStatement, blocks: &[BlockPublic], dir: &std::path::Path) -> Result<(), String> {
    let l = st.rs.l;
    if blocks.len() != l {
        return Err(format!("private run: {} public statements for {l} blocks", blocks.len()));
    }
    let paths = run_sink::segment_paths(dir, l)?;
    let mut v = RunVerifier::start(st, blocks)?;
    for (k, p) in paths.iter().enumerate() {
        // ONE segment's bytes are resident: read here, dropped at the end of
        // this iteration, before the next file is opened
        let bytes = std::fs::read(p).map_err(|e| format!("private run: segment {k} ({}) cannot be read: {e}", p.display()))?;
        v.step(k, &bytes)?;
    }
    v.finish()
}
