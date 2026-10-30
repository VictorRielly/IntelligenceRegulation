# Hash and registry gates before R13 activation

The source-pin/hash-call/absorb checks passed on the58-test public-helper
tree. The subsequently installed twelve profile entries are being compiled;
their complete profile/hash-kind census is not yet extended or accepted.

S24 H-4, S25 W-2/W-7 and S33's built-profile comparison each read every
profile literal in shape.rs/run.rs. Add the twelve R13 block shapes to those
comparisons through a dedicated accuracy_profile_tests::registered_shapes
fixture. Do not append them indiscriminately to the old trained fixture
list: unrelated older relation tests deliberately execute the legacy define
body. R13 run profile entries still need their own registration and fixtures.

## D2 has a bounded family of lengths

BlockPublic::digest already binds AccuracyPublic::encode, and trained model
layer records already bind that actual BlockPublic digest (check_against
compares it). No separate unbound calibration preference is needed.

The D2 public/weights hash INPUT LENGTH changes with1..4 SiLU groups. Update
the independent S25 census to cover all four lengths, rather than auditing
one convenient group count. hash_domain.rs deliberately delegates D2/D3/D5
to this census because the layout-time guard does not hold their inputs;
retain that existing boundary rather than changing it without need.
The fixed framing of the new encoding is:

-19-byte zk60-low-public/v2\0 domain;
-u32 registry length + registry bytes; u32 stack length + stack bytes;
-four u64 geometry values; nine u32 base shifts; two i32 member exponents;
-seven u64 lengths + all u16 multiplier words;
-u64 group count + two i32 values per group;
-u64 channel-ID count + u64 IDs for every true hidden channel;
-u64 table length +4096 i16 words per group.

Then D2 adds12-byte R13-accuracy +u64 encoding length +that encoding after
the unchanged attention/FFN public framing. The old FFN act[256] remains in
that existing framing even while the R13 relation uses the new tables.

Derive a bounded encoded-length helper and compare it byte-for-byte with
real encodings for both stacks/registries and every1..4 group count. Derive
the independent S25 formula separately. Gate common shift has fixed u32
encoding; group IDs/tables have constructor-checked shapes, so their values
do not introduce any further length case.

Also correct the D2 shape formula to use q_pad*d_pad for Wq and
d_pad*q_pad for Wo. Its old d_pad*d_pad formula happened to agree at the
three model geometries, including Shieldstral's padded Q/D widths, but not
at the decoupled-head development geometries. Retained byte checks remain
required; a metadata/classifier correction must not move a legacy transcript.

No new hash constructor is introduced by the installed components. The
existing call-site and absorb censuses must still be run after every source
integration, and the full profile census must be green before the long suite.
