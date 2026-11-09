#!/usr/bin/env python3
"""Lane A28 (diagnostics): how long the pinned Python activation writer takes for ONE public post, by how its
category chunks are grouped. The app's service runs one writer process per category job (WRITERS_AT_ONCE at a
time); the native stream driver runs one process for a post's three categories. Timed here, with 4 BLAS
threads a process as both do:
  one process, one category;  one process, three categories;  three processes of one category at once;
  two at once and then the third (the app's WRITERS_AT_ONCE = 2).
Public text only (A24's one.json). The activations go to an owner-only directory outside the repository and
are deleted at the end. Also: are a category's activation files the same bytes in both groupings?

usage: writer_time.py <tag>
"""
import hashlib
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import stream_driver as sd  # noqa: E402


def run(req_file, out):
    return subprocess.Popen(['/usr/bin/env', 'OPENBLAS_NUM_THREADS=4', 'OMP_NUM_THREADS=4', 'VECLIB_MAXIMUM_THREADS=4', sd.PY, str(sd.WRITER),
                             '--request', str(req_file), '--out', str(out)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)


def tree_hash(d):
    h = hashlib.sha256()
    for p in sorted(Path(d).glob('x_*.bin')):
        h.update(p.name.encode())
        h.update(hashlib.sha256(p.read_bytes()).digest())
    return h.hexdigest()


def main():
    tag = sys.argv[1]
    texts = json.loads((sd.WT / 'results/zk60_a24_app_20261107/posts/one.json').read_text())
    ids = sd.encode(texts)[0]
    root = sd.PRIV / f'writer-{tag}'
    sd.PRIV.mkdir(mode=0o700, exist_ok=True)
    root.mkdir(mode=0o700)
    content = root / 'content.ids'
    sd.private_write(content, (','.join(map(str, ids)) + '\n').encode())
    rows = [{'name': f'{c}-c0', 'policy_id': sd.POL[c], 'content_file': str(content), 'chunk_index': 0} for c in sd.CATS]
    reqs = {}
    for k, sel in (('all', rows), ('c0', rows[:1]), ('c1', rows[1:2]), ('c2', rows[2:3])):
        reqs[k] = root / f'req-{k}.json'
        sd.private_write(reqs[k], json.dumps(sel).encode())
    out = {'tag': tag, 'tokens': len(ids)}

    def timed(name, groups):
        """groups: a list of waves; each wave a list of (request key, out dir name) started together"""
        t0 = time.time()
        for wave in groups:
            ps = [run(reqs[k], root / d) for k, d in wave]
            for p in ps:
                err = p.communicate()[1]
                if p.returncode != 0:
                    raise SystemExit(f'{name}: the writer failed: {err[-400:]}')
        out[name] = round(time.time() - t0, 2)

    timed('one process, one category', [[('c0', 'a1')]])
    timed('one process, three categories', [[('all', 'a3')]])
    timed('three processes of one category at once', [[('c0', 'b0'), ('c1', 'b1'), ('c2', 'b2')]])
    timed('two at once, then the third', [[('c0', 'd0'), ('c1', 'd1')], [('c2', 'd2')]])
    same = all(tree_hash(root / 'a3' / r['name']) == tree_hash(root / f'b{i}' / r['name']) for i, r in enumerate(rows))
    out['a category\'s activation files are the same bytes alone and in a three-category process'] = same
    shutil.rmtree(root, ignore_errors=True)
    print(json.dumps(out, indent=1))


if __name__ == '__main__':
    main()
