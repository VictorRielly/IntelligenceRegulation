# F12 fix: every value that moved, old → new (D65(1), 2026-11-04)

Every new value below was printed by the code itself (the test that pins it, run under the resource guard) and
copied from that output; none was computed by hand. Logs: `logs/`.

**How each move is attributed.** The change was run in two stages on the full lib suite:
- **Run A** (`logs/a_theta_only_full.log`): only `combined_weights` moved to θ¹ (plus the new F12 tests), every
  profile string still at `/1`. 907 passed, 4 failed: the three known failures and the W16R2 rung golden. So
  under the θ change alone, the only pinned value of the ordinary suite that moved is the W16R2 rung golden,
  which digests a seeded proof (and so `M`'s opening).
- **Run B** (`logs/b_versions_full.log`): the strings at `/2` as well. Every additional move is a value that
  hashes a profile string (a hash-tag key, a transcript domain, an export that names its profile) and did not
  move in Run A.

Nothing moved that is not explained by `M`'s opening bytes or by a profile string. In particular the R-5 boundary
digests, the toy schedule digest (`TOY_SCHEDULE_DIGEST`, the toy prints its legacy label), every receipt and
export LENGTH, and the public block digests of the retained 125M statements did not move.

## 1. Profile strings

All 130 distinct strings, old → new, are in `profile_versions.tsv` (written by the rename script; 184 rewrites in
30 files of `ops/zkp-mvp/gpu-metal/hashline`, src, tests and examples). In short: every
`hashline-zk-mr1/…/1` profile of section 2 of the README and the two `unregistered-dev-twin/…/1` dev twins → `/2`;
`ffn-v3-mr1-fresh-io-poc/2` → `/3`; `ffn-v3-mr1-fresh-poc/1` and `ffn-v3-mr1-probe/1` → `/2`, also where they
appear without the prefix (the fresh layout's self-report in `zk.rs`, the observation JSON writers). Not renamed
(not profiles of `M`): `hashline-zk-mr1/metal-test/1`, `metal-bench/1`, `wrong-profile/1`, `no-such-block/1`,
`private-run-not-registered/1`.

The other version tokens:

| Where | Old | New |
|---|---|---|
| `zk.rs` v2 `--zk` header (`absorb_statement`, `header_v2` legacy tuple) | `P1` | `P1/2` |
| `zk.rs` v3 `--zk` header, legacy tuple (`header_v3`) | `P1-v3` | `P1-v3/2` |
| `zk.rs` v3 / v2 header body, other modes | `HL-ZK/1\|profile=…` | `HL-ZK/2\|profile=…` |
| `private_seam.rs` seam receipt wire magic | `HLSEAM01` | `HLSEAM02` |

## 2. Pinned values

| Pin (file) | Old | New | Moved by |
|---|---|---|---|
| `w16r2_tests::W16R2_RUNG_GOLDEN` (CPU and Metal golden) | `c6d5c2d8` | `96e4f0b6` (full: `96e4f0b6f34f78762df36c5fc9a19b8578f067521de101244c7cd43f996479f0`) | `M` (Run A: θ¹ under `/1` gave `553137f1d45afbf58030479f07486552b7d1e62c4706ff18645b5bde1c52349a`) and the string |
| `hash_tag_tests`, rung-G (`…/private-block-rung-g-t24-dev/2`) transcript key | `51b7d0b0171d54b5bb45fd42c3f9369cad87894b625e0569b89fac0036d20dbe` | `af9f98d9a9788bd5f1133dc47617c3dee3dc01db636daa06e45c1b6e665c6137` | string |
| rung-G column key | `2295498fd6fd5e41320da717e9da89462e5c90a5b3b2d72ac496bcc157c2cd2c` | `4f10e589280b46dab8f2b827dc6ab7cd04bcbf2da80fed85afd4de9788424710` | string |
| rung-G leaf key | `fe211417895c73c4a70430cb9bfb7081289ec7532f2716d2a86f609b0de54032` | `156ba7b7fec5a686b56ea21159874a8231a27575f83300ed804ea33d823b4c1a` | string |
| rung-G node key | `8c4d2cfe7b8528d350f20dece1250c8d81596eb25d26bffda1247238f0f71fcc` | `8ae134a0fa508099b54f5b0f380560f1fa1f8acb975bf5006fc7a12baf6c350e` | string |
| `hash_tag_tests`, 125M (`…/private-block-m125/2`) transcript key | `125f9b4d44ac3c46712a35419cdeda6c1428db443ccaf58da67f35b15b37291c` | `e6c8bbcad37f235f51b570d589a5b44434ac80ce8f93d07ecd5e973fe4bacadb` | string |
| 125M column key | `d5fc391cc58eed85631b4c3dabc7d377477eb1a0a725aeccaec0f4d10061b135` | `b340b2d66358fde90ee3def6782e8f615d9f374d069b2508cf39af52f6d9b4cc` | string |
| 125M leaf key | `1dc6f7146ad501ede6d90b3071da2f3251d38137303ffcc0a6a48b7f89effe83` | `6b72d4c162d2215928906e80395fa8f7f3a973b16f0590914be06a32b067276f` | string |
| 125M node key | `798eb64ff187f6f3e8e889ac4c4742607ac71a71fa09e2944a0ecc5e8a42026b` | `fd7aa4d6411246dd40edece1b2b96e588ffe8708336dedf026b29440f535ca7b` | string |
| `run_capture_tests` (the run file carries rung-G's four keys) | the four rung-G keys above | the four new rung-G keys above | string |
| `run_tests::R5_RUNG_G_L3_BINDING` (run header transcript state) | `[161, 7, 121, 146, 199, 166, 87, 15, 139, 122, 99, 225, 216, 105, 193, 132, 236, 40, 177, 39, 105, 8, 163, 160, 180, 109, 150, 228, 120, 158, 27, 105]` | `[236, 113, 40, 11, 252, 209, 161, 91, 85, 24, 88, 2, 95, 96, 225, 198, 152, 14, 133, 168, 222, 13, 222, 69, 230, 38, 118, 216, 120, 195, 152, 174]` | string (the run profile is the transcript domain; Run A did not move it) |
| `run_tests::R5_RUNG_G_L3_BOUNDARIES` | unchanged | unchanged | — |
| `slot_ir_tests::EXPORT_DIGESTS` toy (99,232 B) | `12e7ed013f6ca106232e2f3be87ecce6a82e7382df75c45aabe0a13f358f6bfc` | `2e524e80bd306c561cbbc14f4888d3c026478f708b77f22209ed60b260a6b46f` | string (the export's `"profile"` line is its only diff) |
| rung (109,631 B) | `506d06db2158a16952975a29e5b36d7213761b2ce7fce28ba260d24e8bf774ad` | `8a73235757d270acee29f4a3cfdb1a20077831e4c0337853ec63bdccb600f7e2` | string |
| rung_g (109,635 B) | `5cb8323a2a6607f38860e6c79ec1ee9b2f37fb4468cd7cf053fb77838f17d496` | `00f976f0769e457a4d353309a6c58cf19977c615c476167a67e3505d6cd4a1f9` | string |
| rung_k4 (109,637 B) | `e40501335cd10bfe75c04cf49d5b184426472e420658c8c7ade794a17a7f0401` | `8a1146da35d7e078efb7a986752fca4f791a52cbe257ed837add5f1ac8256086` | string |
| rung_p2 (107,276 B) | `fa11ed91ecf9662d446d123ee3c7b9ef190e099a8b40b3656ff92ab4ae80d677` | `457a366137f595c0f233defc4a7028513d761065a02fea375189df4c3b94425e` | string |
| rung_c6 (105,384 B) | `120b116474c7265ebe75bbb122b87e2d5c1db10f068f5c951de2d133d2b4a9ba` | `50cbc83736715ce7e0de89282398c69289679f1260af585327b5988345f842c4` | string |
| rung_w14 (105,395 B) | `d207b45cae6a43a950cb641c75ad2f8c1c8d3698a4255bc61c973d0a6aa9d3ad` | `846e67e0768cd76d16210bb3992f024583c0cf912a49d0035b964a2a19e2b937` | string |
| rung_e32 (105,393 B) | `500aefdcf6655f4c40aeb8a36d9651b51992f8427bd6aa6981eb0bbc031c04a7` | `42fba6721b9b38008eec7a945b6a0d8e9a6388c5c1681ea0d38a13c2983a2ba8` | string |
| m125 (105,382 B) | `2e8cdb877d4938a63d92dc8f4b054e59ff296456c56063f61c1ad8e39e948d39` | `75dc94d91e9cd50c4e1ac65303c5def5f16444326b17f77b0d10f0fa2ddc80dd` | string |
| `r9_golden_tests` / `r12_golden_tests` tinyllama-t128 (seeded core proof, `#[ignore]`) | `782b64c97a88cba4c6c34a2fecb73132f26d5f54adc9bd159f3d6cf9df4205c0` | `d21f06fe13ac860ecd0ebaca43537a20357642dc38c7f2a557f46448170703bd` | `M` and the string (the digested text holds `M`'s opening and the final transcript state; the profile is absorbed first) |
| llama3-8b-t128 | `05a22d72a892aff5fb2e35da4d0ab0c894d696f2e6afa542b6ecece5aeb9f4db` | `d535bf8ae2a38cb1b56eb34719a8905a7f95e4a2be419de4ddb591b92c74ccb2` | `M` and the string |
| `r12_golden_tests` tinyllama-t128-dd | `e50e71f86ab64c6f4d69c6bee1ec7881feef75b1dc4c3972e20a6810c4428324` | `9db560c2c7d66e73628434a490687199e02657dd35727e05b786af2f3b87fe7a` | `M` and the string |
| llama3-8b-t128-dd | `9c2572a3d5bc7b39374e39c3781d467f2c065279b23dd580bb0c9e02dd63c282` | `31e6a3d7f0917008d898c79a4616fb70126219b2564151df0e5ead917c99111e` | `M` and the string |
| `r12_golden_tests::GOLDEN_IDENTITIES` (synthetic trained-model statement identity, `#[ignore]`) llama3-8b-t128 | `3a1a4533863de5ca158418d2e2eef29c067395c3881ab8cfd4fd55c0afeb0548` | `95c12aac32d497856f6aaf17dd517424ca59277a072c00aee9ac8c2e733e034e` | string (a statement names its block profile; no proof is made) |
| llama3-8b-t128-dd | `a0354c192baaf7243f07e023865f003a67d9ef8b1da605186f3f9aeb17b708b7` | `446eb305bc1ab6bd07e6160da6d46fdf6e500d538adc1d2620c8aa502ac51513` | string |
| rung-dd | `35ea356f20f3c001c069273461fb807d3ad28503a81af76cc03e717f0ccc8bcd` | `586989cae4340ad57b7c5745d78540c5c4201b08887bcd4d44bc28460640ac8a` | string |
| tinyllama-t128 | `f9b1e6c427637153ef7e40efd336952fb8d53b11e039f09031425d1e4cd8f22a` | `a74e1e6cc7e9df8089bf302781d5db10732b512a331ab0522236a3fe139883ec` | string |
| tinyllama-t128-dd | `0827ed029a86d3aa47679962dcb96ed752a79d59a2603dcc2a9374acd60f8505` | `40125be623128a3b084f5f68d23166aaed084686fd0777e3a72cee6a586e789f` | string |
| `zk.rs` `tests_v3` P1 tag assertion | `P1-v3` | `P1-v3/2` (and `header_v2` = `P1/2`, newly asserted) | the version token itself |

The r9/r12 seeded goldens and the statement identities are `#[ignore]` and were not run in Run A, so for the
goldens the split between `M` and the string is not measured separately (both are in the digested text). The
identities cannot depend on `M`: they digest the statement, which is fixed before any proof exists.

## 2a. The six pinned trained digests

`slot_ir::accuracy::tests::m4_trained_accuracy_block_cpu_and_metal_digests_and_times` (the commands of
`results/zk60_h124_witness_20261104/check_par2.sh`, `HL_GPU_REQUIRED=1`; `logs/d3_trained.log`, and again in
`logs/final/trained.log`). It pins nothing in
source: the check scripts grep for the digests. Each new value is the same on the CPU and on Metal, cold and warm.
The seeded digest covers the proof (so `M`) and the transcript, whose domain is the profile string.

| Profile | Old | New |
|---|---|---|
| R13_SHIELD_T128_H24 | `2b0d04bbf22b5e52faf1d0ce9a13d85c5587eac4a0c0b45d66b0fa1ec4731101` | `5a6193d3df87cf21ac75e444629e8bfbe53e9c5d9fe5d40d501f0e3cd9443ecb` |
| R13_8B_T128_H24 | `678953f646fcd15d28e9209984cb42ff8af8358b8bb657f0440fd51878f33d89` | `f590b01fa9f8aa0fb7f198577fca2c21a99c17409e09cfa83c207ea2367ddac1` |
| W16_SHIELD_T128_H24 | `01a6d51d3b0476dac75ecaf0ff37541d191d18722aa6aa5293876fa0318d4eb2` | `79f987effee528792726c5908278abb5e0bb09b3f52525811344642ead0f281f` |
| W16_8B_T128_H24 | `c5e0bdac78cc47bb4de6528a29e809f56fcdb60417bb2c205c6fb693fadeae7b` | `a8258241b31944c31a1ffd2b1163a0838b67c022fd7d53164e410b930803dc71` |
| W16R2_SHIELD_T128_H24 | `a9a19ee52f68ef23cd0fb5f87a490114f5b8de76341bc3af9f1852300870ba1a` | `0e88d84fd04b33ab841ca56382e503aae9503b7cea269d24636d1ea9e9921c1a` |
| W16R2_8B_T128_H24 | `4e189ccc9c8efaed0790c6a1cd8c0104e13ac4506e9d77dff11b160603871dc2` | `90003b760eb7ad80a5b85136cc69510fc42d95cfa1997947e4a8d0c871dbdebe` |

`check_f12.sh` in this directory checks the new values (`check_par2.sh` is another lane's record and still
greps for the old ones).

## 3. Regenerated evidence files

`ops/zkp-mvp/gpu-metal/results/zk60_block125m_lane/x34-slot-ir/slot_ir_{toy,rung,rung_g,rung_k4,rung_p2,rung_c6,rung_w14,rung_e32,m125}.json`
are written by `slot_ir_tests::the_slot_ir_export_is_canonical_and_its_digest_is_pinned_at_every_registered_shape`.
Each file's only change is its `"profile"` line (`…/1` → `…/2`).
