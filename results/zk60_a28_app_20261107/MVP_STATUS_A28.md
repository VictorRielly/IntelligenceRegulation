# A28: text for `docs/zkmatrix-poc/MVP_STATUS.md` (for the coordinator to merge)

Every number is [MEASURED] in `results/zk60_a28_app_20261107/README.md` unless marked. The A27 figures in the
row are this lane's own re-measurements of A27's pinned binary in the same jobs (2026-11-10, after the reboot;
the machine measured about 3% slower than on 2026-11-07, when A27's row was written).

## The table row (after the A27 row)

| **the media app with lane A28's binary (the same receipts byte for byte; the commitments' GPU time cut by 9%, one proof's by 3.9%; two server settings; development mode `shieldstral-fast`, privacy statement pending, not production)** | A27 re-measured beside it: native stream 16.42 tok/s, one post 43.3 s, proof only 17.75 | **native stream 16.66 tok/s with the binary alone (+1.5%), 16.90 with the two settings (+2.9%; A B C C B A, mirrored order); one post 42.0 s (-3%); proof only 17.82 (no difference); through the app: stream 16.8 tok/s, one long post 125.5 s, one post APP_ONE** [MEASURED; app rows single runs] |

## The bullet (after the A27 bullet)

- **The media app's commitment kernels at the device's limits, and scheduling measured out (A28, 2026-11-09/10)**
  [MEASURED; `results/zk60_a28_app_20261107/README.md`].
  - Two byte-identical kernel changes: the commitment's forward transform skips the zero half of its first pass
    (the rows are zero-padded fourfold), and the column hash runs as BLAKE3's own tree in two passes. The
    commitments' GPU time fell 9% (A 42.4 -> 38.6 ms, H 40.5 -> 36.8 ms per block) and one proof's GPU time
    5.04 -> 4.84 s. Deeper radix passes, in-register tails and rewritten field arithmetic lost or tied: the
    transform now runs at the device's 64-bit arithmetic rate, its tail and hash at about 500 GB/s.
  - Scheduling does not fill the GPU's idle gaps. Seal-ahead (a lane seals its next request beside the running
    one) works on one lane but gives +1.3% on six for 60 GiB more memory: built, tested in both modes, off by
    default. More threads a lane (8, 10), more lanes (8) and two server processes give the same stream: about
    one category proof every 6 to 6.5 s in its rounds, whatever the setting.
  - Why: a proof that takes 19.6 s alone takes 38 s beside five others on the same five threads. It waits 12 to
    15 s for the one shared device instead of 5.4 s, and its host work takes 29 to 31 s instead of 16 s (every
    host section, serial ones included, 1.3x to 3x slower in company).
  - A B C C B A against A27, every receipt freshly verified: the 8-post stream 16.42 -> 16.66 proved tok/s with
    the binary alone (+1.5%), 16.90 with A7's spin-then-block wait and a 300 ms stagger between request starts
    (+2.9%; the prover's CPU per proof 84 -> 65 CPU-s); one post 43.3 -> 42.0 s; proof only 17.75 -> 17.82.
    Through the app (single runs): the stream 16.8 tok/s, one long post 125.5 s.
  - **Byte identity on the real export** (A26's fixed-entropy harness): A27's binary, A28's, A28 with every
    switch off, and A28 on one lane with seal-ahead on and off make identical receipts, every file of every
    category; the six trained profiles' recorded digests (the 8B profiles included) hold on CPU and Metal, and
    the 8B stack's server tests pass on the device; the full lib suite has exactly its 3 known failures. The
    app pins the A28 binary (`80f2b704…`, the committed tree's build); identity `e4f97455…` unchanged; 219 app
    tests OK.
  - **30 tok/s is not reached (about 1.8x short, as after A27), and no byte-preserving scheduling change will
    reach it.** What is left, with this lane's estimates [INFERRED]: rows of W16R2's size (the protocol lever,
    Victor's ruling: about 22 to 25 tok/s on this stream), a second GPU (about 1.9x), the prover's re-checks
    from the startup records (`HL_A26_KEPT`, a reading like D72/D74: about +5%), the classifier tables' digests
    (+2 to 3%), the device sumcheck slots (+3%).
  - For the privacy gate: the two kernels branch on shapes only; `gpu/metal.rs` and `gpu/metal_kernels.metal`
    have new digests to re-read. Seal-ahead, if someone turns it on, holds two requests' witnesses per lane.
