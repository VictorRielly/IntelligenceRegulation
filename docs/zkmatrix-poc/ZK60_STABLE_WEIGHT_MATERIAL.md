# Stable-weight registration material: protected storage

This is Codex's next FA4 H2 component after the [public slot journal](ZK60_STABLE_WEIGHT_SLOTS.md).
It encrypts registration material and reconstructs its exact CPU PCS commitment.
It does **not** enable a stable P3 prover, authenticate model approval, establish
an int8 weight/gamma range premise, or close the repeated-proof privacy review.
FA4 H2's complete registration/prover integration remains open.

## Scope and API

Enable `hashline`'s `stable-weight-storage` feature to access
`hashline::stable_weight_material`. The dependencies are optional and remain
outside `zkp-core`. Existing default builds, proof formats and PCS algorithms
are unchanged. The existing public journal remains available without this feature.

- `MaterialKey::from_bytes([u8; 32])` imports an externally protected, uniformly
  random key. It has no Debug, Clone or serialization API. This is not a password
  KDF, key vault, key-distribution protocol or deterministic proof seed API.
- `MaterialPolicy::new(slots, mask_rows, prox_mask_row)` binds an independently
  trusted `SlotPolicy` and independently supplied row roles. Mask rows must be
  unique and in range; the optional proximity row must be in range and separate.
  Their **order** is bound. The caller must establish that these roles implement
  the reviewed schedule identified by the slot policy's layout digest. This
  module neither derives that schedule nor judges its privacy.
- `create_material(path, key, policy, material, limits)` checks the supplied
  PCS geometry, options and roles, then rebuilds the root from data, pads and
  salts before touching the destination file. It does not trust the supplied
  cached encoding or tree as evidence for those secrets.
- `load_material(path, key, policy, limits)` authenticates an existing file,
  parses canonical field values, rebuilds the CPU encoding/Merkle tree and
  compares the root with the independently trusted commitment. It returns a
  `RestoredMaterial` whose `pcs()` accessor borrows the reconstructed commitment.
  Its roles come from the trusted policy, not the file.

No function creates, resets or spends journal slots. At first registration the
caller must durably register the material and its one canonical journal before
exposing the commitment for use. Reopening an existing registration must open
the existing journal and load the matching material; a missing/corrupt/exhausted
journal must never trigger fresh registration. A future stable prover must
consume the durable `ReservedSlot` and enforce the corresponding reviewed mask
schedule. The low-level accessor is not that integrated proof boundary.

## Encryption and byte format

The locked implementation uses RustCrypto `chacha20poly1305` 0.10.1 with
XChaCha20Poly1305 and `zeroize` 1.9.0. The former provides a 256-bit key,
192-bit nonce and 128-bit authentication tag; its
[upstream API and security notes](https://docs.rs/chacha20poly1305/0.10.1/chacha20poly1305/)
describe the construction and supported CPU assumptions. This use is tested on
the project's x86-64 Linux/WSL host; it is not a new cryptographic construction
or an independent audit of the dependency.

The file consists of:

| Bytes | Contents |
|---|---|
| 0–7 | ASCII `HLWMAT01` |
| 8–39 | Material-policy BLAKE3 digest |
| 40–63 | Fresh OS-generated 24-byte nonce |
| 64 onward | Encrypted payload, followed by the 16-byte AEAD tag |

The **entire 64-byte header** is AEAD associated data. The material-policy digest
hashes the domain `hashline-stable-material-policy-v1/`, the slot-policy digest,
mask-row count and ordered indices, and the proximity index (`u64::MAX` for
None). Integers in that digest input are unsigned 64-bit little-endian words.
The slot-policy digest already binds the manifest, layer, layout, commitment,
PCS parameters, hiding options and opening budget.

The plaintext is exactly `rows*n` data field words, `rows*q_pad` pad field words,
and `nn` 32-byte salts, in that order. Field words are canonical unsigned 64-bit
little-endian values strictly below the Goldilocks modulus. All dimensions come
from the trusted policy. No file-supplied lengths, seeds, encoded rows, cached
trees, row-role metadata, keys or opening counters are serialized.

Each creation obtains its nonce using an exact read from `/dev/urandom` and
propagates an entropy error; there is no fixture-seed fallback. Identical
material encrypted twice has different ciphertext. Authentication precedes
field parsing and root reconstruction. A rewritten clear policy header cannot
substitute a different trusted policy without invalidating the tag.

## Storage and memory contract

Storage assumes trusted local Unix directories and filesystem behavior.
Creation uses `create_new` with owner-only permissions and syncs the completed
file and its parent directory before success. Existing files, including empty
or corrupt files, are never overwritten or removed. A failed write/sync may
leave an incomplete or complete file; reopening refuses the former and validates
and syncs the latter before exposing material. There is no automatic recovery
that resets state. Reopening requires a regular file with no group/other access,
the exact expected length and no trailing bytes. Other platforms are unsupported;
other Unix filesystems are not qualified by the Linux/WSL tests.

Default trusted allocation limits are 64 MiB of file bytes and 16,777,216 encoded
field elements. Checked arithmetic and those bounds precede payload allocation
and NTT construction. They are configurable implementation limits, not total-RSS
limits, approved model sizes, proof security parameters or distance guarantees.

Owned keys, plaintext byte buffers and reconstructed data/pads/salts/encoded
vectors are wiped on ordinary drop. Refused parsed/reconstructed vectors have
the same guards. Existing PCS temporary copies, the caller's input commitment,
caller-created copies, process aborts, swap and core dumps are outside this
guarantee. The host must protect the external key; the library does not write it.

AEAD protects encrypted-file confidentiality and integrity under its assumptions.
It does not authenticate approval, prevent trusted-key misuse or protect the
public journal against rollback, replacement, copied journals or restored
backups. Those journal threats still require an external monotonic authority.

## Validation and next integration

The storage tests cover exact root/data/pads/salts/encoded-row and ordinary PCS
opening-byte parity; fresh nonces and private file permissions; wrong keys;
corruption at every byte offset; truncated/trailing data; changed policies and
row roles, including clear-header substitution; authenticated noncanonical
field words and inconsistent roots; malformed source material; allocation
limits/overflow; and a separate-process reload preserving spent and exhausted
journal slots. Two compile-fail examples guard accidental key formatting and
material cloning. All material and keys in these tests are public synthetic
fixtures, not registered model secrets. The ordinary PCS parity test makes no
new privacy claim about the legacy opening protocol.

[Round 14's local registration handle](ZK60_STABLE_WEIGHT_REGISTRATION.md)
now coordinates this store with the journal, an external key-provider callback,
durable publication and reserved material access. It refuses incomplete state
and derives one registration directory per root within the configured registry.
Remaining H2 work includes the reviewed stable-weight mask-layout generator,
authenticated approver/application integration and protected key provisioning.
H3/H4 then need the prover that consumes a slot and the corresponding verifier
policy. FA6–FA8's complete masking/transcript and bounded-reuse review remains
the protocol integration gate. Fable's PCS extraction now supplies the canonical
helpers from the core; this host storage module remains outside it.
