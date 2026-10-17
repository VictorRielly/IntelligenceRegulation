//! **STAGE 12 / R2: the INTERNAL BOUNDARY of a private run.**
//!
//! A run of `L` blocks under one transcript has `L - 1` internal boundaries.
//! At boundary `k` the prover commits the padded hidden plane ONCE, to a
//! commitment of its own, and TWO slots claim it: block `k`'s output-equality
//! slot (`SC_IO_OUT`) and block `k + 1`'s input-equality slot (`SC_IO_IN`).
//! The commitment is opened exactly ONCE, in stage `k + 1`, with both claims
//! in that one opening. Transitively `A_k`'s output plane equals `A_{k+1}`'s
//! input plane word for word, which is the chaining statement.
//!
//! **The geometry is DERIVED, never accepted (ruling M-1).** The independent
//! check's exact rank model found that a boundary with a single proximity row
//! — `rows = data + 2*sites + 1` — has joint rank 5 of 6 on its reserved rows
//! and discloses one real dimension, and that the schedule audit does not stop
//! it (finding U-1 of this lane sharpens that: the audit tracks the caller's
//! DECLARATION, not the truth of the geometry). So this module computes
//!
//! ```text
//! rows = data + 2 * sites + 2      (one reserved PAIR per claim site,
//!                                   then the proximity PAIR)
//! ```
//!
//! from the padded plane and the site count, and refuses any other row count
//! BY NAME. `2 * (G + 1)` real dimensions need `2 * (G + 1)` free base-field
//! mask coordinates, and with `sites` claim sites plus a proximity vector that
//! is exactly `2 * sites + 2` rows.
//!
//! **The two EXTERNAL endpoints of a run keep today's `endpoint_g` geometry
//! (ruling M-7)** — `data + 5` rows, one claim site. This module is only ever
//! asked for the internal boundaries, and nothing of `endpoint_g.rs` moves.
//!
//! **What is NOT claimed.** This is an experimental component. It commits a
//! plane and lets two claims be opened against it in one opening; it is not a
//! proof that a run is zero knowledge, and no privacy statement is made from
//! it. The run's joint-rank obligation — over ALL THREE commitments that hold
//! an interior plane, `A_k`'s output rows, this boundary, and `A_{k+1}`'s
//! input rows, restricted to the reserved mask rows — has no tool yet and has
//! not been run.
//!
//! Modelled on `endpoint_g.rs` line for line, with `sites` as a parameter and
//! with the `open_zk` wrapper the check's CORRECTION 1 asks for.

use super::protocol;
use zkp_core::hashtag::HashTag;
use crate::field::{Fp, P};
use crate::merkle::Digest;
use crate::ntt::NttTables;
use crate::pcs::{self, Commitment, CommittedZk, OpeningZk, PcsParams, ZClaim, ZkOpts};
use crate::transcript::Transcript;
use crate::zk::ZkRng;

/// Its OWN domain label, so that a boundary statement's digest can never
/// collide with `endpoint_g`'s (42 bytes) or with the frozen seam's. 43 bytes,
/// so neither of the two lengths code condition C-H4' forbids (28 and 35 —
/// written here WITHOUT a byte-string prefix on purpose, because the C-H4'
/// scan reads this file's source and a citation is indistinguishable from a
/// label).
const DOMAIN: &[u8] = b"hashline/private-block/internal-boundary/v1";

/// A bounded prototype ceiling, not a soundness bound: `2^24` words is 32x the
/// 125M boundary plane (`2^19`). Same value and same reason as
/// `endpoint_g::MAX_LOG_LEN`.
const MAX_LOG_LEN: u32 = 24;

/// At most this many claim sites on one boundary. A boundary between two
/// blocks has exactly two; the parameter exists so that the geometry rule is
/// stated once rather than hard-coded, and a caller asking for an arity no
/// run has is refused rather than silently served.
const MAX_SITES: usize = 4;

/// The internal boundary statement. Built only through [`BoundarySpec::new`],
/// which DERIVES the commitment's row count and refuses by name every
/// geometry the construction cannot express — including a caller-declared row
/// count that is not the derived one (ruling M-1).
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct BoundarySpec {
    context: Digest,
    /// the boundary plane's padded axes (`t_pad`, `d_pad` of the run's shape)
    rows: usize,
    cols: usize,
    /// **RULING M-4.** ONE field, shared by construction between block `k`'s
    /// declared output scale and block `k + 1`'s declared input scale. A run
    /// cannot declare two scales at one boundary because there is only one
    /// place to declare it.
    scale: i32,
    /// which internal boundary of the run this is (`1 ..= L - 1`), so that two
    /// boundaries of one run can never share a statement digest
    index: u64,
    /// how many slots claim this commitment (2 for an internal boundary)
    sites: usize,
    log_len: u32,
    /// the COMMITMENT's row width
    log_n: u32,
    inv_rate: usize,
    /// the opened columns, which is also the pad count
    checks: usize,
}

impl BoundarySpec {
    /// `declared_rows` is CHECKED against the derived row count, never used as
    /// one: that is the whole of ruling M-1 in one line. A caller who wants
    /// the geometry has to state it and be told when it is wrong.
    ///
    /// This is [`BoundarySpec::new_with_tag`] under the LEGACY hash rule,
    /// which is the rule that imposes the C-H4 length guard — the fail-closed
    /// direction for a caller with no tag to offer.
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new(context: Digest, rows: usize, cols: usize, scale: i32, index: u64, sites: usize, log_n: usize, inv_rate: usize, checks: usize, declared_rows: usize) -> Result<Self, String> {
        Self::new_with_tag(context, rows, cols, scale, index, sites, log_n, inv_rate, checks, declared_rows, &HashTag::legacy())
    }

    /// **STAGE 18, ruling T-3 AS AMENDED.** The same constructor, told which
    /// hash rule this boundary's run hashes under. The ONLY thing the tag
    /// changes is the C-H4 length guard at the bottom — imposed under the
    /// legacy rule, not under a tag
    /// (`hash_domain::imposed_shape_free`). Ruling M-1's declared-row check
    /// and every geometry refusal above it are unchanged and fire under both
    /// rules. The one production call site is `RunStatement::boundary_spec`,
    /// which passes the tag its own shape derives (ruling T-7: the key set is
    /// never an input).
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new_with_tag(context: Digest, rows: usize, cols: usize, scale: i32, index: u64, sites: usize, log_n: usize, inv_rate: usize, checks: usize, declared_rows: usize, tag: &HashTag) -> Result<Self, String> {
        if context == [0; 32] {
            return Err("boundary: a nonempty context is required".into());
        }
        if !(1..=MAX_SITES).contains(&sites) {
            return Err(format!("boundary: {sites} claim sites, the construction carries 1..={MAX_SITES}"));
        }
        let len = rows.checked_mul(cols).ok_or("boundary: shape overflow")?;
        if !rows.is_power_of_two() || !cols.is_power_of_two() || !(2..=1usize << MAX_LOG_LEN).contains(&len) {
            return Err(format!("boundary: supported plane has 2..2^{MAX_LOG_LEN} values and power-of-two axes"));
        }
        if !(-31..=31).contains(&scale) {
            return Err("boundary: unsupported scale".into());
        }
        let log_len = len.trailing_zeros();
        if !(2..=log_len as usize).contains(&log_n) || !inv_rate.is_power_of_two() || inv_rate < 2 || log_n + inv_rate.trailing_zeros() as usize > 30 {
            return Err("boundary: the row geometry is out of range".into());
        }
        if checks == 0 || checks > 1usize << log_n {
            return Err("boundary: the pad count must be nonzero and at most the row width".into());
        }
        let spec = Self { context, rows, cols, scale, index, sites, log_len, log_n: log_n as u32, inv_rate, checks };
        // **RULING M-1.** The row count is a function of the plane and the
        // site count. A declaration that is not it is refused here, by name,
        // with both numbers in the message — and the 37-row geometry of
        // blocking item B4 is exactly this refusal at `sites = 2`.
        let derived = spec.commitment_rows();
        if declared_rows != derived {
            return Err(format!("boundary: this statement declares {declared_rows} rows, its plane and {sites} claim sites give {derived} (data + 2*sites + 2: one reserved pair per site, then the proximity pair)"));
        }
        // C-H4: a commitment whose column hashes to 40 or 64 bytes could be
        // confused with a randomness-refill block or an internal Merkle node.
        // STAGE 18 (T-3 amended): imposed under the LEGACY rule only.
        super::layout::no_commitment_has_a_node_shaped_column_under(&[("internal boundary", derived)], tag)?;
        Ok(spec)
    }

    pub(crate) fn len(&self) -> usize {
        self.rows * self.cols
    }
    pub(crate) fn params(&self) -> PcsParams {
        PcsParams { log_cols: self.log_n, inv_rate: self.inv_rate, num_col_checks: self.checks }
    }
    pub(crate) fn log_n(&self) -> usize {
        self.log_n as usize
    }
    pub(crate) fn sites(&self) -> usize {
        self.sites
    }
    /// Which internal boundary of the run this is (`1 ..= L - 1`) — a PUBLIC
    /// word of the run's statement. **STAGE 26** reads it here so that a
    /// boundary's generator domain can carry it as a fixed-width index.
    pub(crate) fn index(&self) -> u64 {
        self.index
    }
    pub(crate) fn scale(&self) -> i32 {
        self.scale
    }
    /// how many rows of this commitment carry plane words
    pub(crate) fn data_rows(&self) -> usize {
        self.len() >> self.log_n
    }
    /// **THE DERIVED GEOMETRY**: data rows, one reserved PAIR per claim site,
    /// then the proximity PAIR.
    pub(crate) fn commitment_rows(&self) -> usize {
        self.data_rows() + 2 * self.sites + 2
    }
    /// every reserved claim-pair row, in order (the proximity pair excluded) —
    /// the `site_rows` argument `audit_claims` takes
    pub(crate) fn site_rows(&self) -> Vec<usize> {
        (self.data_rows()..self.data_rows() + 2 * self.sites).collect()
    }
    /// the first row of the proximity PAIR
    pub(crate) fn prox_row(&self) -> usize {
        self.data_rows() + 2 * self.sites
    }
    /// the first row of claim site `s`'s reserved pair. Site 0 is the OUTGOING
    /// claim (block `k`'s slot 22) and site 1 the INCOMING one (block
    /// `k + 1`'s slot 21); the assignment is the run's declared schedule and
    /// is covered by the run's schedule digest.
    pub(crate) fn mask_row(&self, site: usize) -> Result<usize, String> {
        if site >= self.sites {
            return Err(format!("boundary: claim site {site} on a commitment with {} sites", self.sites));
        }
        Ok(self.data_rows() + 2 * site)
    }
    /// `log2` of the encoded row length — the NTT size this boundary needs
    pub(crate) fn enc_log(&self) -> u32 {
        self.log_n + self.inv_rate.trailing_zeros()
    }
    /// The statement digest, under this module's OWN domain. Every parameter
    /// the geometry depends on is in it, and so is the DERIVED row count, so
    /// that a verifier cannot be handed a statement whose geometry it did not
    /// agree to.
    pub(crate) fn digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(DOMAIN);
        h.update(&self.context);
        for n in [
            self.rows as u64,
            self.cols as u64,
            self.index,
            self.sites as u64,
            self.log_n as u64,
            self.inv_rate as u64,
            self.checks as u64,
            self.commitment_rows() as u64,
            self.prox_row() as u64,
        ] {
            h.update(&n.to_le_bytes());
        }
        h.update(&self.scale.to_le_bytes());
        *h.finalize().as_bytes()
    }
}

/// Private prover state, and the answer to the check's CORRECTION 1.
/// `pcs::open_zk` takes the commitment by SHARED REFERENCE, so it cannot
/// itself enforce "opened once"; this wrapper owns the `CommittedZk`, has no
/// `Clone` and no opening method that borrows, and its
/// [`PreparedBoundary::into_opening`] consumes `self`. A second opening of one
/// boundary therefore does not type-check.
pub(crate) struct PreparedBoundary {
    spec_digest: Digest,
    committed: CommittedZk,
}

impl PreparedBoundary {
    pub(crate) fn commitment(&self) -> Commitment {
        self.committed.cm.commitment()
    }
    pub(crate) fn root(&self) -> Digest {
        self.committed.cm.commitment().root
    }
    /// The committed matrix, as a SHARED slice, for the two adjacent blocks'
    /// equality slots.
    ///
    /// This is the one accessor beyond `root()`, and it is here for the same
    /// reason `protocol::prove_inner_at` reads `ein.data.as_slice()` today:
    /// the masked terminal of an IO tab is an evaluation of the commitment's
    /// own mask rows (`argument::mask_eval`), so the slot loop must be able to
    /// read the committed matrix. It hands out a borrow and never ownership,
    /// so no second commitment and no second opening can be formed from it,
    /// and the load-bearing discipline — ONE opening — is enforced by
    /// `into_opening` consuming the owner.
    pub(crate) fn data(&self) -> &[Fp] {
        &self.committed.data
    }
    /// **THE ONE OPENING.** Consumes the owner, audits the claim schedule
    /// against the DERIVED geometry, requires exactly `sites` column-weight
    /// groups, replays the PCS challenge prefix for its refusals, and only
    /// then calls `pcs::open_zk`. Every claim on a boundary goes through
    /// `audit_claims` because there is no other way to open one.
    pub(crate) fn into_opening(self, spec: &BoundarySpec, claims: &[ZClaim], tr: &mut Transcript) -> Result<OpeningZk, String> {
        if self.spec_digest != spec.digest() {
            return Err("boundary: prepared context mismatch".into());
        }
        check_opening(spec, claims, tr)?;
        Ok(pcs::open_zk(&self.committed, claims, tr))
    }
}

/// The audit, the exact group count and the challenge refusals of ONE boundary
/// opening, from PUBLIC inputs only. The verifier runs exactly this before
/// `pcs::verify_zk`, which is what makes it a check and not an assumption.
pub(crate) fn check_opening(spec: &BoundarySpec, claims: &[ZClaim], tr: &Transcript) -> Result<(), String> {
    protocol::check_opening(claims, spec.log_n(), spec.commitment_rows(), &spec.site_rows(), None, spec.prox_row(), spec.sites(), tr)
}

/// The generalised endpoint's `check_ntt` (`endpoint_g.rs:169-185`), at this
/// spec's parameters: the table must be canonical and cover this boundary's
/// encoding domain. Caller-selected or malformed root tables are refused.
fn check_ntt(spec: &BoundarySpec, ntt: &NttTables) -> Result<(), String> {
    let need = spec.enc_log();
    if ntt.max_log < need {
        return Err(format!("boundary: NttTables cover 2^{} but this boundary encodes over 2^{need}", ntt.max_log));
    }
    let half = (1usize << ntt.max_log) / 2;
    if ntt.roots.len() != ntt.max_log as usize + 1 || ntt.inv_roots.len() != ntt.max_log as usize + 1 || ntt.twiddle_tables().0.len() != half.max(1) || ntt.twiddle_tables().1.len() != half.max(1) {
        return Err("boundary: malformed NttTables".into());
    }
    for k in 0..=ntt.max_log {
        let want = Fp::two_adic_root(k);
        if ntt.roots[k as usize] != want || ntt.inv_roots[k as usize] != want.inv() {
            return Err("boundary: changed NTT roots".into());
        }
    }
    Ok(())
}

/// Commit the padded boundary plane. Fresh secret entropy on every call; no
/// deterministic seed is exposed. `rng` is the caller's stream so that a run
/// draws its `L - 1` boundaries from the same OS-seeded generator the rest of
/// the stage uses, and a failure to obtain entropy aborts the run rather than
/// one boundary.
/// **STAGE 17, ruling T-1.** `tag` is the RUN's profile hash tag, handed in
/// by `run::prove_run` from its own statement. An internal boundary is one of
/// the run's commitments, so it hashes under the same rule as the rest of
/// them (ruling T-2 as amended: no mixtures within a profile).
///
/// **STAGE 26 (the ruling on finding B-1), and why this function is the ONE
/// commitment on the path with no generator of its own.** The ruling gives
/// every generator a domain that says what it is for, and a boundary has
/// none to give a domain to: `rng` is the caller's, by the design above, and
/// `s25_tests::no_profile_on_this_path_can_obtain_a_generator_other_than_
/// from_the_operating_system` fails if this file ever grows a generator
/// construction of its own — which is why the call is NOT spelled in this
/// comment, exactly as `endpoint_g.rs` does not spell the frozen seam's
/// domain label: the scans read this file's source and a citation is
/// indistinguishable from a call. The domain a boundary WOULD use is written
/// anyway — `hash_domain::boundary_seed_domain(index, spec.digest())`, the
/// use literal, the boundary index as a `u64` and the public spec digest —
/// so that the day a boundary needs its own stream the domain exists, is
/// separated from every other one in the run, and cannot be improvised out
/// of the nearest constant.
pub(crate) fn prepare(spec: &BoundarySpec, values: &[Fp], ntt: &NttTables, rng: &mut ZkRng, tag: &HashTag) -> Result<PreparedBoundary, String> {
    check_ntt(spec, ntt)?;
    if values.len() != spec.len() || values.iter().any(|x| x.0 >= P) {
        return Err("boundary: wrong length or noncanonical input words".into());
    }
    let n = 1usize << spec.log_n;
    let first_mask = spec.data_rows();
    let mut data = vec![Fp::ZERO; spec.commitment_rows() * n];
    data[..values.len()].copy_from_slice(values);
    for x in &mut data[first_mask * n..] {
        *x = rng.fp();
    }
    let params = spec.params();
    let mut committed = pcs::commit_zk_owned_tagged(&params, data, ntt, &ZkOpts::standard(&params), rng, tag);
    committed.mask_rows = spec.site_rows();
    committed.prox_mask_row = Some(spec.prox_row());
    Ok(PreparedBoundary { spec_digest: spec.digest(), committed })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::field::Fp2;
    use crate::mle::eq_table_msb;
    use crate::pcs::{Slice, ZPart};

    fn ctx() -> Digest {
        *blake3::hash(b"stage 12: the internal boundary's own test context").as_bytes()
    }

    /// the 125M internal boundary: a padded `(512, 1024)` plane over rows of
    /// `2^14`, two claim sites, 38 rows
    fn m125_spec() -> BoundarySpec {
        BoundarySpec::new(ctx(), 512, 1024, 0, 1, 2, 14, 4, 256, 38).expect("the 125M boundary statement is well formed")
    }

    /// the rung-G internal boundary: the padded `(32, 128)` plane over rows of
    /// `2^10`, so four data rows, two claim sites, 10 rows
    fn rung_g_spec() -> BoundarySpec {
        BoundarySpec::new(ctx(), 32, 128, 0, 1, 2, 10, 4, 256, 10).expect("the rung-G boundary statement is well formed")
    }

    fn plane(len: usize, seed: u64) -> Vec<Fp> {
        (0..len).map(|i| Fp::from_i64(((i as u64).wrapping_mul(2_654_435_761).wrapping_add(seed) % 4_096) as i64 - 2_048)).collect()
    }

    /// **STAGE 26.** The generator these tests hand [`prepare`], seeded under
    /// this boundary's OWN domain
    /// ([`super::super::hash_domain::boundary_seed_domain`]: the use literal,
    /// the boundary index and the public spec digest).
    ///
    /// Until this stage the six sites below seeded the generator with
    /// `DOMAIN`, the module's spec-digest domain LABEL — the same 43 bytes at
    /// every boundary of every run, and a second use of a string that means
    /// something else. In PRODUCTION nothing is affected either way: a
    /// boundary never makes a generator, it is handed the run's one stream
    /// (`prepare`'s doc comment), which is why this builder has no production
    /// call site and is exercised here.
    fn test_generator(spec: &BoundarySpec) -> ZkRng {
        ZkRng::from_os(&super::super::hash_domain::boundary_seed_domain(spec.index(), &spec.digest())).expect("secret entropy")
    }

    /// **THE DERIVED GEOMETRY, at both shapes the run will use.**
    #[test]
    fn the_declared_geometry_is_what_the_spec_derives() {
        let g = rung_g_spec();
        assert_eq!((g.len(), g.data_rows(), g.commitment_rows(), g.enc_log()), (4_096, 4, 10, 12), "the rung-G boundary geometry");
        assert_eq!((g.site_rows(), g.prox_row()), (vec![4, 5, 6, 7], 8), "the rung-G boundary's reserved rows");
        assert_eq!((g.mask_row(0), g.mask_row(1)), (Ok(4), Ok(6)), "the rung-G boundary's two claim sites");
        let m = m125_spec();
        assert_eq!((m.len(), m.data_rows(), m.commitment_rows(), m.enc_log()), (524_288, 32, 38, 16), "the 125M boundary geometry");
        assert_eq!((m.site_rows(), m.prox_row()), (vec![32, 33, 34, 35], 36), "the 125M boundary's reserved rows");
        assert!(m.mask_row(2).is_err(), "a third claim site on a two-site boundary was served");
    }

    /// **RULING M-1.** Every row count but the derived one is refused BY NAME,
    /// at both shapes and at every site count the construction offers. The
    /// 37-row case — one proximity row instead of two, joint rank 5 of 6 on
    /// the reserved rows — is the reason the rule exists.
    #[test]
    fn every_row_count_but_the_derived_one_is_refused_by_name() {
        // NOTE the third row: a ONE-site boundary at the rung-G plane would be
        // `4 + 2 + 2 = 8` rows and C-H4 refuses it outright, so the one-site
        // arity is exercised at the 125M plane instead. Nothing in a run asks
        // for it — the two external endpoints keep `endpoint_g`'s `data + 5`
        // geometry (ruling M-7) — but the rule has to hold at every arity the
        // module offers.
        for (what, r, c, log_n, sites, derived) in [("125M", 512usize, 1024usize, 14usize, 2usize, 38usize), ("rung-G", 32, 128, 10, 2, 10), ("125M, one site", 512, 1024, 14, 1, 36)] {
            BoundarySpec::new(ctx(), r, c, 0, 1, sites, log_n, 4, 256, derived).unwrap_or_else(|e| panic!("{what}: the derived geometry was refused: {e}"));
            for wrong in [derived - 1, derived + 1, derived + 7] {
                let e = BoundarySpec::new(ctx(), r, c, 0, 1, sites, log_n, 4, 256, wrong).err().unwrap_or_else(|| panic!("{what}: {wrong} rows was accepted"));
                assert!(e.contains(&format!("declares {wrong} rows")) && e.contains(&format!("give {derived}")), "{what}: {e}");
            }
        }
        // and the one the rank model singled out, stated on its own
        let e = BoundarySpec::new(ctx(), 512, 1024, 0, 1, 2, 14, 4, 256, 37).expect_err("the 37-row boundary was accepted");
        assert!(e.contains("declares 37 rows") && e.contains("give 38"), "the B4 geometry: {e}");
    }

    /// The digest is this module's own, and moves with every parameter —
    /// including the two DERIVED numbers, so a reader of the digest is
    /// reading the geometry that was actually committed.
    #[test]
    fn the_digest_is_its_own_and_moves_with_every_parameter() {
        let base = rung_g_spec();
        let endpoint = super::super::endpoint_g::EndpointSpecG::new(ctx(), 32, 128, 0, 41, 42, 10, 4, 256).expect("the generalised endpoint at the same plane");
        assert_ne!(base.digest(), endpoint.digest(), "the boundary digest collides with the generalised endpoint's");
        let variants = [
            ("context", BoundarySpec::new([7u8; 32], 32, 128, 0, 1, 2, 10, 4, 256, 10)),
            ("plane axes", BoundarySpec::new(ctx(), 64, 64, 0, 1, 2, 10, 4, 256, 10)),
            ("scale", BoundarySpec::new(ctx(), 32, 128, 1, 1, 2, 10, 4, 256, 10)),
            ("boundary index", BoundarySpec::new(ctx(), 32, 128, 0, 2, 2, 10, 4, 256, 10)),
            // STAGE 16 (T-3): FOUR claim sites, not three. Three gives
            // `4 + 6 + 2 = 12` commitment rows, whose column hashes to 96
            // bytes — the length of the `public-statement` absorb — and the
            // completed C-H4 refuses it. Four gives 14, which is clear, and
            // still isolates the site count from every other parameter.
            ("claim sites", BoundarySpec::new(ctx(), 32, 128, 0, 1, 4, 10, 4, 256, 14)),
            ("row width", BoundarySpec::new(ctx(), 32, 128, 0, 1, 2, 9, 4, 256, 14)),
            ("inverse rate", BoundarySpec::new(ctx(), 32, 128, 0, 1, 2, 10, 2, 256, 10)),
            ("opened columns", BoundarySpec::new(ctx(), 32, 128, 0, 1, 2, 10, 4, 128, 10)),
        ];
        for (what, v) in variants {
            assert_ne!(base.digest(), v.unwrap_or_else(|e| panic!("{what}: {e}")).digest(), "{what} does not enter the digest");
        }
    }

    /// Every statement the construction cannot express is refused BY NAME.
    #[test]
    fn the_malformed_statements_are_refused_by_name() {
        let cases: [(&str, Result<BoundarySpec, String>); 7] = [
            ("zero context", BoundarySpec::new([0u8; 32], 32, 128, 0, 1, 2, 10, 4, 256, 10)),
            ("zero claim sites", BoundarySpec::new(ctx(), 32, 128, 0, 1, 0, 10, 4, 256, 6)),
            ("more claim sites than the construction carries", BoundarySpec::new(ctx(), 32, 128, 0, 1, 9, 10, 4, 256, 24)),
            ("an axis that is not a power of two", BoundarySpec::new(ctx(), 24, 96, 0, 1, 2, 10, 4, 256, 10)),
            ("a row width wider than the plane", BoundarySpec::new(ctx(), 32, 128, 0, 1, 2, 13, 4, 256, 7)),
            ("more pads than message positions", BoundarySpec::new(ctx(), 32, 128, 0, 1, 2, 10, 4, 2_048, 10)),
            ("an unsupported scale", BoundarySpec::new(ctx(), 32, 128, 99, 1, 2, 10, 4, 256, 10)),
        ];
        for (what, r) in cases {
            assert!(r.is_err(), "{what} was accepted");
        }
    }

    /// **FINDING A9.4 OF THE CHECK, AS A TEST.** A `sites`-parameterised
    /// module can be asked for a node-shaped column and must refuse: `data = 1`
    /// with one site gives 5 rows and `data = 2` with two sites gives 8, and
    /// C-H4 forbids both.
    #[test]
    fn a_node_shaped_boundary_column_is_refused() {
        for (what, r, c, log_n, sites, rows) in [("five rows", 2usize, 2usize, 2usize, 1usize, 5usize), ("eight rows", 2, 4, 2, 2, 8)] {
            let e = BoundarySpec::new(ctx(), r, c, 0, 1, sites, log_n, 4, 2, rows).err().unwrap_or_else(|| panic!("{what} was accepted"));
            assert!(e.contains("C-H4"), "{what}: the node-shaped-column refusal did not fire: {e}");
        }
    }

    /// The commitment: the plane's words at the front, the reserved rows
    /// declared as the derived geometry says, and the same plane committed
    /// twice giving two different roots (fresh entropy per call).
    #[test]
    fn a_prepared_boundary_commits_the_words_and_declares_its_reserved_rows() {
        let spec = rung_g_spec();
        let ntt = NttTables::new(spec.enc_log());
        let values = plane(spec.len(), 1);
        let mut rng = test_generator(&spec);
        let p = prepare(&spec, &values, &ntt, &mut rng, &HashTag::legacy()).expect("the boundary commits");
        let cm = p.commitment();
        assert_eq!((cm.rows, cm.log_cols), (10, 10), "the committed geometry is not the derived one");
        assert_eq!(p.committed.mask_rows, vec![4, 5, 6, 7], "the two reserved pairs are not where the geometry puts them");
        assert_eq!(p.committed.prox_mask_row, Some(8), "the proximity pair does not start at data + 2*sites");
        assert_eq!(p.data().len(), 10 * 1_024, "the committed matrix is not rows x n");
        assert_eq!(&p.data()[..spec.len()], &values[..], "the plane's words are not at the front");
        assert_eq!(p.committed.zk.q_pad, 256, "the pad count is not the opened-column count");
        let q = prepare(&spec, &values, &ntt, &mut rng, &HashTag::legacy()).expect("a second commitment to the same plane");
        assert_ne!(q.root(), cm.root, "two commitments to one plane share a root");
    }

    /// A prepared boundary may not be opened against another statement.
    #[test]
    fn a_prepared_boundary_refuses_a_different_statement() {
        let spec = rung_g_spec();
        let ntt = NttTables::new(spec.enc_log());
        let mut rng = test_generator(&spec);
        let other = BoundarySpec::new(ctx(), 32, 128, 0, 2, 2, 10, 4, 256, 10).expect("the next boundary of the same run");
        let p = prepare(&spec, &plane(spec.len(), 2), &ntt, &mut rng, &HashTag::legacy()).expect("the owner commits");
        let mut tr = Transcript::new(b"boundary test: a foreign statement");
        let e = match p.into_opening(&other, &[], &mut tr) {
            Ok(_) => panic!("a foreign statement was accepted"),
            Err(e) => e,
        };
        assert!(e.contains("context mismatch"), "{e}");
    }

    /// Wrong-length and noncanonical planes, and an NTT table that does not
    /// cover the encoding domain, are refused before anything is committed.
    #[test]
    fn the_prepare_refusals_fire() {
        let spec = rung_g_spec();
        let ntt = NttTables::new(spec.enc_log());
        let mut rng = test_generator(&spec);
        assert!(prepare(&spec, &plane(spec.len() - 1, 3), &ntt, &mut rng, &HashTag::legacy()).is_err(), "a short plane was committed");
        let mut bad = plane(spec.len(), 3);
        bad[0] = Fp(P);
        assert!(prepare(&spec, &bad, &ntt, &mut rng, &HashTag::legacy()).is_err(), "a noncanonical word was committed");
        let small = NttTables::new(spec.enc_log() - 1);
        let e = match prepare(&spec, &plane(spec.len(), 3), &small, &mut rng, &HashTag::legacy()) {
            Ok(_) => panic!("a short NTT table was accepted"),
            Err(e) => e,
        };
        assert!(e.contains("NttTables cover"), "{e}");
    }

    /// One claim of exactly the shape `argument::build_claim` produces, with
    /// its TRUE value computed from the committed matrix: the data slice over
    /// the whole padded plane plus the reserved pair of site `s` with weights
    /// `(cm, cm * U)`. The three parts share one column key (the point's last
    /// `log_n` coordinates), which is what makes them one group.
    fn true_claim(spec: &BoundarySpec, data: &[Fp], site: usize, point: &[Fp2], cm: Fp2) -> ZClaim {
        let (n, log_n, log_len) = (1usize << spec.log_n(), spec.log_n(), spec.log_len as usize);
        let mask_row = spec.mask_row(site).expect("a declared claim site");
        let tail = point[log_len - log_n..].to_vec();
        let mut parts = vec![ZPart { slice: Slice { offset: 0, log_size: log_len as u32 }, coef: Fp2::ONE, point: point.to_vec() }];
        for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
            parts.push(ZPart { slice: Slice { offset: (mask_row + k) * n, log_size: log_n as u32 }, coef: cm.mul(u), point: tail.clone() });
        }
        // value = sum over parts of coef * MLE(slice)(point), which for these
        // three parts is (row weights) . (columns folded with the shared key)
        let col = eq_table_msb(&tail);
        let fold = |r: usize| (0..n).fold(Fp2::ZERO, |a, c| a.add(col[c].mul_base(data[r * n + c])));
        let eq_r = eq_table_msb(&point[..log_len - log_n]);
        let mut value = eq_r.iter().enumerate().fold(Fp2::ZERO, |a, (i, e)| a.add(e.mul(fold(i))));
        for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
            value = value.add(cm.mul(u).mul(fold(mask_row + k)));
        }
        ZClaim { parts, value }
    }

    fn test_point(spec: &BoundarySpec, seed: u64) -> Vec<Fp2> {
        (0..spec.log_len as u64).map(|i| Fp2::new(Fp::from_i64((7 + seed * 131 + i * 17) as i64), Fp::from_i64((11 + seed * 53 + i * 29) as i64))).collect()
    }

    /// **THE POINT OF THE MODULE.** ONE opening carrying TWO claims at TWO
    /// different points, on disjoint reserved pairs, verifies through
    /// `pcs::verify_zk`; a one-bit change to either claim's value is rejected;
    /// and two claims at the SAME point form one column-weight group and trip
    /// the declared-count refusal instead of being silently batched.
    #[test]
    fn one_opening_carries_two_claims_at_two_points_and_verifies() {
        let spec = rung_g_spec();
        let ntt = NttTables::new(spec.enc_log());
        let mut rng = test_generator(&spec);
        let values = plane(spec.len(), 5);
        let owner = prepare(&spec, &values, &ntt, &mut rng, &HashTag::legacy()).expect("the boundary commits");
        let cm = owner.commitment();
        let (p0, p1) = (test_point(&spec, 1), test_point(&spec, 2));
        let claims = vec![true_claim(&spec, owner.data(), 0, &p0, Fp2::ONE), true_claim(&spec, owner.data(), 1, &p1, Fp2::U)];
        let mut tr = Transcript::new(b"boundary test: one opening, two claims");
        tr.absorb(b"root", &cm.root);
        let mut vtr = Transcript::clone_state(&tr);
        let opening = owner.into_opening(&spec, &claims, &mut tr).expect("the one opening");
        assert_eq!(opening.group_vecs.len(), 2, "two claims at two points did not form two groups");
        let params = spec.params();
        let zko = ZkOpts::standard(&params);
        // the verifier runs the SAME audit before it verifies
        check_opening(&spec, &claims, &vtr).expect("the verifier's own audit of the boundary schedule");
        pcs::verify_zk(&params, &zko, &cm, &claims, &opening, &ntt, &mut vtr).expect("the two-claim boundary opening verifies");
        // a one-bit change to either claim's value is rejected
        for which in 0..2 {
            let mut bad = claims.clone();
            bad[which].value = bad[which].value.add(Fp2::ONE);
            let mut vtr2 = Transcript::new(b"boundary test: one opening, two claims");
            vtr2.absorb(b"root", &cm.root);
            check_opening(&spec, &bad, &vtr2).expect("the audit does not read values");
            assert!(pcs::verify_zk(&params, &zko, &cm, &bad, &opening, &ntt, &mut vtr2).is_err(), "claim {which} with a changed value verified");
        }
    }

    /// Two claims at the SAME point are ONE column-weight group, and the
    /// schedule declares two: `check_opening` refuses before anything is
    /// opened. A completeness failure at about `2^-1792`, never an
    /// unsoundness — but it must be a refusal and not a silent batching.
    #[test]
    fn two_boundary_claims_at_one_point_trip_the_declared_group_count() {
        let spec = rung_g_spec();
        let ntt = NttTables::new(spec.enc_log());
        let mut rng = test_generator(&spec);
        let owner = prepare(&spec, &plane(spec.len(), 6), &ntt, &mut rng, &HashTag::legacy()).expect("the boundary commits");
        let p = test_point(&spec, 3);
        let claims = vec![true_claim(&spec, owner.data(), 0, &p, Fp2::ONE), true_claim(&spec, owner.data(), 1, &p, Fp2::U)];
        let tr = Transcript::new(b"boundary test: one point, two claims");
        let e = check_opening(&spec, &claims, &tr).expect_err("two claims at one point were accepted");
        assert!(e.contains("opening groups, the schedule declares 2"), "{e}");
    }

    /// A shared reserved pair is refused on the OPENING path too, not only in
    /// the hand-built R1 schedule: there is no way to open a boundary that
    /// does not go through `audit_claims`.
    #[test]
    fn a_boundary_opening_on_a_shared_pair_is_refused() {
        let spec = rung_g_spec();
        let ntt = NttTables::new(spec.enc_log());
        let mut rng = test_generator(&spec);
        let owner = prepare(&spec, &plane(spec.len(), 7), &ntt, &mut rng, &HashTag::legacy()).expect("the boundary commits");
        let (p0, p1) = (test_point(&spec, 4), test_point(&spec, 5));
        let claims = vec![true_claim(&spec, owner.data(), 0, &p0, Fp2::ONE), true_claim(&spec, owner.data(), 0, &p1, Fp2::U)];
        let mut tr = Transcript::new(b"boundary test: a shared pair");
        let e = owner.into_opening(&spec, &claims, &mut tr).expect_err("a shared reserved pair was opened");
        assert!(e.contains("a reserved pair is unused or shared between claims"), "{e}");
    }
}
