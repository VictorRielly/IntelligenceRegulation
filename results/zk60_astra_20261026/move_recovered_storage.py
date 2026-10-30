"""Preview, or atomically move the recovered app state outside the repository.

No proofs, transactions, new keys or server starts. The host apply checks for
app processes, checkpoints SQLite, and verifies every private file unchanged.
Private file hashes stay inside the mode-700 private directory.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import sqlite3

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
APP=ROOT/'apps/proven-media'
OUT=HERE/'real_app_demo_1'
RECOVERY=OUT/'recovery-20261030'
SOURCE=APP/'.testnet-private/real-app-demo-recovery'
DEST=Path('/home/victor/zk60-owner-private/proven-media-astra-demo')
INVENTORY='.storage-migration-inventory.json'


def require(ok,why):
    if not ok:raise RuntimeError(why)


def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for data in iter(lambda:stream.read(1<<20),b''):h.update(data)
    return h.hexdigest()


def save(path,value,mode=0o644):
    temp=path.with_suffix(path.suffix+'.tmp')
    fd=os.open(temp,os.O_CREAT|os.O_EXCL|os.O_WRONLY,mode)
    with os.fdopen(fd,'w') as stream:
        json.dump(value,stream,indent=2);stream.write('\n');stream.flush();os.fsync(stream.fileno())
    os.replace(temp,path)


def files(root):
    result={}
    for path in root.rglob('*'):
        require(not path.is_symlink(),'private tree contains a symlink; inspect before moving')
        if path.is_file() and path.name!=INVENTORY:
            require(not path.name.endswith(('-wal','-shm')),'SQLite journal still present; stop readers before move')
            result[str(path.relative_to(root))]={'sha256':digest(path),'bytes':path.stat().st_size,
                                               'mode':path.stat().st_mode&0o777}
    return result


def host_quiescence():
    status=dict(line.split(':',1) for line in Path('/proc/self/status').read_text().splitlines() if ':' in line)
    require(Path('/proc/1/comm').read_text().strip() in ('systemd','init','/init')
            and status.get('NSpid','').split()==[str(os.getpid())],'apply on the host for process visibility')
    forbidden={'serve.py','classifier_pipeline.py','run_real_app_demo.py','check_recovered_app.py','run_durable_app_demo.py'}
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit() or int(proc.name)==os.getpid():continue
        try:words=[w.decode(errors='replace') for w in (proc/'cmdline').read_bytes().split(b'\0') if w]
        except (FileNotFoundError,PermissionError,ProcessLookupError):continue
        require('proven_media.app:app' not in words and not any(Path(w).name in forbidden for w in words),
                f'app process {proc.name} is still active')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    complete=json.loads((OUT/'complete.json').read_text())
    if (RECOVERY/'storage_move.json').exists():
        result=json.loads((RECOVERY/'storage_move.json').read_text())
        require(result['applied'] and DEST.exists() and not SOURCE.exists(),'completed migration state differs')
        print(json.dumps({'already_moved':True,'destination':str(DEST)}));return
    root=SOURCE if SOURCE.exists() else DEST
    require(root.exists(),'neither source nor destination exists')
    require(not SOURCE.is_symlink() and not DEST.is_symlink(),'storage root must not be a symlink')
    if not args.apply:
        entries=files(root)
        print(json.dumps({'source':str(SOURCE),'destination':str(DEST),'files':len(entries),
                          'bytes':sum(v['bytes'] for v in entries.values()),'key_changes':False,'apply':False}));return
    host_quiescence()
    require(DEST.parent.exists() and DEST.parent.stat().st_mode&0o777==0o700,'destination parent must exist with mode700')
    require(not (SOURCE.exists() and DEST.exists()),'destination already exists; never overwrite')
    require(str(complete['recovery']['private_root']) in (str(SOURCE),str(DEST)),'unexpected original private root')
    if SOURCE.exists():
        require(SOURCE.stat().st_dev==DEST.parent.stat().st_dev,'atomic move needs one filesystem')
        db=sqlite3.connect(str(SOURCE/'app.sqlite3'))
        require(db.execute("SELECT count(*) FROM jobs WHERE status IN ('queued','running')").fetchone()[0]==0,
                'app jobs still pending')
        require(db.execute('SELECT count(*) FROM posts WHERE id=?',(complete['post_id'],)).fetchone()[0]==1,
                'recovered post missing')
        require(db.execute('PRAGMA wal_checkpoint(TRUNCATE)').fetchone()[0]==0,'database checkpoint busy')
        db.close()
        entries=files(SOURCE)
        save(SOURCE/INVENTORY,entries,mode=0o600)
        if not (RECOVERY/'complete.before-storage-move.json').exists():
            save(RECOVERY/'complete.before-storage-move.json',complete)
        save(RECOVERY/'storage_move.intent.json',{'source':str(SOURCE),'destination':str(DEST),'post_id':complete['post_id']})
        os.rename(SOURCE,DEST)
        for parent in (SOURCE.parent,DEST.parent):
            fd=os.open(parent,os.O_RDONLY|os.O_DIRECTORY);os.fsync(fd);os.close(fd)
    else:
        require((RECOVERY/'storage_move.intent.json').exists(),'destination exists without a migration journal')
        entries=json.loads((DEST/INVENTORY).read_text())
    require(DEST.stat().st_mode&0o777==0o700,'moved private root is not mode700')
    require(files(DEST)==entries,'private files changed during the atomic move')
    complete['recovery']['private_root']=str(DEST)
    complete['recovery']['storage_migration']='recovery-20261030/storage_move.json'
    save(OUT/'complete.json',complete)
    state=json.loads((HERE/'continuation_20261028.json').read_text())
    state['real_app']['private_root']=str(DEST);save(HERE/'continuation_20261028.json',state)
    result={'at':datetime.now(timezone.utc).isoformat(),'applied':True,'source':str(SOURCE),'destination':str(DEST),
            'files_verified_unchanged':len(entries),'bytes':sum(v['bytes'] for v in entries.values()),
            'private_root_mode':'0700','key_rotation':False,'new_proofs':0,'new_transactions':0,
            'original_lost_owner_openings_recovered':False,'services_restarted':False}
    save(RECOVERY/'storage_move.json',result);print(json.dumps(result))


if __name__=='__main__':main()
