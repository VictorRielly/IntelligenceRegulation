//! **STEP S11b: the GENERALISED hidden endpoint.**
//!
//! `private_seam.rs` is FROZEN and is not edited by this lane. It is also at
//! exactly its ceiling: `SeamSpec::new` accepts a plane of at most
//! `2^MAX_LOG_LEN = 4,096` words, and the padded rung endpoint `(32, 128)` is
//! 4,096 words. The 125M endpoint plane is `512 x 1024 = 2^19` words, so the
//! frozen seam cannot carry it at all.
//!
//! This module is the same construction built ADDITIVELY beside it: a hiding
//! PCS commitment to the padded endpoint plane, laid out as `data` rows of
//! plane words followed by the five reserved random rows — the terminal pair
//! at `(data, data + 1)`, the proximity row at `data + 2`, two further random
//! rows — with one opening, the owner consumed by value, and fresh OS
//! entropy per call. Every parameter the frozen seam fixes as a module
//! constant (`LOG_COLS = 8`, `INV_RATE = 8`, `CHECKS = 256`, `MAX_LOG_LEN =
//! 12`) is taken here from the [`super::shape::Shape`] instead.
//!
//! **WHAT IS NOT CLAIMED.** This is an experimental component. It commits a
//! plane and lets one claim be opened against it; it is not a proof that the
//! enclosing block is zero knowledge, and no privacy statement is made from
//! it. The joint-view, rank and CFS tools are owed again at every new shape
//! and none has been run on a receipt carrying this endpoint.
//!
//! **Nothing private of `private_seam.rs` is used.** Two small things are
//! duplicated with citations: the five-row mask budget
//! (`private_seam.rs:36`, already duplicated once as
//! `protocol::ENDPOINT_MASK_ROWS`) and the shape of its `check_ntt`
//! (`private_seam.rs:164-182`), generalised from "exactly `NttTables::new(12)`"
//! to "a canonical table that covers this endpoint's encoding domain".

use crate::field::{Fp, P};
use crate::merkle::Digest;
use crate::ntt::NttTables;
use crate::pcs::{self, Commitment, CommittedZk, PcsParams, ZkOpts};
use crate::zk::ZkRng;
use zkp_core::hashtag::HashTag;

/// Its OWN domain label, which is why `EndpointSpecG::digest()` can never
/// collide with `SeamSpec::digest()`: the two hashers absorb a different
/// string first. 42 bytes, so neither of the two forbidden domain-label
/// lengths of code condition C-H4' (28 and 35 — the frozen seam's own
/// "experimental-private-seam/v1" is 28 — written here WITHOUT its byte-string
/// prefix on purpose, because the C-H4' scan reads this file's source and a
/// citation in a comment is indistinguishable from a label).
const DOMAIN: &[u8] = b"hashline/private-block/general-endpoint/v1";

/// `private_seam.rs:36`'s mask budget, unchanged and for the same reason:
/// two terminal masks give a full `Fp2`-valued row and three further base
/// rows are reserved for the separate random proximity combination. This is
/// an explicit local mask budget, not a proof that the inherited PCS is
/// universally zero knowledge.
pub(crate) const MASK_ROWS: usize = 5;

/// A bounded prototype ceiling, not a soundness bound: it exists so that a
/// malformed statement cannot ask for an unbounded allocation. `2^24` words
/// is 32x the 125M endpoint plane (`2^19`).
const MAX_LOG_LEN: u32 = 24;

/// The generalised endpoint statement, beside the frozen [`crate::private_seam::SeamSpec`]
/// and never in place of it. Built only through [`EndpointSpecG::new`], which
/// refuses by name every geometry the construction cannot express.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct EndpointSpecG {
    context: Digest,
    /// the endpoint plane's padded axes (`t_pad`, `d_pad` of the shape)
    rows: usize,
    cols: usize,
    scale: i32,
    left_slot: u64,
    right_slot: u64,
    log_len: u32,
    /// the COMMITMENT's row width, `sh.endpoint_log_n`
    log_n: u32,
    /// `sh.endpoint_inv_rate`
    inv_rate: usize,
    /// the opened columns, which is also the pad count, `sh.opened_cols`
    checks: usize,
}

impl EndpointSpecG {
    /// The statement under the LEGACY hash rule. Every check is
    /// [`EndpointSpecG::new_with_tag`]'s; the rule decides one of them, the
    /// C-H4 length guard, and the legacy rule is the one that imposes it
    /// (the fail-closed direction, for a caller with no tag to offer).
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new(context: Digest, rows: usize, cols: usize, scale: i32, left_slot: u64, right_slot: u64, log_n: usize, inv_rate: usize, checks: usize) -> Result<Self, String> {
        Self::new_with_tag(context, rows, cols, scale, left_slot, right_slot, log_n, inv_rate, checks, &HashTag::legacy())
    }

    /// **STAGE 18, ruling T-3 AS AMENDED.** The same constructor, told which
    /// hash rule the profile this statement belongs to runs under. The ONLY
    /// thing the tag changes is the C-H4 length guard at the bottom: it is
    /// imposed under the legacy rule and not under a tag, because on a tagged
    /// profile the four hash domains are four different members of the BLAKE3
    /// family and a coincidence of their input lengths separates nothing
    /// (`hash_domain::imposed_shape_free`). Every other refusal — the
    /// context, the slots, the plane's axes, the row geometry, the pad count
    /// — is unchanged and fires under both rules.
    ///
    /// The tag is a PUBLIC function of the profile string and is never an
    /// input a caller chooses: the one production call site is
    /// `IoSpec::endpoints_g`, which passes the tag `Shape::hash_tag` derived
    /// for it (ruling T-7).
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new_with_tag(context: Digest, rows: usize, cols: usize, scale: i32, left_slot: u64, right_slot: u64, log_n: usize, inv_rate: usize, checks: usize, tag: &HashTag) -> Result<Self, String> {
        if context == [0; 32] || left_slot == right_slot {
            return Err("general endpoint: nonempty context and distinct endpoint slots required".into());
        }
        let len = rows.checked_mul(cols).ok_or("general endpoint: shape overflow")?;
        if !rows.is_power_of_two() || !cols.is_power_of_two() || !(2..=1usize << MAX_LOG_LEN).contains(&len) {
            return Err(format!("general endpoint: supported plane has 2..2^{MAX_LOG_LEN} values and power-of-two axes"));
        }
        if !(-31..=31).contains(&scale) {
            return Err("general endpoint: unsupported scale".into());
        }
        let log_len = len.trailing_zeros();
        // The row width may not exceed the plane (there must be at least one
        // data row) and the encoding domain is kept inside the field's
        // two-adic range with room to spare.
        if !(2..=log_len as usize).contains(&log_n) || !inv_rate.is_power_of_two() || inv_rate < 2 || log_n + inv_rate.trailing_zeros() as usize > 30 {
            return Err("general endpoint: the row geometry is out of range".into());
        }
        // The pad count IS the number of opened columns (`ZkOpts::standard`),
        // and a row cannot carry more pads than it has message positions.
        if checks == 0 || checks > 1usize << log_n {
            return Err("general endpoint: the pad count must be nonzero and at most the row width".into());
        }
        let spec = Self { context, rows, cols, scale, left_slot, right_slot, log_len, log_n: log_n as u32, inv_rate, checks };
        // C-H4: a commitment whose column hashes to 40 or 64 bytes could be
        // confused with a Merkle node or a refill block. STAGE 18 (T-3
        // amended): imposed under the LEGACY rule only.
        super::layout::no_commitment_has_a_node_shaped_column_under(&[("general endpoint", spec.commitment_rows())], tag)?;
        Ok(spec)
    }

    pub(crate) fn len(&self) -> usize {
        self.rows * self.cols
    }
    pub(crate) fn params(&self) -> PcsParams {
        PcsParams { log_cols: self.log_n, inv_rate: self.inv_rate, num_col_checks: self.checks }
    }
    /// how many rows of this commitment carry plane words
    pub(crate) fn data_rows(&self) -> usize {
        self.len() >> self.log_n
    }
    /// data rows plus the five reserved mask rows
    pub(crate) fn commitment_rows(&self) -> usize {
        self.data_rows() + MASK_ROWS
    }
    /// `log2` of the encoded row length — the NTT size this endpoint needs
    pub(crate) fn enc_log(&self) -> u32 {
        self.log_n + self.inv_rate.trailing_zeros()
    }
    /// The statement digest. The field list is the frozen seam's
    /// (`private_seam.rs:115-133`) with its four module constants replaced by
    /// this spec's values, under this module's OWN domain.
    pub(crate) fn digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(DOMAIN);
        h.update(&self.context);
        for n in [self.rows as u64, self.cols as u64, self.left_slot, self.right_slot, self.log_n as u64, self.inv_rate as u64, self.checks as u64, MASK_ROWS as u64] {
            h.update(&n.to_le_bytes());
        }
        h.update(&self.scale.to_le_bytes());
        *h.finalize().as_bytes()
    }
}

/// Private prover state. No `Clone`, no data getter, no repeated-opening
/// method — the frozen seam's discipline (`private_seam.rs:142-162`).
pub(crate) struct PreparedPlaneG {
    spec_digest: Digest,
    committed: CommittedZk,
}

impl PreparedPlaneG {
    pub(crate) fn commitment(&self) -> Commitment {
        self.committed.cm.commitment()
    }
    /// Consumes the owner: it cannot be borrowed for a second proof.
    pub(crate) fn into_endpoint(self, spec: &EndpointSpecG) -> Result<CommittedZk, String> {
        if self.spec_digest != spec.digest() {
            return Err("general endpoint: prepared context mismatch".into());
        }
        Ok(self.committed)
    }
}

/// The generalised form of `private_seam.rs:164-182`. The frozen seam pins
/// EXACTLY `NttTables::new(12)`, which is what makes it unusable at a wider
/// shape; here the requirement is that the table is canonical and covers this
/// endpoint's encoding domain. Caller-selected or malformed root tables are
/// still refused.
fn check_ntt(spec: &EndpointSpecG, ntt: &NttTables) -> Result<(), String> {
    let need = spec.enc_log();
    if ntt.max_log < need {
        return Err(format!("general endpoint: NttTables cover 2^{} but this endpoint encodes over 2^{need}", ntt.max_log));
    }
    let half = (1usize << ntt.max_log) / 2;
    if ntt.roots.len() != ntt.max_log as usize + 1 || ntt.inv_roots.len() != ntt.max_log as usize + 1 || ntt.twiddle_tables().0.len() != half.max(1) || ntt.twiddle_tables().1.len() != half.max(1) {
        return Err("general endpoint: malformed NttTables".into());
    }
    for k in 0..=ntt.max_log {
        let want = Fp::two_adic_root(k);
        if ntt.roots[k as usize] != want || ntt.inv_roots[k as usize] != want.inv() {
            return Err("general endpoint: changed NTT roots".into());
        }
    }
    Ok(())
}

/// Fresh secret entropy on every call; no deterministic seed is exposed.
///
/// **STAGE 17, ruling T-1.** `tag` is the PROFILE's hash tag, carried in from
/// the caller's own `IoSpec` (which derives it from the shape). An endpoint
/// is one of the profile's five commitments, so it hashes under the same rule
/// as the rest of them — a profile is wholly legacy or wholly tagged, never a
/// mixture (ruling T-2 as amended).
pub(crate) fn prepare(spec: &EndpointSpecG, values: &[Fp], ntt: &NttTables, tag: &HashTag) -> Result<PreparedPlaneG, String> {
    check_ntt(spec, ntt)?;
    if values.len() != spec.len() || values.iter().any(|x| x.0 >= P) {
        return Err("general endpoint: wrong length or noncanonical input words".into());
    }
    let mut rng = ZkRng::from_os(DOMAIN).map_err(|_| "general endpoint: secret entropy unavailable")?;
    // the frozen seam's `prepare_with_rng` layout, word for word
    // (`private_seam.rs:200-223`), at this spec's parameters
    let n = 1usize << spec.log_n;
    let first_mask = spec.data_rows();
    let mut data = vec![Fp::ZERO; spec.commitment_rows() * n];
    data[..values.len()].copy_from_slice(values);
    for x in &mut data[first_mask * n..] {
        *x = rng.fp();
    }
    let params = spec.params();
    let mut committed = pcs::commit_zk_owned_tagged(&params, data, ntt, &ZkOpts::standard(&params), &mut rng, tag);
    committed.mask_rows = vec![first_mask, first_mask + 1];
    committed.prox_mask_row = Some(first_mask + 2);
    Ok(PreparedPlaneG { spec_digest: spec.digest(), committed })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::private_seam::{self, SeamSpec, Side};

    fn ctx() -> Digest {
        *blake3::hash(b"S11b: the generalised endpoint's own test context").as_bytes()
    }

    /// The RUNG-G endpoint statement: the padded `(32, 128)` plane at the
    /// rung's own row width (`log_cols 10`) and rate (4).
    fn rung_g_spec() -> EndpointSpecG {
        EndpointSpecG::new(ctx(), 32, 128, 0, 41, 42, 10, 4, 256).expect("the rung-G endpoint statement is well formed")
    }

    fn plane(len: usize, seed: u64) -> Vec<Fp> {
        (0..len).map(|i| Fp::from_i64(((i as u64).wrapping_mul(2_654_435_761).wrapping_add(seed) % 4_096) as i64 - 2_048)).collect()
    }

    /// **THE REASON THIS MODULE EXISTS, as a test.** The frozen seam refuses a
    /// plane of `2^13` words by name, so nothing at 125M (`2^19`) can use it.
    #[test]
    fn the_frozen_seam_refuses_a_plane_past_its_ceiling_and_this_module_does_not() {
        let e = SeamSpec::new(ctx(), 64, 128, 0, 41, 42).expect_err("8,192 words must be refused by the frozen seam");
        assert!(e.contains("2..4096"), "the frozen seam's refusal changed: {e}");
        // exactly at the ceiling it still works, which is what the rung rides
        assert!(SeamSpec::new(ctx(), 32, 128, 0, 41, 42).is_ok(), "the padded rung plane is the frozen seam's ceiling");
        // and 125M's plane is refused too
        assert!(SeamSpec::new(ctx(), 512, 1024, 0, 41, 42).is_err(), "125M's endpoint plane must be refused by the frozen seam");
        // the generalised endpoint accepts all three.
        //
        // **STAGE 16 (ruling T-3).** The row width is 2^11 here and was 2^10.
        // At 2^10 the 8,192-word plane gives `8 + MASK_ROWS = 13` commitment
        // rows, whose column hashes to 104 bytes — the length of a degree-2
        // `sc-round` absorb — and the COMPLETED C-H4 refuses it. That is a
        // real refusal of a real geometry, not a test artefact, so it is
        // asserted here rather than dodged silently; the three planes are
        // then accepted at a width that clears the set.
        let e = EndpointSpecG::new(ctx(), 64, 128, 0, 41, 42, 10, 4, 256).expect_err("a 13-row endpoint must be refused by the completed C-H4");
        assert!(e.contains("C-H4") && e.contains("104 bytes") && e.contains("sc-round"), "the completed C-H4 refusal: {e}");
        for (r, c) in [(64usize, 128usize), (32, 128), (512, 1024)] {
            EndpointSpecG::new(ctx(), r, c, 0, 41, 42, 11, 4, 256).unwrap_or_else(|e| panic!("({r}, {c}): {e}"));
        }
    }

    /// The geometry the design note declares, at both new shapes.
    #[test]
    fn the_declared_geometry_is_what_the_spec_derives() {
        let s = rung_g_spec();
        assert_eq!((s.len(), s.data_rows(), s.commitment_rows(), s.enc_log()), (4_096, 4, 9, 12), "the rung-G endpoint geometry");
        let m = EndpointSpecG::new(ctx(), 512, 1024, 0, 41, 42, 14, 4, 256).expect("the 125M endpoint statement");
        assert_eq!((m.len(), m.data_rows(), m.commitment_rows(), m.enc_log()), (524_288, 32, 37, 16), "the 125M endpoint geometry");
        // and the frozen seam's own numbers, for the record: the padded rung
        // plane at LOG_COLS 8 is 16 data rows and 21 commitment rows
        let f = EndpointSpecG::new(ctx(), 32, 128, 0, 41, 42, 8, 8, 256).expect("the frozen parameters as a generalised spec");
        assert_eq!((f.data_rows(), f.commitment_rows()), (16, 21), "the frozen seam's geometry, reproduced");
    }

    /// The digest separates this construction from the frozen one, and
    /// separates every parameter from every other.
    #[test]
    fn the_digest_is_its_own_and_moves_with_every_parameter() {
        let base = rung_g_spec();
        let seam = SeamSpec::new(ctx(), 32, 128, 0, 41, 42).expect("the frozen spec at the same plane");
        assert_ne!(base.digest(), seam.digest(), "the generalised digest collides with the frozen seam's");
        let variants = [
            ("context", EndpointSpecG::new([7u8; 32], 32, 128, 0, 41, 42, 10, 4, 256)),
            ("plane rows", EndpointSpecG::new(ctx(), 64, 64, 0, 41, 42, 10, 4, 256)),
            ("scale", EndpointSpecG::new(ctx(), 32, 128, 1, 41, 42, 10, 4, 256)),
            ("slots", EndpointSpecG::new(ctx(), 32, 128, 0, 43, 44, 10, 4, 256)),
            // STAGE 16 (T-3): the neighbouring width is 2^11 and was 2^9,
            // because 2^9 gives 13 commitment rows and the completed C-H4
            // refuses that column length (104 bytes, a degree-2 `sc-round`).
            ("row width", EndpointSpecG::new(ctx(), 32, 128, 0, 41, 42, 11, 4, 256)),
            ("inverse rate", EndpointSpecG::new(ctx(), 32, 128, 0, 41, 42, 10, 2, 256)),
            ("opened columns", EndpointSpecG::new(ctx(), 32, 128, 0, 41, 42, 10, 4, 128)),
        ];
        for (what, v) in variants {
            assert_ne!(base.digest(), v.unwrap_or_else(|e| panic!("{what}: {e}")).digest(), "{what} does not enter the digest");
        }
    }

    /// Every geometry the construction cannot express is refused BY NAME.
    #[test]
    fn the_malformed_statements_are_refused_by_name() {
        let cases: [(&str, Result<EndpointSpecG, String>); 7] = [
            ("zero context", EndpointSpecG::new([0u8; 32], 32, 128, 0, 41, 42, 10, 4, 256)),
            ("equal slots", EndpointSpecG::new(ctx(), 32, 128, 0, 41, 41, 10, 4, 256)),
            ("an axis that is not a power of two", EndpointSpecG::new(ctx(), 24, 96, 0, 41, 42, 10, 4, 256)),
            ("a row width wider than the plane", EndpointSpecG::new(ctx(), 32, 128, 0, 41, 42, 13, 4, 256)),
            ("an inverse rate that is not a power of two", EndpointSpecG::new(ctx(), 32, 128, 0, 41, 42, 10, 3, 256)),
            ("more pads than message positions", EndpointSpecG::new(ctx(), 32, 128, 0, 41, 42, 10, 4, 2_048)),
            ("an unsupported scale", EndpointSpecG::new(ctx(), 32, 128, 0, 41, 42, 32, 4, 256)),
        ];
        for (what, r) in cases {
            assert!(r.is_err(), "{what} was accepted");
        }
    }

    /// **CORRECTED BY STAGE 16 (ruling T-3): the second sentence below is no
    /// longer true.** C-H4 forbids more than 5 and 8 rows now — the whole set
    /// of hash-input lengths on the profile's path — and the reachable row
    /// counts of this construction are `2^k + MASK_ROWS`, i.e. 6, 7, 9, 13,
    /// 21, 37, ... Of those, **13 is refused at every profile** (its column
    /// is 104 bytes, a degree-2 `sc-round` absorb), **6 is refused at the
    /// 125M profile** and **7 at the frozen-seam rung** (their transcript
    /// constructors). So the refusal is reachable, and two tests above now
    /// exercise it on real geometries. The assertions below are unchanged and
    /// still hold: 5 and 8 in particular remain unreachable.
    ///
    /// **FINDING S11b-F2, as a test.** The C-H4 refusal (no commitment whose
    /// column hashes to 40 or 64 bytes, i.e. 5 or 8 rows) is checked by
    /// `EndpointSpecG::new` and can NEVER fire for this construction: the
    /// padded plane and the row width are both powers of two, so the data
    /// row count is a power of two, and `data + MASK_ROWS` is one of 6, 7,
    /// 9, 13, 21, 37, ... — never 5 (which would need 0 data rows) and never
    /// 8 (which would need 3). The check is kept as a guard against a future
    /// change to `MASK_ROWS` or to the plane rule, and the refusal itself is
    /// exercised here directly so that it cannot rot unnoticed.
    #[test]
    fn a_node_shaped_endpoint_column_is_unreachable_and_still_refused() {
        for log_len in 2..=24u32 {
            for log_n in 2..=log_len as usize {
                let rows = (1usize << (log_len as usize - log_n)) + MASK_ROWS;
                assert!(rows != 5 && rows != 8, "a {log_len}-word plane at row width 2^{log_n} gives {rows} rows");
            }
        }
        let e = super::super::layout::no_commitment_has_a_node_shaped_column(&[("general endpoint", 8)]).expect_err("8 rows must be refused");
        assert!(e.contains("C-H4"), "the node-shaped-column refusal did not fire: {e}");
    }

    /// The commitment: the plane's words at the front, the five mask rows
    /// declared exactly as the frozen seam declares them, and the same plane
    /// committed twice gives two different roots (fresh entropy per call).
    #[test]
    fn a_prepared_plane_commits_the_words_and_declares_the_frozen_mask_rows() {
        let spec = rung_g_spec();
        let ntt = NttTables::new(spec.enc_log());
        let values = plane(spec.len(), 1);
        let p = prepare(&spec, &values, &ntt, &HashTag::legacy()).expect("the generalised endpoint commits");
        let cm = p.commitment();
        assert_eq!((cm.rows, cm.log_cols), (9, 10), "the committed geometry is not the declared one");
        let committed = p.into_endpoint(&spec).expect("the owner opens against its own statement");
        assert_eq!(committed.mask_rows, vec![4, 5], "the terminal pair is not at (data, data + 1)");
        assert_eq!(committed.prox_mask_row, Some(6), "the proximity row is not at data + 2");
        assert_eq!(committed.data.len(), 9 * 1_024, "the committed matrix is not rows x n");
        assert_eq!(&committed.data[..spec.len()], &values[..], "the plane's words are not at the front");
        assert_eq!(committed.zk.q_pad, 256, "the pad count is not the opened-column count");
        // fresh OS entropy per call: the same plane, two different roots
        let q = prepare(&spec, &values, &ntt, &HashTag::legacy()).expect("a second commitment to the same plane");
        assert_ne!(q.commitment().root, cm.root, "two commitments to one plane share a root");
    }

    /// A tampered plane gives a different root — the binding this endpoint
    /// contributes, at the commitment level.
    #[test]
    fn one_changed_word_changes_the_root() {
        let spec = rung_g_spec();
        let ntt = NttTables::new(spec.enc_log());
        let values = plane(spec.len(), 1);
        // the same secret stream cannot be replayed, so the honest root is
        // compared against itself through the data, not through two calls
        let honest = prepare(&spec, &values, &ntt, &HashTag::legacy()).expect("honest").into_endpoint(&spec).expect("owner");
        let mut tampered = values.clone();
        tampered[7] = tampered[7].add(Fp::ONE);
        let other = prepare(&spec, &tampered, &ntt, &HashTag::legacy()).expect("tampered").into_endpoint(&spec).expect("owner");
        assert_ne!(honest.data[7], other.data[7], "the tampered word is not in the committed matrix");
        assert_ne!(honest.cm.commitment().root, other.cm.commitment().root, "a changed plane word left the root alone");
    }

    /// A prepared plane may not be opened against another statement: a
    /// different context, scale, slot pair or set of PCS parameters is a
    /// different digest, and `into_endpoint` refuses it.
    #[test]
    fn a_prepared_plane_refuses_a_different_statement() {
        let spec = rung_g_spec();
        let ntt = NttTables::new(spec.enc_log());
        let values = plane(spec.len(), 2);
        for (what, other) in [
            ("the output endpoint's slots", EndpointSpecG::new(ctx(), 32, 128, 0, 43, 44, 10, 4, 256)),
            ("another context", EndpointSpecG::new([3u8; 32], 32, 128, 0, 41, 42, 10, 4, 256)),
            // STAGE 16 (T-3): 2^11, not 2^9 — see the note in
            // `the_digest_is_its_own_and_moves_with_every_parameter`
            ("another row width", EndpointSpecG::new(ctx(), 32, 128, 0, 41, 42, 11, 4, 256)),
        ] {
            let p = prepare(&spec, &values, &ntt, &HashTag::legacy()).expect("the owner commits");
            // neither `CommittedZk` nor `PreparedPlaneG` is `Debug` (no data
            // getter of any kind), so the refusals are matched, not unwrapped
            let e = match p.into_endpoint(&other.expect("a well-formed other statement")) {
                Ok(_) => panic!("{what}: a foreign statement was accepted"),
                Err(e) => e,
            };
            assert!(e.contains("context mismatch"), "{what}: {e}");
        }
    }

    /// Wrong-length and noncanonical inputs, and an NTT table that does not
    /// cover the encoding domain, are refused before anything is committed.
    #[test]
    fn the_prepare_refusals_fire() {
        let spec = rung_g_spec();
        let ntt = NttTables::new(spec.enc_log());
        assert!(prepare(&spec, &plane(spec.len() - 1, 3), &ntt, &HashTag::legacy()).is_err(), "a short plane was committed");
        let mut bad = plane(spec.len(), 3);
        bad[0] = Fp(P);
        assert!(prepare(&spec, &bad, &ntt, &HashTag::legacy()).is_err(), "a noncanonical word was committed");
        let small = NttTables::new(spec.enc_log() - 1);
        let e = match prepare(&spec, &plane(spec.len(), 3), &small, &HashTag::legacy()) {
            Ok(_) => panic!("a short NTT table was accepted"),
            Err(e) => e,
        };
        assert!(e.contains("NttTables cover"), "{e}");
        // and the frozen seam's own refusal, for contrast: it demands the
        // canonical 2^12 table exactly, so a WIDER table is refused too
        let seam = SeamSpec::new(ctx(), 32, 128, 0, 41, 42).expect("the frozen spec");
        let wide = NttTables::new(16);
        assert!(private_seam::prepare(&seam, Side::Right, &plane(4_096, 4), &wide).is_err(), "the frozen seam accepted a 2^16 table");
        assert!(prepare(&spec, &plane(spec.len(), 4), &wide, &HashTag::legacy()).is_ok(), "the generalised endpoint refused a wider canonical table");
    }
}
