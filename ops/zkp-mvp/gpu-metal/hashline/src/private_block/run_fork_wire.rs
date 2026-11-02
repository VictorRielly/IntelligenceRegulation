//! **D55 (2026-11-01): the frames of a "commit, fork, join" run receipt.**
//! Built as an opt-in, unregistered prototype under Victor's D55 ruling;
//! REGISTERED by D60 (2026-11-02) as an opt-in run profile, so production code
//! since D60. No byte of the format moved at registration. Design:
//! `docs/zkmatrix-poc/ZK60_D55_CONCURRENT_RUN_DESIGN.md`; prover and verifier:
//! `run_fork.rs`.
//!
//! A D55 receipt is `L + 2` frames. None of them decodes as a D12a run segment
//! (`HLPRUNS1`) or as a block receipt (`HLPBLOK1`), and a D12a segment decodes
//! as none of them, because each kind has its own magic and its own counted
//! length:
//!
//! * the **head** (`HLPFKHD1`): the run binding, `L`, the `L - 1` internal
//!   boundary roots in boundary order, and the position tag of `S0` (the run
//!   transcript after phase 1);
//! * one **fork frame** per block (`HLPFORK1`): the binding, `L`, `k`, the
//!   position tag at the start of fork `k`, block `k`'s own three roots, its
//!   twenty-three slot proofs and its `M` / `A` / `H` openings (a D12a segment
//!   without its boundary root and without its IO openings), and fork `k`'s end
//!   tag;
//! * the **tail** (`HLPFKTL1`): the binding, `L`, the position tag of `S1` (the
//!   run transcript after the join), the `L - 1` boundary openings (each with
//!   its two claim sites), the external input endpoint's opening, the external
//!   output endpoint's opening, and the run's end tag.
//!
//! Every count is a function of the verifier's own statement; nothing read
//! from a frame controls an allocation or a loop bound. As in D12a (ruling
//! M-6), the binding, indices and position tags are COMPARED, never adopted,
//! and are outside the Fiat-Shamir chain: they localise a fault, the chain
//! is what binds.

use super::{wire_ceiling, Dim, Reader, MASK_CHECKS, MASK_DOM, MASK_PATH, MASK_VEC};
use crate::merkle::Digest;
use crate::pcs::OpeningZk;
use crate::private_block::argument::SlotProof;
use crate::private_block::layout::Layout;
use crate::private_block::shape::Shape;
use crate::sumcheck::SumcheckProof;
use crate::zk::MaskOpening;

const HEAD_MAGIC: &[u8; 8] = b"HLPFKHD1";
const FORK_MAGIC: &[u8; 8] = b"HLPFORK1";
const TAIL_MAGIC: &[u8; 8] = b"HLPFKTL1";

/// One block's sub-proof on its own fork: everything `protocol::prove_core`
/// returns but the IO claims (which the join absorbs and the tail opens).
pub(crate) struct ForkFrame {
    pub a_root: Digest,
    pub h_root: Digest,
    pub mask_root: Digest,
    pub slots: Vec<SlotProof>,
    pub mask_open: MaskOpening,
    pub a_open: OpeningZk,
    pub h_open: OpeningZk,
}

/// The run-level tail: every opening of an IO commitment, made after `S1`.
pub(crate) struct TailFrame {
    /// `B_0 .. B_{L-2}`, each with block `k`'s slot-22 claims then block
    /// `k + 1`'s slot-21 claims (two sites)
    pub boundary_opens: Vec<OpeningZk>,
    /// the external input endpoint, with block 0's slot-21 claims
    pub in_open: OpeningZk,
    /// the external output endpoint, with block `L - 1`'s slot-22 claims
    pub out_open: OpeningZk,
}

fn endpoint_dim(sh: &Shape) -> Dim {
    Dim::new(sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols)
}

fn slots_len(lay: &Layout) -> usize {
    let sl = lay.slots();
    (0..lay.n_slots()).map(|s| (1 + (sl[s].0 + sl[s].1) * (sl[s].2 + 1) + lay.slot_terms(s)) * 16).sum()
}

fn mask_len(lay: &Layout) -> usize {
    2 * MASK_VEC * 16 + MASK_CHECKS * (8 + lay.m_rows() * 8 + 32 + MASK_PATH * 32)
}

/// magic, binding, `L`, the `L - 1` roots, the S0 tag
pub(crate) fn head_len(l: usize) -> usize {
    8 + 32 + 8 + 32 * l.saturating_sub(1) + 32
}

/// magic, binding, `L`, `k`, the start tag, three roots, the slots, the
/// three openings, the end tag
pub(crate) fn fork_len(lay: &Layout) -> usize {
    let sh = lay.shape();
    let bd = Dim::block(lay);
    8 + 32 + 8 + 8 + 32 + 3 * 32 + slots_len(lay) + mask_len(lay) + bd.opening_len(sh.a_groups(), lay.a_rows) + bd.opening_len(sh.h_groups(), lay.h_rows) + 32
}

/// magic, binding, `L`, the S1 tag, the boundary openings, the two endpoint
/// openings, the end tag
pub(crate) fn tail_len(sh: &Shape, l: usize, boundary_rows: usize, sites: usize) -> usize {
    let ed = endpoint_dim(sh);
    8 + 32 + 8 + 32 + l.saturating_sub(1) * ed.opening_len(sites, boundary_rows) + 2 * ed.opening_len(1, sh.endpoint_rows) + 32
}

pub(crate) fn encode_head(binding: &Digest, l: usize, roots: &[Digest], s0_tag: &[u8; 32]) -> Result<Vec<u8>, String> {
    if roots.len() + 1 != l {
        return Err(format!("D55 wire: the head of an {l}-block run carries {} boundary roots, not {}", l - 1, roots.len()));
    }
    let mut out = Vec::with_capacity(head_len(l));
    out.extend_from_slice(HEAD_MAGIC);
    out.extend_from_slice(binding);
    out.extend_from_slice(&(l as u64).to_le_bytes());
    for r in roots {
        out.extend_from_slice(r);
    }
    out.extend_from_slice(s0_tag);
    debug_assert_eq!(out.len(), head_len(l));
    Ok(out)
}

/// the head's roots and its S0 tag (returned for the caller to COMPARE with
/// its own S0, never to adopt)
pub(crate) fn decode_head(bytes: &[u8], binding: &Digest, l: usize) -> Result<(Vec<Digest>, [u8; 32]), String> {
    if bytes.len() != head_len(l) {
        return Err(format!("D55 wire: the head is {} B, the counted length is {}", bytes.len(), head_len(l)));
    }
    let mut r = Reader { bytes, pos: 0 };
    if &r.take::<8>()? != HEAD_MAGIC {
        return Err("D55 wire: the head's frame profile".into());
    }
    if &r.take::<32>()? != binding {
        return Err("D55 wire: the head belongs to another run".into());
    }
    if u64::from_le_bytes(r.take::<8>()?) != l as u64 {
        return Err(format!("D55 wire: the head is not an {l}-block run's"));
    }
    let roots = (0..l.saturating_sub(1)).map(|_| r.take::<32>()).collect::<Result<Vec<Digest>, String>>()?;
    let s0 = r.take::<32>()?;
    if r.pos != bytes.len() {
        return Err("D55 wire: trailing bytes in the head".into());
    }
    Ok((roots, s0))
}

fn validate_fork(f: &ForkFrame, lay: &Layout) -> Result<(), String> {
    let sh = lay.shape();
    let bd = Dim::block(lay);
    if f.slots.len() != lay.n_slots() {
        return Err("D55 wire: slot count".into());
    }
    for (i, sp) in f.slots.iter().enumerate() {
        let (n, e, d) = lay.slots()[i];
        if sp.sc.rounds.len() != n + e || sp.sc.rounds.iter().any(|x| x.len() != d + 1) || sp.terms.len() != lay.slot_terms(i) {
            return Err("D55 wire: argument shape".into());
        }
    }
    let m = &f.mask_open;
    if m.q.len() != MASK_VEC
        || m.prox.len() != MASK_VEC
        || m.columns.len() != MASK_CHECKS
        || m.columns.iter().any(|(j, c, _, p)| *j >= MASK_DOM || c.len() != lay.m_rows() || p.len() != MASK_PATH)
        || !bd.hiding_ok(&f.a_open, sh.a_groups(), lay.a_rows)
        || !bd.hiding_ok(&f.h_open, sh.h_groups(), lay.h_rows)
    {
        return Err("D55 wire: fork opening shape".into());
    }
    Ok(())
}

pub(crate) fn encode_fork(f: &ForkFrame, lay: &Layout, binding: &Digest, l: usize, k: usize, start_tag: &[u8; 32], end_tag: &[u8; 32]) -> Result<Vec<u8>, String> {
    validate_fork(f, lay)?;
    let len = fork_len(lay);
    if len > wire_ceiling(lay.shape()) {
        return Err("D55 wire: fork frame exceeds bound".into());
    }
    let mut out = Vec::with_capacity(len);
    out.extend_from_slice(FORK_MAGIC);
    out.extend_from_slice(binding);
    out.extend_from_slice(&(l as u64).to_le_bytes());
    out.extend_from_slice(&(k as u64).to_le_bytes());
    out.extend_from_slice(start_tag);
    for root in [&f.a_root, &f.h_root, &f.mask_root] {
        out.extend_from_slice(root);
    }
    for sp in &f.slots {
        out.extend_from_slice(&sp.scalar.to_bytes());
        sp.sc.write_bytes(&mut out);
        for t in &sp.terms {
            out.extend_from_slice(&t.to_bytes());
        }
    }
    f.mask_open.write_bytes(&mut out);
    f.a_open.write_bytes(&mut out);
    f.h_open.write_bytes(&mut out);
    out.extend_from_slice(end_tag);
    if out.len() != len {
        return Err(format!("D55 wire: fork frame {k} is {} B, the counted length is {len}", out.len()));
    }
    Ok(out)
}

/// Decode fork frame `k`; the header is compared against the verifier's own
/// binding, `L`, `k` and its own fork-start position, and the end tag is
/// returned to be compared after the fork is replayed.
pub(crate) fn decode_fork(bytes: &[u8], lay: &Layout, binding: &Digest, l: usize, k: usize, start_tag: &[u8; 32]) -> Result<(ForkFrame, [u8; 32]), String> {
    let sh = lay.shape();
    let len = fork_len(lay);
    if bytes.len() != len || len > wire_ceiling(sh) {
        return Err(format!("D55 wire: fork frame {k} is {} B, the counted length is {len}", bytes.len()));
    }
    let bd = Dim::block(lay);
    let mut r = Reader { bytes, pos: 0 };
    if &r.take::<8>()? != FORK_MAGIC {
        return Err("D55 wire: fork frame profile".into());
    }
    if &r.take::<32>()? != binding {
        return Err(format!("D55 wire: fork frame {k} belongs to another run"));
    }
    if u64::from_le_bytes(r.take::<8>()?) != l as u64 || u64::from_le_bytes(r.take::<8>()?) != k as u64 {
        return Err(format!("D55 wire: frame {k} is not the {l}-block run's fork {k}"));
    }
    if &r.take::<32>()? != start_tag {
        return Err(format!("D55 wire: fork frame {k}'s start tag is not the verifier's own fork-{k} position"));
    }
    let (a_root, h_root, mask_root) = (r.take::<32>()?, r.take::<32>()?, r.take::<32>()?);
    let mut slots = Vec::with_capacity(lay.n_slots());
    for s in 0..lay.n_slots() {
        let (n, e, d) = lay.slots()[s];
        let scalar = r.fp2()?;
        let rounds = (0..n + e).map(|_| r.fp2_vec(d + 1)).collect::<Result<Vec<_>, String>>()?;
        let terms = r.fp2_vec(lay.slot_terms(s))?;
        slots.push(SlotProof { scalar, sc: SumcheckProof { rounds }, terms });
    }
    let q = r.fp2_vec(MASK_VEC)?;
    let prox = r.fp2_vec(MASK_VEC)?;
    let columns = (0..MASK_CHECKS).map(|_| r.column(lay.m_rows(), MASK_DOM, MASK_PATH)).collect::<Result<Vec<_>, String>>()?;
    let mask_open = MaskOpening { q, prox, columns };
    let a_open = r.hiding(bd, sh.a_groups(), lay.a_rows)?;
    let h_open = r.hiding(bd, sh.h_groups(), lay.h_rows)?;
    let end_tag = r.take::<32>()?;
    if r.pos != bytes.len() {
        return Err("D55 wire: trailing bytes in a fork frame".into());
    }
    let f = ForkFrame { a_root, h_root, mask_root, slots, mask_open, a_open, h_open };
    validate_fork(&f, lay)?;
    Ok((f, end_tag))
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn encode_tail(t: &TailFrame, sh: &Shape, binding: &Digest, l: usize, boundary_rows: usize, sites: usize, s1_tag: &[u8; 32], end_tag: &[u8; 32]) -> Result<Vec<u8>, String> {
    let ed = endpoint_dim(sh);
    if t.boundary_opens.len() + 1 != l
        || t.boundary_opens.iter().any(|o| !ed.hiding_ok(o, sites, boundary_rows))
        || !ed.hiding_ok(&t.in_open, 1, sh.endpoint_rows)
        || !ed.hiding_ok(&t.out_open, 1, sh.endpoint_rows)
    {
        return Err("D55 wire: tail opening shape".into());
    }
    let len = tail_len(sh, l, boundary_rows, sites);
    if len > wire_ceiling(sh) {
        return Err("D55 wire: tail exceeds bound".into());
    }
    let mut out = Vec::with_capacity(len);
    out.extend_from_slice(TAIL_MAGIC);
    out.extend_from_slice(binding);
    out.extend_from_slice(&(l as u64).to_le_bytes());
    out.extend_from_slice(s1_tag);
    for o in &t.boundary_opens {
        o.write_bytes(&mut out);
    }
    t.in_open.write_bytes(&mut out);
    t.out_open.write_bytes(&mut out);
    out.extend_from_slice(end_tag);
    if out.len() != len {
        return Err(format!("D55 wire: the tail is {} B, the counted length is {len}", out.len()));
    }
    Ok(out)
}

/// Decode the tail; its S1 tag is compared against the verifier's own S1 and
/// its end tag is returned to be compared after the last opening.
pub(crate) fn decode_tail(bytes: &[u8], sh: &Shape, binding: &Digest, l: usize, boundary_rows: usize, sites: usize, s1_tag: &[u8; 32]) -> Result<(TailFrame, [u8; 32]), String> {
    let len = tail_len(sh, l, boundary_rows, sites);
    if bytes.len() != len || len > wire_ceiling(sh) {
        return Err(format!("D55 wire: the tail is {} B, the counted length is {len}", bytes.len()));
    }
    let ed = endpoint_dim(sh);
    let mut r = Reader { bytes, pos: 0 };
    if &r.take::<8>()? != TAIL_MAGIC {
        return Err("D55 wire: tail frame profile".into());
    }
    if &r.take::<32>()? != binding {
        return Err("D55 wire: the tail belongs to another run".into());
    }
    if u64::from_le_bytes(r.take::<8>()?) != l as u64 {
        return Err(format!("D55 wire: the tail is not an {l}-block run's"));
    }
    if &r.take::<32>()? != s1_tag {
        return Err("D55 wire: the tail's S1 tag is not the verifier's own joined transcript position".into());
    }
    let boundary_opens = (0..l.saturating_sub(1)).map(|_| r.hiding(ed, sites, boundary_rows)).collect::<Result<Vec<_>, String>>()?;
    let in_open = r.hiding(ed, 1, sh.endpoint_rows)?;
    let out_open = r.hiding(ed, 1, sh.endpoint_rows)?;
    let end_tag = r.take::<32>()?;
    if r.pos != bytes.len() {
        return Err("D55 wire: trailing bytes in the tail".into());
    }
    Ok((TailFrame { boundary_opens, in_open, out_open }, end_tag))
}
