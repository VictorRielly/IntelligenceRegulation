//! [ZK60 encode conformance] The drop-in test for the vectors of
//! `docs/zkmatrix-poc/ZK60_ENCODE_CONFORMANCE_VECTORS.md`, produced by a THIRD
//! implementation (`results/zk60_encode_vectors/encode_ref.py`) that is
//! validated against the DEFINITION — a direct O(n^2) evaluation of the
//! polynomial at the roots of unity, and a closed-form Lagrange basis at the
//! production widths — not against a transcription of this crate.
//!
//! **This test is the first Rust-side test of the harness.** Until it runs,
//! the vectors are an independent prediction of what `encode_row_zk` produces;
//! after it runs, they are a pinned contract that any device NTT must meet.
//!
//! Drop in as `zkp-core/src/pcs/encode_conformance_tests.rs` and add
//! `#[cfg(test)] mod encode_conformance_tests;` beside `mod backend;` in
//! `zkp-core/src/pcs.rs`. `sha2` is already a dependency of this crate
//! (`zkp-core/Cargo.toml`), so nothing new is pulled in.

use super::*;
use crate::field::P;
use crate::ntt::NttTables;
use sha2::{Digest as _, Sha256};

// ---------------------------------------------------------------------------
// The vectors' PRNG: SplitMix64, specified in the memo so that the inputs can
// be regenerated in any language. It is NOT the prover's `ZkRng`: these are
// fixed synthetic fixtures, and the pad DRAW is not part of this contract.
// ---------------------------------------------------------------------------

struct SplitMix64(u64);

impl SplitMix64 {
    fn new(seed: u64) -> SplitMix64 {
        SplitMix64(seed)
    }
    fn next_u64(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    fn fp(&mut self) -> Fp {
        Fp::new(self.next_u64() % P)
    }
    fn fp_vec(&mut self, n: usize) -> Vec<Fp> {
        (0..n).map(|_| self.fp()).collect()
    }
}

fn seed_for(log_n: u32, inv_rate: usize, role: u64) -> u64 {
    (0x5A5A_5A5Au64 << 32) | ((log_n as u64) << 16) | ((inv_rate as u64) << 8) | role
}

fn sha256_hex(row: &[Fp]) -> String {
    let mut h = Sha256::new();
    for v in row {
        h.update(v.to_bytes());
    }
    h.finalize().iter().map(|b| format!("{b:02x}")).collect()
}

/// The five message/pad kinds, in the order the vectors file lists them.
const KIND_NAMES: [&str; 5] = ["zero", "zero_msg_seeded_pad", "delta0", "delta_last", "seeded"];

fn inputs(kind: usize, log_n: u32, inv_rate: usize, q: usize) -> (Vec<Fp>, Vec<Fp>) {
    let n = 1usize << log_n;
    match kind {
        0 => (vec![Fp::ZERO; n], vec![Fp::ZERO; q]),
        1 => (vec![Fp::ZERO; n], SplitMix64::new(seed_for(log_n, inv_rate, 2)).fp_vec(q)),
        2 => {
            let mut m = vec![Fp::ZERO; n];
            m[0] = Fp::ONE;
            (m, vec![Fp::ZERO; q])
        }
        3 => {
            let mut m = vec![Fp::ZERO; n];
            m[n - 1] = Fp::ONE;
            (m, vec![Fp::ZERO; q])
        }
        _ => (
            SplitMix64::new(seed_for(log_n, inv_rate, 1)).fp_vec(n),
            SplitMix64::new(seed_for(log_n, inv_rate, 2)).fp_vec(q),
        ),
    }
}

/// `(log_n, inv_rate, Q, the five encoded-row SHA-256s in `KIND_NAMES` order)`.
/// 2^8/rate 8 is the toy and the frozen seam; 2^10/rate 4 the rungs;
/// 2^14/rate 4 rung-W14 and 125M. The first three widths are definitional.
#[allow(clippy::type_complexity)]
const PROFILES: &[(u32, usize, usize, [&str; 5])] = &[
    (3, 4, 4, [
        "5341e6b2646979a70e57653007a1f310169421ec9bdd9f1a5648f75ade005af1",
        "99f1f74e60240b0adf5e8ebc78b6286ed1945d4562c71696a5c6bbac40af88fe",
        "f58fae79ec4f1c800a5f1f85af09d0dfde316a3cbec42ad33daa7aadb938226b",
        "359e2ccb1fd3979e59a83f532d68e93c6d46686459b6e0fd9b42a763f2714378",
        "ae6ff4f286d0821a33eb0a4a51da60e4677f2a248734ca9935f13a3b8d2901ec",
    ]),
    (4, 4, 8, [
        "076a27c79e5ace2a3d47f9dd2e83e4ff6ea8872b3c2218f66c92b89b55f36560",
        "c1fe92e7e2f490be445806acdfe432cc86415d14d3c1479bb41c8bb11d3ee244",
        "62576d7a3aecba7154e698142d62a4e3cc065d22e1553c3fad7b78ac340a18e9",
        "4bd8d9b21bdee39e8ad85d3275243a3bce50714f5d5c780634ccf78f91bec9a9",
        "abdc63baa7193eef169aeb28fa428dda73292ddf2b310794395b4f28722fbdf7",
    ]),
    (6, 4, 32, [
        "e5a00aa9991ac8a5ee3109844d84a55583bd20572ad3ffcd42792f3c36b183ad",
        "1ad55ef90c11c871a73a49a14df45019e8f87893dc29cbaef9fe562dac8b2f4f",
        "21f9ee42e9567b32f61239e12d7402aa2bcdd1b56b4a60ce41d1644bf1b48f2e",
        "f7dc54e71171f8986e2042357c0442eb6f391153ec30c4fceff803400031041e",
        "36b00bbf2c8ffa5e222993e8cd8dc86be05f3cd955e07a58b84e1c499f022142",
    ]),
    (8, 4, 256, [
        "9f1dcbc35c350d6027f98be0f5c8b43b42ca52b7604459c0c42be3aa88913d47",
        "e12602065c6fc4afe04074d3ec0219284a11955d8a83ed9e63f93a80ea05fe8b",
        "0664aa45965f0b601ea2660dc2efe6cefc391cad59629451a2c2b4e3cbc80b72",
        "27214b6c51d8e742c63ec57414156eb41c1ec7be278b6dfbbcec0f14b10f3c7f",
        "70b22dff4b214ced7dc194783a721c705e76613abe3a9b1ad8c68a481c02e568",
    ]),
    (8, 8, 256, [
        "4fe7b59af6de3b665b67788cc2f99892ab827efae3a467342b3bb4e3bc8e5bfe",
        "50dfde443ed404e537cb07fee949d438bd07be7d6cc2784ef955afd50d78394a",
        "a16a54b8383285a9a76b5a94536d7dbc6475604c12d26ab16cad061d6234a5b9",
        "6c0721d2b0a5e68c1fe990eba8e74941f3067d0888d34ba101e18c67f77292c2",
        "a9bc48623fe6e9b28e97770180eef5f6b926efdcdfc175a94a9b5446e847f92e",
    ]),
    (10, 4, 256, [
        "c35020473aed1b4642cd726cad727b63fff2824ad68cedd7ffb73c7cbd890479",
        "70e6389c73652494e8d04e3984fe8953e788569694a7bfdf2ad502f8f72a5074",
        "bddd26c474a25ab21e413c8cfa3817f44349f3fb9a98c213004789ec616d57f4",
        "aa2f7061e1cd15aa06b4d0ff9fd973fb1a73ef622c1660d38be70cd0b3c3e098",
        "de6980b6d74c1024f3ee9dadeb5bc02be843379c3cbf8018251a1880b3b18c0a",
    ]),
    (14, 4, 256, [
        "07854d2fef297a06ba81685e660c332de36d5d18d546927d30daad6d7fda1541",
        "429e9b5db72a44c4d573f863a06e5d788934b21a3507225464e88c88dc106052",
        "6dbf41b067a4d01fe0a913eec0bd6c8986afc090ac7e7490fb0b193f38137baa",
        "79f2366701d3871ec33fa7829b5d0d94cb4068c85c6f9e32f712cc35e7d9024b",
        "bf144694ffbd31733ee32a4de9f5c1f8bd50a1f4b568dc95dec5c595ab9733c1",
    ]),
];

/// The NEGATIVE CONTROLS: a digest here is a NAMED BUG, not a random mismatch.
/// `(digest, the implementation that produces it)`, for the `seeded` vector at
/// 2^14 -> 2^16, at 2^6 -> 2^8 and at 2^3 -> 2^5.
const CONTROL_DIGESTS: &[(&str, &str)] = &[
    // 2^14 -> 2^16 (rung-W14 / 125M)
    ("43c5b6d188567aebcae48fbb137290deed3a3423e1c1eacc8983f153dfce05a0",
     "w14: (a) decimation-in-frequency -- your final NTT returns BIT-REVERSED output"),
    ("6abd622c06b9c742d7f0ad07ebfa49c6194c192ac7d3638b39ae1525cf2bafa6",
     "w14: (b) the conjugate two-adic root -- forward and inverse twiddles swapped"),
    ("630836315e82f365f48e55de9bcc3267a047941cec0b079ff6850b6288385afd",
     "w14: (c) an off-by-one twiddle stride -- tw[k*(max_n/len) + 1]"),
    ("de18aaaf03ec8167ed1234de92b484ea4768228734978615ee0f43d231621b73",
     "w14: (d) the inverse NTT scaled by 1/nn instead of 1/n"),
    ("5c9b895cc6bbda95d410e6b2154591dd1430cd2a4d6c15b203a4818e3f4fb147",
     "w14: (bonus) the shared max-size twiddle table indexed as a per-size table, tw[k]"),
    // 2^6 -> 2^8
    ("975a2b6eb272c06d84719faade776e555962816d9029178eaffaaad25226682f",
     "w6: (a) decimation-in-frequency (bit-reversed output)"),
    ("b509d53ba1d7c22e7525f30defdb2c4b6532b488efcb321e1daa6e4e51d20806",
     "w6: (b) the conjugate two-adic root"),
    ("1df89df5af5f4e0b3a110d109b72d4b6260ce79ab1d088fc583f79c332538327",
     "w6: (c) an off-by-one twiddle stride"),
    ("04c150e35b0faecc01af4b7b1e8af280c46c56ca589bc850b6f2c688cd4bfced",
     "w6: (d) the inverse NTT scaled by 1/nn"),
    ("5ffb585b01b46729508d0abc190b5affce4f6d4f552dc56095da2109d50f8cc8",
     "w6: (bonus) tw[k] instead of tw[k*(max_n/len)]"),
    // 2^3 -> 2^5
    ("5ada7fa09a9272e8b86a2a779dd9b0894a2965a6c94c56859b4ecb1e5633719b",
     "w3: (a) decimation-in-frequency (bit-reversed output)"),
    ("a13c24bf7eefe7138ec0618d3ceeb195f5fb7b5df9fa22923052accd7f40a349",
     "w3: (b) the conjugate two-adic root"),
    ("f41a39821ba0c89e0c1a5f6af106fd5585f87ac19c8561c31dbb9075724f5495",
     "w3: (c) an off-by-one twiddle stride"),
    ("a8dc9a8c515839ce561c709c1839a61a4a801c6f47eac9de7f94bc53db9b56a7",
     "w3: (d) the inverse NTT scaled by 1/nn"),
    ("f50360b21ff79bedf887e6c18cd5032f4c64be3fa1d4c354f8335e70513e9798",
     "w3: (bonus) tw[k] instead of tw[k*(max_n/len)]"),
];

fn diagnose(digest: &str) -> String {
    for (d, why) in CONTROL_DIGESTS {
        if *d == digest {
            return format!(" -- THIS IS A KNOWN NEGATIVE CONTROL: {why}");
        }
    }
    String::new()
}

/// `(Q, the `seeded` vector's correct digest)` for a profile in `PROFILES`.
/// [added by the lane that first compiled this file] Two of the tests below
/// need the profile row by name rather than by position.
fn seeded_profile(log_n: u32, inv_rate: usize) -> (usize, &'static str) {
    for (l, r, q, digests) in PROFILES {
        if *l == log_n && *r == inv_rate {
            return (*q, digests[4]); // 4 = `seeded`
        }
    }
    panic!("no profile w{log_n}r{inv_rate} in PROFILES");
}

fn encode(log_n: u32, inv_rate: usize, msg: &[Fp], pad: &[Fp]) -> Vec<Fp> {
    let n = 1usize << log_n;
    let nn = n * inv_rate;
    let ntt = NttTables::new(nn.trailing_zeros());
    let pows = coset_powers(Fp::new(7), nn); // ZkOpts::standard's coset
    let mut out = vec![Fp::ZERO; nn];
    encode_row_zk(&ntt, msg, pad, &pows, &mut out);
    out
}

/// THE CONFORMANCE TEST. 35 vectors over 7 (width, rate) profiles.
#[test]
fn encode_row_zk_matches_the_third_implementations_conformance_vectors() {
    for (log_n, inv_rate, q, digests) in PROFILES {
        for (kind, want) in digests.iter().enumerate() {
            let (msg, pad) = inputs(kind, *log_n, *inv_rate, *q);
            let got = sha256_hex(&encode(*log_n, *inv_rate, &msg, &pad));
            assert_eq!(
                got.as_str(), *want,
                "vector w{log_n}r{inv_rate}-{}{}",
                KIND_NAMES[kind],
                diagnose(&got)
            );
        }
    }
}

/// R2a must meet the same full-row third-implementation contract, not only
/// agree with the old row encoder at the verifier's sampled columns.
#[test]
fn initialize_once_buffer_matches_all_35_independent_full_row_vectors() {
    for (log_n, inv_rate, q, digests) in PROFILES {
        let n = 1usize << log_n;
        let nn = n * inv_rate;
        let ntt = NttTables::new(nn.trailing_zeros());
        let pows = coset_powers(Fp::new(7), nn);
        for (kind, want) in digests.iter().enumerate() {
            let (msg, pad) = inputs(kind, *log_n, *inv_rate, *q);
            let out = super::encode_buffer::encode_rows(&ntt, &msg, n, &pad, *q, &pows);
            assert_eq!(sha256_hex(&out), *want, "R2a w{log_n}r{inv_rate} kind {kind}");
        }
    }
}

/// The inputs are pinned separately, so a PRNG disagreement is never reported
/// as an encode disagreement.
#[test]
fn the_conformance_inputs_are_the_ones_the_vectors_were_built_from() {
    // (log_n, inv_rate, Q, sha256(msg), sha256(pad)) for the `seeded` vector.
    let cases: &[(u32, usize, usize, &str, &str)] = &[
        (3, 4, 4,
         "e7bd29cbe88d69bed28d44a920ae975b5a1dc5b6ac631f4a1226c78130ed8885",
         "2f897fe5e06d30cbc8ca36b803ffcc6e962c6a0a06cbad7b90007c753b30fa65"),
        (8, 8, 256,
         "0b91544648a1c2c01ef1f1476a0e98fed0764d1b45b55e13ff474384f877ef13",
         "4a13cad453d750a2bd132012615415032c5be76914f37e8a9bb3b1d1f358116e"),
        (10, 4, 256,
         "b1dc9087eb68e96a1df8db6417ce5fc14d60d88d42c816c4024447210478764f",
         "97b537cd5009cdc2495b73f80235057f54a6bab147d31272aeb06591adbdab6c"),
        (14, 4, 256,
         "053da6d19072c3db3b190028a36c64bb750f5a3afe0303d978c7499736e7f1f4",
         "9e0a4b753a0930cf7bd121513d79b9dea7cc34adb01591fd77c4d0c4a3424086"),
    ];
    for (log_n, inv_rate, q, wm, wp) in cases {
        let (msg, pad) = inputs(4, *log_n, *inv_rate, *q); // 4 = `seeded`
        assert_eq!(sha256_hex(&msg).as_str(), *wm, "message of w{log_n}r{inv_rate}-seeded");
        assert_eq!(sha256_hex(&pad).as_str(), *wp, "pads of w{log_n}r{inv_rate}-seeded");
    }
}

/// The smallest vector in full, so a failure is debuggable by eye: message
/// 2^3, rate 4, Q = 4, the `seeded` kind.
#[test]
fn the_smallest_conformance_vector_matches_entry_by_entry() {
    let (msg, pad) = inputs(4, 3, 4, 4);
    assert_eq!(
        msg.iter().map(|v| v.0).collect::<Vec<u64>>(),
        vec![
            13165580579705175456, 18210882911321197463, 11251177064544540234,
            3854080798751542840, 6950373697262493184, 1653300282129755443,
            11279950891899390549, 6180868182034427927,
        ],
        "the message the PRNG must produce"
    );
    assert_eq!(
        pad.iter().map(|v| v.0).collect::<Vec<u64>>(),
        vec![
            12958305900188953204, 12707502957647800691, 9025898841439606855,
            5612407619606071436,
        ],
        "the pads the PRNG must produce"
    );
    let got: Vec<u64> = encode(3, 4, &msg, &pad).iter().map(|v| v.0).collect();
    assert_eq!(
        got,
        vec![
            17001233229391541759, 9525882795350743510, 10685261833338387181,
            11883848538122421164, 12135637215749084494, 14487658604129027219,
            13956248148305193365, 728841911929532220, 17594403611113277726,
            13323381216430728279, 11952886996136697578, 15462680855146825542,
            6833670393533424550, 10031315790080029380, 17362465940490424173,
            1030025762374198429, 17562784682548004046, 3730969806722800446,
            6172047982576767076, 5693909200286625114, 1859001937226429571,
            15037052584695150825, 9672972197962433396, 1881927289116817088,
            18129160555214809121, 8351872777809323709, 15801800976565837046,
            11592350932643550688, 7886103473328438184, 13884731224812854872,
            11408272210597226156, 4027269886183593974,
        ],
        "the full encoded row at 2^3 -> 2^5"
    );
}

/// [added by the lane that first compiled this file, 2026-09-22] The five
/// NAMED BUGS are distinct from the truth in Rust too.
///
/// The controls are WRONG ENCODES, so they are not executed here — nothing in
/// this crate implements them. What is checked is the property that makes a
/// passing run mean something: the digest the real `encode_row_zk` produces is
/// the CORRECT one *and* is none of the five control digests at that width, so
/// no device that earns a named bug can also pass the conformance test. The
/// count assertion keeps the control table from silently losing an entry.
#[test]
fn the_named_negative_controls_are_all_distinct_from_the_real_encode() {
    // The three widths the control table covers.
    for (log_n, inv_rate) in [(3u32, 4usize), (6, 4), (14, 4)] {
        let (q, correct) = seeded_profile(log_n, inv_rate);
        let (msg, pad) = inputs(4, log_n, inv_rate, q);
        let got = sha256_hex(&encode(log_n, inv_rate, &msg, &pad));
        assert_eq!(got.as_str(), correct, "w{log_n}r{inv_rate}-seeded");
        let prefix = format!("w{log_n}:");
        let mut named = 0;
        for (digest, why) in CONTROL_DIGESTS {
            if !why.starts_with(&prefix) {
                continue;
            }
            named += 1;
            assert_ne!(
                got.as_str(),
                *digest,
                "the real encode reproduces a NAMED BUG at w{log_n}: {why}"
            );
        }
        assert_eq!(named, 5, "all five named bugs must be listed at w{log_n}");
    }
}

/// [added by the lane that first compiled this file, 2026-09-22] The ORDERING
/// control, the one the running protocol is least able to see, reproduced from
/// the REAL Rust encode.
///
/// No wrong NTT is implemented here: control (a) is, by the reference's own
/// self-check S8, exactly `bitrev(correct)`, so permuting the row this crate
/// really produced must hash to the control's digest. It does — at 2^3, 2^6
/// and at the 125M width — which makes the named diagnosis of a bit-reversed
/// device output a Rust-side fact rather than a Python prediction. The count
/// of moved entries is pinned too: the permutation on 2^k points fixes
/// 2^ceil(k/2) of them, 256 of 65,536 at the production width.
#[test]
fn the_ordering_control_is_the_real_rows_bit_reversal() {
    fn bitrev(i: usize, log_nn: u32) -> usize {
        i.reverse_bits() >> (usize::BITS - log_nn)
    }
    // (log_n, inv_rate, control (a)'s digest, entries differing from correct)
    let cases: &[(u32, usize, &str, usize)] = &[
        (3, 4, "5ada7fa09a9272e8b86a2a779dd9b0894a2965a6c94c56859b4ecb1e5633719b", 24),
        (6, 4, "975a2b6eb272c06d84719faade776e555962816d9029178eaffaaad25226682f", 240),
        (14, 4, "43c5b6d188567aebcae48fbb137290deed3a3423e1c1eacc8983f153dfce05a0", 65280),
    ];
    for (log_n, inv_rate, want, want_moved) in cases {
        let (q, _correct) = seeded_profile(*log_n, *inv_rate);
        let (msg, pad) = inputs(4, *log_n, *inv_rate, q);
        let enc = encode(*log_n, *inv_rate, &msg, &pad);
        let nn = enc.len();
        let log_nn = nn.trailing_zeros();
        let permuted: Vec<Fp> = (0..nn).map(|i| enc[bitrev(i, log_nn)]).collect();
        assert_eq!(
            sha256_hex(&permuted).as_str(),
            *want,
            "the bit-reversal of the real w{log_n}r{inv_rate}-seeded row is control (a)"
        );
        let moved = (0..nn).filter(|&i| permuted[i] != enc[i]).count();
        assert_eq!(
            moved, *want_moved,
            "entries an ordering bug moves at w{log_n}r{inv_rate}"
        );
    }
}

/// The four entries an ORDERING bug moves, at the production width: a device
/// that returns bit-reversed output leaves index 0 alone and moves these.
#[test]
fn the_ordering_probes_at_the_125m_row_width_are_pinned() {
    let (msg, pad) = inputs(4, 14, 4, 256);
    let enc = encode(14, 4, &msg, &pad);
    assert_eq!(enc[0].0, 3655851916429667015, "index 0");
    assert_eq!(enc[1].0, 3177249528031755686, "index 1");
    assert_eq!(enc[1 << 15].0, 15144069108932809041, "index 2^15");
    assert_eq!(enc[(1 << 16) - 1].0, 4160362776790354634, "index 2^16 - 1");
}
