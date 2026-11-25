# Default-path timing set for the error-recovery and L1-binding branches (2026-11-25)

Question: is the merged binary, with no new switch set, slower than the pushed head at the installed classifier profile?
Definition (posted and pushed before the run): `ops/zkp-mvp/RECOVERY_COORDINATION.md`, entry of 2026-11-25T21:08:55Z.

- **Binaries** (guarded builds, `cargo build --release --offline --locked -j 2 --features gpu-metal --example zk60_classify`):
  B0 = the pushed head's prover source (an export of `ops/zkp-mvp/gpu-metal`, tree `d44392110507`, the tree of `9fbc85292`),
  sha256 `66caf7ad6ebb5ab8643b1eeed0d476a8c50f4c2cb01034c45341a5fdfb845314`; B1 = merge object `f44edf443`
  (`agy/metal-err-recovery` at `932915a9e` and `agy/l1-block-binding` at `b6d7f92c9`, tree `28973dbedcc1`),
  sha256 `964b8c2192bf10e09733d4c9518e9bc80b263cb447765366958bf3e035b0a308`.
- **Harness:** the files here are a copy of `results/zk60_hostw2_app_20261124/` in which only the two binary paths and the guard
  label prefix differ. Trained Shieldstral classifier, installed profile, six lanes by five threads, per-thread Metal queues;
  a leg is 6 lead-in requests and 48 timed ones; rate = 48 x 128 / (completion[54] - completion[6]). Arm A = B0, arm B = B1,
  both with the five merged switches of the wave-2 default-path set; every receipt of every leg checked by B0 with no switch.
- **Smoke** (`raw/p23_smoke`, two legs of 6 timed requests): A 48.70, B 48.75 tok/s, 12 of 12 receipts checked on each.
- **Set `p23_ab8`** (guard run `56afceb7a88f`, 2863 s, nine legs, all proved, 54 of 54 receipts checked on every leg, no
  guarded job overlapping a leg: `raw/p23_ab8.overlap.txt`). Lead-in leg (A, not read) 54.29. Then, in order A B B A B A A B:
  54.66, 54.45, 54.41, 53.69, 54.05, 54.46, 53.29, 54.63 tok/s.
- **Reading by the posted rule:** mean A 54.03, mean B 54.39, r = +0.67 percent, at or above -1.5: **default path intact**.
  Spread inside A 2.6 percent, inside B 1.1 percent. This is not a gain: the difference is inside the legs' own scatter.
- **Not measured:** the W2 switch on (the binding branch changes only that path), six lanes by eight threads, the 8B shape.
  The rates of this set are not to be compared with rates of other sets or days.
- The first merge object (`f04bc012b`) failed its gate (`results/zk60_p23_merge_20261125/`, `gate1`); `raw/build_b1_f04bc012b.*`
  is the build of that object and was not used for timing. `raw/confirm_cli_alone.*` is the fresh-process run that confirmed
  the diagnosis of that failure.
