"""Token round 18, A5_PATCH_REVIEW.md section 4.3 step 9: the reviewed r16b fresh checks of the batch's receipts.

usage (two halves, two interpreters):
  APP_PYTHON -B fresh_checks.py list A5_DIR JOB_DIR TOTAL OUT.json      (PM_PROVER=shieldstral; Astra's batch_request
                                                                       builds the commands; nothing is run)
  python3 fresh_checks.py run CMDS.json LOG_DIR RESULT.json            (each command in its OWN fresh process, through
                                                                       the guard, cpu, need 2.9 / cap 7, max 600 s;
                                                                       1800 s for a label; wait_turn before each)
"""
import json, subprocess, sys

R = "/home/victor/IntelligenceRegulation"
T = R + "/results/zk60_token_io_r1_20261017/r18"
GUARD = R + "/scripts/zk60_resource_guard.py"


def main():
    if sys.argv[1] == "list":
        a5, job, total, out = sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
        sys.path.insert(0, a5)
        import batch_request as b
        m = json.load(open(job + "/batch-request.json"))
        cmds = [[n, list(c)] for n, c in b.fresh_check_commands(m, total, job)]
        json.dump(cmds, open(out, "w"), indent=1)
        for n, c in cmds:
            print(n, " ".join(c))
        return 0
    cmds, logs, result = json.load(open(sys.argv[2])), sys.argv[3], sys.argv[4]
    res = {}
    for n, c in cmds:
        subprocess.run(["python3", T + "/tools/wait_turn.py", T + "/logs/queue.log", "--need", "2.9"], check=True)
        mx = "1800" if n.endswith("-label") else "600"
        args = ["python3", GUARD, "run", "--class", "cpu", "--need-gib", "2.9", "--cap-gib", "7", "--max-secs", mx,
                "--wait-secs", "14400", "--label", f"tio18-a5-{n}", "--log", f"{logs}/{n}.log",
                "--done", f"{logs}/{n}.guard.done", "--result-json", f"{logs}/{n}.guard.json", "--",
                "/usr/bin/env", "RAYON_NUM_THREADS=8"] + c
        res[n] = subprocess.run(args).returncode
        json.dump(res, open(result, "w"), indent=1)
    print(json.dumps(res))
    return 0 if len(res) == len(cmds) and all(v == 0 for v in res.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
