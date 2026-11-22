# L63: deployment premises of the Shield run's Lean top

Written by the L63 leg 20 agent (clock read 2026-11-22 00:22 UTC). The Lean top (`sshC_productionReadyL_epP_blkEF`
and the tops below it) is a statement about a verifier with a fixed setting. The items below are facts about how the
app runs the verifier. The Lean statement does not prove them; it holds for a deployment only when they are true.
Labels: READ (source reading), CHECKED (a script run), PROVED (Lean).

1. **The layer list comes from a trusted statement identity (finding L63-14, answered).** The verifier's layer list
   is the one fixed by a trained statement identity that the verifier obtained from a trusted source. The identity is a
   BLAKE3 hash (`identity`, `trained_statement.rs:970-971`) of an encoding with the record count and each record's
   index, block digest and manifest digest (`trained_statement.rs:936-940`). The one-shot verifier
   (`classify_cli.rs:888-891`) and the resident verifier (`check_server_start`, `classify_serve.rs:630`, comparison at
   636-644) refuse an export whose identity differs from the `--expect-statement` value. BLAKE3 binding (collision
   resistance) is assumed. READ (Sol, SHIELD_CLASSIFIER_SCOPE_495.md; the cited lines were read again this leg at
   a32421f9).
2. **Both configured profiles list layers 0 to 25, in order, with T = 128.** The R13 profile (sha256 `2ba468f9…7f05a0`)
   and the W16R2 profile (sha256 `94643880…cd4ce20a`) both list layers 0 to 25. The archived R13 receipt's statement
   says `blocks: 26`. CHECKED (Sol's audit_shield_classifier_scope495.py, re-run this leg: "R13 and W16R2 ordered
   profiles, archived R13 statement and 28 wire frames verified"; the lane's l63_geom495.py: 39 of 39 OK).
3. **An identity from an untrusted source is outside the claim.** A verifier given an identity from an untrusted
   source can accept a run over a consecutive sub-range of the 26 layers. The generic statement check
   (`TrainedStatement::check_self_with`; `trained_statement.rs:164,785-797`) accepts any consecutive range that ends
   below layer 26. The Lean top covers only full 26-layer runs (`ShieldRun`, `shdP_blks_length`). The segment count 28
   and the OUT-C stage index 27 hold only for 26 blocks.
4. **The vocabulary is exactly 2^17 (ruling L63-7).** The top keeps the premise `hV131072 : Rp.inp.V = 131072`. The
   deployed stage IN-C must use the registered embedding with `V = 131072`.
5. **The blocks are the shield export's calibrations (`ShieldRun`).** The run's blocks are the 26 calibrations of the
   app's verifier export in order. Item 1 pins them in deployment: the identity commits to every block digest and
   layer manifest digest.
6. **The public block data passes the native loader.** `BlockPublic.Valid` (CircuitBlock.lean) lists what the
   native loader enforces. Since this leg that includes the ACT zero row `act 0 2048 = 0` (field `act0`; code:
   `accuracy_act.rs:21-22`, `accuracy_public.rs:157-163`). The premise holds only when the verifier builds the public
   data through `AccuracyPublic`'s checks, as the native verifier does. The field is PROVED; the code enforcement is READ.
7. **The transcript domain is the run profile string.** `shdP_runDomain` is the 73 bytes
   `hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/2`. The archived statement carries this
   string (CHECKED by l63_geom495.py). The verifier uses it as the transcript domain (`classify.rs:1314`), which is READ
   only.
8. **The geometry evidence is archived.** Sol's 495 checks that the statement file and the 28 frames hash to the
   values in Astra's archived audit. That audit recorded one fresh native verification. Neither Sol nor this lane
   re-ran the native verifier (`ran_native_verifier: false`).
