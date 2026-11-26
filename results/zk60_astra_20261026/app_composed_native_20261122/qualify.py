"""Exercise an invited author and guest over loopback HTTP, then independently check the publications."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
from urllib.request import ProxyHandler, build_opener

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
APP = ROOT / 'apps/proven-media'
sys.path[:0] = [str(APP), str(HERE.parent / 'w16r2_app_native_qualification_20261113')]
from support import clean_guard, quiet, sha

CATEGORIES = {'sexual', 'violence', 'hate'}
FIXTURE = ROOT / 'results/zk60_a24_app_20261107/posts/one.json'
TOKENS = HERE.parent / 'app_decision_refresh_20261104/tokenizers'


def save(path, value):
    temp = path.with_suffix('.writing')
    temp.write_text(json.dumps(value, indent=2) + '\n')
    temp.replace(path)


def configure(private, public):
    os.environ.update(PM_PROVER='shieldstral-fast-w16r2', PM_FAST_WRITER_MODE='resident',
        PM_PRIVATE_DIR=str(private), PM_PUBLIC_DIR=str(public), PM_PUBLISHER='local',
        PM_REPO_ROOT=str(ROOT), PM_FAST_WRITER_PYTHON=sys.executable, PM_FAST_SERVICE_PYTHON=sys.executable,
        PM_SHIELDSTRAL_TOKENIZER=str(TOKENS / 'tekken.json'), PM_TINYLLAMA_TOKENIZER=str(TOKENS / 'tokenizer.model'),
        PM_FAST_IDLE_SECS='180', PM_BATCH_SECS='30', PYTHONDONTWRITEBYTECODE='1',
        ZK60_GUARD_DISK_FLOOR_GIB='55', ZK60_GUARD_DISK_KILL_GIB='55',
        OPENBLAS_NUM_THREADS='4', OMP_NUM_THREADS='4', VECLIB_MAXIMUM_THREADS='4')
    os.environ.pop('PM_NO_WORKER', None)
    assert not os.environ.get('DYLD_INSERT_LIBRARIES') and not os.environ.get('A26_FIXED_ENTROPY_FILE')


@contextmanager
def loopback(app):
    import uvicorn
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        sock.listen(32)
        server = uvicorn.Server(uvicorn.Config(app, access_log=False, log_level='warning'))
        thread = threading.Thread(target=server.run, kwargs={'sockets': [sock]})
        thread.start()
        try:
            deadline = time.monotonic() + 180
            while not server.started:
                assert thread.is_alive() and time.monotonic() < deadline, 'app startup failed or expired'
                time.sleep(.1)
            yield f'http://127.0.0.1:{sock.getsockname()[1]}'
        finally:
            server.should_exit = True
            thread.join(45)
            assert not thread.is_alive(), 'app did not shut down'


def download_bundle(guest, pid, detail, signed, private):
    root = f'proven-media-{pid}'
    segments = {f"{root}/chunk-{c['index']}/run/{s['file']}": s
                for c in detail['record']['chunks'] for s in c['record']['receipt']['files']}
    statements = {f"{root}/chunk-{e['chunk']}/run/statement/statement.json": e['statement_sha256']
                  for e in signed['entries']}
    with tempfile.TemporaryFile(dir=private) as stream:
        with guest.stream('GET', f'/api/posts/{pid}/bundle.tar') as response:
            response.raise_for_status()
            for data in response.iter_bytes(1 << 20):
                stream.write(data)
            size = stream.tell()
            assert size == int(response.headers['content-length'])
        stream.seek(0)
        with tarfile.open(fileobj=stream, mode='r:') as archive:
            names = archive.getnames()
            assert len(names) == len(set(names))
            assert json.load(archive.extractfile(f'{root}/{pid}.manifest.json')) == signed
            assert json.load(archive.extractfile(f'{root}/record.json')) == detail['record']
            readme = archive.extractfile(f'{root}/VERIFY.md').read().decode()
            for entry in signed['entries']:
                assert entry['policy_id'] in readme
            for path, segment in segments.items():
                assert archive.getmember(path).size == segment['bytes']
                assert hashlib.file_digest(archive.extractfile(path), 'sha256').hexdigest() == segment['sha256']
            for path, expected in statements.items():
                assert hashlib.file_digest(archive.extractfile(path), 'sha256').hexdigest() == expected
    return {'bytes': size, 'members': len(names), 'segments_rehashed': len(segments),
            'signed_statement_hashes_checked': len(statements)}


def qualify(out, private, public, facts, guest_app=APP):
    configure(private, public)
    import httpx
    from proven_media import app, config, fast_service
    from proven_media.fast_runtime_selection import runtime_for
    runtime = runtime_for()
    config.GUARD_WAIT_SECS = 3600
    assert not runtime.VERIFIER_EXPORT.exists()
    facts.update(prover=runtime.server_argv('prove'), verifier=runtime.server_argv('check'),
                 writer_binding=runtime.service_binding(), fixture_sha256=sha(FIXTURE))
    assert sha(Path(facts['prover'][0])) == runtime.PROVER_BINARY_SHA
    assert sha(Path(facts['verifier'][0])) == runtime.BINARY_SHA
    child = None
    service = runtime.service_dir()

    def launch(argv):
        nonlocal child
        assert child is None and argv[-6:] == [str(APP/'tools/fast_service.py'), '--prover-mode',
                                              runtime.KIND, '--writer-mode', 'resident', str(service)]
        argv = list(argv)
        argv[argv.index('--max-secs') + 1] = '900'
        split = argv.index('--')
        argv[split:split] = ['--result-json', str(out/'service.guard.json')]
        with (private/'controller.log').open('xb') as log:
            child = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)
        return child.pid

    started = time.monotonic()
    with loopback(app.app) as url, httpx.Client(base_url=url, trust_env=False, timeout=60) as client, \
            httpx.Client(base_url=url, trust_env=False, timeout=60) as guest:
        try:
            facts['cold_app_start_seconds'] = time.monotonic() - started
            for template in runtime.templates():
                runtime.validate(runtime.deployment(template))
            assert guest.get('/').status_code == 200 and guest.get('/api/config').json()['prover_mode'] == runtime.KIND
            assert guest.get('/api/session').json() == {'author': None, 'operator': False}
            assert guest.get('/api/feed').json()['posts'] == [] and guest.get('/api/submissions').status_code == 401
            pubkey = guest.get('/api/publisher-key').raise_for_status().json()
            save(out/'publisher_public_key.json', pubkey)
            app.S.prover.launcher = launch
            subprocess.run([sys.executable, '-B', str(APP/'tools/create_author.py'), 'astra_qualification'],
                           check=True, capture_output=True, timeout=30)
            credential, = private.glob('astra_qualification-access-*.json')
            login = client.post('/api/session', json={'access_key': json.loads(credential.read_bytes())['access_key']})
            identity = login.raise_for_status().json()
            assert identity['author'] == '@astra_qualification' and identity['operator'] is False
            client.headers['X-PM-CSRF'] = identity['csrf']
            assert client.get('/api/queue').status_code == 403
            assert client.post('/api/ledger/close-batch').status_code == 403
            quiet()
            assert child is None and not fast_service.service_live(service)
            text = json.loads(FIXTURE.read_bytes())[0]
            start = time.monotonic()
            reply = client.post('/api/posts', data={'author': 'astra_qualification', 'kind': 'text', 'text': text})
            reply.raise_for_status()
            pid = reply.json()['post_id']
            assert reply.json()['proofs'] == 3
            assert client.get('/api/submissions').json()['posts'][0]['status'] == 'pending'
            assert guest.get(f'/api/posts/{pid}').status_code == 404 and guest.get('/api/feed').json()['posts'] == []
            facts.update(post_id=pid, invited_author=True, guest_pending_hidden=True, operator_routes_refused=True)
            while time.monotonic() - start < 4200:
                post = app.S.store.post(pid)
                if post['status'] in ('published', 'failed'):
                    break
                assert child is None or child.poll() is None, 'service guard ended before publication'
                time.sleep(.5)
            assert post['status'] == 'published', post['status']
            published = time.monotonic()
            facts['cold_submission_to_publication_seconds'] = published - start
            hb = fast_service.heartbeat(service)
            assert hb['writer_binding'] == facts['writer_binding'] and hb['resident_writers_alive']
            facts['service_run_id'] = hb['run_id']
            detail = guest.get(f'/api/posts/{pid}').raise_for_status().json()
            assert detail['text'] == text and guest.get('/api/feed').json()['posts'][0]['id'] == pid
            assert 'run_dir' not in json.dumps(detail['record'])
            labels = {row['category']: row['value'] for row in detail['labels']}
            minor = guest.get(f'/api/posts/{pid}', params={'audience': 'minor'}).json()
            assert set(labels) == CATEGORIES
            hide = any(value != 'no' for value in labels.values())
            assert bool(minor.get('hidden')) == hide and (('text' not in minor) if hide else minor['text'] == text)
            facts.update(guest_labels=labels, minor_filter_hidden=hide)
            assert guest.post(f'/api/posts/{pid}/verify').status_code == 401
            queued = client.post(f'/api/posts/{pid}/verify').raise_for_status().json()
            assert queued['status'] == 'queued' and queued['chunks'] == 3
            download = guest.get(f'/api/posts/{pid}/manifest.json').raise_for_status()
            signed = download.json()
            assert len(signed['entries']) == 3 and {e['category'] for e in signed['entries']} == CATEGORIES
            assert all(e['proof_status'] == 'accepted' and e['verdict_bound_by_proof']
                       and e['verdict'] == labels[e['category']] for e in signed['entries'])
            assert signed['item']['post_id'] == pid
            (out/'manifest.json').write_bytes(download.content)
            offline_public, offline_private = private/'absent-store', private/'absent-private'
            check = subprocess.run([sys.executable, '-I', '-B', str(guest_app/'tools/verify_manifest.py'), str(out/'manifest.json'),
                '--signature-only', '--public-key', pubkey['public_key']], capture_output=True, text=True, timeout=30,
                env=dict(os.environ, PM_PUBLIC_DIR=str(offline_public), PM_PRIVATE_DIR=str(offline_private)))
            signature = json.loads(check.stdout)
            assert check.returncode == 0 and signature['accepted'] and signature['scope'] == 'publisher_signature_only'
            assert not offline_public.exists() and not offline_private.exists()
            save(out/'offline_signature.json', signature)
            facts['guest_bundle'] = download_bundle(guest, pid, detail, signed, private)
            deadline = time.monotonic() + 600
            while time.monotonic() < deadline:
                checks = guest.get(f'/api/posts/{pid}').raise_for_status().json().get('checks', [])
                if len(checks) == 3:
                    break
                time.sleep(1)
            assert len(checks) == 3 and {c['verdict']['chunk'] for c in checks} == {0, 1, 2}
            assert all(c['ok'] and c['verdict']['details']['content_binding'] for c in checks)
            facts['author_native_rechecks_with_owner_binding'] = len(checks)
            deadline = time.monotonic() + 120
            while time.monotonic() < deadline:
                anchors = app.S.publisher.anchors_of(pid)
                if len(anchors) == 3 and all(a.status == 'anchored' for a in anchors.values()):
                    break
                time.sleep(1)
            checked = guest.post(f'/api/posts/{pid}/verify-manifest').raise_for_status().json()
            assert checked['accepted'] and not checked['pending_anchor']
            coverage = checked['signed_post_coverage']
            assert coverage['planned_chunks'] == coverage['accepted_chunks'] == 3
            assert coverage['content_tokens'] == signed['item']['content_length_tokens']
            assert coverage['labels'] == signed['labels']
            publication = guest.post(f'/api/posts/{pid}/verify-publication').raise_for_status().json()
            assert publication['accepted'] and not publication['pending'] and len(publication['per_proof']) == 3
            for entry in signed['entries']:
                digest = entry['bundle']['manifest_sha256']
                raw = app.S.publisher.get_bytes(digest)
                assert hashlib.sha256(raw).hexdigest() == digest
                inventory = json.loads(raw)
                assert inventory['post_id'] == pid and inventory['statement_sha256'] == entry['statement_sha256']
                (out / (entry['category'] + '.publication.json')).write_bytes(raw)
            facts['automatic_local_batch_seconds_configured'] = app.S.publisher.batch_secs
            save(out/'guest_checks.json', {'manifest': checked, 'publication': publication})
            destination = private/'guest-download'
            destination.mkdir()
            opener = build_opener(ProxyHandler({}))
            with opener.open(f'{url}/api/posts/{pid}/verification-store.tar', timeout=180) as response:
                facts['downloaded_store_bytes'] = int(response.headers['Content-Length'])
                with tarfile.open(fileobj=response,mode='r|') as archive:
                    names = set()
                    for member in archive:
                        assert member.isfile() and member.name.startswith(f'proven-media-{pid}/')
                        assert member.name not in names and '..' not in Path(member.name).parts
                        names.add(member.name)
                        archive.extract(member,destination,filter='data')
            received = destination/f'proven-media-{pid}'
            downloaded_store = received/'public-store'
            received_manifest = received/f'{pid}.manifest.json'
            assert json.loads(received_manifest.read_bytes()) == signed
            command = [sys.executable,'-I','-B',str(guest_app/'tools/verify_manifest.py'),str(received_manifest),
                       '--public-key',pubkey['public_key'],'--public-dir',str(downloaded_store),'--rehash']
            checked = json.loads(subprocess.check_output(command,timeout=300,
                env=dict(os.environ,PM_PRIVATE_DIR=str(offline_private),PM_PUBLIC_DIR=str(offline_public))))
            assert checked['accepted'] and not checked['pending_anchor'] and checked['signed_post_coverage'] == coverage
            assert not offline_public.exists() and not offline_private.exists()
            save(out/'downloaded_store.json',checked)
            facts['downloaded_store_members'] = len(names)
            record = json.loads(post['record'])
            assert record['prover']['binary_sha256'] == runtime.BINARY_SHA
            assert record['prover']['prover_binary_sha256'] == runtime.PROVER_BINARY_SHA
            chunks = record['chunks']
            assert len(chunks) == 3 and {c['category'] for c in chunks} == CATEGORIES
            facts['segments'] = {c['category']: len(c['record']['receipt']['files']) for c in chunks}
            assert set(facts['segments'].values()) == {28}
            rows = app.S.store.q("SELECT * FROM jobs WHERE post_id=? AND kind='prove'", (pid,))
            assert len(rows) == 3
            for row in rows:
                job = Path(row['job_dir'])
                assert row['status'] == 'done'
                assert json.loads((job/'classifier-job.json').read_bytes())['writer_binding'] == facts['writer_binding']
                for name in ('verify', 'inowner'):
                    assert (job/'logs'/f'{name}.exit').read_text().strip() == '0'
        finally:
            app.S.worker.stop()
            app.S.worker.join(timeout=30)
            if child and child.poll() is None:
                fast_service.stop(service)
                child.wait(timeout=180)
            if child:
                facts['guard_exit'] = child.returncode
            if (private/'controller.log').exists():
                shutil.copyfile(private/'controller.log', out/'controller.log')
    clean_guard(json.loads((out/'service.guard.json').read_bytes()))
    assert facts['guard_exit'] == 0
    replay_guest(out, private, downloaded_store, signed, checked, facts, guest_app)


def replay_guest(out, private, downloaded_store, signed, checked, facts, guest_app):
    pid = signed['item']['post_id']
    facts['public_verification'] = {}
    from tools.verify_manifest import verify_proofs
    from proven_media.publisher import LocalChainPublisher

    def standalone(pub, publication, post_id):
        assert post_id == pid == publication['post_id']
        time.sleep(10)
        quiet()
        category = publication['category']
        unused = private/'unused-public-verifier-root'
        env = dict(os.environ, PM_PRIVATE_DIR=str(unused), PM_PROVER='stub', PM_FAST_WRITER_MODE='oneshot')
        run = subprocess.run([sys.executable, '-I', '-B', str(guest_app/'tools/verify_publication.py'), '--post-id', pid,
            '--category', category, '--chunk', str(publication['chunk']), '--public-dir', str(downloaded_store), '--run-verifier'],
            env=env, capture_output=True, text=True, timeout=4800)
        (out/f'{category}.json').write_text(run.stdout)
        (out/f'{category}.stderr').write_text(run.stderr)
        assert run.returncode == 0, category
        result = json.loads(run.stdout)
        proof = result['proof_verifier']
        assert result['accepted'] and proof['ok'] and proof['public_content_only'] and not proof['production']
        assert not unused.exists() and proof['fresh_input_owner_check'] is False
        clean_guard(proof['guard'])
        facts['public_verification'][category] = {'accepted': True, 'report_sha256': sha(out/f'{category}.json')}
        return proof

    verify_proofs(signed, LocalChainPublisher(downloaded_store), checked, standalone)
    assert checked['accepted'] and checked['checks']['complete_post_proof_replay']
    facts['native_post_coverage'] = checked['signed_post_coverage']
    facts['passed'] = True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--released-reader', action='store_true', help='use the pinned guest source for the independent CLI calls')
    args = parser.parse_args()
    os.umask(0o077)
    out = HERE / datetime.now(timezone.utc).strftime('qualification-%Y%m%dT%H%M%S.%fZ')
    out.mkdir()
    result = {'passed': False, 'public_fixture_only': True}
    try:
        quiet()
        public = Path(tempfile.mkdtemp(prefix='astra-merged-w16r2-', dir=Path.home()/'zk60-artifacts'))
        result['public_scratch'] = str(public)
        with tempfile.TemporaryDirectory(prefix='astra-merged-w16r2-', dir=Path.home()/'zk60-owner-private') as private, \
                tempfile.TemporaryDirectory(prefix='astra-public-reader-') as guest:
            guest_app = APP
            if args.released_reader:
                from qualify_reader_source import ARCHIVE_SHA, unpack_reader
                reader = Path(guest).resolve()/'reader'
                unpack_reader(reader)
                guest_app = reader/'apps/proven-media'
                result['guest_source_sha256'] = ARCHIVE_SHA
            qualify(out, Path(private), public, result, guest_app)
        shutil.rmtree(public)
        result['public_scratch_removed'] = True
    except Exception as error:
        result['error'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        save(out/'RESULT.json', result)
    print(out/'RESULT.json', flush=True)
