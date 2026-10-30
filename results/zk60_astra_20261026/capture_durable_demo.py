"""Capture the actual public demo with installed Windows Chrome, then stop server.

No browser install, login, proof worker, new transaction or external publication.
All images and the isolated browser profile stay in this lane's durable tree.
"""
from datetime import datetime,timezone
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.request

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];APP=ROOT/'apps/proven-media'
OUT=HERE/'real_app_demo_2';SHOTS=OUT/'screenshots'
CHROME=Path('/mnt/c/Program Files/Google/Chrome/Application/chrome.exe')
PORT=8766


def winpath(path):
    return subprocess.check_output(['wslpath','-w',str(path)],text=True).strip()


def main():
    complete=json.loads((OUT/'complete.json').read_text())
    assert CHROME.is_file() and all(a['status']=='anchored' for a in complete['anchors'].values())
    SHOTS.mkdir(exist_ok=True)
    profile=SHOTS/'browser-profile';profile.mkdir(mode=0o700,exist_ok=True)
    (SHOTS/'.gitignore').write_text('browser-profile/\n')
    # Refuse to touch another server; this port belongs only to this snapshot.
    with socket.socket() as sock:sock.bind(('127.0.0.1',PORT))
    env=dict(os.environ,PM_PRIVATE_DIR=complete['private_root'],PM_PUBLIC_DIR=complete['public_root'],
             PM_PROVER='shieldstral',PM_NO_WORKER='1',PM_PUBLISHER='base-sepolia',
             PM_SEPOLIA_CONFIG=str(APP/'.testnet-private/sepolia.json'))
    captures=[]
    with (SHOTS/'server.log').open('ab') as log:
        server=subprocess.Popen([str(APP/'.venv/bin/python'),str(APP/'serve.py'),'--port',str(PORT)],
            cwd=ROOT,env=env,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,
            start_new_session=True)
    try:
        base=f'http://127.0.0.1:{PORT}'
        for _ in range(60):
            if server.poll() is not None:raise RuntimeError('snapshot server failed; see server.log')
            try:
                with urllib.request.urlopen(base+'/api/posts/'+complete['post_id'],timeout=2) as response:
                    assert json.load(response)['status']=='published'
                break
            except (OSError,TimeoutError):time.sleep(1)
        else:raise RuntimeError('snapshot server did not become ready')
        for name,route in [('feed','#/'),('post','#/post/'+complete['post_id']),('ledger','#/ledger')]:
            target=SHOTS/(name+'.png')
            if target.exists():raise RuntimeError('screenshot already exists; inspect it before replacing')
            cmd=[str(CHROME),'--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check',
                 '--disable-background-networking','--disable-sync','--hide-scrollbars',
                 '--window-size=1440,1100','--virtual-time-budget=10000',
                 '--user-data-dir='+winpath(profile),'--screenshot='+winpath(target),base+'/'+route]
            with (SHOTS/(name+'.browser.log')).open('wb') as log:
                result=subprocess.run(cmd,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,
                                      timeout=60,cwd=ROOT)
            assert result.returncode==0 and target.is_file() and target.read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
            captures.append({'route':route,'file':name+'.png','bytes':target.stat().st_size,
                             'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
    finally:
        (Path(complete['private_root'])/'STOP-SERVER').touch(mode=0o600)
        try:server.wait(timeout=15)
        except subprocess.TimeoutExpired:
            server.terminate();server.wait(timeout=10)
    result={'at':datetime.now(timezone.utc).isoformat(),'post_id':complete['post_id'],
            'captures':captures,'server_exit':server.returncode,'proof_worker_started':False,
            'signed_in':False,'browser':'installed Windows Chrome,isolated headless profile',
            'visual_review_pending':True}
    (SHOTS/'capture.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))


if __name__=='__main__':main()
