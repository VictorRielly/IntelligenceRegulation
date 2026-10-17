# PRIVACY GATE lane — the joint-view / run gate at the trained TinyLlama T32 profile (2026-10-17 UTC)

Scope: produce, at the trained TinyLlama-1.1B T=32 profile (calibration
export `pg_rot1_export_T32`), the same privacy evidence the 125M development
shape has (all-zero reference proves; per-commitment linear view; blinding
reproduction; joint assignment; hash layer; tamper controls), so the security
owner can decide. **Nothing here is a privacy acceptance and no statement here
establishes a privacy property.** D22 covers only the toy.

Ownership: `ops/zkp-mvp/trained-1b-gate/` (native copy, additive test-scoped
capture code only), `ops/zkp-mvp/gate-tinyllama/` (adapted gate tools), this
directory (evidence), `/home/victor/zk60-artifacts/tinyllama-trained-capture-*`
(bundles, outside the repo). No git. Every build/test/proof/heavy pass through
`scripts/zk60_resource_guard.py`, one guarded job of this lane at a time.

## Log

- 10:11 UTC: lane opened; read CLAUDE.md, ZK60_RESOURCE_PROTOCOL.md, readiness
  §3 runbook, MVP_STATUS privacy table, decisions D12..D24, the gate's round 9m.
- 10:12 UTC: `ops/zkp-mvp/trained-1b-gate/` = rsync of
  `ops/zkp-mvp/trained-1b-review-r2/` excluding `target/` (the r2 copy checked
  first against `trained-1b-review-r2.sha256`: all 193 OK).
