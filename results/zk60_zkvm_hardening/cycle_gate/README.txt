ZK60 zkVM block host - P3 constant-cycle gate, first record
===========================================================

Date (UTC)   : 2026-09-19 (record generated_utc 2026-09-19T03:21:32Z)
Produced by  : scripts/zk60_zkvm_cycle_gate.py (standard library only)
Command      : python3 scripts/zk60_zkvm_cycle_gate.py \
                 --host  zkvm-block/target/release/zk60-block-host \
                 --model zkvm-block/fixtures/synthetic-model.bin \
                 --r0vm  /home/victor/.cargo/bin/r0vm \
                 --out   results/zk60_zkvm_hardening/cycle_gate
Host binary  : zkvm-block/target/release/zk60-block-host
               SHA-256 1ae9038481d1dcd668122dd184bb128165246da3b45b92edaec4eee9f59d10bf
Guest image  : c5a04b83448eb2a17919e38a9a00db7edfab4bdc979800ee867be11f5dc295a5
Model        : zkvm-block/fixtures/synthetic-model.bin
               SHA-256 c345ccdb09ccfa4f235d04003835cca9eff9e5cb10c84a5555abc4d13a9bdc55
r0vm         : /home/victor/.cargo/bin/r0vm (RISC Zero 3.0.6)
               SHA-256 751b9b188d341e8bec5e02060086b7b1dc3f7289e90f726c38589bb6735dd6d7
Segment limit: 2^18 (SEGMENT_LIMIT_PO2 = 18, reported with every count)

VERDICT
-------
constant_cycles        : FALSE  (both questions must pass; the second does not)
constant_total_cycles  : TRUE   - every one of the 9 accepted input patterns
                         produced 6,553,600 padded cycles in 25 segments.
                         Total cycle spread: 0.
constant_user_cycles   : FALSE  - the executor's unpadded user cycle count
                         differs per input: 5,343,122 (all zero) to 5,360,732
                         (all -64). User cycle spread: 17,610 cycles, which is
                         0.2687% of the padded total. Nine accepted patterns
                         produced nine distinct user cycle counts.

Declared leakage (verbatim from cycle_gate.json):
  "Declared timing leakage: over 9 accepted input patterns the padded total
  (6553600 cycles) and the segment count (25) are identical, so the
  proof-visible execution length is constant; the executor's unpadded USER
  cycle count is not, spanning 17610 cycles (5343122 to 5360732, 0.2687% of
  the padded total). Anything that observes the executor's own work rather
  than the receipt -- host-side timing, r0vm telemetry -- learns that much
  about a private input."

What this does and does not say
------------------------------
It says the quantity a receipt exposes through continuations - the segment
count, and with it the padded proving work - did not move with the input over
this input set, and that the executor's own work did. It is a measurement of
the executor, not a proof, and no receipt was created (the gate never proves
and never takes /tmp/zk-heavy.lock). It is not a security proof of constant
time: a fixed-shape input set cannot show that no input moves the segment
count, only that none of these did.

Input set (9 patterns, each 512 little-endian i16 = 1,024 bytes)
  zero, pos3 (+3), neg3 (-3), alt (+3/-3 alternating), rows_equal (each row
  of 16 constant, rows differing - the softmax-tie shape), random_small
  (fresh uniform [-3,3] from secrets), ramp ((i mod 7) - 3), and the two
  out-of-small-range probes pos64 (+64) and neg64 (-64).

All 9 were ACCEPTED: this calibration refused none of them, so +-64 is inside
the accepted computation range, and no refusal path was exercised by this run.

Determinism control
-------------------
The gate was run twice back to back. All eight fixed patterns reproduced their
user cycle count exactly (5,343,122 / 5,347,964 / 5,354,108 / 5,351,006 /
5,348,955 / 5,349,058 / 5,354,588 / 5,360,732), even though prepare-input
draws fresh random context and salts for every run. Only random_small changed
(5,349,272 -> 5,348,920), because its input is freshly drawn each run. So the
user cycle count is a deterministic function of the input VALUES, not run
noise and not the salts. The second run's record is not kept: it was a
control, and the first record is the one on file.

Caveats
-------
1. Guest image ID. This record was produced in the worktree
   /home/victor/wt-zk60-zkvm-hardening, whose build reports image ID
   c5a04b83... instead of the 8d74aab3d58c1a713045dfd1ea4ffa15e61439e61af58b72a5fdb792111998d9
   recorded for the 2026-09-18 loop. Every guest-affecting source file is
   byte-identical to that build's proof-build-source.json record; risc0-build
   3.0.6 does not remap paths outside its docker mode, and the guest ELF
   embeds one absolute source path,
   /home/victor/wt-zk60-zkvm-hardening/private-block-kernel/src/lib.rs, which
   in the main checkout reads /home/victor/IntelligenceRegulation/... . The
   image ID is therefore build-location dependent; re-run this gate from the
   approved checkout before quoting the counts against the approved image.
2. Seconds are not a benchmark. prepare_seconds/execute_seconds in the JSON
   are quantized by the gate's exponential poll and were taken while an
   unrelated real proof was running on the box. Use the cycle counts; ignore
   the seconds.
3. Counts only. The record carries no input, salt, request or journal bytes;
   refusal text is copied only when it matches a known static host message.
