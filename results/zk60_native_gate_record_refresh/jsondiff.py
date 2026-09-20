"""Key-by-key diff of two P10 records (read-only; no gate arithmetic here).

    python3 jsondiff.py <committed>/privacy_gate.json <fresh>/privacy_gate.json

Every leaf is compared at its full path; paths that differ only in a list
index are grouped, so "12x /per_capture/N/channels/N/status" reads as three
channels on each of the four captures.  Used to produce
`diff_p10_before_refresh.txt` and `diff_channels_before_refresh.txt` in this
directory.
"""
import json
import sys


def walk(a, b, path, out):
    if type(a) is not type(b):
        out.append((path, repr(a)[:120], repr(b)[:120]))
        return
    if isinstance(a, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a:
                out.append((path + "/" + str(k), "<absent>", repr(b[k])[:120]))
            elif k not in b:
                out.append((path + "/" + str(k), repr(a[k])[:120], "<absent>"))
            else:
                walk(a[k], b[k], path + "/" + str(k), out)
    elif isinstance(a, list):
        if len(a) != len(b):
            out.append((path + "/len", len(a), len(b)))
            return
        for i, (x, y) in enumerate(zip(a, b)):
            walk(x, y, path + "/" + str(i), out)
    else:
        if a != b:
            out.append((path, repr(a)[:120], repr(b)[:120]))


def main():
    left, right = sys.argv[1], sys.argv[2]
    a = json.load(open(left))
    b = json.load(open(right))
    out = []
    walk(a, b, "", out)
    print("committed:", left)
    print("current  :", right)
    print("differing paths:", len(out))
    groups = {}
    for p, x, y in out:
        key = "/".join("N" if q.isdigit() else q for q in p.split("/"))
        groups.setdefault(key, []).append((p, x, y))
    for key in sorted(groups):
        rows = groups[key]
        p, x, y = rows[0]
        print(f"  [{len(rows):>3}x] {key}")
        print(f"          committed: {x}")
        print(f"          current  : {y}")


main()
