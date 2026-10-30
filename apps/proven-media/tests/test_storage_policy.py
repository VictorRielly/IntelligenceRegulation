"""Crash prevention: no production startup with volatile keys or openings."""
from pathlib import Path
import tempfile
import json
import unittest
from unittest.mock import Mock, patch

from proven_media import config
from proven_media.storage_policy import durable_path, validate_storage


class StoragePolicyTests(unittest.TestCase):
    def setUp(self):
        private=Path('/home/victor/zk60-owner-private/storage-policy-fixture')
        public=config.REPO/'results/storage-policy-fixture'
        self.values=dict(PRIVATE_DIR=private,DB_PATH=private/'app.sqlite3',SIGNING_KEY=private/'signing.key',
                         JOBS_DIR=private/'jobs',MEDIA_DIR=private/'media',PUBLIC_DIR=public,
                         RUNS_DIR=public/'runs',STORE_DIR=public/'bundle-store',LEDGER_PATH=public/'ledger/ledger.jsonl')
        fixture=patch.multiple(config,**self.values);fixture.start();self.addCleanup(fixture.stop)
        env=patch.dict('os.environ',{'PM_PUBLISHER':'local'});env.start();self.addCleanup(env.stop)

    def test_durable_external_private_and_repo_public_are_allowed_without_writes(self):
        validate_storage()
        self.assertFalse(self.values['PRIVATE_DIR'].exists())

    def test_every_configured_state_and_evidence_path_refuses_tmp(self):
        for name in self.values:
            with self.subTest(path=name),patch.object(config,name,Path('/tmp/forbidden')/name):
                with self.assertRaisesRegex(ValueError,'durable storage'):validate_storage()

    def test_other_volatile_roots_and_normalized_paths_refuse(self):
        for root in ('/var/tmp','/dev/shm','/run/user/1000','/home/victor/../../tmp'):
            with self.subTest(root=root),self.assertRaises(ValueError):
                durable_path(Path(root)/'state','state')

    def test_temporary_symlink_alias_to_durable_target_refuses(self):
        with tempfile.TemporaryDirectory() as directory:
            alias=Path(directory)/'alias';alias.symlink_to(self.values['PRIVATE_DIR'])
            with self.assertRaises(ValueError):durable_path(alias/'app.sqlite3','database')

    def test_durable_alias_resolving_to_tmp_refuses(self):
        # Exercise resolution without writing outside the test sandbox.
        path=self.values['PRIVATE_DIR']/'redirected.key'
        with patch.object(Path,'resolve',return_value=Path('/tmp/lost.key')):
            with self.assertRaises(ValueError):durable_path(path,'key')

    def test_private_repo_path_and_escaped_key_refuse(self):
        with patch.object(config,'PRIVATE_DIR',config.REPO/'apps/proven-media/.private'):
            with self.assertRaisesRegex(ValueError,'outside the repository'):validate_storage()
        with patch.object(config,'SIGNING_KEY',Path('/home/victor/elsewhere.key')):
            with self.assertRaisesRegex(ValueError,'inside the private'):validate_storage()

    def test_public_private_overlap_refuses(self):
        with patch.object(config,'PUBLIC_DIR',self.values['PRIVATE_DIR']/'public'):
            with self.assertRaisesRegex(ValueError,'overlap'):validate_storage()

    def test_saved_owner_directory_in_tmp_or_other_private_root_refuses(self):
        for path in ('/tmp/old-job','/home/victor/another-private-root/job'):
            with self.subTest(path=path),self.assertRaises(ValueError):
                validate_storage(Mock(q=Mock(return_value=[{'job_dir':path}])))
        validate_storage(Mock(q=Mock(return_value=[{'job_dir':str(config.JOBS_DIR/'post/prove')}])))

    def test_startup_refuses_before_key_or_prover_creation(self):
        from proven_media import app
        with patch.object(config,'PRIVATE_DIR',Path('/tmp/lost-state')), \
             patch.object(app.manifest,'public_key_hex') as key,patch.object(app.provers,'make_prover') as prover:
            with self.assertRaisesRegex(ValueError,'durable storage'):app.init_state(start_worker=False)
            key.assert_not_called();prover.assert_not_called()

    def test_testnet_key_requires_durable_external_storage(self):
        settings=config.REPO/'apps/proven-media/.testnet-private/test-settings.json'
        for key in ('/tmp/wallet.json',str(config.REPO/'apps/proven-media/.testnet-private/wallet.json')):
            with self.subTest(key=key),patch.dict('os.environ',{'PM_PUBLISHER':'base-sepolia','PM_SEPOLIA_CONFIG':str(settings)}), \
                 patch.object(Path,'read_text',return_value=json.dumps({'key_file':key})):
                with self.assertRaises(ValueError):validate_storage()
        with patch.dict('os.environ',{'PM_PUBLISHER':'base-sepolia','PM_SEPOLIA_CONFIG':str(settings)}), \
             patch.object(Path,'read_text',return_value=json.dumps({'key_file':str(config.PRIVATE_DIR/'testnet/key.json')})):
            validate_storage()


if __name__=='__main__':unittest.main()
