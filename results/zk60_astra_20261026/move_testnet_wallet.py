"""Move the existing throwaway testnet key outside the repo, without rotation or RPC."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];APP=ROOT/'apps/proven-media'
sys.path[:0]=[str(APP),str(HERE)]
from move_recovered_storage import host_quiescence,require,save
from proven_media.base_sepolia import read_throwaway_key

CONFIG=APP/'.testnet-private/sepolia.json'
SOURCE=APP/'.testnet-private/throwaway.sepolia-key.json'
DEST=Path('/home/victor/zk60-owner-private/proven-media-astra-demo/testnet/throwaway.sepolia-key.json')
OUT=HERE/'real_app_demo_1/recovery-20261030'


def main():
    p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');args=p.parse_args()
    cfg=json.loads(CONFIG.read_text());configured=(CONFIG.parent/cfg['key_file']).resolve()
    require(configured in (SOURCE,DEST),'unexpected configured wallet path')
    require(not (SOURCE.exists() and DEST.exists()),'both wallet locations exist; inspect rather than overwrite')
    location=SOURCE if SOURCE.exists() else DEST
    account=read_throwaway_key(location)
    require(account.address.lower()==cfg['publisher_address'].lower(),'wallet does not match the deployed publisher')
    if not args.apply:
        print(json.dumps({'source':str(location),'destination':str(DEST),'address_unchanged':True,'apply':False}));return
    host_quiescence()
    if SOURCE.exists():
        original=SOURCE.read_bytes()
        require(DEST.parent.parent.is_dir() and DEST.parent.parent.stat().st_mode&0o777==0o700,
                'durable private root must exist and be mode700')
        DEST.parent.mkdir(mode=0o700,exist_ok=True)
        require(not DEST.parent.is_symlink() and DEST.parent.stat().st_mode&0o777==0o700,'unsafe wallet directory')
        if not (OUT/'sepolia.before-key-move.json').exists():save(OUT/'sepolia.before-key-move.json',cfg)
        os.rename(SOURCE,DEST)
        require(DEST.read_bytes()==original,'wallet bytes changed during move')
        for parent in (SOURCE.parent,DEST.parent):
            fd=os.open(parent,os.O_RDONLY|os.O_DIRECTORY);os.fsync(fd);os.close(fd)
    cfg['key_file']=str(DEST);save(CONFIG,cfg)
    require(read_throwaway_key(DEST).address==account.address,'moved wallet does not match')
    result={'at':datetime.now(timezone.utc).isoformat(),'source':str(SOURCE),'destination':str(DEST),
            'address':account.address,'same_key':True,'new_transactions':0,'mode':'0600','parent_mode':'0700'}
    save(OUT/'testnet_key_move.json',result);print(json.dumps(result))


if __name__=='__main__':main()
