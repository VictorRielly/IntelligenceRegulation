"""Preserve every baseline test outcome, normalizing only doctest line numbers."""
from pathlib import Path
from collections import Counter
import hashlib
import re

def census(path):
    text = path.read_text()
    summaries = re.findall(r"test result: ok\. (\d+) passed; 0 failed; (\d+) ignored", text)
    assert summaries and "test result: FAILED" not in text
    tests = Counter()
    for line in text.splitlines():
        match = re.fullmatch(r"test (.+) \.\.\. (ok|FAILED|ignored.*)", line)
        if match:
            name = re.sub(r"\(line \d+\)", "(line)", match[1])
            tests[(name, match[2].split(",")[0])] += 1
    passed = sum(int(a) for a, _ in summaries)
    ignored = sum(int(b) for _, b in summaries)
    assert sum(count for (_, state), count in tests.items() if state == "ok") == passed
    assert sum(count for (_, state), count in tests.items() if state == "ignored") == ignored
    return tests, summaries, passed, ignored

def validate(current: Path, baseline: Path):
    old, old_summaries, old_passed, old_ignored = census(baseline)
    new, summaries, passed, ignored = census(current)
    assert old_passed == 816 and len(old_summaries) == 29
    assert len(summaries) == len(old_summaries)
    assert not old - new, f"baseline outcomes removed or changed: {old - new}"
    added = new - old
    assert passed == old_passed + sum(n for (_, state), n in added.items() if state == "ok")
    assert ignored == old_ignored + sum(n for (_, state), n in added.items() if state == "ignored")
    return {"passed": passed, "ignored": ignored, "summaries": summaries,
            "baseline_passed_preserved": old_passed, "baseline_ignored_preserved": old_ignored,
            "baseline_log_sha256": hashlib.sha256(baseline.read_bytes()).hexdigest(),
            "current_log_sha256": hashlib.sha256(current.read_bytes()).hexdigest(),
            "added": [{"test": name, "state": state, "count": count} for (name, state), count in sorted(added.items())],
            "normalization": "Only numeric doctest (line N) locations; names, status and multiplicity preserved."}
