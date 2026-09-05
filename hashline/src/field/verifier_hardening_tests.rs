//! Unit-only late lookup challenge fault injection: not a transcript preimage.
//! Complete honest verifier prefixes run before alpha collides with one active
//! table row. The hook and its state do not exist in non-test crate builds.
use super::{batch_inverse2, batch_inverse2_checked, Fp, Fp2, P};
use std::cell::Cell;

thread_local! {
    static COLLISION: Cell<Option<&'static str>> = const { Cell::new(None) };
}

pub(crate) fn lookup_alpha(site: &'static str, alpha: Fp2, table_value: Fp2) -> Fp2 {
    COLLISION.with(|state| {
        if state.get() == Some(site) {
            state.set(None);
            table_value
        } else {
            alpha
        }
    })
}

#[cfg(not(feature = "gpu-cuda"))]
fn with_collision<T>(site: &'static str, run: impl FnOnce() -> T) -> T {
    struct Restore(Option<&'static str>);
    impl Drop for Restore {
        fn drop(&mut self) {
            COLLISION.with(|state| state.set(self.0));
        }
    }
    let old = COLLISION.with(|state| state.replace(Some(site)));
    let _restore = Restore(old);
    assert!(old.is_none(), "nested fault injection is unsupported");
    let result = run();
    assert!(
        COLLISION.with(|state| state.get().is_none()),
        "production site not reached"
    );
    result
}

#[test]
fn hardening_checked_batch_rejects_zero_without_mutation() {
    for length in [1, 2, 9] {
        for zero_at in 0..length {
            let mut values: Vec<_> = (0..length)
                .map(|i| Fp2::new(Fp::new(i as u64 + 3), Fp(P - 1)))
                .collect();
            values[zero_at] = Fp2::ZERO;
            let before = values.clone();
            assert_eq!(
                batch_inverse2_checked(&mut values),
                Err("zero extension-field batch denominator")
            );
            assert_eq!(values, before);
        }
    }
    let mut all_zero = [Fp2::ZERO; 5];
    assert!(batch_inverse2_checked(&mut all_zero).is_err());
    assert_eq!(all_zero, [Fp2::ZERO; 5]);
}

#[test]
fn hardening_checked_batch_matches_legacy_and_individual_inverses() {
    for length in [0, 1, 2, 17, 257] {
        let mut values: Vec<_> = (0..length)
            .map(|i| match i % 4 {
                0 => Fp2::U,
                1 => Fp2::from_base(Fp(P - 1)),
                2 => Fp2::new(Fp(P - 1), Fp(P - 1)),
                _ => Fp2::new(Fp::new(i as u64 + 2), Fp::new(17 * i as u64)),
            })
            .collect();
        let before = values.clone();
        let mut legacy = values.clone();
        batch_inverse2(&mut legacy);
        assert_eq!(batch_inverse2_checked(&mut values), Ok(()));
        assert_eq!(values, legacy);
        for (value, original) in values.iter().zip(before) {
            assert_eq!(*value, original.inv());
            assert_eq!(value.mul(original), Fp2::ONE);
        }
    }
}

#[cfg(not(feature = "gpu-cuda"))]
mod cpu {
    use super::*;
    use crate::attention::verify_attn;
    use crate::causal_oracle::public_synthetic_fixture;
    use crate::layer::{prove_layer, verify_layer, verify_layer_v3, LayerParams, Statement};
    use crate::ntt::NttTables;
    use crate::public_block_oracle::{
        public_block_transcript, verify_public_block, PublicBlockError, PublicBlockOracle,
        PublicBlockProof,
    };
    use crate::transcript::Transcript;
    use std::sync::OnceLock;

    fn public_proof() -> &'static PublicBlockProof {
        static PROOF: OnceLock<PublicBlockProof> = OnceLock::new();
        PROOF.get_or_init(|| {
            assert!(!crate::pcs_compact::selected());
            let (approved, weights, input) = public_synthetic_fixture();
            PublicBlockOracle::new(&approved, weights)
                .unwrap()
                .prove(&input)
                .unwrap()
        })
    }

    #[test]
    fn hardening_attention_production_verifier_refuses_collision_and_preserves_bytes() {
        let (approved, _, _) = public_synthetic_fixture();
        let r = approved.registration();
        let proof = public_proof();
        verify_public_block(&approved, proof).unwrap();
        let wire = crate::public_block_wire::encode_components(proof).unwrap();
        assert_eq!(
            blake3::hash(&wire).to_hex().as_str(),
            "b965cc4ddd05ac2eabc949579ee6482af650b7db89890d5e7cc0ae979cd6df95"
        );
        let mut tr = public_block_transcript(&approved);
        let result = with_collision("attention", || {
            verify_attn(
                &proof.attention,
                &r.attention,
                &r.residual,
                &r.params,
                &mut tr,
            )
        });
        assert_eq!(
            result.err().as_deref(),
            Some("attention LogUp: zero lookup denominator")
        );
        assert_eq!(
            with_collision("attention", || verify_public_block(&approved, proof)),
            Err(PublicBlockError::Verification("attention argument"))
        );
        verify_public_block(&approved, proof).unwrap();
        assert_eq!(
            wire,
            crate::public_block_wire::encode_components(proof).unwrap()
        );
    }

    #[test]
    fn hardening_v3_production_verifier_refuses_collision_and_propagates() {
        let (approved, _, _) = public_synthetic_fixture();
        let r = approved.registration();
        let proof = public_proof();
        let mut tr = public_block_transcript(&approved);
        verify_attn(
            &proof.attention,
            &r.attention,
            &r.residual,
            &r.params,
            &mut tr,
        )
        .unwrap();
        let ntt = NttTables::new(r.params.log_cols + r.params.inv_rate.trailing_zeros());
        let result = with_collision("layer-v3", || {
            verify_layer_v3(&r.ffn, &proof.ffn, &r.params, &ntt, &mut tr)
        });
        assert_eq!(result, Err("FFN v3 LogUp: zero lookup denominator".into()));
        assert_eq!(
            with_collision("layer-v3", || verify_public_block(&approved, proof)),
            Err(PublicBlockError::Verification("FFN argument/openings"))
        );
        verify_public_block(&approved, proof).unwrap();
    }

    #[test]
    fn hardening_v2_production_verifier_refuses_collision_after_honest_prefix() {
        use crate::chain::LayerWitness;
        use crate::export::{D, F};
        // Existing v2 has fixed d768/f2048. T1 and reduced public test PCS
        // parameters bound memory/runtime; this is not a security-strength row.
        let w = LayerWitness {
            l: 0,
            shifts: (0, 0, 0, 0),
            table: [0; 256],
            table_digest: "h1-public-zero-table".into(),
            e_gate: 0,
            e_act: 0,
            x: vec![0; D],
            wg_t: vec![0; D * F],
            wu_t: vec![0; D * F],
            wd_t: vec![0; F * D],
            g8: vec![0; F],
            rg: vec![0; F],
            a8: vec![0; F],
            u8v: vec![0; F],
            ru: vec![0; F],
            h8: vec![0; F],
            rh: vec![0; F],
            z: vec![0; D],
            rd: vec![0; D],
            range_ok: true,
            z_digest: "h1-public-zero-output".into(),
        };
        assert!(!crate::pcs_compact::selected());
        let params = LayerParams {
            log_cols: 8,
            inv_rate: 2,
            num_col_checks: 2,
        };
        let ntt = NttTables::new(9);
        let st = Statement {
            l: w.l,
            t_rows: 1,
            shifts: w.shifts,
            table: w.table,
            table_digest: w.table_digest.clone(),
        };
        let domain = b"zk60-h1-v2-public-refusal-test";
        let proof = prove_layer(&w, 1, &params, &ntt, &mut Transcript::new(domain)).proof;
        let before = proof.to_bytes();
        verify_layer(&st, &proof, &params, &ntt, &mut Transcript::new(domain)).unwrap();
        let result = with_collision("layer-v2", || {
            verify_layer(&st, &proof, &params, &ntt, &mut Transcript::new(domain))
        });
        assert_eq!(result, Err("FFN v2 LogUp: zero lookup denominator".into()));
        verify_layer(&st, &proof, &params, &ntt, &mut Transcript::new(domain)).unwrap();
        assert_eq!(before, proof.to_bytes());
    }
}
