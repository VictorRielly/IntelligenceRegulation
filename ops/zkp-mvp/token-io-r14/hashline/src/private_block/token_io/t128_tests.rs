//! **TOKEN I/O ROUND 8: THE 128-TOKEN NEXT-TOKEN PROFILES** (TinyLlama-1.1B
//! and Llama-3-8B at T = 128). TEST CODE ONLY, public synthetic data.
//!
//! DESIGN v3's first geometry (T <= 128): the input token endpoint's plane is
//! ONE 256-word row (the public-row variant seals the T ids and zero pad
//! words; variant P's column half bit is not built), so the endpoint, its
//! row width 2^8, rate 1/8 and its one claim site are the T32 profile's;
//! only `T`, `t_pad` and the block shape move. Here, written before the
//! profiles are registered:
//!
//! * the two T128 token-run profiles exist (`load::token_run_profile_of`
//!   maps each trained T128 block shape to its own token-I/O profile, D17),
//!   and each statement's DERIVED whole-run figure at the whole model's `L`
//!   (22 / 32) is at least D27's 95 bits;
//! * completeness on a GENERIC DENSE witness at TinyLlama T128 (dense
//!   synthetic block words, a prompt over the whole vocabulary, generic
//!   tables): proves, verifies, both owners check, the receipt is the counted
//!   length;
//! * a T32 receipt is refused under the T128 statement and a T128 receipt
//!   under the T32 statement, and a T32 block shape is refused under a T128
//!   profile and the reverse.

use super::load::token_run_profile_of;
use super::run::*;
use super::tests::*;
use super::*;
use super::super::run::RunShape;

const POLICY: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 93 };

fn tiny_at(t: usize) -> Shape {
    Shape::tinyllama_trained(t, &r2_calibration(), R2_F_E).expect("the trained TinyLlama shape")
}

fn eight_at(t: usize) -> Shape {
    Shape::llama3_8b_trained(t, &r3_calibration(), R3_F_E).expect("the trained Llama-3-8B shape")
}

/// the generic TinyLlama final norm: tn 10 makes the window exactly 32 bits
/// at width 2,048; the refusal-free `g0 Cn = 127 * 2^tn` (DESIGN C-7)
const TINY_NORM_GENERIC: FinalNorm = FinalNorm { g0: 127, cn: 1024, tn: 10, ceps: 74_429 };

/// a census-style statement (one synthetic block's digest standing for `l`)
fn statement_at(sh: &Shape, profile: &'static str, l: usize, tables: &TokenTables, norm: FinalNorm, bos: u64) -> TokenRunStatement {
    let blk = blocks(sh, 1).remove(0);
    let model = model_of_one(sh, &blk, l, profile);
    let d = blk.digest();
    drop(blk);
    TokenRunStatement::new(RunShape::new(sh.clone(), l, profile).expect("the token run shape"), ctx(), vec![d; l], &model, tables, bos, norm, SelectorVariant::PublicRow, Tier::R1_MVP, ([1u8; 32], [2u8; 32])).expect("the token run statement")
}

/// **ROUND 8, FAILING FIRST: the T128 profiles exist and their whole-run
/// figures reach D27's 95 bits** at the whole model (TinyLlama L = 22,
/// Llama-3-8B L = 32), printed beside the T32 profiles' for comparison. The
/// input endpoint stays one 256-word row at T128 (DESIGN v3's first
/// geometry).
#[test]
fn t128_profiles_exist_and_their_whole_run_floor_reaches_95_bits() {
    let tiny_t = census_tables(super::super::run::RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32);
    let eight_t = census_tables(super::super::run::RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32);
    let mut rows = Vec::new();
    for (name, sh, l, tables, norm, bos) in [
        ("TinyLlama T32", tiny_at(32), 22usize, tiny_t, R2_NORM, 1u64),
        ("TinyLlama T128", tiny_at(128), 22, tiny_t, R2_NORM, 1),
        ("Llama-3-8B T32", eight_at(32), 32, eight_t, R3_NORM_GENERIC, R3_BOS),
        ("Llama-3-8B T128", eight_at(128), 32, eight_t, R3_NORM_GENERIC, R3_BOS),
    ] {
        let profile = token_run_profile_of(&sh).unwrap_or_else(|e| panic!("ROUND 8: {name} has no token-I/O run profile: {e}"));
        let st = statement_at(&sh, profile, l, tables, norm, bos);
        let w = st.whole_run();
        assert_eq!(st.tp.in_ep_words(), 256, "{name}: the input endpoint is not one 256-word row (DESIGN v3's first geometry)");
        assert!(w.floor_bits >= 95, "{name}: the derived whole-run figure is {} bits (2^{:.2}), below D27's 95", w.floor_bits, w.total_log2);
        rows.push(format!("{name} ({profile}, L = {l}): {} openings, column 2^{:.2}, LogUp 2^{:.2}, PCS-field/sumcheck 2^{:.2}, whole run 2^{:.2} -> floor {} bits", w.openings, w.column_log2, w.logup_log2, w.omitted_log2, w.total_log2, w.floor_bits));
    }
    for r in &rows {
        eprintln!("TOKEN-IO ROUND 8 WHOLE-RUN | {r}");
    }
    let (a, b) = (token_run_profile_of(&tiny_at(128)).unwrap(), token_run_profile_of(&eight_at(128)).unwrap());
    assert!(a != token_run_profile_of(&tiny_at(32)).unwrap() && b != token_run_profile_of(&eight_at(32)).unwrap(), "a T128 profile is a T32 profile's string");
}

/// a dense TinyLlama fixture at `T`, `L = 1`, a prompt over the whole
/// vocabulary (BOS first), generic tables
fn tiny_fx(t: usize, seed: u64) -> Fx {
    let sh = tiny_at(t);
    let profile = token_run_profile_of(&sh).unwrap_or_else(|e| panic!("ROUND 8: TinyLlama T{t} has no token-I/O run profile: {e}"));
    let blocks = blocks(&sh, 1);
    let model = model_at(&sh, &blocks, profile);
    let mut s = seed;
    let mut tokens = vec![1u64];
    while tokens.len() < sh.tokens {
        tokens.push(lcg(&mut s) % 32_000);
    }
    Fx { name: if t == 128 { "tinyllama-t128-dense" } else { "tinyllama-t32-dense" }, tables: census_tables(super::super::run::RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32).clone(), sh, blocks, model, tokens, norm: TINY_NORM_GENERIC, bos: 1 }
}

fn statement_of(fx: &Fx, roots: (Digest, Digest)) -> Result<TokenRunStatement, String> {
    let profile = token_run_profile_of(&fx.sh)?;
    TokenRunStatement::new(RunShape::new(fx.sh.clone(), fx.blocks.len(), profile)?, ctx(), fx.blocks.iter().map(|b| b.digest()).collect(), &fx.model, &fx.tables, fx.bos, fx.norm, SelectorVariant::PublicRow, Tier::R1_MVP, roots)
}

/// prove `fx` under its own profile: `(statement, segments, owners' hand-off, next token)`
fn prove_fx(fx: &Fx) -> (TokenRunStatement, Vec<Vec<u8>>, OwnerHandoff, usize, f64) {
    let tp = TokenProfile::new(&fx.sh, &fx.tables, fx.bos, fx.norm, SelectorVariant::PublicRow, Tier::R1_MVP).expect("the token profile");
    let mut pipe = honest_pipeline(&fx.sh, &tp, &fx.tables, &fx.blocks, &fx.tokens).unwrap_or_else(|e| panic!("{}: the honest pipeline refused: {e}", fx.name));
    let want = pipe.out_values.tok;
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag()).unwrap();
    let st = statement_of(fx, roots).expect("the statement");
    let t0 = std::time::Instant::now();
    let mut segs = Vec::new();
    let (_, hand) = prove_token_run(&st, &fx.blocks, &fx.tables, &mut PipelineSource(&mut pipe), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .unwrap_or_else(|e| panic!("{}: prove: {e}", fx.name));
    (st, segs, hand, want, t0.elapsed().as_secs_f64())
}

/// **ROUND 8, FAILING FIRST: completeness at TinyLlama T128 on a generic
/// dense witness, and T32 / T128 are not interchangeable.** A dense
/// TinyLlama T128 run (L = 1) proves, verifies, the receipt is the counted
/// length and both owners check (the decommitted id is the pipeline's); a
/// T32 run of the same recipe likewise; each receipt is REFUSED under the
/// other's statement; and a T32 block shape is refused under the T128
/// profile and the reverse.
#[test]
fn t128_a_dense_tinyllama_run_proves_and_t32_and_t128_are_not_interchangeable() {
    let f128 = tiny_fx(128, 0x7431_3238);
    let f32_ = tiny_fx(32, 0x7433_3200);
    let (p128, p32) = (token_run_profile_of(&f128.sh).unwrap(), token_run_profile_of(&f32_.sh).unwrap());
    // the door: a shape is refused under the other T's profile
    assert!(RunShape::new(f32_.sh.clone(), 1, p128).is_err(), "a T32 block shape was accepted under the T128 profile");
    assert!(RunShape::new(f128.sh.clone(), 1, p32).is_err(), "a T128 block shape was accepted under the T32 profile");
    let (st128, s128, h128, want128, secs128) = prove_fx(&f128);
    let (st32, s32, h32, want32, secs32) = prove_fx(&f32_);
    for (name, st, segs, fx, hand, want) in [("T128", &st128, &s128, &f128, &h128, want128), ("T32", &st32, &s32, &f32_, &h32, want32)] {
        verify_token_run(st, &fx.blocks, &fx.tables, segs, POLICY).unwrap_or_else(|e| panic!("the honest dense {name} run did not verify: {e}"));
        assert_eq!(segs.iter().map(|s| s.len()).collect::<Vec<_>>(), st.segment_lens().unwrap(), "{name}: the segments are not the counted lengths");
        let tok = owner_check_output(st, &hand.output).unwrap_or_else(|e| panic!("{name}: the output owner's check: {e}"));
        assert_eq!(tok, want, "{name}: the decommitted id is not the pipeline's next token");
        owner_check_input(st, &hand.input, &fx.tokens).unwrap_or_else(|e| panic!("{name}: the input owner's check: {e}"));
    }
    let e1 = verify_token_run(&st128, &f128.blocks, &f128.tables, &s32, POLICY).err().expect("A T32 RECEIPT VERIFIED UNDER THE T128 STATEMENT");
    let e2 = verify_token_run(&st32, &f32_.blocks, &f32_.tables, &s128, POLICY).err().expect("A T128 RECEIPT VERIFIED UNDER THE T32 STATEMENT");
    eprintln!(
        "TOKEN-IO ROUND 8 T128 DENSE: TinyLlama T128 L=1 proves in {secs128:.1} s ({} B), T32 in {secs32:.1} s ({} B) [MEASURED, test build, shared box]; both verify, both owners check; T32 receipt under T128: {e1}; T128 receipt under T32: {e2}",
        s128.iter().map(|s| s.len()).sum::<usize>(),
        s32.iter().map(|s| s.len()).sum::<usize>()
    );
}
