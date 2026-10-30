"""Stage the real SQLite/worker startup hook without changing the live app."""
import difflib
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
APP = HERE.parents[2]/'apps/proven-media/proven_media'
DEST = HERE/'queue_candidate'


def main():
    DEST.mkdir(exist_ok=True)
    (DEST/'__init__.py').write_text('__path__.append('+repr(str(APP))+')\n')
    pins, diffs = {}, []
    for name in ('store.py', 'jobs.py'):
        source = APP/name
        before = source.read_text()
        if name == 'store.py':
            after = before.replace('        self.db.executescript(SCHEMA)\n',
                '        self.db.executescript(SCHEMA)\n'
                '        from batch_registry import SCHEMA as BATCH_SCHEMA\n'
                '        self.db.executescript(BATCH_SCHEMA)\n')
        else:
            after = before.replace('    def tick(self) -> None:\n',
                '    def tick(self) -> None:\n'
                '        from batch_registry import recover_registered_batches\n'
                '        if recover_registered_batches(self):\n'
                '            return\n')
        assert after != before
        (DEST/name).write_text(after)
        pins[name] = hashlib.sha256(source.read_bytes()).hexdigest()
        diffs.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                     fromfile='a/apps/proven-media/proven_media/'+name,
                     tofile='b/apps/proven-media/proven_media/'+name))
    (HERE/'queue_startup.patch').write_text(''.join(diffs))
    (HERE/'queue_startup_base.json').write_text(json.dumps(pins, indent=2)+'\n')
    print(json.dumps({'staged_files':2, 'production_changed':False}))


if __name__ == '__main__':
    main()
