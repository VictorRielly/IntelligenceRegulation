//! EXPERIMENTAL one-shot equality of two independently hiding committed planes.
//!
//! This is not a private transformer proof, range proof, model-approval registry,
//! or certification of whole-proof zero knowledge. See ZK60_PRIVATE_SEAM.md.
//! The caller supplies the expected roots and a trusted connection description.
//! Merely accepting roots supplied by the prover proves equality of those planes,
//! not that either plane belongs to the intended model execution.
//!
//! Both plane roots and a fresh CFS mask root precede the equality challenge.
//! We sum eq(tau,x)*(A(x)-B(x)), then append a variable extending eq to zero
//! and each private plane to its own precommitted mask. No raw A/B MLE is sent.
//! Prepared planes are consumed once: opening the same hiding commitment in
//! multiple receipts is deliberately not supported by this API.

use crate::field::{Fp, Fp2, P};
use crate::merkle::Digest;
use crate::mle::{eq_point, eq_table_msb, eval_mle_base};
use crate::ntt::NttTables;
use crate::pcs::{
    self, Commitment, CommittedZk, OpeningZk, PcsParams, Slice, ZClaim, ZPart, ZkOpts,
};
use crate::sumcheck::{self, masked_terminal, CfsMask, SumcheckProof};
use crate::transcript::Transcript;
use crate::zk::{self, MaskFunctional, MaskOpening, ZkRng};

const DOMAIN: &[u8] = b"experimental-private-seam/v1";
const MAGIC: &[u8; 8] = b"HLSEAM02"; // D65(1), F12: M's theta powers start at theta^1 (was HLSEAM01)
const LOG_COLS: u32 = 8;
const CHECKS: usize = 256;
const INV_RATE: usize = 8;
const MAX_LOG_LEN: u32 = 12;
const DEGREE: usize = 2;
// Two terminal masks give a full Fp2-valued row; three extra base rows are
// reserved for the separate random proximity combination. This is an explicit
// local mask budget, not a proof that the inherited PCS is universally ZK.
const MASK_ROWS: usize = 5;

/// A bounded, immutable connection description, obtained independently of a
/// candidate proof. The context should authenticate the model/calibration and
/// request. Slots identify the two intended endpoints; scale means value*2^scale.
/// Equality here is field-word equality: range/representation facts are owed by
/// the enclosing arguments, even though their declared scale is transcript-bound.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SeamSpec {
    context: Digest,
    rows: usize,
    cols: usize,
    scale: i32,
    left_slot: u64,
    right_slot: u64,
    log_len: u32,
}

impl SeamSpec {
    pub fn new(
        context: Digest,
        rows: usize,
        cols: usize,
        scale: i32,
        left_slot: u64,
        right_slot: u64,
    ) -> Result<Self, String> {
        if context == [0; 32] || left_slot == right_slot {
            return Err("seam: nonempty context and distinct endpoint slots required".into());
        }
        let len = rows.checked_mul(cols).ok_or("seam: shape overflow")?;
        if !rows.is_power_of_two()
            || !cols.is_power_of_two()
            || !(2..=1usize << MAX_LOG_LEN).contains(&len)
        {
            return Err("seam: supported plane has 2..4096 values and power-of-two axes".into());
        }
        if !(-31..=31).contains(&scale) {
            return Err("seam: unsupported scale".into());
        }
        Ok(Self {
            context,
            rows,
            cols,
            scale,
            left_slot,
            right_slot,
            log_len: len.trailing_zeros(),
        })
    }

    pub fn len(&self) -> usize {
        self.rows * self.cols
    }
    pub fn is_empty(&self) -> bool {
        false
    }
    pub fn shape(&self) -> (usize, usize) {
        (self.rows, self.cols)
    }
    pub fn scale(&self) -> i32 {
        self.scale
    }
    pub fn params(&self) -> PcsParams {
        PcsParams {
            log_cols: LOG_COLS,
            inv_rate: INV_RATE,
            num_col_checks: CHECKS,
        }
    }
    fn data_rows(&self) -> usize {
        self.len().div_ceil(1usize << LOG_COLS)
    }
    fn commitment_rows(&self) -> usize {
        self.data_rows() + MASK_ROWS
    }
    fn mask_spec(&self) -> [(usize, usize); 1] {
        [(self.log_len as usize + 1, DEGREE)]
    }
    pub fn digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(DOMAIN);
        h.update(&self.context);
        for n in [
            self.rows as u64,
            self.cols as u64,
            self.left_slot,
            self.right_slot,
            LOG_COLS as u64,
            INV_RATE as u64,
            CHECKS as u64,
            MASK_ROWS as u64,
        ] {
            h.update(&n.to_le_bytes());
        }
        h.update(&self.scale.to_le_bytes());
        *h.finalize().as_bytes()
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Side {
    Left,
    Right,
}

/// Private prover state. No Clone, data getter, or repeated-opening method.
pub struct PreparedPlane {
    spec_digest: Digest,
    side: Side,
    committed: CommittedZk,
}

impl PreparedPlane {
    pub fn commitment(&self) -> Commitment {
        self.committed.cm.commitment()
    }

    // The fixed FFN IO adapter consumes the owner; it cannot borrow it for a
    // second proof. No secret getter or arbitrary opening enters the public API.
    pub(crate) fn into_ffn_endpoint(self, spec: &SeamSpec) -> Result<CommittedZk, String> {
        if self.spec_digest != spec.digest() || self.side != Side::Right {
            return Err("FFN IO: endpoint context or side mismatch".into());
        }
        Ok(self.committed)
    }
}

fn check_ntt(ntt: &NttTables) -> Result<(), String> {
    // Exact small table size keeps this opt-in prototype bounded and removes
    // caller-selected/malformed public root tables from its verifier boundary.
    if ntt.max_log != zk::MASK_LOG_DOM
        || ntt.roots.len() != 13
        || ntt.inv_roots.len() != 13
        || ntt.twiddle_tables().0.len() != 2048
        || ntt.twiddle_tables().1.len() != 2048
    {
        return Err("seam: canonical NttTables::new(12) required".into());
    }
    for k in 0..=12 {
        let want = Fp::two_adic_root(k);
        if ntt.roots[k as usize] != want || ntt.inv_roots[k as usize] != want.inv() {
            return Err("seam: changed NTT roots".into());
        }
    }
    Ok(())
}

/// Fresh secret entropy on every call. No deterministic seed option is exposed
/// by the deployment-facing prototype API.
pub fn prepare(
    spec: &SeamSpec,
    side: Side,
    values: &[Fp],
    ntt: &NttTables,
) -> Result<PreparedPlane, String> {
    check_ntt(ntt)?;
    if values.len() != spec.len() || values.iter().any(|x| x.0 >= P) {
        return Err("seam: wrong length or noncanonical input words".into());
    }
    let mut rng = ZkRng::from_os(DOMAIN).map_err(|_| "seam: secret entropy unavailable")?;
    prepare_with_rng(spec, side, values, ntt, &mut rng)
}

fn prepare_with_rng(
    spec: &SeamSpec,
    side: Side,
    values: &[Fp],
    ntt: &NttTables,
    rng: &mut ZkRng,
) -> Result<PreparedPlane, String> {
    let n = 1usize << LOG_COLS;
    let first_mask = spec.data_rows();
    let mut data = vec![Fp::ZERO; spec.commitment_rows() * n];
    data[..values.len()].copy_from_slice(values);
    for x in &mut data[first_mask * n..] {
        *x = rng.fp();
    }
    let params = spec.params();
    let mut committed = pcs::commit_zk_owned(&params, data, ntt, &ZkOpts::standard(&params), rng);
    committed.mask_rows = vec![first_mask, first_mask + 1];
    committed.prox_mask_row = Some(first_mask + 2);
    Ok(PreparedPlane {
        spec_digest: spec.digest(),
        side,
        committed,
    })
}

#[derive(Clone, Debug)]
pub struct ExperimentalSeamProof {
    pub spec_digest: Digest,
    pub left: Commitment,
    pub right: Commitment,
    pub mask_root: Digest,
    pub gamma: Fp2,
    pub sc: SumcheckProof,
    pub terminals: [Fp2; 2],
    pub mask_eval: Fp2,
    pub mask_opening: MaskOpening,
    pub left_opening: OpeningZk,
    pub right_opening: OpeningZk,
}

fn same_commitment(a: &Commitment, b: &Commitment) -> bool {
    a.root == b.root && a.rows == b.rows && a.log_cols == b.log_cols
}

fn transcript(spec: &SeamSpec, proof: &ExperimentalSeamProof) -> Transcript {
    let mut tr = Transcript::new(DOMAIN);
    tr.absorb(b"spec", &spec.digest());
    for (label, cm) in [
        (b"left".as_slice(), &proof.left),
        (b"right".as_slice(), &proof.right),
    ] {
        tr.absorb(label, &cm.root);
        tr.absorb_u64(b"rows", cm.rows as u64);
        tr.absorb_u64(b"log-cols", cm.log_cols as u64);
    }
    tr.absorb(b"round-mask", &proof.mask_root);
    tr
}

fn poly(v: &[Fp2]) -> Fp2 {
    v[0].mul(v[1].sub(v[2]))
}

fn terminal_mask(spec: &SeamSpec, cm: &CommittedZk, rho: &[Fp2]) -> Fp2 {
    let log_mask = spec.log_len.min(LOG_COLS) as usize;
    let tail = &rho[rho.len() - log_mask..];
    let n = 1usize << LOG_COLS;
    let len = 1usize << log_mask;
    let first = spec.data_rows() * n;
    eval_mle_base(&cm.data[first..first + len], tail)
        .add(Fp2::U.mul(eval_mle_base(&cm.data[first + n..first + n + len], tail)))
}

fn terminal_claim(spec: &SeamSpec, rho: &[Fp2], e: Fp2, value: Fp2) -> ZClaim {
    let log_mask = spec.log_len.min(LOG_COLS);
    let tail = rho[rho.len() - log_mask as usize..].to_vec();
    let first_mask = spec.data_rows() * (1usize << LOG_COLS);
    ZClaim {
        parts: vec![
            ZPart {
                slice: Slice {
                    offset: 0,
                    log_size: spec.log_len,
                },
                coef: Fp2::ONE.sub(e),
                point: rho.to_vec(),
            },
            ZPart {
                slice: Slice {
                    offset: first_mask,
                    log_size: log_mask,
                },
                coef: e,
                point: tail.clone(),
            },
            ZPart {
                slice: Slice {
                    offset: first_mask + (1usize << LOG_COLS),
                    log_size: log_mask,
                },
                coef: e.mul(Fp2::U),
                point: tail,
            },
        ],
        value,
    }
}

fn functionals(spec: &SeamSpec, rho: &[Fp2], c: Fp2, gamma: Fp2, eval: Fp2) -> Vec<MaskFunctional> {
    vec![
        MaskFunctional {
            terms: vec![(
                0,
                CfsMask::sum_weights(spec.log_len as usize + 1, DEGREE)
                    .iter()
                    .map(|x| x.mul(c))
                    .collect(),
            )],
            value: gamma,
        },
        MaskFunctional {
            terms: vec![(0, CfsMask::eval_weights(rho, DEGREE))],
            value: eval,
        },
    ]
}

fn absorb_terminals(tr: &mut Transcript, proof: &ExperimentalSeamProof) {
    tr.absorb_fp2(b"masked-terminals", &proof.terminals);
    tr.absorb_fp2(b"mask-evaluation", &[proof.mask_eval]);
}

/// Produces a proof attempt, consuming both prepared planes. It deliberately
/// does not compare the secret inputs first: a rebuilt unequal witness reaches
/// the verifier and fails its polynomial identity, not a prover-side assertion.
pub fn prove(
    spec: &SeamSpec,
    left: PreparedPlane,
    right: PreparedPlane,
    ntt: &NttTables,
) -> Result<ExperimentalSeamProof, String> {
    check_ntt(ntt)?;
    if left.spec_digest != spec.digest()
        || right.spec_digest != spec.digest()
        || left.side != Side::Left
        || right.side != Side::Right
    {
        return Err("seam: prepared context or endpoint mismatch".into());
    }
    let mut rng = ZkRng::from_os(DOMAIN).map_err(|_| "seam: secret entropy unavailable")?;
    let mc = zk::mask_commit(&spec.mask_spec(), ntt, &mut rng);
    let mut proof = ExperimentalSeamProof {
        spec_digest: spec.digest(),
        left: left.commitment(),
        right: right.commitment(),
        mask_root: mc.tree.root(),
        gamma: Fp2::ZERO,
        sc: SumcheckProof::default(),
        terminals: [Fp2::ZERO; 2],
        mask_eval: Fp2::ZERO,
        mask_opening: MaskOpening::default(),
        left_opening: OpeningZk::default(),
        right_opening: OpeningZk::default(),
    };
    let mut tr = transcript(spec, &proof);
    let tau = tr.challenge_fp2_vec(spec.log_len as usize);
    let c = tr.challenge_fp2();
    if c.is_zero() {
        return Err("seam: zero masking challenge; use fresh commitments".into());
    }
    proof.gamma = c.mul(mc.masks[0].total());
    tr.absorb_fp2(b"masked-sum", &[proof.gamma]);
    let mut tables = vec![
        eq_table_msb(&tau),
        left.committed.data[..spec.len()]
            .iter()
            .copied()
            .map(Fp2::from_base)
            .collect(),
        right.committed.data[..spec.len()]
            .iter()
            .copied()
            .map(Fp2::from_base)
            .collect(),
    ];
    let (mut rounds, mut rho, finals) =
        zk::masked_prove(&mut tables, DEGREE, poly, &mc.masks[0], c, &mut tr);
    let exts = [
        Fp2::ZERO,
        terminal_mask(spec, &left.committed, &rho),
        terminal_mask(spec, &right.committed, &rho),
    ];
    let e = zk::extension(
        &finals,
        &exts,
        DEGREE,
        poly,
        &mc.masks[0],
        c,
        &rho,
        &mut rounds,
        &mut tr,
    );
    if e.is_zero() {
        return Err("seam: zero terminal mask challenge; use fresh commitments".into());
    }
    proof.terminals = [
        masked_terminal(finals[1], exts[1], e),
        masked_terminal(finals[2], exts[2], e),
    ];
    let lc = terminal_claim(spec, &rho, e, proof.terminals[0]);
    let rc = terminal_claim(spec, &rho, e, proof.terminals[1]);
    rho.push(e);
    proof.mask_eval = mc.masks[0].eval(&rho);
    proof.sc = SumcheckProof { rounds };
    absorb_terminals(&mut tr, &proof);
    tr.absorb(b"opening", b"mask");
    proof.mask_opening = zk::mask_open(
        &mc,
        &functionals(spec, &rho, c, proof.gamma, proof.mask_eval),
        ntt,
        &mut tr,
    );
    tr.absorb(b"opening", b"left");
    proof.left_opening = pcs::open_zk(&left.committed, &[lc], &mut tr);
    tr.absorb(b"opening", b"right");
    proof.right_opening = pcs::open_zk(&right.committed, &[rc], &mut tr);
    Ok(proof)
}

/// Verify against endpoints obtained independently from the enclosing proof's
/// authenticated commitments. This does not independently approve those roots.
pub fn verify(
    spec: &SeamSpec,
    expected_left: &Commitment,
    expected_right: &Commitment,
    proof: &ExperimentalSeamProof,
    ntt: &NttTables,
) -> Result<(), String> {
    check_ntt(ntt)?;
    proof.validate_encoding(spec)?;
    if !same_commitment(expected_left, &proof.left)
        || !same_commitment(expected_right, &proof.right)
    {
        return Err("seam: unexpected endpoint commitment".into());
    }
    let mut tr = transcript(spec, proof);
    let tau = tr.challenge_fp2_vec(spec.log_len as usize);
    let c = tr.challenge_fp2();
    if c.is_zero() {
        return Err("seam: zero masking challenge".into());
    }
    tr.absorb_fp2(b"masked-sum", &[proof.gamma]);
    let (final_value, rho) = sumcheck::verify(
        proof.gamma,
        DEGREE,
        spec.log_len as usize + 1,
        &proof.sc,
        &mut tr,
    )?;
    let e = rho[spec.log_len as usize];
    if e.is_zero() {
        return Err("seam: zero terminal mask challenge".into());
    }
    let body_rho = &rho[..spec.log_len as usize];
    let want = Fp2::ONE
        .sub(e)
        .mul(eq_point(&tau, body_rho))
        .mul(proof.terminals[0].sub(proof.terminals[1]))
        .add(c.mul(proof.mask_eval));
    if final_value != want {
        return Err("seam: terminal equality relation".into());
    }
    absorb_terminals(&mut tr, proof);
    tr.absorb(b"opening", b"mask");
    zk::mask_verify(
        &proof.mask_root,
        &spec.mask_spec(),
        &functionals(spec, &rho, c, proof.gamma, proof.mask_eval),
        &proof.mask_opening,
        ntt,
        &mut tr,
    )?;
    let params = spec.params();
    let opts = ZkOpts::standard(&params);
    tr.absorb(b"opening", b"left");
    pcs::verify_zk(
        &params,
        &opts,
        &proof.left,
        &[terminal_claim(spec, body_rho, e, proof.terminals[0])],
        &proof.left_opening,
        ntt,
        &mut tr,
    )?;
    tr.absorb(b"opening", b"right");
    pcs::verify_zk(
        &params,
        &opts,
        &proof.right,
        &[terminal_claim(spec, body_rho, e, proof.terminals[1])],
        &proof.right_opening,
        ntt,
        &mut tr,
    )
}

fn fp2_canonical(x: &Fp2) -> bool {
    x.c0.0 < P && x.c1.0 < P
}

impl ExperimentalSeamProof {
    fn validate_encoding(&self, spec: &SeamSpec) -> Result<(), String> {
        if self.spec_digest != spec.digest() {
            return Err("seam: statement digest".into());
        }
        for cm in [&self.left, &self.right] {
            if cm.rows != spec.commitment_rows() || cm.log_cols != LOG_COLS {
                return Err("seam: commitment shape".into());
            }
        }
        if ![
            self.gamma,
            self.mask_eval,
            self.terminals[0],
            self.terminals[1],
        ]
        .iter()
        .all(fp2_canonical)
            || self.sc.rounds.len() != spec.log_len as usize + 1
            || self
                .sc
                .rounds
                .iter()
                .any(|r| r.len() != DEGREE + 1 || !r.iter().all(fp2_canonical))
        {
            return Err("seam: invalid scalar or sumcheck encoding".into());
        }
        let mo = &self.mask_opening;
        if mo.q.len() != 1024
            || mo.prox.len() != 1024
            || mo.columns.len() != CHECKS
            || !mo.q.iter().chain(&mo.prox).all(fp2_canonical)
            || mo.columns.iter().any(|(j, c, _, p)| {
                *j >= 4096 || c.len() != 6 || p.len() != 12 || c.iter().any(|v| v.0 >= P)
            })
        {
            return Err("seam: mask opening encoding".into());
        }
        for op in [&self.left_opening, &self.right_opening] {
            if op.group_vecs.len() != 1
                || op.group_vecs[0].len() != 512
                || op.prox_vec.len() != 512
                || op.columns.len() != CHECKS
                || !op.group_vecs[0]
                    .iter()
                    .chain(&op.prox_vec)
                    .all(fp2_canonical)
                || op.columns.iter().any(|(j, c, _, p)| {
                    *j >= 2048
                        || c.len() != spec.commitment_rows()
                        || p.len() != 11
                        || c.iter().any(|v| v.0 >= P)
                })
            {
                return Err("seam: plane opening encoding".into());
            }
        }
        Ok(())
    }

    /// Exact bounded frame; all vector lengths follow from the trusted spec.
    /// No attacker-supplied length is used for an allocation.
    pub fn to_bytes(&self, spec: &SeamSpec) -> Result<Vec<u8>, String> {
        self.validate_encoding(spec)?;
        let mut out = Vec::with_capacity(Self::encoded_len(spec));
        out.extend_from_slice(MAGIC);
        out.extend_from_slice(&self.spec_digest);
        for cm in [&self.left, &self.right] {
            out.extend_from_slice(&cm.root);
            out.extend_from_slice(&(cm.rows as u64).to_le_bytes());
            out.extend_from_slice(&(cm.log_cols as u64).to_le_bytes());
        }
        out.extend_from_slice(&self.mask_root);
        for x in [
            self.gamma,
            self.terminals[0],
            self.terminals[1],
            self.mask_eval,
        ] {
            out.extend_from_slice(&x.to_bytes());
        }
        self.sc.write_bytes(&mut out);
        self.mask_opening.write_bytes(&mut out);
        self.left_opening.write_bytes(&mut out);
        self.right_opening.write_bytes(&mut out);
        debug_assert_eq!(out.len(), Self::encoded_len(spec));
        Ok(out)
    }

    pub fn encoded_len(spec: &SeamSpec) -> usize {
        8 + 32
            + 2 * 48
            + 32
            + 4 * 16
            + (spec.log_len as usize + 1) * 3 * 16
            + 2 * 1024 * 16
            + CHECKS * (8 + 6 * 8 + 32 + 12 * 32)
            + 2 * (2 * 512 * 16 + CHECKS * (8 + spec.commitment_rows() * 8 + 32 + 11 * 32))
    }

    pub fn from_bytes(spec: &SeamSpec, bytes: &[u8]) -> Result<Self, String> {
        if bytes.len() != Self::encoded_len(spec) {
            return Err("seam: wrong frame length".into());
        }
        let mut r = Reader { bytes, pos: 0 };
        if r.take::<8>()? != *MAGIC {
            return Err("seam: wrong frame version".into());
        }
        let spec_digest = r.take()?;
        if spec_digest != spec.digest() {
            return Err("seam: frame statement mismatch".into());
        }
        let left = r.commitment(spec)?;
        let right = r.commitment(spec)?;
        let mask_root = r.take()?;
        let gamma = r.fp2()?;
        let terminals = [r.fp2()?, r.fp2()?];
        let mask_eval = r.fp2()?;
        let mut rounds = Vec::with_capacity(spec.log_len as usize + 1);
        for _ in 0..=spec.log_len {
            rounds.push(r.fp2_vec(3)?);
        }
        let mask_opening = MaskOpening {
            q: r.fp2_vec(1024)?,
            prox: r.fp2_vec(1024)?,
            columns: r.columns(6, 12, 4096)?,
        };
        let left_opening = r.plane_opening(spec)?;
        let right_opening = r.plane_opening(spec)?;
        if r.pos != bytes.len() {
            return Err("seam: trailing bytes".into());
        }
        let proof = Self {
            spec_digest,
            left,
            right,
            mask_root,
            gamma,
            sc: SumcheckProof { rounds },
            terminals,
            mask_eval,
            mask_opening,
            left_opening,
            right_opening,
        };
        proof.validate_encoding(spec)?;
        Ok(proof)
    }
}

struct Reader<'a> {
    bytes: &'a [u8],
    pos: usize,
}
impl Reader<'_> {
    fn take<const N: usize>(&mut self) -> Result<[u8; N], String> {
        let end = self.pos.checked_add(N).ok_or("seam: cursor overflow")?;
        let slice = self
            .bytes
            .get(self.pos..end)
            .ok_or("seam: truncated frame")?;
        self.pos = end;
        Ok(slice.try_into().map_err(|_| "seam: internal frame width")?)
    }
    fn u64(&mut self) -> Result<u64, String> {
        Ok(u64::from_le_bytes(self.take()?))
    }
    fn fp(&mut self) -> Result<Fp, String> {
        let x = self.u64()?;
        if x >= P {
            return Err("seam: noncanonical field word".into());
        }
        Ok(Fp(x))
    }
    fn fp2(&mut self) -> Result<Fp2, String> {
        Ok(Fp2::new(self.fp()?, self.fp()?))
    }
    fn fp2_vec(&mut self, n: usize) -> Result<Vec<Fp2>, String> {
        (0..n).map(|_| self.fp2()).collect()
    }
    fn commitment(&mut self, spec: &SeamSpec) -> Result<Commitment, String> {
        let root = self.take()?;
        let rows = self.u64()?;
        let log_cols = self.u64()?;
        if rows != spec.commitment_rows() as u64 || log_cols != LOG_COLS as u64 {
            return Err("seam: frame commitment shape".into());
        }
        Ok(Commitment {
            root,
            rows: rows as usize,
            log_cols: log_cols as u32,
        })
    }
    fn columns(
        &mut self,
        rows: usize,
        depth: usize,
        bound: usize,
    ) -> Result<Vec<(usize, Vec<Fp>, [u8; 32], Vec<Digest>)>, String> {
        let mut columns = Vec::with_capacity(CHECKS);
        for _ in 0..CHECKS {
            let j = self.u64()?;
            if j >= bound as u64 {
                return Err("seam: column index out of bounds".into());
            }
            let col = (0..rows)
                .map(|_| self.fp())
                .collect::<Result<Vec<_>, _>>()?;
            let salt = self.take()?;
            let path = (0..depth)
                .map(|_| self.take())
                .collect::<Result<Vec<_>, _>>()?;
            columns.push((j as usize, col, salt, path));
        }
        Ok(columns)
    }
    fn plane_opening(&mut self, spec: &SeamSpec) -> Result<OpeningZk, String> {
        Ok(OpeningZk {
            group_vecs: vec![self.fp2_vec(512)?],
            prox_vec: self.fp2_vec(512)?,
            columns: self.columns(spec.commitment_rows(), 11, 2048)?,
        })
    }
}
