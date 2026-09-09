#!/usr/bin/env python3
"""Research-only deferred Merkle preparation in a programmable random oracle.

This is oracle bookkeeping, NOT a BLAKE3 simulator or a complete PCS simulator.
SimPrepare chooses roots before SimOpen receives columns. One table serves
nodes, inner column hashes and salted leaves; previously answered points cannot
be programmed. Columns must come from a separately justified joint sampler.
There is deliberately no import-from-existing-root construction.
"""
import argparse
import hashlib
import json
from pathlib import Path
import secrets

P = 2**64 - 2**32 + 1


class Refused(ValueError):
    pass


class RandomOracle:
    def __init__(self, random_bytes=secrets.token_bytes):
        self.random_bytes = random_bytes
        self.table = {}
        self.programmed = set()

    def query(self, message):
        if message not in self.table:
            self.table[message] = self.random_bytes(32)
        return self.table[message]

    def program_fresh(self, message, output):
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
    return oracle.query(left + right)


def verify(oracle, root, index, values, salt, path):
    if type(index) is not int or not 0 <= index < 2048 or len(path) != 11 or len(salt) != 32:
        return False
    current = oracle.query(oracle.query(column_bytes(values)) + salt)
    for sibling in path:
        if len(sibling) != 32:
            return False
        current = node(oracle, sibling, current) if index & 1 else node(oracle, current, sibling)
        index >>= 1
    return current == root


class PreparedSimulation:
    """Owns a simulator-created tree; carries no endpoint values or real owner state."""
    def __init__(self, oracle):
        self.oracle = oracle
        self.spent = False
        # These are independent random digest handles, not hashes of a hidden
        # witness. Opening later will explain only the selected leaves.
        self.levels = [[oracle.random_bytes(32) for _ in range(2048)]]
        while len(self.levels[-1]) > 1:
            previous = self.levels[-1]
            self.levels.append([node(oracle, previous[i], previous[i+1])
                                for i in range(0, len(previous), 2)])
        self.root = self.levels[-1][0]

    def open_once(self, expected_root, indices, columns):
        if self.spent:
            raise Refused("simulation owner already consumed")
        self.spent = True  # burn on failure too; publish no partial opening
        if expected_root != self.root:
            raise Refused("root was not issued by this simulation state")
        if len(indices) != 256 or len(columns) != 256:
            raise Refused("expected exactly 256 query positions and columns")
        opened, result = {}, []
        for index, values in zip(indices, columns):
            if type(index) is not int or not 0 <= index < 2048:
                raise Refused("endpoint index outside domain")
            encoded = column_bytes(values)
            if index in opened:
                entry = opened[index]
                if entry[0] != encoded:
                    raise Refused("inconsistent duplicate column")
                result.append(entry[1])
                continue
            inner = self.oracle.query(encoded)
            salt = self.oracle.random_bytes(32)
            # Same 64-byte input domain as node(): never an independent table.
            self.oracle.program_fresh(inner + salt, self.levels[0][index])
            path, at = [], index
            for level in self.levels[:-1]:
                path.append(level[at ^ 1])
                at >>= 1
            opening = (index, list(values), salt, path)
            opened[index] = (encoded, opening)
            result.append(opening)
        return result


def experiment():
    oracle = RandomOracle()
    owners = [PreparedSimulation(oracle), PreparedSimulation(oracle)]
    roots = [owner.root for owner in owners]  # public before columns are chosen
    # Deterministic query positions deliberately include duplicates. The column
    # choices are arbitrary diagnostic values, not a sampled valid PCS view.
    indices = [(i * 37) % 241 for i in range(256)]
    columns = [[(j + 1) * (row + 1) for row in range(7)] for j in indices]
    rows = []
    for owner, root in zip(owners, roots):
        openings = owner.open_once(root, indices, columns)
        assert all(verify(oracle, root, *op) for op in openings)
        rows.append(dict(root=root.hex(), positions=len(openings), unique_columns=len(set(indices)),
                         every_path_accepts_under_original_root=True))
    return dict(schema=1, status="passed", endpoints=rows,
                programmed_salted_leaf_inputs=len(oracle.programmed),
                one_shared_oracle_table=True, preexisting_points_reprogrammed=0,
                simulator_generated_roots=True, root_only_simulation=False,
                actual_blake3_programmed=False, columns_sampled_from_PCS_distribution=False,
                full_privacy_review_complete=False,
                scope="executable consistency of deferred Merkle preparation/opening in an ideal programmable oracle",
                tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = experiment()
    with args.out.open("x") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    print("PASS: two preparation-issued roots, 512 consistent openings, one oracle table")


if __name__ == "__main__":
    main()
