# Chain publication feasibility lane — PROGRESS

Lane: research and costing only (D39 item 2). No prover code, no git writes,
no heavy runs, no wallets, no transactions.

| UTC | Step |
|---|---|
| 2026-10-21 02:37 | Lane opened. Read CLAUDE.md, D3/D4/D37–D39, MVP_STATUS receipt sizes and the zkVM line's measured figures (6.55 M cycles -> 3,743 s CPU STARK + 197 s Groth16 wrap, 785-byte receipt, 8 ms verify). `apps/proven-media/` holds only a venv so far. |
| 2026-10-21 02:40 | Read-only Explore agent launched on the hashline verifier's work breakdown (for the zkVM cycle estimate). Web price research started. |
| 2026-10-21 02:43–03:00 | Live reads: Arweave price endpoint (14.377 AR/GiB), Turbo rates ($84.78/GiB), CoinGecko token prices, gas prices on Ethereum/Base/OP/Arbitrum/Polygon, OP-stack L1 fee oracle, Arbitrum NodeInterface, Solana rent and priority fees. All read-only; no transactions. Snapshot saved to `prices_20261021.json`. |
| 2026-10-21 03:05 | Verifier survey back: verify work is O(params) + O(receipt). It folds and re-hashes every int8 weight, with no cached weight commitment, which drives the zkVM estimate to about 2–3 x 10^11 cycles for Shieldstral. |
| 2026-10-21 03:15 | `costs.py` written and run (all DERIVED figures). The harness refused the REPORT.md write (subagent report-file rule), so per the brief's fallback the full report text goes in the final hand-back message for the caller to save as `REPORT.md` here. |
