# S8: distinguish stale swap occupancy from insufficient admission headroom

Status: proposal only. The installed guard and its consumer pins are unchanged.
Independent review and a quiescent swap window are required by the S8 brief in
`docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md`.

Observed block on 2026-10-28: 13.42 GiB MemAvailable, 1.29 GiB swap used,
1.6 GiB of declared live light work, both heavy/build locks free. Native
acceptance and a GPU-enabled CLI compilation wait solely on swap occupancy.

Proposed predicate, only when swap use exceeds the existing 1 GiB threshold:

    refuse if MemAvailable < declared_need + existing_margin + all_swap_used

The existing margin is 1 GiB. Reserving room to bring **all** currently swapped
pages back into RAM is conservative. It avoids treating old swapped-out pages
as evidence of current pressure while preserving a separate swap reserve above
the ordinary job margin. For the observed dense proof declaration, the required
headroom is 8.5 + 1 + 1.29 = 10.79 GiB, below 13.42 GiB available. At 10 GiB
available with 2 GiB swapped, that same job still refuses (needs 11.5 GiB).

The global declared budget, FIFO reservation logic, exclusive heavy lock, GPU
idle/telemetry checks, kernel/watchdog caps, 1.2 GiB runtime memory floor and
process cleanup are byte-for-byte unchanged. This is an admission change,
not a pressure-monitor rewrite. It does not predict future allocations; the
existing caps and runtime floor remain necessary.

Validation: nine pure policy tests pass, including the measured snapshot,
the exact threshold and just below it, genuinely insufficient swap headroom,
ordinary low memory, large swap, declared-budget refusal, exclusive heavy
admission, FIFO reservations and GPU telemetry/idle refusal. No real guard
state, lock, GPU, meminfo or heavy process is used by these tests.

The existing suite's old assertion that *any* swap occupancy must refuse is
intentionally changed in a private test copy to use insufficient available
memory. Its remaining cases and the 31 S3 regressions still need revalidation
against this candidate; host-only systemd checks remain required at a swap
window. No live deployment is authorized by the candidate tests alone.

Source hashes are in `base.sha256.json`. Any approved installation must follow
the S3 backup, drain, atomic replace, consumer-pin and rollback procedure, with
FIFO remaining off unless separately changed by the coordinator.

## Completed candidate regressions

The existing45-case suite passes with4 systemd user-scope skips. Its single
swap-only refusal fixture was changed in a private copy to use2.5 GiB free
with2 GiB swapped, so it still exercises genuine insufficient headroom.
All31 S3/FIFO/mixed-version regressions pass without skips. JSON reports are
`existing.json` and `s3.json`; the candidate-only patch is `admission-only.patch`.
The installed guard was re-hashed afterward and remains the approved87138bda.
Host-only checks, independent review and an explicit swap window remain pending.
