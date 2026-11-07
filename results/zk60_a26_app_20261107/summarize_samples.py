#!/usr/bin/env python3
"""Lane A26: write each sampled run's text profile (`profile_prover.txt`, `profile_checker.txt`) next to
its raw `sample_*.txt`, then move the raw samples (tens of MB each: public code symbols only, but over
the repository's 1 MB file limit) out of the repository to `--keep-dir`.

usage: summarize_samples.py <results dir> <keep dir> <run tag>...
"""
import subprocess
import shutil
import sys
from pathlib import Path

res, keep = Path(sys.argv[1]), Path(sys.argv[2])
here = Path(__file__).resolve().parent
keep.mkdir(parents=True, exist_ok=True)
for tag in sys.argv[3:]:
    d = res / f'stream_{tag}'
    for side in ('prover', 'checker'):
        raw = d / f'sample_{side}.txt'
        if not raw.exists():
            continue
        out = subprocess.run([sys.executable, str(here / 'sample_profile.py'), str(raw), '--top', '30', '--hash', '--who'],
                             capture_output=True, text=True).stdout
        (d / f'profile_{side}.txt').write_text(out)
        (keep / tag).mkdir(exist_ok=True)
        shutil.move(str(raw), str(keep / tag / raw.name))
        print(tag, side, 'profile', len(out), 'bytes; raw moved to', keep / tag)
