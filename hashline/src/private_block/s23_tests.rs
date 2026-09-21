//! **STAGE 23 — the two shape refusals of the security owner's disposition on
//! the generic-rank lemma at the shaped layouts**
//! (`docs/zkmatrix-poc/ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md`, rulings
//! **S-1** and **S-3**; the independent check's findings **B-2** and **B-3**).
//!
//! Both rulings name a SHAPE CONDITION that the privacy argument silently
//! depends on and that no code path checked. Neither is reachable by any
//! shape this module builds — and that is the point: each was safe *by
//! construction* rather than *by check*, so a future shape could have taken
//! it away without anything failing at construction time.
//!
//! **Nothing an existing profile proves moves by a byte.** A refusal that
//! fires on no existing shape cannot move a receipt; the first test of each
//! pair asserts exactly that over all five shapes, so a change that made one
//! of them violate its condition would fail here rather than somewhere the
//! bytes are.

use super::layout::{Dom, U8_LEN};
use super::shape::Shape;

/// the five shapes this module builds, and the only ones anything is ever
/// proved, captured or counted at
fn every_shape() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::m125()]
}

/// `clog2`, as `Shape::natural_log` uses it
fn clog2(v: usize) -> usize {
    (usize::BITS - (v - 1).leading_zeros()) as usize
}

// ---------------------------------------------------------------------------
// ITEM 1 — ruling S-1: `log(Dom::Tab) == log_cols` is an invariant
// ---------------------------------------------------------------------------

/// **RULING S-1, the positive half.** The condition the privacy argument's
/// repaired "Fact 1" now carries as a hypothesis holds at every shape that
/// exists, and it holds for the reason the check gives: `Dom::Tab`'s natural
/// log is the fixed `clog2(U8_LEN) = 8`, and the P-3 lift raises it to the row
/// width whenever the row width is above it.
///
/// The consequence — the one that matters to the argument — is asserted in the
/// same breath: the table domain occupies EXACTLY ONE commitment row, so the
/// two zero-sum rows of the helper commitment carry a point-INDEPENDENT weight
/// and the claim of `SC_ZS` on `H_U` cannot write data-dependent coefficients
/// into the non-data block.
#[test]
fn the_lookup_table_domain_sits_at_exactly_the_row_width_at_every_shape() {
    for sh in every_shape() {
        assert_eq!(sh.natural_log(Dom::Tab), clog2(U8_LEN), "{}: Dom::Tab's natural log is not clog2(U8_LEN)", sh.name);
        assert_eq!(
            sh.log(Dom::Tab),
            sh.log_cols,
            "{}: ruling S-1's invariant is broken — the lookup-table domain is not at the row width",
            sh.name
        );
        assert_eq!(sh.rows_of(Dom::Tab), 1, "{}: the lookup-table domain spans more than one commitment row", sh.name);
        // and the lift is what does it: at or above the table's natural size,
        // never below
        assert!(sh.log_cols >= clog2(U8_LEN), "{}: the row width is below the lookup table's natural size", sh.name);
    }
}

/// **RULING S-1, the refusal.** A shape whose row width is BELOW the lookup
/// table's natural size leaves `Dom::Tab` at its natural log, above the row
/// width, so the table spans several rows and the helper commitment's zero-sum
/// rows would carry point-DEPENDENT data weights. Nothing refused it before
/// this stage.
///
/// **It was constructible.** The geometry below is the toy's in every respect
/// but the row width, and before stage 23 `Shape::new` returned it happily:
/// `log_cols = 7` is inside the declared `2..=30` range, the three bilinear
/// domains all sit at or above `2^7` so ruling F-2's P-3 refusal does not
/// fire, and no other construction check looks at `Dom::Tab` at all. What the
/// shape would then have produced is a two-row table domain — the exact
/// configuration the repaired Fact 1 excludes.
#[test]
fn a_row_width_below_the_lookup_tables_natural_size_is_refused_by_name() {
    // the toy's axes, at a row width of 2^7 instead of 2^8
    let e = Shape::new("S-23 probe: the toy at a row width below the table", "hashline-zk-mr1/private-block-s23-probe/1", 32, 16, 16, 2, 8, 1, 7, 8, 9, 7, None, None, None, None)
        .expect_err("a shape whose row width is below the lookup table's natural size was accepted");
    assert!(e.contains("ruling S-1"), "the refusal does not name the ruling: {e}");
    assert!(e.contains("lookup-table domain"), "the refusal does not name the domain: {e}");
    assert!(e.contains("zero-sum rows"), "the refusal does not say what breaks: {e}");
    // the probe really is otherwise well formed: the SAME axes at the toy's
    // own row width construct, so `log_cols` is the only thing the refusal
    // reacts to
    Shape::new("S-23 probe control: the toy's own row width", "hashline-zk-mr1/private-block-s23-probe/1", 32, 16, 16, 2, 8, 1, 8, 8, 9, 7, None, None, None, None)
        .expect("the control at the toy's row width is well formed");
}

/// The refusal is a statement about the ROW WIDTH alone, so it fires at every
/// row width below the table's natural size and at none at or above it. This
/// is the sweep that says the condition is not accidentally tied to the toy's
/// other axes.
#[test]
fn the_lookup_table_refusal_is_exactly_the_row_widths_below_the_tables_log() {
    // The toy's axes: `Dom::Kv` sits at `2^8`, so above the toy's own row
    // width ruling F-2's older refusal takes over (a bilinear domain lifted
    // by P-3). What is asserted per row width is therefore which refusal
    // OWNS it, not that the shape constructs.
    for log_cols in 2..=11usize {
        let r = Shape::new("S-23 sweep", "hashline-zk-mr1/private-block-s23-sweep/1", 32, 16, 16, 2, 8, 1, log_cols, 8, 9, 7, None, None, None, None);
        match (log_cols.cmp(&clog2(U8_LEN)), r) {
            (std::cmp::Ordering::Less, Ok(sh)) => panic!("row width 2^{log_cols} was accepted: Dom::Tab at {}", sh.log(Dom::Tab)),
            (std::cmp::Ordering::Less, Err(e)) => assert!(e.contains("ruling S-1"), "row width 2^{log_cols} is refused by something else: {e}"),
            (std::cmp::Ordering::Equal, r) => {
                let sh = r.unwrap_or_else(|e| panic!("the toy's own row width was refused: {e}"));
                assert_eq!(sh.log(Dom::Tab), sh.log_cols);
            }
            // above the table's log the lift puts `Dom::Tab` on the row width
            // whatever else happens, so ruling S-1 must never be the reason
            (std::cmp::Ordering::Greater, Ok(sh)) => assert_eq!(sh.log(Dom::Tab), sh.log_cols),
            (std::cmp::Ordering::Greater, Err(e)) => {
                assert!(!e.contains("ruling S-1"), "row width 2^{log_cols} is refused by ruling S-1 above the table's log: {e}");
                assert!(e.contains("lifted by P-3"), "row width 2^{log_cols}: the refusal is neither F-2's nor expected: {e}");
            }
        }
    }
}

// ---------------------------------------------------------------------------
// ITEM 2 — ruling S-3: a head dimension at or above the row width
// ---------------------------------------------------------------------------

/// **RULING S-3, the positive half.** `SC_SCORE`'s two private factors end
/// their coordinate lists in two copies of the SAME symbol segment,
/// `rho(lkv .. lkv + log2(head_dim))` (`argument.rs:1141-1158`). A column key
/// is the last `log_cols` entries of a list, so if `log2(head_dim)` reached
/// `log_cols` both keys would be the last `log_cols` entries of that one
/// shared segment — equal by construction on EVERY run, one opening group
/// short, and `check_opening` would refuse every proof at that shape.
///
/// No shape is near it, and this records by how much.
#[test]
fn the_head_dimension_is_below_the_row_width_at_every_shape() {
    for sh in every_shape() {
        assert!(
            sh.head_dim < 1usize << sh.log_cols,
            "{}: ruling S-3's invariant is broken — head dimension {} against a row width of 2^{}",
            sh.name,
            sh.head_dim,
            sh.log_cols
        );
        // the margin, as the check's own table states it (8 / 16 / 8 / 64
        // against 2^8 / 2^10 / 2^10 / 2^14, and the frozen-seam rung's 16
        // against 2^10)
        assert!(clog2(sh.head_dim) + 2 <= sh.log_cols, "{}: the head dimension is within two bits of the row width", sh.name);
    }
}

/// **RULING S-3, the refusal.** The trap, forced.
///
/// **It was constructible**: the geometry below satisfies every construction
/// check that existed before stage 23 — the padded head slots tile the padded
/// width (`d_pad = h_pad * head_dim = 1 * 256`), the head dimension is a power
/// of two, the key-value heads divide both head counts, the row geometry is in
/// range, `Dom::Q`, `Dom::Kv` and `Dom::S` all sit at or above the row width
/// so ruling F-2 does not fire, and `Dom::Tab` sits exactly at it so item 1's
/// new refusal does not fire either. Before this stage `Shape::new` returned
/// it, and every proof taken at it would then have been refused by
/// `check_opening` with a message about opening-group counts — a liveness
/// cliff with no name.
#[test]
fn a_head_dimension_at_or_above_the_row_width_is_refused_by_name() {
    // 16 tokens, width 256, one head of 256 over one key-value head, at a row
    // width of 2^8: `Dom::S = h_pad * t_pad^2 = 2^8` exactly, `Dom::Q` and
    // `Dom::Kv` are `2^12`, `Dom::Tab` is `2^8`.
    let e = Shape::new("S-23 probe: a head dimension at the row width", "hashline-zk-mr1/private-block-s23-probe/1", 16, 256, 256, 1, 256, 1, 8, 4, 9, 21, None, None, None, None)
        .expect_err("a shape whose head dimension reaches the row width was accepted");
    assert!(e.contains("ruling S-3"), "the refusal does not name the ruling: {e}");
    assert!(e.contains("head dimension"), "the refusal does not name the axis: {e}");
    assert!(e.contains("column keys"), "the refusal does not say what collides: {e}");
    // strictly above it too
    let e2 = Shape::new("S-23 probe: a head dimension above the row width", "hashline-zk-mr1/private-block-s23-probe/1", 16, 512, 256, 1, 512, 1, 8, 4, 9, 21, None, None, None, None)
        .expect_err("a shape whose head dimension exceeds the row width was accepted");
    assert!(e2.contains("ruling S-3"), "{e2}");
    // THE CONTROL: the same geometry with the head dimension one bit below the
    // row width constructs, so the refusal reacts to the head dimension and
    // not to anything else about this probe.
    let ok = Shape::new("S-23 probe control: a head dimension below the row width", "hashline-zk-mr1/private-block-s23-probe/1", 16, 128, 256, 1, 128, 1, 8, 4, 9, 21, None, None, None, None)
        .expect("the control one bit below the row width is well formed");
    assert_eq!(ok.head_dim, 128);
    assert!(ok.head_dim < 1usize << ok.log_cols);
}

/// **WHAT `SC_PV` AND THE BILINEAR-FREE SLOTS DO INSTEAD** — ruling S-3 asks
/// for the analogue to be checked, and the answer is that there is none, for
/// reasons already enforced elsewhere. Recorded as assertions so that a change
/// to either reason fails here.
///
/// * **`SC_PV`.** Its two private factors are `A_P` on `Dom::S` and `A_V8` on
///   `Dom::Kv` (`argument.rs:1162-1186`). They share the source-token segment
///   `tp = rho(lkv .. lkv + log2(t_pad))`, which is the LAST segment of `A_P`'s
///   list and the FIRST of `A_V8`'s. `A_V8`'s list continues with
///   `rho(0 .. lkv)` and ends in `fixed(r_i)`, a segment of
///   `log2(head_dim) >= 1` entries that is a transcript point and not a
///   sumcheck symbol. So however large `t_pad` grows against the row width,
///   the two keys end in different KINDS of coordinate and cannot coincide by
///   construction. The guard that keeps it that way is the existing T-8
///   refusal `head_dim >= 2`: at `head_dim = 1` the `fixed(r_i)` segment would
///   be empty and `A_V8`'s list would end in the shared `tp` exactly as
///   `A_P`'s does.
/// * **The feed-forward slots** `SC_GMM`, `SC_UMM`, `SC_DMM` and the
///   projection `SC_WO` raise ONE `A` claim each, so the two-private-factor
///   trap cannot arise in them at all. `SC_GMM` and `SC_UMM` do share a plane
///   and a fixed row point (the disposition's S-5 inventory), but they are
///   different SLOTS with different `rho` symbols and one claim apiece.
#[test]
fn the_source_token_axis_and_the_feed_forward_slots_carry_no_such_trap() {
    for sh in every_shape() {
        // `A_V8`'s list ends in `log2(head_dim)` fixed entries, and T-8 keeps
        // that segment non-empty
        assert!(sh.head_dim >= 2, "{}: the T-8 refusal no longer keeps A_V8's fixed tail non-empty", sh.name);
        assert!(clog2(sh.head_dim) >= 1, "{}: A_V8's fixed tail is empty", sh.name);
        // and the source-token axis may sit anywhere against the row width
        // without that changing: at 125M `t_pad = 2^9` against `2^14`, at the
        // rungs `2^5` against `2^10`, at the toy `2^5` against `2^8`
        let lt = clog2(sh.t_pad);
        assert!(lt <= sh.log_cols, "{}: the source-token axis has grown past the row width; re-read the SC_PV argument", sh.name);
    }
    // the count that makes the feed-forward half of the statement checkable
    // from the source rather than from memory: the module's own `define` is
    // the authority, and `scripts/zk60_private_block_layout_model.py`'s
    // `claim_sites` already pins one `A` claim for each of the three matmul
    // slots and for `SC_WO` at every shape.
    let sh = Shape::rung_g();
    let (sites, _) = sh.claim_sites();
    for (slot, name) in [(super::layout::SC_GMM, "SC_GMM"), (super::layout::SC_UMM, "SC_UMM"), (super::layout::SC_DMM, "SC_DMM"), (super::layout::SC_WO, "SC_WO")] {
        assert_eq!(sites[slot], 1, "{name} raises more than one A claim; the two-private-factor trap may now reach it");
    }
    for (slot, name) in [(super::layout::SC_SCORE, "SC_SCORE"), (super::layout::SC_PV, "SC_PV")] {
        assert_eq!(sites[slot], 2, "{name} is no longer the two-private-factor slot the rulings reason about");
    }
}
