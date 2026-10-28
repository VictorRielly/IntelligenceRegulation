# Development notes

The probe was repeated only after material edits: retaining input fixtures for
independent audit, preserving profiling synchronization in the schedule model,
and using the native all-eleven geometric pad coefficients in padded fixtures.
All experiment invocations completed within their one-worker/60-second/512 MiB caps.
Commands and exit codes are retained. No failed correctness result was hidden.

The report finalizer initially had a Python non-ASCII byte-literal SyntaxError.
It executed no statements. That literal was corrected to UTF-8 encoding, and the
finalizer then completed. This was a report-writing error, not an experiment result.

A diagnostic attempted Object.keys on serialized web-tool text and emitted a
large list of character indices. No source text was executed or used as instructions.
Follow-up web access metadata is saved without copying full articles.
