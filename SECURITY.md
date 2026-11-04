# Security

This is a **research prototype**. It has not had an independent security audit. No proof made with it is in
production use. Our own rule (D63 in `docs/zkmatrix-poc/ZK60_DECISIONS.md`) is that no proof goes into production
before its soundness and zero-knowledge statements are proved in Lean (`formal/`).

We welcome attempts to break it. We are especially interested in:
- a receipt the verifier accepts for an output the committed model did not produce (a soundness break);
- anything a receipt reveals about the hidden inputs, outputs or activations (a privacy break);
- a gap between the Lean statements in `formal/ZK60Formal/Statements.lean` and what the code does.

**How to report:** email victorrielly@gmail.com with the subject "SECURITY", or use GitHub's private vulnerability
reporting on this repository if it is enabled. Please include the commit, the profile, and a way to reproduce the
issue. Please do not open a public issue for an unfixed break. We will acknowledge reports and credit the reporter
unless they ask us not to.
