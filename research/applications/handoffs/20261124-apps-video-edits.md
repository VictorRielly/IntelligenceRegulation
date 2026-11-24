# Proving edits to a short video

A useful first receipt would let a viewer check that a published clip consists of specified frames from a signed capture, with a declared crop and redaction. The recorder must bind the ordered frames, timestamps, dimensions and pixel format. The prover sees the original footage. A trusted camera can record a screen playing generated content. A valid edit receipt establishes the recording and transformation history subject to that trust. [Capture study](20261124-apps-captured-image.md) · [Project privacy requirements](../../../docs/zkmatrix-poc/ZK60_PRIVACY_REQUIREMENTS.md)

## Count the samples before pricing the proof

**DERIVED** for progressive RGB8 video, one committed value per color channel. Values per second = width × height × 3 × frames/s. These counts cover the input witness only. Encoding field elements, intermediate planes, openings and proof bytes have separate costs.

| Raster | RGB values per frame | At 30 frames/s | At 60 frames/s |
| --- | ---: | ---: | ---: |
| 1080p, 1,920 × 1,080 | 6,220,800 | 186,624,000 | 373,248,000 |
| UHD 4K, 3,840 × 2,160 | 24,883,200 | 746,496,000 | 1,492,992,000 |

For 8-bit YCbCr 4:2:0, one luma sample per pixel and two chroma samples per four pixels yield 1.5 stored samples/pixel. **DERIVED** at 30 frames/s, that is 93,312,000 and 373,248,000 samples/s respectively before padding. A proof over those samples must fix chroma layout and any conversion to the displayed RGB. Eva's encoding relation explicitly models subsampled macroblocks. [Eva, §3](https://research.birmingham.ac.uk/files/267378145/Eva_Zero_Knowledge_Video_Authentication.pdf)

| Edit | Relation a verifier could check |
| --- | --- |
| Cut | Bind an allowed source interval, output count and timebase. For a sequence of signed or committed frame digests, copying an unchanged frame can use its indexed opening. The output sequence must account for every selected frame in order. |
| Crop | With a fixed rectangle, output pixel `(x,y)` equals source pixel `(x+left,y+top)` in the corresponding frame. Bind rectangle bounds, all output channels and the output digest. |
| Redact a region | Copy pixels outside an authenticated mask and use a specified fill inside. This certifies which region changed. Whether the region covers every face or identifying detail requires a separate test. |
| Change frame rate | For a declared drop/duplicate rule, pin presentation timestamps and their mapping to source frames. Linear blending needs an arithmetic and rounding rule. Motion interpolation introduces its own model and relation. |
| Deliver a lossy re-encode | An ordinary hash of the edited raw frames cannot authenticate an H.264 bitstream. Prediction, transform and quantization, codec parameters and the binding to the actual stream need a codec-specific relation. Eva demonstrates one approach. The current project has no qualified video encoder proof. |

Bind or explicitly exclude audio, subtitles, rotation and variable frame timing. A valid visual-only proof leaves those streams outside its claim.

## Published measurements

- **[Source's numbers]** VIMz reports 187.1 s of proving and 0.7 GB peak memory for a fixed-origin HD still-image crop on its mid-range laptop. Its HD blur took 555.3 s and 2.5 GB. Those are measurements for individual image transformations. [Authors' implementation and benchmarks](https://github.com/zero-savvy/vimz#performance)
- **[Source's numbers]** Zhang and colleagues report a 448-byte Eva proof for a two-minute 1,280 × 720 H.264 video at 30 frames/s, produced in about 2.4 hours with their accelerated implementation. Their construction binds signed source video and metadata to declared edits and the encoded stream. It uses information that the verifier can derive from the public stream. **DERIVED** 2.4 hours / 2 minutes ≈ 72 times playback duration in that experiment. No measurement transfers directly to this project's prover. [IEEE paper](https://ieeexplore.ieee.org/abstract/document/11023495) · [Authors' protocol and evaluation](https://research.birmingham.ac.uk/files/267378145/Eva_Zero_Knowledge_Video_Authentication.pdf)

## A reproducible first test

**COUNTED locally, byte reference only.** Generate 60 row-major RGB8 frames of 96 × 64 at 30 frames/s. Channel value = `(frame + 3*x + 5*y + 17*channel) mod 256`, using zero-based indices. Keep even source frames at 15 frames/s, crop a 48 × 32 rectangle with origin (16,8), and fill output coordinates `4 ≤ x < 12, 5 ≤ y < 11` with black. Row slicing followed by filling and a separate direct coordinate formula agreed on all **138,240 output bytes**. SHA-256 of concatenated raw frames was `847ad23e26dc7dae3984dcaa7851fb0755f09264b89d674acccefd131142e60c` for the 1,105,920-byte input and `26e6cbf119b2a36ba4d60f48e1345589c2bc17703948d6c1a3c0ea4194632e57` for the output. Swapping the first two frames, omitting the last or flipping its last channel bit each changed the output digest.

The first proof test should sign a versioned input sequence with an explicitly synthetic recorder, prove that the private frames open that commitment, then verify the public output, timebase and exact operation list in a fresh process. Reject a changed crop origin, an unauthorized cut and a substituted output. Measure proof bytes and checking time before scaling the raster. This handoff qualified the reference arithmetic only. Hardware capture, a video proof, codec support and production privacy remain open.
