# What a receipt can say about a 12-megapixel capture

A7 asks whether a verifier can recognize an unchanged capture, check a permitted edit while the original stays private, or check that a screen-recapture detector ran. I read the app’s image intake, the standalone image receipt, the local GPU measurements and three image-proof systems. The prover operator sees the original. A camera pointed at a screen can genuinely capture what it displays. [Project privacy requirements](../../../docs/zkmatrix-poc/ZK60_PRIVACY_REQUIREMENTS.md) · [Audio capture analogue](../../../docs/provenance/MUSIC_PROVENANCE_POC.md)

## Statements and missing components

| Claim | What the verifier needs |
| --- | --- |
| Identical file | Recompute the exact file hash, verify the device’s signed manifest and trust chain, and validate the timestamp evidence. This uses zero committed pixel values. A trusted timestamp establishes existence by that time. A shutter-time claim needs a trusted capture clock or interval. [C2PA attestation and camera example](https://spec.c2pa.org/specifications/specifications/1.4/attestations/attestation.html) |
| Published edit of a private original | Bind the private witness to the signed capture, then check the stated operation against the entire published output. Fixed index maps or sparse linear maps express copy, crop, mask and neighborhood sums. Lookup and range checks express rounding. The project needs image-specific relations, authenticated indexing across tiles, endpoint openings and a verifier for the published raster and edit parameters. |
| Capture by an unnamed approved device | Prove knowledge of a valid signature over this capture under a hidden key belonging to an approved device set. Publish the issuer or set root, validity interval and revocation epoch. This needs signature and membership verification or an anonymous credential. Matrix products and lookup tables alone supply neither. Repeated stable identifiers or identifying metadata can still link captures. |
| Detector ran on this capture | Bind the same signed input through a versioned decode, orientation, color conversion, resize and layout to a pinned detector and its score or threshold. Trained matrix products, lookup and range arithmetic already run in the standalone image pipeline. A recapture detector, raw sensor processing, capture binding and a held-out screen-versus-scene evaluation remain to be supplied. A valid proof authenticates a model result. |

COUNTED in the upload handler, lines 453–487. The app discards the uploaded bytes, hashes a re-encoded RGB master and commits to a salted 224 × 224 tensor. MEASURED independently on this Mac, changing one channel sample in a 12 MP raster changed the master digest and produced exactly the same tensor. The trained standalone proof covers all 102 stages on one synthetic white canvas. Neither artifact establishes a signed original. [Upload path](../../../apps/proven-media/proven_media/app.py) · [Synthetic 12 MP check](../../../results/zk60_astra_20261026/a4_capture_preprocessing_20261124/RESULT.json) · [Standalone receipt](../../../results/zk60_astra_20261026/a4_decoder_recovery_20261123/REVIEW.md)

## Counts and work-machine estimates

DERIVED for a proposed representation. A 4,000 × 3,000 RGB8 source has 36 million byte-valued field cells. Materialize and commit the output as well, bind it to the published pixels, and for rounded averages commit one remainder per output channel. For neighborhood sum `s`, divisor `d` and byte output `y`, check `s + floor(d/2) = d*y + r` and `0 ≤ r < d`. Counts exclude padding, lookup helpers, masks, digest and credential witnesses.

| Fixed edit | Output cells | Remainders | Total committed cells | Estimated GPU time for commits and edit checks |
| --- | ---: | ---: | ---: | ---: |
| Crop a public 2,000 × 1,500 rectangle | 9M | 0 | 45M | 0.51 s |
| Resize to 2,000 × 1,500 by 2 × 2 averaging | 9M | 9M | 54M | 0.62 s |
| Opaque public rectangle, preserve all pixels outside it | 36M | 0 | 72M | 0.79 s |
| Full 3 × 3 box blur with repeated edge pixels | 36M | 36M | 108M | 1.19 s |

MEASURED on the M3 Ultra, W16R2 8B warm control. A+H commitments took 30.50 ms for (2,501 + 2,602) × 16,384 = 83,607,552 cells. Slot 18 took 21.34 ms for a 2²¹-point domain. ESTIMATE for the table assumes that commitment time scales with cell count and each proposed relation tile costs one entire reference slot. Use 18 source-byte tiles plus one output pass for copy/mask or two for average/range. For example, resize costs 30.50 × 54M / 83,607,552 + 21.34 × (18 + 2 × 5) = 617 ms. These hypothetical kernels exclude witness construction, tile wiring, capture hashing, signatures, openings and serialization. Actual lookup multiplicities and padding depend on the circuit. [Block timings](../../../results/zk60_w16r2_shield_block_20261120/README.md) · [Row census, line 218](../../../results/zk60_effplan_20261105/census.log) · [Slot geometry](../../../results/zk60_slot18_14_breakdown_20261117/README.md)

**Full prover planning estimate for a 12 MP crop.** [Source’s numbers] HyperVerITAS proved a 50% crop with signature knowledge on a 36 GB M3 laptop. Brakedown-127 took 58.2 s and 22.4 GB for 2²³ pixels, 130.9 s and 26.3 GB for 2²⁴. For an equivalent implementation on the work Mac, assuming the same elapsed time per size and giving it no Ultra speed credit, interpolation gives 58.2 + (130.9 − 58.2) × (12M − 2²³)/2²³ ≈ 90 s. Padding the whole input to 2²⁴ suggests 131 s. This estimates that particular crop protocol. The native project has no end-to-end capture-proof timing, and the signature/hash format matters. [HyperVerITAS, §§1 and 5.2, Table 3](https://petsymposium.org/popets/2026/popets-2026-0036.pdf)

[Source’s numbers] ZK-IMG cropped 1,280 × 720 to 720 × 480 on 64 AWS vCPUs. Proving took 7.8 s and 1.72 GB for the transform, 328.2 s and 70.7 GB with the input Poseidon hash, and 557.1 s and 139.1 GB with both hashes. VIMz reports 187.1 s and 0.7 GB for its fixed-origin HD crop and 555.3 s and 2.5 GB for HD blur on a Core i5 laptop. These measurements use different protocols and machines. [ZK-IMG, Tables 2, 4 and 5](https://arxiv.org/pdf/2211.04775) · [VIMz benchmarks](https://github.com/zero-savvy/vimz#performance)

## Deciding test

Use a synthetic signer over a versioned RGB8 raster and prove one fixed crop. Bind dimensions, orientation, colorspace, pixel encoding, public edit parameters and the entire output. Require fresh verification to reject a changed source under the original signature, a changed output pixel, a shifted crop and an untrusted signer. Compare edit-only and signed-input runs at the same sizes and report wall time, peak memory and receipt bytes. A JPEG- or raw-file signature also requires an authenticated decoder or a device-signed commitment to the decoded raster. No real camera, hidden credential or recapture accuracy was evaluated here.
