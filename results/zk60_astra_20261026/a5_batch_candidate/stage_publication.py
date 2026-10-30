"""Stage quarantine exclusion in real publisher/download source; do not apply."""
import difflib
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
APP=ROOT/'apps/proven-media'
DEST=HERE/'publication_candidate'
HELPER='''"""Never expose quarantined batch receipts through publication or downloads."""
from pathlib import Path


def require_public_receipt_path(path):
    path = Path(path)
    for candidate in (path.absolute(), path.resolve()):
        if '.batch-quarantine' in candidate.parts:
            raise ValueError('quarantined batch receipts cannot be published or downloaded')
    return path
'''


def main():
    DEST.mkdir(exist_ok=True)
    # Isolated test package falls back to unchanged app dependencies. No app
    # runtime state or installed factory is modified by staging/importing it.
    (DEST/'__init__.py').write_text('__path__.append('+repr(str(APP/'proven_media'))+')\n')
    (DEST/'quarantine_paths.py').write_text(HELPER)
    diffs=[];pins={}
    for name in ('publisher.py','testnet_publisher.py','app.py'):
        source=APP/'proven_media'/name;before=source.read_text();after=before
        anchor='from __future__ import annotations\n'
        assert after.count(anchor)==1
        after=after.replace(anchor,anchor+'\nfrom .quarantine_paths import require_public_receipt_path\n')
        if name=='publisher.py':
            anchor='    def put_file(self, path: Path, expect_sha: str | None = None) -> tuple[str, int]:\n'
            assert after.count(anchor)==1
            after=after.replace(anchor,anchor+'        require_public_receipt_path(path)\n')
            anchor='        if record.verdict not in ("yes", "no"):\n'
            assert after.count(anchor)==1
            after=after.replace(anchor,'        for path in record.receipt_segments:\n            require_public_receipt_path(path)\n'+anchor)
        elif name=='testnet_publisher.py':
            anchor='    def publish(self, record):\n';assert after.count(anchor)==1
            after=after.replace(anchor,anchor+'        for path in record.receipt_segments:\n            require_public_receipt_path(path)\n')
        else:
            anchor='    for ci, run, crec in chunk_runs:\n';assert after.count(anchor)==1
            after=after.replace(anchor,anchor+'        require_public_receipt_path(run)\n')
            # Both segment and statement members are checked before streaming;
            # recheck immediately before opening a member after the response.
            after=after.replace('            members.append((f"{root}/chunk-{ci}/run/',
                                '            require_public_receipt_path(f)\n            members.append((f"{root}/chunk-{ci}/run/')
            anchor='                with open(src, "rb") as fh:\n';assert after.count(anchor)==1
            after=after.replace(anchor,'                require_public_receipt_path(src)\n'+anchor)
        (DEST/name).write_text(after)
        pins[name]=hashlib.sha256(source.read_bytes()).hexdigest()
        diffs.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
                    fromfile='a/apps/proven-media/proven_media/'+name,tofile='b/apps/proven-media/proven_media/'+name))
    diffs.extend(difflib.unified_diff([],HELPER.splitlines(True),fromfile='/dev/null',
                tofile='b/apps/proven-media/proven_media/quarantine_paths.py'))
    (HERE/'publication_exclusion.patch').write_text(''.join(diffs))
    (HERE/'publication_exclusion_base.json').write_text(json.dumps(pins,indent=2)+'\n')
    print(json.dumps({'staged_files':4,'production_changed':False}))


if __name__=='__main__':main()
