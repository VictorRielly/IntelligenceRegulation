//! **TOKEN I/O ROUND 11: THE CLI'S STAGE SHAPE IS THE LIBRARY'S** (review
//! REVIEW6 TR7-5). TEST CODE ONLY, public synthetic data.
//!
//! `CliSource::seal_check` does not run the prover's CS-3 check: it trusts the
//! CLI's own sealing pass (`seal_chain`), which derives each layer's stage
//! shape with COPIED code. If that copy ever diverged from
//! `TokenRunStatement::stage_shape`, the CLI path would seal CS-3 at the wrong
//! shape without a word. This test pins the two together: at EVERY registered
//! token-I/O run profile, for layers with no own constants, with one own
//! constant (the score shift), with every non-window field own at once, and
//! with the norm tn / ceps own alone (each an admissible neighbour of the
//! base value, probed at that shape), the CLI's derivation equals the
//! library's, and the own layers really do change the shape (non-vacuity).

use super::run::*;
use super::tests::*;
use super::*;
use super::super::run::{RunShape, TOKEN_IO_RUN_PROFILES};
use super::super::trained_statement::{apply_own, cal_field, has_own, OWN_FIELDS};

/// an admissible neighbour (base - 1, else base + 1) of field `i` at `sh`, alone
fn neighbour(sh: &Shape, i: usize) -> Option<i64> {
    let base = sh.norm_calibration();
    let b = cal_field(&base, i);
    [b - 1, b + 1].into_iter().find(|v| {
        let mut o = [None; 11];
        o[i] = Some(*v);
        apply_own(&base, &o).ok().is_some_and(|c| sh.with_layer_calibration(&c).is_ok())
    })
}

#[test]
fn r11_the_clis_stage_shape_is_the_librarys_at_every_registered_profile() {
    let (tn, ceps) = (OWN_FIELDS.iter().position(|f| f.0 == "norm_tn").unwrap(), OWN_FIELDS.iter().position(|f| f.0 == "norm_ceps").unwrap());
    let sh_s = OWN_FIELDS.iter().position(|f| f.0 == "sh_s").unwrap();
    for profile in TOKEN_IO_RUN_PROFILES {
        let l = census_l(profile).max(5);
        let (st0, model0, tables) = census_statement(profile, l);
        let sh = st0.sh().clone();
        // layer 0: none; 1: the score shift alone; 2: every non-window field
        // with an admissible neighbour; 3: tn alone; 4: ceps alone
        let mut recs = model0.layers.clone();
        recs[1].own[sh_s] = Some(neighbour(&sh, sh_s).unwrap_or_else(|| panic!("{profile}: no admissible score shift beside the base")));
        let mut multi = 0usize;
        for i in 0..OWN_FIELDS.len() {
            if i == tn || i == ceps {
                continue;
            }
            if let Some(v) = neighbour(&sh, i) {
                recs[2].own[i] = Some(v);
                multi += 1;
            }
        }
        assert!(multi >= 6, "{profile}: only {multi} fields could be own at layer 2");
        if let Some(v) = neighbour(&sh, tn) {
            recs[3].own[tn] = Some(v);
        }
        if let Some(v) = neighbour(&sh, ceps) {
            recs[4].own[ceps] = Some(v);
        }
        let model = model_with_records(&sh, recs, profile);
        let st = TokenRunStatement::new(
            RunShape::new(sh.clone(), l, profile).expect("the run shape"),
            ctx(),
            model.layers.iter().map(|r| r.block_digest).collect(),
            &model,
            tables,
            st0.tp.bos,
            st0.tp.norm,
            SelectorVariant::PublicRow,
            Tier::R1_MVP,
            ([1u8; 32], [2u8; 32]),
        )
        .unwrap_or_else(|e| panic!("{profile}: the statement with own layers: {e}"));
        let mut own_layers = 0usize;
        for k in 0..l {
            let lib = st.stage_shape(k).unwrap();
            let cli = super::cli::cli_stage_shape(st.sh(), &model.layers[k].own).unwrap_or_else(|e| panic!("{profile} layer {k}: the CLI's derivation refused: {e}"));
            assert_eq!(cli, lib, "REVIEW TR7-5: {profile} layer {k}: the CLI's copied stage-shape derivation is not the library's");
            if has_own(&model.layers[k].own) {
                own_layers += 1;
                assert_ne!(lib, sh, "{profile} layer {k}: an own layer left the shape unchanged (the test would be vacuous)");
            }
        }
        assert!(own_layers >= 3, "{profile}: only {own_layers} own layers were exercised");
        eprintln!("TOKEN-IO ROUND 11 TR7-5 | {profile}: L {l}, {own_layers} own layers (score shift; {multi} fields at once; tn / ceps where admissible): CLI stage shape = library stage shape at every layer");
    }
}
