#!/usr/bin/env python3
"""Lane A28 (from A27): print the app run's phases, its first-post checks and the service heartbeat (app_<tag>/summary.json)."""
import json
import sys

s = json.load(open(sys.argv[1]))
print('service ready s', s.get('service_ready_s'), 'app boot s', s.get('app_boot_s'))
for n, p in s['phases'].items():
    print(n, p['posts'], p['published'], p['failed'], round(p['wall_s'], 1), p['category_proofs'], round(p['proved_tok_per_s'], 2), p['steady'])
    print('   first post:', p['first_post_check'])
hb = s.get('service_heartbeat') or {}
print('heartbeat keys', sorted(hb.keys()))
print({k: hb[k] for k in hb if k in ('state', 'binary_sha256', 'lane', 'binary', 'peak_rss_gib', 'guard')})
