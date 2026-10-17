#!/usr/bin/env python3
"""**The D19 separating hash tag, on the Python side** — which BLAKE3 the
gate must compute when it replays a bundle, and how it decides.

Until decision D19 every hash in the proof was the same UNKEYED BLAKE3, so a
transcript absorb, a PCS column digest, a salted Merkle leaf and a Merkle
inner node were separated only by the LENGTH of their inputs.  That is the
LEGACY rule.  A TAGGED profile instead hashes in BLAKE3's KEYED mode under
one fixed public 32-byte key per domain, derived once from the profile's own
string (`zkp-core/src/hashtag.rs`):

    transcript   blake3.derive_key("hashline-zk-mr1 2026-09-20 fiat-shamir transcript", profile)
    column       blake3.derive_key("hashline-zk-mr1 2026-09-20 pcs column digest",      profile)
    leaf         blake3.derive_key("hashline-zk-mr1 2026-09-20 pcs salted merkle leaf", profile)
    node         blake3.derive_key("hashline-zk-mr1 2026-09-20 pcs merkle inner node",  profile)

**RE-DERIVE, NEVER CONSUME (ruling T-7).**  Every context string above is
pinned in THIS FILE, the list of legacy profiles is ported from
`Shape::hashes_under_the_legacy_rule` into THIS FILE, and the four keys are
computed HERE from the profile the bundle's own SHAPE names.  What the
bundle carries in `run.json["hash_tag"]` — the rule name, the profile, the
four contexts and the four keys as hex — is then COMPARED with what this
file derived, field by field.  A disagreement is a refusal by name.  No key,
context or rule is ever taken from a bundle and used.

**WHERE EACH KEY ACTS**, read from the Rust (`transcript.rs`, `merkle.rs`,
`pcs.rs`, all at the digests the caller pins):

* the TRANSCRIPT key keys `Transcript::new_tagged`, every `absorb` and every
  `squeeze_bytes` — so the run binding, every challenge, and the two
  position tags a segment squeezes from a DISCARDED CLONE (the clone carries
  the key: `clone_state`, transcript.rs:156) are all under it;
* the COLUMN key keys the digest of a committed column's little-endian
  bytes (`hash_column_keyed`, pcs.rs:148);
* the LEAF key keys `salt_leaf_keyed(leaf, salt)` (pcs.rs:691) — the one
  function that ends the leaf/node ambiguity, since under the legacy rule a
  salted leaf and an inner node are the SAME call on 64 bytes;
* the NODE key keys every Merkle inner node (`hash_pair_keyed`,
  merkle.rs:28) and therefore `verify_path_keyed`.

**WHAT IS NOT HERE.**  Nothing in this file is a privacy or soundness
statement.  It decides which hash function the replay computes, and it
refuses a bundle whose declared tag is not the one the profile implies.
"""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_field import Transcript  # noqa: E402

# --------------------------------------------------------- the pinned text
# `zkp-core/src/hashtag.rs:47-54`.  These four strings are the gate's own;
# a bundle's `hash_tag.contexts` is compared against them and never read in
# their place.
CTX_TRANSCRIPT = "hashline-zk-mr1 2026-09-20 fiat-shamir transcript"
CTX_COLUMN = "hashline-zk-mr1 2026-09-20 pcs column digest"
CTX_LEAF = "hashline-zk-mr1 2026-09-20 pcs salted merkle leaf"
CTX_NODE = "hashline-zk-mr1 2026-09-20 pcs merkle inner node"
CONTEXTS = {
    "transcript": CTX_TRANSCRIPT,
    "column": CTX_COLUMN,
    "leaf": CTX_LEAF,
    "node": CTX_NODE,
}
ROLES = ("transcript", "column", "leaf", "node")

KEYED_RULE_NAME = "blake3-keyed/1"      # hashtag.rs:59
LEGACY_RULE_NAME = "legacy"             # hashtag.rs:61

# `Shape::hashes_under_the_legacy_rule` (shape.rs:396), ported as the two
# profile strings it names and NOTHING else: every other profile is tagged,
# so a profile this file has never heard of is tagged, which is the
# fail-safe direction.  Both of these are development fixtures barred by
# name from any privacy statement (shape.rs:380-392).
LEGACY_PROFILES = (
    "hashline-zk-mr1/private-block-t32-poc/1",        # TOY_PROFILE, shape.rs:33
    "hashline-zk-mr1/private-block-rung-t24-dev/1",   # FROZEN_SEAM_RUNG_PROFILE, shape.rs:41
)

# The key pins of `hashtag.rs`'s own test `the_four_keys_of_each_tagged_
# profile_are_pinned`.  They are NOT used to build a rule -- `for_profile`
# derives every key it returns -- they are here so that a test can compare
# this file's derivation with the Rust's literals without a bundle.
PINNED_KEYS_HEX = {
    "hashline-zk-mr1/private-block-rung-g-t24-dev/1": {
        "transcript": "51b7d0b0171d54b5bb45fd42c3f9369cad87894b625e0569b89fac0036d20dbe",
        "column": "2295498fd6fd5e41320da717e9da89462e5c90a5b3b2d72ac496bcc157c2cd2c",
        "leaf": "fe211417895c73c4a70430cb9bfb7081289ec7532f2716d2a86f609b0de54032",
        "node": "8c4d2cfe7b8528d350f20dece1250c8d81596eb25d26bffda1247238f0f71fcc",
    },
    "hashline-zk-mr1/private-block-m125/1": {
        "transcript": "125f9b4d44ac3c46712a35419cdeda6c1428db443ccaf58da67f35b15b37291c",
        "column": "d5fc391cc58eed85631b4c3dabc7d377477eb1a0a725aeccaec0f4d10061b135",
        "leaf": "1dc6f7146ad501ede6d90b3071da2f3251d38137303ffcc0a6a48b7f89effe83",
        "node": "798eb64ff187f6f3e8e889ac4c4742607ac71a71fa09e2944a0ecc5e8a42026b",
    },
}


def derive_key(context: str, profile: str) -> bytes:
    """`blake3::derive_key(context, profile.as_bytes())` — note the argument
    order the Python module wants: the CONTEXT is `derive_key_context` and
    the PROFILE STRING's bytes are the hashed material."""
    import blake3

    return blake3.blake3(profile.encode(), derive_key_context=context).digest()


class KeyedTranscript(Transcript):
    """`zkp-core/src/transcript.rs` in BLAKE3's KEYED mode.

    A SUBCLASS, deliberately: `zk60_native_jv_field.Transcript` is a toy
    gate's module whose bytes are pinned by
    `tests/test_zk60_native_gate_record.py`, so the keyed rule may not be
    written into it.  Everything the parent does that is not a hash — the
    absorb framing, the counter, the challenge decoding, `peek_next` — is
    inherited unchanged, which is also the statement that only the hash
    FUNCTION differs between the rules.
    """

    def __init__(self, key: bytes, domain: bytes | None = None,
                 state: bytes | None = None, counter: int = 0):
        import blake3

        if len(key) != 32:
            raise ValueError("a BLAKE3 key is 32 bytes")
        self._blake3 = blake3
        self.key = bytes(key)
        if state is not None:
            self.state = bytes(state)
            self.counter = counter
        else:
            h = self._h()
            h.update(b"hashline-v1/")
            h.update(domain)
            self.state = h.digest()
            self.counter = 0

    def _h(self):
        return self._blake3.blake3(key=self.key)

    def clone(self) -> "KeyedTranscript":
        """`Transcript::clone_state` (transcript.rs:156): **the MODE travels
        with the clone** — the run's position tags are squeezed from a
        discarded clone, and a clone that lost the key would squeeze the
        legacy bytes."""
        return KeyedTranscript(self.key, state=self.state, counter=self.counter)

    def absorb(self, label: bytes, data: bytes) -> None:
        h = self._h()
        h.update(self.state)
        h.update(len(label).to_bytes(8, "little"))
        h.update(label)
        h.update(len(data).to_bytes(8, "little"))
        h.update(data)
        self.state = h.digest()

    def _squeeze(self) -> bytes:
        h = self._h()
        h.update(self.state)
        h.update(b"squeeze")
        h.update(self.counter.to_bytes(8, "little"))
        self.counter += 1
        out = h.digest()
        self.state = out
        return out


class HashRule:
    """Which BLAKE3 a profile hashes under: the legacy (unkeyed) rule, or one
    tagged profile's COMPLETE key set.  There is no third state and no
    constructor that takes key bytes (ruling T-7): a rule is built from a
    profile string, and its keys are derived here."""

    def __init__(self, profile: str | None, keys: dict | None):
        self.profile = profile
        self.keys = keys            # None => legacy
        self.name = LEGACY_RULE_NAME if keys is None else KEYED_RULE_NAME

    # ------------------------------------------------------- construction
    @staticmethod
    def legacy() -> "HashRule":
        return HashRule(None, None)

    @staticmethod
    def for_profile(profile: str) -> "HashRule":
        """`Shape::hash_tag` (shape.rs:405): the legacy rule for the two
        named fixture profiles, the complete derived key set for every
        other."""
        if profile in LEGACY_PROFILES:
            return HashRule(profile, None)
        return HashRule(profile, {r: derive_key(CONTEXTS[r], profile) for r in ROLES})

    @property
    def is_legacy(self) -> bool:
        return self.keys is None

    def key(self, role: str) -> bytes | None:
        return None if self.keys is None else self.keys[role]

    def keys_hex(self) -> dict:
        return {} if self.keys is None else {r: self.keys[r].hex() for r in ROLES}

    # ------------------------------------------------------------- hashing
    def _hasher(self, role: str):
        """The ONE place a hasher is chosen (`hashtag::hasher`, hashtag.rs:
        155).  With no key this is the identical unkeyed call."""
        import blake3

        k = self.key(role)
        return blake3.blake3() if k is None else blake3.blake3(key=k)

    def transcript(self, domain: bytes) -> Transcript:
        """`Transcript::new` or `Transcript::new_tagged`."""
        if self.is_legacy:
            return Transcript(domain=domain)
        return KeyedTranscript(self.key("transcript"), domain=domain)

    def column_digest(self, col_bytes: bytes) -> bytes:
        """`hash_column` / `hash_column_keyed` (pcs.rs:138, :148): one update
        over the column's little-endian `Fp` bytes."""
        h = self._hasher("column")
        h.update(col_bytes)
        return h.digest()

    def salt_leaf(self, leaf: bytes, salt: bytes) -> bytes:
        """`salt_leaf` / `salt_leaf_keyed` (pcs.rs:677, :691)."""
        h = self._hasher("leaf")
        h.update(leaf)
        h.update(salt)
        return h.digest()

    def node(self, left: bytes, right: bytes) -> bytes:
        """`hash_pair` / `hash_pair_keyed` (merkle.rs:14, :28)."""
        h = self._hasher("node")
        h.update(left)
        h.update(right)
        return h.digest()

    def verify_path(self, root: bytes, idx: int, leaf: bytes, path) -> bool:
        """`MerkleTree::verify_path(_keyed)` (merkle.rs:78, :103), with the
        LENGTH left to the caller exactly as the Rust leaves it
        (`verify_zk_tagged` makes the depth a check of its own, pcs.rs:1188)."""
        cur = bytes(leaf)
        for sib in path:
            s = bytes(sib)
            cur = self.node(cur, s) if idx & 1 == 0 else self.node(s, cur)
            idx >>= 1
        return cur == bytes(root)


# ===================================================================
#  the bundle's declared tag, against the gate's own derivation
# ===================================================================
def rule_for_bundle(bundle) -> dict:
    """**The selection, and the comparison.**

    The rule is decided HERE, from the BLOCK profile the bundle's own shape
    names, through `HashRule.for_profile` — this file's port of
    `Shape::hash_tag`.  The bundle's `hash_tag` member is then compared with
    that derivation, member by member; it never selects anything.

    One case is not a comparison, and it is named rather than hidden: a
    bundle written BEFORE stage 17 has no `hash_tag` member at all.  Its
    bytes were made under the legacy rule whatever its profile is now, so it
    is replayed under the legacy rule and marked `superseded`: a pre-tag
    bundle of a tagged profile is the verifier's view of a run made under a
    rule this profile's code no longer uses, and nothing measured on it is a
    statement about what the profile produces today.

    Returns a record; `refusals` non-empty means the gate must not replay.
    """
    prof_block = bundle.run.get("block_profile")
    prof_shape = bundle.run["shape"]["profile"]
    prof_run = bundle.run["profile"]
    out = {
        "what": "the hash rule, DERIVED here from the profile the bundle's shape "
                "names and then compared with the bundle's declared hash_tag "
                "(ruling T-7: re-derive, never consume)",
        "contexts_pinned_in_this_tool": dict(CONTEXTS),
        "legacy_profiles_pinned_in_this_tool": list(LEGACY_PROFILES),
        "block_profile": prof_shape,
        "run_profile": prof_run,
        "declared": None,
        "derived_rule": None,
        "derived_keys_hex": {},
        "keys_compared": 0,
        "contexts_compared": 0,
        "era": "tagged-schema",
        "superseded": False,
        "refusals": [],
        "findings": [],
    }
    f, refuse = out["findings"], out["refusals"]
    if prof_block is not None and prof_block != prof_shape:
        refuse.append(
            f"run.json: block_profile {prof_block!r} is not the shape's profile "
            f"{prof_shape!r}; the keys are the BLOCK shape's"
        )
    if prof_run == prof_shape:
        f.append(
            "run.json: the run profile equals the block profile; at this rung they "
            "differ (the transcript DOMAIN is the run's, the keys are the block's)"
        )
    rule = HashRule.for_profile(prof_shape)
    out["derived_rule"] = rule.name
    out["derived_keys_hex"] = rule.keys_hex()

    tag = bundle.run.get("hash_tag")
    if tag is None:
        out["era"] = "pre-tag"
        out["declared"] = None
        out["superseded"] = rule.name != LEGACY_RULE_NAME
        if out["superseded"]:
            f.append(
                "run.json carries no `hash_tag` member, so this bundle predates "
                "stage 17 and every byte of it was made under the LEGACY rule, "
                f"while the profile {prof_shape!r} is TAGGED in this tool's own "
                "port of Shape::hash_tag. It is replayed under the legacy rule "
                "and marked SUPERSEDED: nothing measured on it is a statement "
                "about what this profile produces now"
            )
        return {**out, "rule": HashRule.legacy()}

    out["declared"] = {
        "rule": tag.get("rule"),
        "profile": tag.get("profile"),
        "contexts": tag.get("contexts"),
        "keys_hex": tag.get("keys_hex"),
    }
    declared_rule = tag.get("rule")
    if declared_rule not in (LEGACY_RULE_NAME, KEYED_RULE_NAME):
        refuse.append(f"run.json hash_tag: rule {declared_rule!r} is not a known rule name")
        return {**out, "rule": None}
    if declared_rule != rule.name:
        refuse.append(
            f"run.json hash_tag: the bundle declares rule {declared_rule!r} while "
            f"the profile {prof_shape!r} hashes under {rule.name!r} in this tool's "
            "own port of Shape::hash_tag"
        )
        return {**out, "rule": None}
    if rule.is_legacy:
        for extra in ("profile", "contexts", "keys_hex"):
            if tag.get(extra) is not None:
                refuse.append(
                    f"run.json hash_tag: the legacy rule carries no {extra}, "
                    "and this bundle declares one"
                )
        return {**out, "rule": rule if not refuse else None}

    if tag.get("profile") != prof_shape:
        refuse.append(
            f"run.json hash_tag: profile {tag.get('profile')!r} is not the shape's "
            f"{prof_shape!r}"
        )
    got_ctx = tag.get("contexts") or {}
    for r in ROLES:
        if got_ctx.get(r) != CONTEXTS[r]:
            refuse.append(
                f"run.json hash_tag: the {r} context {got_ctx.get(r)!r} is not the "
                f"one pinned in this tool ({CONTEXTS[r]!r})"
            )
        else:
            out["contexts_compared"] += 1
    if sorted(got_ctx) != sorted(ROLES):
        refuse.append(
            f"run.json hash_tag: the context set is {sorted(got_ctx)}, not {sorted(ROLES)}"
        )
    got_keys = tag.get("keys_hex") or {}
    for r in ROLES:
        want = rule.keys[r].hex()
        if got_keys.get(r) != want:
            refuse.append(
                f"run.json hash_tag: the {r} key {str(got_keys.get(r))[:16]}... is not "
                f"the one derived here from the profile ({want[:16]}...)"
            )
        else:
            out["keys_compared"] += 1
    if sorted(got_keys) != sorted(ROLES):
        refuse.append(
            f"run.json hash_tag: the key set is {sorted(got_keys)}, not {sorted(ROLES)}"
        )
    if len({rule.keys[r] for r in ROLES}) != len(ROLES):
        refuse.append("the four derived keys are not pairwise distinct")
    return {**out, "rule": rule if not refuse else None}
