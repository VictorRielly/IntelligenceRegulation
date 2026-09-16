#!/usr/bin/env python3
"""Research-only ideal-oracle bookkeeping for the two endpoint simulation experiments.

This tool is ORACLE BOOKKEEPING, not a BLAKE3 simulator, not a PCS simulator and
not a whole-proof distance bound.  It extends the round-23 deferred-preparation
model (scripts/zk60_endpoint_simulation.py) with the two simulators the endpoint
security decision distinguishes (docs/zkmatrix-poc/ZK60_ENDPOINT_SIMULATION_MODEL.md):

  JointSim     -- the "joint preparation and proof" experiment.  The simulator
                  builds honest trees over ZERO-data columns with fresh salts using
                  ordinary oracle queries, issues the endpoint roots first, and later
                  opens any 256 requested positions with genuine paths.  It programs
                  nothing: programmed_points == 0.

  RootOnlySim  -- the "external statement, root-only" experiment.  An
                  HonestCommitter (separate object, private state) builds a real tree
                  over hidden data with hidden salts through the SAME oracle and
                  publishes only its root R.  The simulator receives R and nothing
                  else, builds a fresh zero-data tree with fresh salts up to its two
                  top-level child digests (l', r'), and programs the single 64-byte
                  point l'||r' -> R with program_fresh (refusing if that point was
                  already answered).  It then serves openings whose 11-sibling paths
                  end at the programmed top pair.  Exactly ONE programmed point per
                  endpoint root, two per proof.

One table serves every hash use.  In the maintained source (zkp-core/src/pcs.rs
salt_leaf, zkp-core/src/merkle.rs hash_pair)

    salt_leaf(column_digest, salt) = BLAKE3(column_digest || salt)
    hash_pair(left, right)         = BLAKE3(left || right)

are the same untagged 64-byte call, so here salt_leaf IS node: a prior node query
blocks programming of the identical salted-leaf input and vice versa.  Inner column
digests are the 56-byte call on the seven canonical words.  Tree geometry follows
the endpoint commitments: 2048 salted leaves, 11-sibling paths, 256 opened positions.

Local bound (oracle bookkeeping only).  Let q be the number of 64-byte points the
oracle has answered before RootOnlySim programs l'||r'.  l' and r' are answers to
fresh queries over fresh 256-bit salts, so each is uniform on 32 bytes independent
of the earlier table; the programmed point coincides with an answered point with
probability at most q / 2^256, and the tool refuses on that event instead of
changing an earlier answer.  A distinguisher detects the simulation by holding two
distinct 64-byte preimages of R (the honest top pair l||r and the simulator's
l'||r').  Holding the honest pair requires the committer's secret salts (every leaf
is oracle(column_digest || salt) with a 256-bit salt) or guessing a 256-bit value,
a 2^-256-per-guess event.  These are the local fresh-query and preimage-guessing
bounds for this hash layer.  They are NOT a whole-proof distance bound: they omit
the coupling to committed polynomials, sumcheck and CFS messages, terminal masks,
preparation side information, refusal history and every other bad event.  Real
BLAKE3 cannot be programmed; nothing here yields a receipt the real verifier accepts.
"""
import argparse
import hashlib
import json
from pathlib import Path
import secrets

P = 2**64 - 2**32 + 1
LEAVES = 2048
DEPTH = 11          # log2(LEAVES): siblings per authentication path
POSITIONS = 256     # opened positions per endpoint commitment
ZERO_COLUMN = (0,) * 7


class Refused(ValueError):
    pass


def seeded_bytes(seed):
    """Deterministic byte source (SHA-256 counter stream) so evidence runs are reproducible."""
    prefix = b"zk60_root_simulator/" + int(seed).to_bytes(8, "little")
    counter = [0]

    def random_bytes(count):
        out = bytearray()
        while len(out) < count:
            out += hashlib.sha256(prefix + counter[0].to_bytes(8, "little")).digest()
            counter[0] += 1
        return bytes(out[:count])
    return random_bytes


class RandomOracle:
    """One lazily sampled table for every hash use; answered points are never changed."""

    def __init__(self, random_bytes=secrets.token_bytes):
        self.random_bytes = random_bytes
        self.table = {}
        self.programmed = set()

    def query(self, message):
        if message not in self.table:
            self.table[message] = self.random_bytes(32)
        return self.table[message]

    def program_fresh(self, message, output):
        if len(message) != 64:
            raise Refused("programmed point must be one 64-byte hash call")
        if message in self.table:
            raise Refused("oracle point already answered")
        if len(output) != 32:
            raise Refused("oracle output width")
        self.table[message] = output
        self.programmed.add(message)


def column_bytes(values):
    if len(values) != 7 or any(type(v) is not int or not 0 <= v < P for v in values):
        raise Refused("expected seven canonical endpoint field words")
    return b"".join(v.to_bytes(8, "little") for v in values)


def node(oracle, left, right):
    """hash_pair: the untagged 64-byte call."""
    return oracle.query(left + right)


def salt_leaf(oracle, inner, salt):
    """salt_leaf is the SAME untagged 64-byte call as hash_pair (one table, one domain)."""
    return node(oracle, inner, salt)


def verify(oracle, root, index, values, salt, path):
    """Recompute a path through `oracle.query`; orientation matches MerkleTree::verify_path."""
    if type(index) is not int or not 0 <= index < LEAVES or len(path) != DEPTH or len(salt) != 32:
        return False
    current = salt_leaf(oracle, oracle.query(column_bytes(values)), salt)
    for sibling in path:
        if len(sibling) != 32:
            return False
        current = node(oracle, sibling, current) if index & 1 else node(oracle, current, sibling)
        index >>= 1
    return current == root


def build_levels(oracle, leaves, stop_width):
    """Levels from the leaves upward, ending at the first level of width `stop_width` (1 = root)."""
    levels = [list(leaves)]
    while len(levels[-1]) > stop_width:
        previous = levels[-1]
        levels.append([node(oracle, previous[i], previous[i + 1]) for i in range(0, len(previous), 2)])
    return levels


def sibling_path(levels, index):
    path, at = [], index
    for level in levels[:DEPTH]:  # exactly the eleven non-root levels
        path.append(level[at ^ 1])
        at >>= 1
    return path


def query_positions():
    """256 positions spanning the whole leaf range, with 16 deliberate duplicates."""
    distinct = [(i * 733) % LEAVES for i in range(POSITIONS - 16)]
    return distinct + distinct[:16]


class _Owner:
    """Shared once-only opening discipline: refuse foreign roots and second use; failure consumes."""
    spent = False
    root = None
    _levels = None

    def _column_and_salt(self, index):
        raise NotImplementedError

    def open_once(self, expected_root, indices):
        if self.spent:
            raise Refused("owner already consumed")
        self.spent = True  # burn on failure too; publish no partial opening
        if expected_root != self.root:
            raise Refused("root was not issued to this owner")
        if len(indices) != POSITIONS:
            raise Refused("expected exactly 256 query positions")
        result, seen = [], {}
        for index in indices:
            if type(index) is not int or not 0 <= index < LEAVES:
                raise Refused("endpoint index outside domain")
            if index not in seen:
                values, salt = self._column_and_salt(index)
                seen[index] = (index, list(values), salt, sibling_path(self._levels, index))
            result.append(seen[index])  # duplicates return the identical answer
        return result


class HonestCommitter(_Owner):
    """Real-world endpoint owner: hidden columns, hidden salts, a real tree through the shared oracle.

    Only `root` is published.  The underscore state never leaves this object except
    through the two negative-control exports, which model side information the
    security experiment may grant a distinguisher; they are not an interface.
    """

    def __init__(self, oracle, columns, salt_bytes=None):
        if len(columns) != LEAVES:
            raise Refused("expected 2048 columns")
        salt_bytes = salt_bytes or oracle.random_bytes
        self._columns = [tuple(c) for c in columns]
        self._salts = [salt_bytes(32) for _ in range(LEAVES)]
        self._inner = [oracle.query(column_bytes(c)) for c in self._columns]
        leaves = [salt_leaf(oracle, i, s) for i, s in zip(self._inner, self._salts)]
        self._levels = build_levels(oracle, leaves, 1)
        self.root = self._levels[-1][0]
        self.programmed_points = 0

    def _column_and_salt(self, index):
        return self._columns[index], self._salts[index]

    def secret_top_pair(self):
        """NEGATIVE CONTROL ONLY: a distinguisher holding the committer's secret salts could compute this."""
        return self._levels[DEPTH - 1][0], self._levels[DEPTH - 1][1]

    def secret_values(self, unopened_only_from=None):
        """NEGATIVE CONTROL ONLY: every private byte string (salts, column bytes, inner digests, non-root nodes).

        With `unopened_only_from` (an index list) return only the columns/salts of positions
        NOT in that list; sibling leaf digests of opened positions are revealed by any Merkle
        opening by design, so digests are excluded in that mode.
        """
        if unopened_only_from is not None:
            opened = set(unopened_only_from)
            out = set()
            for i in range(LEAVES):
                if i not in opened:
                    out.add(self._salts[i])
                    out.add(column_bytes(self._columns[i]))
            return out
        out = set(self._salts) | {column_bytes(c) for c in self._columns} | set(self._inner)
        for level in self._levels[:-1]:
            out.update(level)
        return out


class JointSim(_Owner):
    """Joint experiment: zero-data tree, fresh salts, ordinary queries only; root issued first."""

    def __init__(self, oracle, salt_bytes=None):
        salt_bytes = salt_bytes or oracle.random_bytes
        self._salts = [salt_bytes(32) for _ in range(LEAVES)]
        inner = oracle.query(column_bytes(ZERO_COLUMN))
        leaves = [salt_leaf(oracle, inner, s) for s in self._salts]
        self._levels = build_levels(oracle, leaves, 1)
        self.root = self._levels[-1][0]
        self.programmed_points = 0

    def _column_and_salt(self, index):
        return ZERO_COLUMN, self._salts[index]


class RootOnlySim(_Owner):
    """External-statement experiment: receives a fixed root R and nothing from its owner.

    Builds a fresh zero-data tree only up to the two top-level children (the top pair
    is never queried) and programs l'||r' -> R.  Refuses if that point was answered.
    """

    def __init__(self, oracle, root, salt_bytes=None):
        if len(root) != 32:
            raise Refused("expected a 32-byte root")
        salt_bytes = salt_bytes or oracle.random_bytes
        self._salts = [salt_bytes(32) for _ in range(LEAVES)]
        inner = oracle.query(column_bytes(ZERO_COLUMN))
        leaves = [salt_leaf(oracle, inner, s) for s in self._salts]
        self._levels = build_levels(oracle, leaves, 2)
        left, right = self._levels[-1]
        self.programmed_points = 0
        try:
            oracle.program_fresh(left + right, root)  # the ONLY programmed point for this root
        except Refused:
            self.spent = True
            raise
        self.programmed_points = 1
        self.programmed_point = left + right
        self.root = root

    def _column_and_salt(self, index):
        return ZERO_COLUMN, self._salts[index]


class Distinguisher:
    """Sees roots, openings and its own oracle answers; recomputes every path itself."""

    def __init__(self, oracle):
        self._oracle = oracle
        self.log = {}         # every oracle message it asked -> answer
        self.roots = []
        self.openings = []    # (root, opening)

    def query(self, message):
        answer = self._oracle.query(message)
        self.log[message] = answer
        return answer

    def receive_root(self, root):
        self.roots.append(root)

    def receive_openings(self, root, openings):
        if root not in self.roots:
            self.roots.append(root)
        self.openings.extend((root, op) for op in openings)

    def verify_all(self):
        return bool(self.openings) and all(verify(self, root, *op) for root, op in self.openings)

    def preimages(self, root):
        """Distinct 64-byte inputs this distinguisher has seen answered with `root`."""
        return {m for m, a in self.log.items() if a == root and len(m) == 64}

    def collision_detected(self, root):
        return len(self.preimages(root)) >= 2

    def visible_values(self):
        out = set(self.roots)
        for _, (index, values, salt, path) in self.openings:
            out.add(column_bytes(values))
            out.add(salt)
            out.update(path)
        for message, answer in self.log.items():
            out.add(message)
            out.add(answer)
            if len(message) == 64:
                out.add(message[:32])
                out.add(message[32:])
        return out


def hidden_columns(random_bytes):
    raw = random_bytes(LEAVES * 7 * 8)
    words = [int.from_bytes(raw[i:i + 8], "little") % P for i in range(0, len(raw), 8)]
    return [tuple(words[7 * j:7 * j + 7]) for j in range(LEAVES)]


def run_joint(oracle, indices):
    sims = [JointSim(oracle), JointSim(oracle)]
    dist = Distinguisher(oracle)
    for sim in sims:
        dist.receive_root(sim.root)          # roots issued before any position is chosen
    for sim in sims:
        dist.receive_openings(sim.root, sim.open_once(sim.root, indices))
    return sims, dist


def run_root_only(oracle, indices, random_bytes):
    committers = [HonestCommitter(oracle, hidden_columns(random_bytes)) for _ in range(2)]
    fixed_roots = [c.root for c in committers]  # the only thing the simulator receives
    sims = [RootOnlySim(oracle, root) for root in fixed_roots]
    dist = Distinguisher(oracle)
    for root in fixed_roots:
        dist.receive_root(root)
    for sim in sims:
        dist.receive_openings(sim.root, sim.open_once(sim.root, indices))
    return committers, sims, dist


def exercise_refusals(oracle, indices):
    """Drive every refusal branch once; return the counts of refusals observed."""
    counts = {}

    def expect(name, action):
        try:
            action()
        except Refused:
            counts[name] = counts.get(name, 0) + 1
            return
        raise AssertionError(f"refusal {name} did not fire")

    committer = HonestCommitter(oracle, hidden_columns(oracle.random_bytes))
    other = JointSim(oracle)
    sim = RootOnlySim(oracle, committer.root)
    expect("root_only_different_root", lambda: sim.open_once(other.root, indices))
    expect("root_only_second_use_after_failure", lambda: sim.open_once(committer.root, indices))
    joint = JointSim(oracle)
    joint.open_once(joint.root, indices)
    expect("joint_second_use_after_success", lambda: joint.open_once(joint.root, indices))
    expect("joint_different_root", lambda: JointSim(oracle).open_once(other.root, indices))
    short = JointSim(oracle)
    expect("wrong_position_count", lambda: short.open_once(short.root, indices[:-1]))
    fixed = lambda count: b"s" * count
    JointSim(oracle, salt_bytes=fixed)  # queries the fixed-salt zero tree's top pair as an ordinary root
    expect("root_only_top_pair_already_answered", lambda: RootOnlySim(oracle, committer.root, salt_bytes=fixed))
    return counts


def experiment(random_bytes):
    oracle = RandomOracle(random_bytes)
    indices = query_positions()
    distinct = len(set(indices))

    joint_sims, joint_dist = run_joint(oracle, indices)
    assert joint_dist.verify_all()
    assert not any(joint_dist.collision_detected(r) for r in joint_dist.roots)
    joint_programmed = len(oracle.programmed)
    assert joint_programmed == 0

    committers, root_sims, root_dist = run_root_only(oracle, indices, random_bytes)
    assert root_dist.verify_all()
    assert not any(root_dist.collision_detected(r) for r in root_dist.roots)
    root_programmed = len(oracle.programmed) - joint_programmed
    assert root_programmed == 2
    secrets_visible = any(c.secret_values() & root_dist.visible_values() for c in committers)
    assert not secrets_visible

    informed = Distinguisher(oracle)
    for c in committers:
        left, right = c.secret_top_pair()
        informed.query(left + right)  # side information: the honest top pair (needs the secret salts)
    for root, op in root_dist.openings:
        informed.receive_openings(root, [op])
    assert informed.verify_all()
    informed_detects = all(informed.collision_detected(c.root) for c in committers)
    assert informed_detects

    refusals = exercise_refusals(oracle, indices)

    return dict(
        schema=1, status="passed",
        oracle_model="one lazily sampled table; hash_pair and salt_leaf are the same untagged 64-byte call; "
                     "inner column digests are the 56-byte call; answered points are never changed",
        geometry=dict(leaves=LEAVES, path_siblings=DEPTH, positions=POSITIONS, distinct_positions=distinct),
        experiments=dict(
            joint_preparation_and_proof=dict(
                roots_issued_by_simulator_before_positions=True,
                endpoints=[dict(root=s.root.hex(), positions=POSITIONS, distinct_positions=distinct,
                                every_path_verifies_under_issued_root=True, programmed_points=s.programmed_points)
                           for s in joint_sims],
                programmed_points=joint_programmed),
            external_statement_root_only=dict(
                simulator_receives="fixed root only; no columns, salts, owner or oracle history from the committer",
                endpoints=[dict(fixed_root=s.root.hex(), positions=POSITIONS, distinct_positions=distinct,
                                every_path_verifies_under_fixed_root=True, programmed_points=s.programmed_points,
                                programmed_point_is_top_pair=all(op[3][-1] in (s.programmed_point[:32], s.programmed_point[32:])
                                                                 for r, op in root_dist.openings if r == s.root))
                           for s in root_sims],
                programmed_points=root_programmed,
                honest_secrets_visible_to_distinguisher=secrets_visible,
                collision_detected_without_side_information=False,
                collision_detected_holding_honest_top_pair=informed_detects)),
        refusals_exercised=refusals,
        oracle_points_answered=len(oracle.table),
        local_bound=dict(refusal_probability_per_programmed_point="<= q / 2^256 with q prior answered points",
                         collision_detection_requires="the honest top pair: the committer's secret salts or a 2^-256-per-guess event",
                         whole_proof_distance_bound=False),
        claims_not_made=dict(actual_blake3_programmed=False, real_verifier_receipt=False,
                             columns_sampled_from_PCS_distribution=False, full_privacy_review_complete=False),
        tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description="ideal-oracle bookkeeping for the joint and root-only endpoint simulators")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20260915, help="DRBG seed; omit for the default reproducible run")
    args = parser.parse_args()
    result = experiment(seeded_bytes(args.seed))
    result["seed"] = args.seed
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    joint = result["experiments"]["joint_preparation_and_proof"]["programmed_points"]
    root_only = result["experiments"]["external_statement_root_only"]["programmed_points"]
    print(f"PASS: joint programmed {joint}, root-only programmed {root_only}, "
          f"{result['geometry']['distinct_positions']} distinct of {POSITIONS} positions per endpoint, "
          f"{sum(result['refusals_exercised'].values())} refusals exercised")


if __name__ == "__main__":
    main()
