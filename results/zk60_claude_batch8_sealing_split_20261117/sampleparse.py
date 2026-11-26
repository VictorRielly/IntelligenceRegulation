"""Parse a macOS /usr/bin/sample call graph into per-thread self-sample stacks that keep each frame's name
and its call-site offset (name, offset). Own copy of the A11 parser (results/zk60_effplan_20261105/a11/sample_summary.py)
with the offsets kept."""
import re
LINE = re.compile(r"^    ([ +!:|]*)(\d+) (.*)$")
HASH = re.compile(r"::h[0-9a-f]{16}$")
OFF = re.compile(r"\)? \+ (\d+)\s+\[0x[0-9a-f]+\]\s*$")

def split_name(rest):
    name = rest.split("  (in ")[0].strip()
    name = HASH.sub("", name)
    m = re.search(r" \+ (\d+)\s+\[0x[0-9a-f]+\]\s*$", rest)
    return name, int(m.group(1)) if m else -1

def parse(path):
    """list of (thread_header, total_count, [(stack[(name,off)...], self_count)])"""
    threads = []
    cur = None
    in_graph = False
    with open(path, errors="replace") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if line.startswith("Call graph:"):
                in_graph = True
                continue
            if not in_graph:
                continue
            if line.startswith("Total number in stack") or line.startswith("Sort by top of stack"):
                break
            m = LINE.match(line)
            if not m:
                continue
            guides, count, rest = m.group(1), int(m.group(2)), m.group(3)
            depth = len(guides) // 2
            if depth == 0:
                cur = [rest, count, []]
                threads.append(cur)
                continue
            if cur is not None:
                cur[2].append((depth, count, split_name(rest)))
    out = []
    for header, total, nodes in threads:
        out.append((header, total, self_samples(nodes)))
    return out

def self_samples(nodes):
    stack = []
    out = []
    def pop_to(d):
        while stack and stack[-1][0] >= d:
            dd, c, n, cs = stack.pop()
            if c - cs > 0:
                out.append(([s[2] for s in stack] + [n], c - cs))
    for depth, count, nm in nodes:
        pop_to(depth)
        if stack:
            stack[-1][3] += count
        stack.append([depth, count, nm, 0])
    pop_to(0)
    return out
