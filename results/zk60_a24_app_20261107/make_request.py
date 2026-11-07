#!/usr/bin/env python3
"""A24: write an owner-only activation request for every category chunk of one content file.

usage: make_request.py <content.ids> <request.json> [category ...]
Chunk counts come from the app's registered templates (content length is public, D45(1)).
"""
import json
import os
import sys

CATS = {'sexual': 55, 'violence': 55, 'hate': 49}


def plan(total, size, overlap=8):
    if total < size:
        return [(0, total)]
    starts = list(range(0, total - size + 1, size - overlap))
    if starts[-1] != total - size:
        starts.append(total - size)
    return [(a, a + size) for a in starts]


def main():
    content, out = sys.argv[1], sys.argv[2]
    cats = sys.argv[3:] or list(CATS)
    n = len(open(content).read().strip().split(','))
    req = []
    for c in cats:
        for i, _ in enumerate(plan(n, CATS[c])):
            req.append({'name': f'{c}-c{i}', 'policy_id': f'shieldstral-1.0-3b-moderate-{c}/1',
                        'content_file': content, 'chunk_index': i})
    fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.write(fd, json.dumps(req).encode())
    os.close(fd)
    print(json.dumps({'content_tokens': n, 'jobs': len(req)}))


if __name__ == '__main__':
    main()
