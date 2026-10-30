# S8 guard swap-rule candidate — coordinator review (2026-10-28 23:14 UTC)

**Verdict: ACCEPT for installation at a quiet window, with the conditions
below.** Reviewer: Claude (coordinator). This review covers the admission
logic only, not a re-review of the whole guard.

## What was reviewed

- Candidate: `results/zk60_sol_20261026/guard-s8/zk60_resource_guard.py.candidate`
  (sha256 `88af4c63…`). Live guard: `scripts/zk60_resource_guard.py`
  (sha256 `87138bda…`, unchanged).
- Full diff live → candidate: **13 lines, one hunk** in `_admission_reasons`.
  It is identical to `admission-only.patch`; nothing else changed.
- `PROPOSAL.md`, `S8_CANDIDATE_REPORT.json`, `test_swap_admission.py`.

## The change

- **Old rule:** refuse every class whenever swap use > 1 GiB.
- **New rule:** when swap use > 1 GiB, refuse only if
  `MemAvailable < need + 1 GiB margin + all swap in use`; otherwise admit.
- The plain memory check (`MemAvailable < need + margin`) is unchanged and
  still applies at any swap level.

## Assessment

- **Sound as an admission rule.** It still refuses whenever the box could not
  page every swapped page back in and also fit the new job with the usual
  margin. It stops treating old, idle swapped pages (WSL swappiness 60 pushes
  idle session pages out) as current pressure, which caused the stalls on
  10-26 19:51 and 10-28 ~22:08 with 12–14 GiB available.
- **The worst case is no worse than today's plain memory rule:** with 1.3 GiB
  swapped, the new rule requires 1.3 GiB more headroom than a swap-free box.
- **Unchanged and still load-bearing:** the global declared budget, the
  exclusive heavy lock, FIFO reservations (off), the GPU telemetry and idle
  checks, the kernel and watchdog caps, the 1.2 GiB runtime floor, and process
  cleanup.
- **Tests:** I re-ran the 9 policy tests here (pass, 0.006 s). Sol reports the
  existing suite at 45 tests with 4 systemd skips, using a private copy whose
  swap fixture was changed, and the S3 regressions at 31 / 31.
- **Limitation (unchanged by S8; record it in the protocol doc):** the guard
  sees only the VM's memory, never the Windows host's. Page cache that WSL has
  not handed back to Windows can make the laptop look full while
  MemAvailable is high (Victor's 21:53 concern). Neither rule detects host
  pressure. Victor's side remedies are `drop_caches` or `.wslconfig`
  `autoMemoryReclaim`.

## Conditions for installation

1. Follow the S3 procedure: drain, `.orig` backup outside /tmp, atomic
   replace, both static consumer pins updated, rollback ready, FIFO off.
2. Make the fixture change in the **official** existing suite, not a private
   copy: the old "any swap refuses" case becomes "insufficient headroom
   refuses", keeping a case that still refuses at 2 GiB swapped. Then run the
   45 + 31 + 9 tests **on the host without the systemd skips**.
3. Add the limitation above to `docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md`.
4. **Victor's OK to install.** The guard is the safety mechanism behind his
   memory concern, so the install window is his call, as D42 was.
