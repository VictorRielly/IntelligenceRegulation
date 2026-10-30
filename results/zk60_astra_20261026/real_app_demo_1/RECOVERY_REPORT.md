# First real app post and recovery after reboot

The public garden post completed all three Shieldstral category proofs through
the app. Sexual content, violence and hate were each **not flagged**. The three
retained receipts passed fresh native verification after reboot and share one
confirmed [Base Sepolia transaction](https://sepolia.basescan.org/tx/0x0f2dc9dd777d33a72a5930f169ea5ba49b485fc25010ebdaa0f536bd5a9ad01a),
at block **52,075,726**. This is testnet; receipts are stored locally, not on-chain.

Post `d1800de17fffed4565733d12e5c30f52` contains 17 content tokens. Binary r16b
`dfb8025e…`, statement identity `29aeba6c…`, T128 profile `2ba468f9…` and all three
moderate policies retain their original pins. Each receipt contains 28 segments
and 848,412,096 bytes. The native verifier reports a 96-bit whole-run floor.
The UI continues to say **privacy statement pending**. The moderate wording is
authorized for this demo; the final product choice remains separate.

## Evidence and measurements

All times below are [MEASURED, n=1, shared laptop]; they are not a comparison of
thread configurations under controlled conditions. The original proofs ran
before the interruption and were not repeated.

| Category | Native threads | Prove time | All pipeline work | Prove sampled RSS |
|---|---:|---:|---:|---:|
| Sexual | 2 | 1,031.16 s | 1,300.01 s | 7.99 GiB |
| Violence | 8 | 456.30 s | 687.49 s | 8.24 GiB |
| Hate | 8 | 457.04 s | 693.51 s | 8.16 GiB |

- Original proof, fresh verify, input-owner and `label --expect-total 17` all
  succeeded for each category. See `sexual.json`, `violence.json`, `hate.json`
  and their terminal markers. `input_owner_capture.json` preserves only the
  public successful owner-check events, without private openings.
- `recovery-20261030/audit.json` records a fresh hash check of all **84 segments,
  2,545,236,288 bytes**, publication/statement/record agreement, original source
  pins, exact category geometry and full-post coverage.
- `stored_verify_complete.json` records three fresh native verifications from
  the content-addressed public store after reboot. These CPU checks used the
  resource guard with watchdog enforcement, without a kernel memory cap.
- `complete.json` records the three confirmed anchor references, all passing
  publication checks and the recovered signed manifest. The existing testnet
  wallet and deployed contract were reused. A transient HTTP 429 was handled
  with bounded retries; a persisted signed batch retains its bytes and nonce.

## What recovery restored and what was lost

Boot `4f7dab84…` differs from original boot `9ecf0dc6…`. The original workspace
`/tmp/zk60-astra-real-app-demo-20261029-1` disappeared. Its SQLite database,
development manifest signing key, salt opening, private owner openings,
activations and job logs are unavailable. The default persistent database did
not contain this post either.

Recovery used the retained public records and receipts. It did **not** rerun
any proof, invent an opening, or resubmit the text for classification. The
original publication manifests, salted commitment, leaves and proof bytes
remain unchanged. The retained successful input-owner capture is historical
evidence. The first garden post's openings are lost, so its proof-to-post link
cannot be rechecked from an opening. Its receipts and public segments still verify.

A new local development manifest key is explicitly identified in
`recovery-20261030/publisher_public_key.json` and in the signed manifest's
`recovery` field. The original public-key pin and `plan.json` remain intact.
The original manifest signature was not recovered, and this is not a claim of
signing-key continuity. Native proof verification does not use that app key.

The display database, replacement development key and D45 item reservation now
live outside the repository in the mode-700 directory
`/home/victor/zk60-owner-private/proven-media-astra-demo/`. The atomic migration
verified all four original files unchanged (`recovery-20261030/storage_move.json`).
The existing testnet wallet also moved unchanged into that root's `testnet/`
directory; its configured address is unchanged and no transaction was sent
(`recovery-20261030/testnet_key_move.json`). The author handle
was normalized to the original handler's `@astra_demo` form, recorded in
`recovery-20261030/author_normalization.json`. There are no recovered running
jobs. Use the public-store verifier for this post: its original private job
directories and owner-based recheck workflow are unavailable. Do not re-prove
the post to replace missing private artifacts.

## Applied app privacy changes

The staged P-7/P-8 changes were applied after the recovered demo completed and
host process checks found no active app server or pipeline. The app requires
operator-issued random author credentials and revocable sessions. Unpublished
posts are visible only to their authenticated author; failures expose only a
generic post-level failure. Mutation routes check sessions, CSRF and origin.
Public records omit proving times; signed historical manifests remain intact.

Validation after integration:

- **188 app tests pass**, 5.142 s test time, cgroup plus watchdog enforcement,
  sampled RSS 0.10 GiB. Evidence:
  `../privacy_app_candidate/integrated-host.log` and its guard result.
- **Five frontend behavior checks pass**: mutation CSRF, sign-out and account
  switch races, expiry clearing private views, and generic failure rendering.
- **Ten real ASGI checks pass**, recorded in `recovery-20261030/app_checks.json`:
  recovered post, adult/minor feeds, real labels, timing removal, recovery
  signature and confirmed references, publisher key, authentication, duplicate
  screening refusal and unchanged stored post/proof/reservation state.
- The first discovery invocation found zero tests and is not counted. Sandbox
  threaded ASGI checks stalled and were explicitly interrupted; their host
  replacements above are authoritative. The first host route check used a
  verifier-only configuration and stopped at startup; the corrected check uses
  the app's actual deployment configuration.

No browser screenshot or visual review is claimed. No server was started or
restarted by the promotion helper. The full 4,872-item integer fidelity
benchmark, final product wording and classifier privacy acceptance remain open.

## Durable storage validation, 2026-10-30

Startup and wallet setup now refuse temporary and in-repository private paths. The final host suite passes **199 tests** (5.269s, sampled RSS0.09GiB, cgroup plus watchdog; measured n=1 shared box). All ten actual recovered-post ASGI checks also pass after the moves, with unchanged retained post/proof/reservation state and no transaction. `../durable_storage_evidence.json` retains exact source pins, modes and guard evidence. The coordinator accepted the storage fix at15:20Z. The new19-token library demo is a separate post under a separate durable private root and is in progress; this does not restore the lost garden-post openings.
