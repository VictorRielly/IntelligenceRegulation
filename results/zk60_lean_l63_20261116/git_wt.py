#!/usr/bin/env python3
"""D63 lane L63: run one git command with cwd set to this lane's worktree (the session's directory is the repository
root and EnterWorktree refused). usage: git_wt.py <git args...>; e.g. git_wt.py status --short"""
import subprocess
import sys

WT = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a8b5788916259e1b2"
sys.exit(subprocess.call(["git"] + sys.argv[1:], cwd=WT))
