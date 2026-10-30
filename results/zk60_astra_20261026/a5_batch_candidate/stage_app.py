"""Assemble one importable app candidate; never edit the installed app/factory."""
import difflib
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
APP = HERE.parents[2]/'apps/proven-media/proven_media'
DEST = HERE/'integrated_app/proven_media'
HELPERS = ('batch_cleanup.py', 'batch_request.py', 'batch_queue_gate.py',
           'batch_registry.py', 'batch_supervisor.py', 'batch_pipeline.py', 'batch_prover.py')


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST/'__init__.py').write_text('__path__.append('+repr(str(APP))+')\n')
    pins, diffs = {}, []
    for name in ('store.py', 'jobs.py', 'publisher.py', 'testnet_publisher.py', 'app.py'):
        source=APP/name;before=source.read_text();after=before
        if name in ('publisher.py', 'testnet_publisher.py', 'app.py'):
            base=json.loads((HERE/'publication_exclusion_base.json').read_text())
            assert hashlib.sha256(source.read_bytes()).hexdigest()==base[name]
            after=(HERE/'publication_candidate'/name).read_text()
        elif name=='store.py':
            after=after.replace('        self.db.executescript(SCHEMA)\n',
                '        self.db.executescript(SCHEMA)\n'
                '        from .batch_registry import SCHEMA as BATCH_SCHEMA\n'
                '        self.db.executescript(BATCH_SCHEMA)\n')
        else:
            anchor='    def finalize(self, pid: str, note: str | None = None) -> None:\n'
            assert after.count(anchor)==1
            after=after.replace(anchor,'    def finalize(self, pid: str, note: str | None = None, *, require_publication=False) -> None:\n')
            anchor='        first = next((r for r in chunk_recs if r), None)\n'
            assert after.count(anchor)==1
            after=after.replace(anchor,
                '        if require_publication and accepted and len(anchors) != len(plan):\n'
                '            raise PublishError("Batch publication is incomplete; retain verified records for retry.")\n'+anchor)
            after=after.replace('    def tick(self) -> None:\n',
                '    def tick(self) -> None:\n'
                '        from .batch_registry import recover_registered_batches\n'
                '        if recover_registered_batches(self):\n'
                '            return\n')
            anchor='                self.store.check_screening(post)\n                d = prove_job_dir(post["id"], ci)\n'
            assert after.count(anchor)==1
            after=after.replace(anchor,'                self.store.check_screening(post)\n'+
                "                if getattr(self.prover, 'batch_proving', False) is True:\n"
                '                    try:\n'
                '                        self.prover.start_batch(self.store, post)\n'
                '                    except Exception:\n'
                "                        if not self.store.one('SELECT post_id FROM batch_runs WHERE post_id=?', (post['id'],)):\n"
                '                            raise\n'
                '                        log.exception("Registered batch launch needs whole-post recovery")\n'
                '                    return\n                d = prove_job_dir(post["id"], ci)\n')
            # Rechecks may refer to a category within the shared batch job.
            anchor='                self.prover.start_recheck(rec, prove_job_dir(post["id"], ci), d)\n'
            assert after.count(anchor)==1
            after=after.replace(anchor,
                "                original = self.store.one(\"SELECT job_dir FROM jobs WHERE post_id=? AND kind='prove' AND chunk=? ORDER BY id LIMIT 1\", (post['id'], ci))\n"
                "                original_dir = Path(original['job_dir']) if original and original['job_dir'] else prove_job_dir(post['id'], ci)\n"
                '                self.prover.start_recheck(rec, original_dir, d)\n')
        assert after!=before
        (DEST/name).write_text(after)
        pins[name]=hashlib.sha256(source.read_bytes()).hexdigest()
        diffs.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
            fromfile='a/apps/proven-media/proven_media/'+name,tofile='b/apps/proven-media/proven_media/'+name))
    for name in (*HELPERS,'quarantine_paths.py'):
        source=HERE/name if name in HELPERS else HERE/'publication_candidate'/name
        after=source.read_text()
        if name=='batch_request.py':
            after=after.replace("REPO = HERE.parents[2]\n", "REPO = Path('/home/victor/IntelligenceRegulation')\n")
            after=after.replace("sys.path.insert(0, str(REPO / 'apps/proven-media'))\n",'')
        after=after.replace('from proven_media import ', 'from . import ')
        after=after.replace('from proven_media.', 'from .')
        for module in [Path(n).stem for n in HELPERS]:
            after=after.replace('from '+module+' import ', 'from .'+module+' import ')
        (DEST/name).write_text(after)
        diffs.extend(difflib.unified_diff([],after.splitlines(True),fromfile='/dev/null',
            tofile='b/apps/proven-media/proven_media/'+name))
    (HERE/'integrated_app.patch').write_text(''.join(diffs))
    (HERE/'integrated_app_sources.json').write_text(json.dumps({'base':pins,
        'candidate':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DEST.glob('*.py')},
        'factory_changed':False,'production_changed':False},indent=2)+'\n')
    print(json.dumps({'candidate':str(DEST),'production_changed':False,'factory_changed':False}))


if __name__=='__main__':main()
