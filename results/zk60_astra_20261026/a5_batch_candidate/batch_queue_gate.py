"""Staged R18-1 startup/terminal gate; production remains r16b per category.

The caller supplies the original queue reservation and confirms termination.
Unknown or live process state blocks the queue, without moving live outputs.
A successful transport is still unverified: fresh per-job checks are required.
"""
from dataclasses import asdict
import hashlib
import json
from pathlib import Path

from batch_cleanup import CleanupScope, quarantine, _atomic_private
from batch_request import collect_batch_result
from proven_media import proof_plans, records
from proven_media.classifier_cli import require
from proven_media.provers import ProverError


def reject_quarantined_source(path):
    """Use before either publication inventory reads or content-store writes."""
    path = Path(path)
    require(all('.batch-quarantine' not in p.parts for p in (path.absolute(), path.resolve())),
            'quarantined batch receipts cannot be published')


def recover_batch(job, receipts, *, post_id, reserved_plan, reserved_context, terminal_confirmed,
                  terminal_exit=None):
    """Queue startup and normal termination share the exact same collector.

    Roots are provided by the queue, never taken from child stdout. A corrupt
    request is quarantined using the retained, independently checked scope.
    No outcome returned by this function permits automatic re-proving.
    """
    require(terminal_confirmed is True, 'live or uncertain batch blocks queue recovery')
    require(terminal_exit is None or type(terminal_exit) is int, 'invalid supervisor exit')
    job, receipts = Path(job).resolve(), Path(receipts).resolve()
    require(job.name == 'batch' and job.parent.name == post_id, 'batch job differs from queue post')
    raw = json.loads((job/'cleanup-scope.json').read_text())
    scope = CleanupScope(**raw)
    require(scope.post_id == post_id and scope.job == str(job) and scope.receipts == str(receipts)
            and scope.count == len(reserved_plan), 'batch cleanup scope differs from original queue')
    require(proof_plans.is_category_plan(reserved_plan), 'original category plan required')
    report = job/'batch-collection.json'

    def fail():
        cleanup = quarantine(scope, terminal_confirmed=True)
        result = {'schema':'pm-batch-collection/1', 'status':'quarantined',
                  'publication_allowed':False, 'retry_allowed':False,
                  'scope':asdict(scope), 'cleanup_complete':cleanup['complete']}
        _atomic_private(report, result)
        return result

    # A completed quarantine is irreversible, even if a success log appears later.
    if (job/'failed-batch-quarantine.json').exists() or terminal_exit not in (None, 0):
        return fail()
    try:
        require(reserved_context == records.screening_context(), 'original batch screening context changed')
        request = json.loads((job/'batch-request.json').read_text())
        total = request['content_total']
        from batch_request import validate_manifest
        work = validate_manifest(request, total)
        proof_plans.check_plan(reserved_plan, work)
        require(hashlib.sha256(records.canonical(request)).hexdigest() == scope.manifest_sha256,
                'batch request differs from prepared scope')
        # Missing log, completion marker, or guard evidence is a failed batch,
        # including startup following a reboot. A proved prefix is insufficient.
        logs = job/'logs'
        stdout = (logs/'prove-batch.log').read_text()
        rc = int((logs/'prove-batch.guard.done').read_text().strip())
        guard = json.loads((logs/'prove-batch.guard.json').read_text())
        routed = collect_batch_result(stdout, rc, request, total, guard, scope,
                                      terminal_confirmed=True)
    except (OSError, ValueError, KeyError, TypeError, ProverError):
        return fail()
    result = {'schema':'pm-batch-collection/1', 'status':'unverified',
              'publication_allowed':False, 'retry_allowed':False,
              'scope':asdict(scope), 'transport':routed}
    _atomic_private(report, result)
    return result
