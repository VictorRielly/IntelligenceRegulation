"""Unit tests (no proof is run): items, records, publisher, stub job layout, and the web flow with the FakeProver.

    /home/victor/IntelligenceRegulation/apps/proven-media/.venv/bin/python -m unittest discover \
        -s /home/victor/IntelligenceRegulation/apps/proven-media/tests
"""
import hashlib
import json
import os
import time
import stat
import struct
import sys
import tempfile
import unittest
from pathlib import Path

TMP = tempfile.mkdtemp(prefix="pm-test-")
os.environ["PM_PRIVATE_DIR"] = os.path.join(TMP, "private")
os.environ["PM_PUBLIC_DIR"] = os.path.join(TMP, "public")
os.environ["PM_PROVER"] = "fake"
os.environ["PM_NO_WORKER"] = "1"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from proven_media import config, items, prompting, provers, records, tokenizer  # noqa: E402
from proven_media import publisher  # noqa: E402
from proven_media.publisher import LocalChainPublisher, PublicationRecord, PublishError, content_commitment  # noqa: E402


class TestItems(unittest.TestCase):
    def png(self, w, h, color=(200, 30, 30)):
        import io
        from PIL import Image
        buf = io.BytesIO()
        Image.new("RGB", (w, h), color).save(buf, "PNG")
        return buf.getvalue()

    def test_canonical_canvas_letterbox(self):
        master, w, h = items.lossless_master(self.png(400, 100))
        self.assertEqual((w, h), (400, 100))
        cv = items.canonical_canvas(master)
        self.assertEqual(cv.size, (items.CANVAS_PX, items.CANVAS_PX))
        self.assertEqual(cv.getpixel((0, 0)), items.FILL_RGB)              # letterbox margin
        self.assertEqual(cv.getpixel((112, 112)), (200, 30, 30))          # the image, centred
        t = items.canonical_tensor(cv)
        self.assertEqual(len(t), items.CANVAS_PX * items.CANVAS_PX * 3)
        self.assertEqual(t, items.canonical_tensor(items.canonical_canvas(master)))   # deterministic

    def test_patch_major_layout(self):
        from PIL import Image
        cv = Image.new("RGB", (items.CANVAS_PX, items.CANVAS_PX), (0, 0, 0))
        cv.putpixel((14, 0), (7, 8, 9))                                   # first pixel of patch (0, 1)
        t = items.canonical_tensor(cv)
        per_patch = 3 * 14 * 14
        self.assertEqual(t[per_patch + 0], 7)                             # R plane of patch 1, (0, 0)
        self.assertEqual(t[per_patch + 196], 8)                           # G plane
        self.assertEqual(t[per_patch + 392], 9)                           # B plane

    def test_exif_orientation_applied_and_garbage_refused(self):
        import io
        from PIL import Image
        im = Image.new("RGB", (40, 20), (10, 20, 30))
        ex = Image.Exif(); ex[0x0112] = 6                                 # rotate 90 on display
        buf = io.BytesIO(); im.save(buf, "JPEG", exif=ex)
        _, w, h = items.lossless_master(buf.getvalue())
        self.assertEqual((w, h), (20, 40))
        with self.assertRaises(items.ImageRefused):
            items.lossless_master(b"\x89PNG not really")

    def test_image_commitment_salted(self):
        t = b"\x01" * 10
        self.assertNotEqual(items.image_commitment(b"\x00" * 32, t), items.image_commitment(b"\x01" * 32, t))


class TestRecords(unittest.TestCase):
    def test_placeholder_labels(self):
        self.assertEqual(records.placeholder_labels("Lovely sunrise run today"), {"sexual": "no", "violence": "no", "hate": "no"})
        self.assertEqual(records.placeholder_labels("I will bomb the place")["violence"], "yes")
        self.assertEqual(records.placeholder_labels("bombastic music")["violence"], "no")   # whole words only

    def test_categories_pinned_and_threshold(self):
        cats = records.categories()
        self.assertEqual([c["id"] for c in cats], ["sexual", "violence", "hate"])
        for c, cfg in zip(cats, config.CATEGORIES):
            self.assertEqual(c["policy"]["sha256"], cfg["sha256"])
            self.assertIn("<Query>:", c["policy"]["text"])
        self.assertEqual(records.threshold()["c"], 0.0)

    def test_visibility_fail_closed(self):
        minor, adult = records.audience_of("minor"), records.audience_of("adult")
        ok, why = records.visibility({"sexual": "no", "violence": "no", "hate": "no"}, minor)
        self.assertTrue(ok)
        ok, why = records.visibility({"sexual": "yes", "violence": "no", "hate": "no"}, minor)
        self.assertFalse(ok)
        self.assertEqual(why[0]["category"], "sexual")
        ok, why = records.visibility({"sexual": "no", "violence": "unproved", "hate": "no"}, minor)
        self.assertFalse(ok)                                                   # unproved = most restrictive
        self.assertIn("not proved", why[0]["why"])
        self.assertTrue(records.visibility({"sexual": "yes", "violence": "unproved", "hate": "yes"}, adult)[0])
        custom = records.audience_of("adult", "hate")
        self.assertFalse(records.visibility({"sexual": "no", "violence": "no", "hate": "yes"}, custom)[0])
        self.assertEqual(records.effective_labels(None), {"sexual": "unproved", "violence": "unproved", "hate": "unproved"})


class TestChunking(unittest.TestCase):
    def test_plan(self):
        self.assertEqual(prompting.chunk_plan(20, 31, 8, 4), [{"index": 0, "start": 0, "end": 20}])
        self.assertEqual(prompting.chunk_plan(50, 31, 8, 4), [{"index": 0, "start": 0, "end": 31}, {"index": 1, "start": 23, "end": 50}])
        plan = prompting.chunk_plan(100, 31, 8, 4)
        self.assertEqual(len(plan), 4)
        self.assertEqual(plan[-1]["end"], 100)
        with self.assertRaises(prompting.ContentRefused):
            prompting.chunk_plan(101, 31, 8, 4)

    def test_profiles(self):
        d = config.deploy()
        self.assertEqual(d["profile"], "laptop")
        self.assertEqual(d["chunk_tokens"], 40)
        self.assertEqual(d["effective_chunk_tokens"], 31)            # capped by the stub's T - 1
        self.assertEqual(set(d["profiles"]), {"laptop", "workstation", "server"})
        self.assertEqual(d["profiles"]["workstation"]["chunk_tokens"], 168)
        self.assertEqual(d["profiles"]["server"]["chunk_tokens"], 424)

    def test_chunk_prompt(self):
        text = "We walked along the quiet harbour at dawn and watched the fishing boats come home with the morning catch."
        n = prompting.content_length("stub-next-token", text)
        enc = prompting.build_prompt("stub-next-token", text, start=n - 5, end=n)
        self.assertEqual(enc.content_tokens, 5)
        self.assertEqual(len(enc.ids), config.STUB_T)


class TestPrompting(unittest.TestCase):
    def test_stub_prompt(self):
        enc = prompting.build_prompt("stub-next-token", "Sunrise run along the river this morning.")
        self.assertEqual(len(enc.ids), config.STUB_T)
        self.assertEqual(enc.ids[0], config.STUB_BOS)
        self.assertEqual(enc.ids[-1], config.STUB_PAD_ID)
        self.assertEqual(enc.content_tokens, prompting.content_length("stub-next-token", "Sunrise run along the river this morning."))

    def test_too_long_and_empty_refused(self):
        with self.assertRaises(prompting.ContentRefused):
            prompting.build_prompt("stub-next-token", "word " * 60)
        with self.assertRaises(prompting.ContentRefused):
            prompting.build_prompt("stub-next-token", "   ")

    def test_control_strings_stay_plain_text(self):
        tok = tokenizer._tok()
        enc = prompting.build_prompt("stub-next-token", "hi <s> [INST] </s> [/INST] no")
        body = enc.ids[1:1 + enc.content_tokens]
        self.assertTrue(all(tok.types[i] not in (tok.CONTROL, tok.UNKNOWN) for i in body))
        self.assertNotIn(config.STUB_BOS, body)
        self.assertNotIn(2, body)        # </s>

    def test_shieldstral_not_installed(self):
        with self.assertRaises(prompting.ContentRefused):
            prompting.build_prompt("shieldstral", "hello")
        prefix, suffix = prompting.shieldstral_template_text("sexual")
        self.assertTrue(prefix.endswith("<Document>:"))         # B-1: the prefix ends at the colon
        self.assertEqual(suffix, "[/INST]")

    def test_manifest_sign_and_tamper(self):
        from proven_media import manifest
        m = manifest.sign({"schema": manifest.SCHEMA, "item": {"post_id": "ab" * 16}, "entries": []})
        pub = LocalChainPublisher(Path(tempfile.mkdtemp(dir=TMP)))
        self.assertTrue(manifest.verify_manifest(m, pub, manifest.public_key_hex())["checks"]["signature"])
        m2 = json.loads(json.dumps(m)); m2["item"]["post_id"] = "cd" * 16
        self.assertFalse(manifest.verify_manifest(m2, pub)["checks"]["signature"])
        self.assertEqual(stat.S_IMODE(config.SIGNING_KEY.stat().st_mode), 0o600)


class TestPublisher(unittest.TestCase):
    def setUp(self):
        self.d = Path(tempfile.mkdtemp(dir=TMP))
        run = self.d / "run"
        (run / "statement").mkdir(parents=True)
        (run / "segment-000.bin").write_bytes(b"A" * 1000)
        (run / "segment-001.bin").write_bytes(b"B" * 700)
        (run / "statement" / "statement.json").write_text('{"x":1}')
        self.run = run
        self.pub = LocalChainPublisher(self.d / "public", batch_secs=600)

    def rec(self, pid=None, verdict="no", category="sexual"):
        import secrets
        salt = secrets.token_bytes(32)
        return PublicationRecord(post_id=pid or secrets.token_hex(16), category=category, statement=b'{"x":1}',
                                 receipt_segments=[str(self.run / "segment-000.bin"), str(self.run / "segment-001.bin")],
                                 verdict=verdict, model_id="cd" * 32, policy_id="12" * 32, profile_id="ef" * 32,
                                 verifier_id="ab" * 32, content_commitment=content_commitment(salt, b"hello"),
                                 segments_json=b"[]")

    def test_merkle(self):
        for n in (1, 2, 3, 5, 8, 13):
            leaves = [hashlib.sha256(bytes([i])).hexdigest() for i in range(n)]
            root, proofs, srt = publisher.merkle(leaves)
            for x in leaves:
                self.assertTrue(publisher.merkle_check(x, proofs[x], root))
            self.assertFalse(publisher.merkle_check("00" * 32, proofs[leaves[0]], root))

    def test_pending_then_anchored_then_verified(self):
        a = self.pub.publish(self.rec())
        self.assertEqual(a.status, "pending")
        r = self.pub.verify_publication(a)
        self.assertFalse(r["accepted"])
        self.assertTrue(r["pending"])
        self.assertIsNone(self.pub.tick())                      # not due yet
        others = [self.pub.publish(self.rec()) for _ in range(4)]
        bid = self.pub.tick(force=True)
        self.assertEqual(bid, "batch-000000")
        for x in [a] + others:
            ar = self.pub.anchor_of(x.post_id, x.category)
            self.assertEqual(ar.status, "anchored")
            r = self.pub.verify_publication(ar)
            self.assertTrue(r["accepted"], r["reasons"])
        self.assertEqual(self.pub.pending_list(), [])
        self.assertEqual(len(self.pub.blocks_list()), 1)

    def test_batch_due_by_time(self):
        a = self.pub.publish(self.rec())
        self.assertIsNotNone(self.pub.tick(now=time.time() + 601))
        self.assertEqual(self.pub.anchor_of(a.post_id, a.category).status, "anchored")

    def test_labels_yes_and_no_published_unproved_refused_once_only(self):
        import secrets
        pid = secrets.token_hex(16)
        self.pub.publish(self.rec(pid, "yes", "sexual"))
        self.pub.publish(self.rec(pid, "no", "violence"))
        with self.assertRaises(PublishError):
            self.pub.publish(self.rec(pid, "unproved", "hate"))
        with self.assertRaises(PublishError):
            self.pub.publish(self.rec(pid, "no", "violence"))                  # proved once
        self.assertEqual(sorted(self.pub.anchors_of(pid)), ["c0.sexual", "c0.violence"])

    def test_tamper_detected(self):
        a = self.pub.publish(self.rec())
        self.pub.tick(force=True)
        ar = self.pub.anchor_of(a.post_id, a.category)
        seg = json.loads(self.pub.get_bytes(ar.manifest_sha256))["segments"][0]
        os.chmod(self.pub._obj(seg["sha256"]), 0o600)
        self.pub._obj(seg["sha256"]).unlink()                       # break the hard link first
        self.pub._obj(seg["sha256"]).write_bytes(b"Z" * seg["bytes"])
        r = self.pub.verify_publication(ar)
        self.assertFalse(r["checks"]["receipt_segments"])
        bl = (self.pub.blocks).read_text().splitlines()
        b = json.loads(bl[0]); b["ts"] = "1999-01-01T00:00:00Z"
        self.pub.blocks.write_text(json.dumps(b) + "\n")
        r = self.pub.verify_publication(ar)
        self.assertFalse(r["checks"]["chain_integrity"])
        ar.merkle_proof = ["00" * 32]
        self.assertFalse(self.pub.verify_publication(ar)["checks"]["merkle_path"])

    def test_salted_commitment(self):
        c1 = content_commitment(b"\x01" * 32, b"hello")
        c2 = content_commitment(b"\x02" * 32, b"hello")
        self.assertNotEqual(c1, c2)
        with self.assertRaises(ValueError):
            content_commitment(b"short", b"hello")


class TestStubJobLayout(unittest.TestCase):
    def test_start_writes_private_files_and_no_content_in_env(self):
        launched = []
        orig = provers.launch_detached
        provers.launch_detached = lambda job: launched.append(job)
        try:
            exp = config.STUB_VERIFIER_EXPORT
            exp.mkdir(parents=True, exist_ok=True)       # skip the hard-link copy in the test
            text = "Sunrise run along the river this morning."
            job = config.JOBS_DIR / "abc123" / "prove"
            provers.StubProver().start("abc123", items.TextItem(text), job)
        finally:
            provers.launch_detached = orig
        self.assertEqual(launched, [job])
        self.assertEqual(stat.S_IMODE(job.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((job / "prompt").stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE((job / "job.env").stat().st_mode), 0o600)
        env = (job / "job.env").read_text()
        self.assertNotIn("Sunrise", env)
        ids = (job / "prompt").read_text().strip().split(",")
        self.assertEqual(len(ids), 32)
        for tok in ids[1:5]:
            self.assertNotIn(f"={tok}\n", env)
        self.assertIn("MODE='prove'", env)

    def test_media_not_supported(self):
        with self.assertRaises(provers.NotSupported):
            provers.StubProver().start("x", items.ImageItem(Path("/nonexistent"), "0" * 64, "image/png", 1), Path(TMP) / "nojob")

    def test_poll_files(self):
        j = Path(tempfile.mkdtemp(dir=TMP))
        (j / "step.current").write_text("prove 100\n")
        (j / "logs").mkdir()
        (j / "logs" / "prove.guard.out").write_text("[zk60-guard 1] admission waiting: budget\n")
        st = provers.poll(j)
        self.assertEqual(st["step"], "prove")
        self.assertTrue(st["waiting_for_machine"])
        (j / "pipeline.done").write_text("12\n")
        st = provers.poll(j)
        self.assertTrue(st["done"])
        self.assertEqual(st["exit"], 12)


class TestWebFlowFake(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from fastapi.testclient import TestClient
        from proven_media import app as appmod
        from proven_media.jobs import Worker

        cls.appmod = appmod
        cls.client = TestClient(appmod.app).__enter__()
        cls.worker = Worker(appmod.S.store, appmod.S.prover, appmod.S.publisher)

    @classmethod
    def tearDownClass(cls):
        cls.client.__exit__(None, None, None)

    def setUp(self):
        self.login_as('fixture_operator')

    def login_as(self, author):
        key = self.appmod.S.auth.provision(author, operator=True, rotate=True)
        response = self.client.post('/api/session', json={'access_key': key})
        self.assertEqual(response.status_code, 200, response.text)
        self.client.headers['X-PM-CSRF'] = response.json()['csrf']

    def submit_as(self, *, data, **kwargs):
        # Explicit fixture credential provisioning; no production test bypass.
        self.login_as(data['author'])
        return self.client.post('/api/posts', data=data, **kwargs)

    def drain(self):
        for _ in range(10):
            self.worker.tick()

    def test_worker_thread_starts_and_stops(self):
        from proven_media.jobs import Worker
        w = Worker(self.appmod.S.store, self.appmod.S.prover, self.appmod.S.publisher, interval=0.05)
        w.start()
        time.sleep(0.2)
        w.stop()
        w.join(5)
        self.assertFalse(w.is_alive())

    def test_changed_threshold_cannot_reprove_or_start_an_old_queued_item(self):
        from unittest.mock import patch
        text = 'A queued item keeps its original screening threshold'
        response = self.submit_as(data={'author': 'ruling', 'text': text})
        self.assertEqual(response.status_code, 200, response.text)
        pid = response.json()['post_id']
        with patch.object(config, 'TAU', 0.75):
            repeat = self.submit_as(data={'author': 'someone_else', 'text': text})
            self.assertEqual(repeat.status_code, 409, repeat.text)
            self.drain()
            post = self.appmod.S.store.post(pid)
            self.assertEqual(post['status'], 'failed')
            self.assertEqual(post['prove_attempted'], 0)
            self.assertNotIn(pid, [p['id'] for p in self.client.get('/api/feed').json()['posts']])
            self.assertFalse(self.appmod.S.publisher.anchors_of(pid))

    def test_labelled_post_published_anchored_manifest_and_rechecked(self):
        c = self.client
        r = self.submit_as(data={"author": "alice", "kind": "text", "text": "Hello sunny world"})
        self.assertEqual(r.status_code, 200, r.text)
        pid = r.json()["post_id"]
        self.drain()
        p = c.get(f"/api/posts/{pid}").json()
        self.assertEqual(p["status"], "published")
        self.assertEqual({x["category"]: x["value"] for x in p["labels"]}, {"sexual": "no", "violence": "no", "hate": "no"})
        self.assertEqual(set(p["publication"]["anchors"]), {"c0.sexual", "c0.violence", "c0.hate"})
        self.assertTrue(all(a["status"] == "pending" for a in p["publication"]["anchors"].values()))
        self.assertEqual(len(pid), 32)
        m = p["manifest"]
        self.assertEqual(m["schema"], "zk60.manifest/1")
        self.assertEqual([e["category"] for e in m["entries"]], ["sexual", "violence", "hate"])
        vm = c.post(f"/api/posts/{pid}/verify-manifest").json()
        self.assertTrue(vm["accepted"], vm["reasons"])
        self.assertEqual(sorted(vm["pending_anchor"]), ["c0.hate", "c0.sexual", "c0.violence"])
        self.assertEqual(c.post("/api/ledger/close-batch").status_code, 200)
        p = c.get(f"/api/posts/{pid}").json()
        self.assertTrue(all(a["status"] == "anchored" for a in p["publication"]["anchors"].values()))
        vm = c.post(f"/api/posts/{pid}/verify-manifest").json()
        self.assertTrue(vm["accepted"], vm["reasons"])
        self.assertEqual(vm["pending_anchor"], [])
        vp = c.post(f"/api/posts/{pid}/verify-publication").json()
        self.assertTrue(vp["accepted"], vp)
        salt = bytes.fromhex(p["publication"]["salt"])
        self.assertEqual(content_commitment(salt, b"Hello sunny world"), m["item"]["content_commitment"])
        dl = c.get(f"/api/posts/{pid}/manifest.json")
        self.assertEqual(dl.status_code, 200)
        self.assertIn(f"{pid}.manifest.json", dl.headers["content-disposition"])
        for aud in ("adult", "minor"):
            self.assertIn(pid, [x["id"] for x in c.get(f"/api/feed?audience={aud}").json()["posts"] if not x.get("hidden")])
        self.assertEqual(c.post(f"/api/posts/{pid}/verify").status_code, 200)
        self.drain()
        self.assertEqual(len(c.get(f"/api/posts/{pid}").json()["checks"]), 1)

    def test_yes_label_published_but_hidden_from_minors(self):
        c = self.client
        pid = self.submit_as(data={"author": "bob", "kind": "text", "text": "Graphic story: they will bomb it"}).json()["post_id"]
        self.drain()
        p = c.get(f"/api/posts/{pid}").json()
        self.assertEqual(p["status"], "published")                          # not rejected for a yes label
        self.assertEqual({x["category"]: x["value"] for x in p["labels"]}["violence"], "yes")
        c.cookies.clear()  # View audience restrictions as an unrelated reader.
        adult = [x for x in c.get("/api/feed?audience=adult").json()["posts"] if x["id"] == pid][0]
        self.assertFalse(adult.get("hidden", False))
        self.assertIn("manifest", adult)                                    # the manifest travels with the item
        minor = [x for x in c.get("/api/feed?audience=minor").json()["posts"] if x["id"] == pid][0]
        self.assertTrue(minor["hidden"])
        self.assertNotIn("text", minor)                                     # content never served when hidden
        self.assertEqual(minor["reasons"][0]["category"], "violence")
        pm = c.get(f"/api/posts/{pid}?audience=minor").json()
        self.assertTrue(pm["hidden"])
        self.assertEqual(c.get(f"/api/posts/{pid}/manifest.json?audience=minor").status_code, 403)

    def test_fail_closed_per_category(self):
        c = self.client
        pid = self.submit_as(data={"author": "fay", "kind": "text",
                                         "text": "please refuse " + provers.FakeProver.REFUSE_MARK}).json()["post_id"]
        self.drain()
        p = c.get(f"/api/posts/{pid}").json()
        self.assertEqual(p["status"], "failed")
        self.assertIn("Could not be verified", p["status_message"])
        self.assertEqual(p, {'id': pid, 'status': 'failed', 'status_message': 'Could not be verified.'})
        self.assertEqual(c.post(f"/api/posts/{pid}/verify-manifest").status_code, 404)
        for audience in ('adult', 'minor'):
            self.assertNotIn(pid, [x['id'] for x in c.get(f'/api/feed?audience={audience}').json()['posts']])
        self.assertNotIn('publication', p)
        self.assertFalse(self.appmod.S.publisher.anchors_of(pid))
        self.assertTrue(self.appmod.S.store.post(pid)['prove_attempted'])          # the fake prover "ran": proved once, no re-proving
        r = self.submit_as(data={"author": "fay", "kind": "text",
                                       "text": "please refuse " + provers.FakeProver.REFUSE_MARK})
        self.assertEqual(r.status_code, 409)

    def test_same_content_screened_once(self):
        c = self.client
        r1 = self.submit_as(data={"author": "gus", "kind": "text", "text": "Dedupe me please"})
        self.assertEqual(r1.status_code, 200)
        self.drain()
        r2 = self.submit_as(data={"author": "hal", "kind": "text", "text": "Dedupe me please"})
        self.assertEqual(r2.status_code, 409)
        self.assertIn("proved once", r2.json()["detail"])

    def test_recheck_rejection_makes_labels_unproved(self):
        c = self.client
        pid = self.submit_as(data={"author": "ivy", "kind": "text", "text": "Will be withdrawn later"}).json()["post_id"]
        self.drain()
        self.assertEqual(c.get(f"/api/posts/{pid}").json()["status"], "published")
        self.appmod.S.prover.reject_rechecks = True
        try:
            c.post(f"/api/posts/{pid}/verify")
            self.drain()
        finally:
            self.appmod.S.prover.reject_rechecks = False
        p = c.get(f"/api/posts/{pid}").json()
        self.assertEqual(p, {'id': pid, 'status': 'failed', 'status_message': 'Could not be verified.'})
        self.assertEqual(p['status'], 'failed')
        for audience in ('adult', 'minor'):
            self.assertNotIn(pid, [x['id'] for x in c.get(f'/api/feed?audience={audience}').json()['posts']])

    def test_delete_crypto_shreds(self):
        c = self.client
        pid = self.submit_as(data={"author": "jo", "kind": "text", "text": "Delete me afterwards"}).json()["post_id"]
        self.drain()
        c.post("/api/ledger/close-batch")
        self.login_as('someone')
        self.assertEqual(c.delete(f"/api/posts/{pid}?author=jo").status_code, 404)
        self.login_as('jo')
        self.assertEqual(c.delete(f"/api/posts/{pid}").status_code, 200)
        row = self.appmod.S.store.post(pid)
        self.assertIsNone(row["text"])
        self.assertIsNone(row["salt_enc"])
        self.assertEqual(row["status"], "deleted")
        self.assertIsNone(c.get(f"/api/posts/{pid}").json().get("publication"))
        self.assertEqual(self.appmod.S.publisher.anchor_of(pid, "sexual").status, "anchored")    # the leaf stays

    def test_too_long_refused(self):
        r = self.submit_as(data={"author": "carol", "kind": "text", "text": "word " * 150})
        self.assertEqual(r.status_code, 400)
        self.assertIn("chunks", r.json()["detail"])

    def test_long_post_chunked_labels_aggregate(self):
        c = self.client
        safe = ("We walked along the quiet harbour at dawn and watched the fishing boats come home with the morning catch. "
                "The cafe on the corner opened early, and the bakery smelled of fresh bread and cinnamon rolls. ")
        text = safe + "Later the film showed a massacre."            # placeholder 'violence' only in the last chunk
        t = c.post("/api/tokenize", json={"text": text}).json()
        self.assertGreaterEqual(t["chunks"], 2)
        self.assertEqual(t["proofs"], 3 * t["chunks"])
        r = self.submit_as(data={"author": "kai", "kind": "text", "text": text}).json()
        pid = r["post_id"]
        self.assertEqual(r["chunks"], t["chunks"])
        p = c.get(f"/api/posts/{pid}").json()
        self.assertEqual(p['status'], 'pending')
        self.assertNotIn('chunks', p)
        self.assertEqual(len(self.appmod.S.store.q('SELECT * FROM jobs WHERE post_id=?', (pid,))), t['chunks'])
        self.drain()
        p = c.get(f"/api/posts/{pid}").json()
        self.assertEqual(p["status"], "published")
        self.assertTrue(all(ch["status"] == "done" for ch in p["chunks"]))
        labels = {x["category"]: x["value"] for x in p["labels"]}
        self.assertEqual(labels["violence"], "yes")                 # yes in ANY chunk
        self.assertEqual(p["chunks"][0]["labels"]["violence"], "no")
        self.assertEqual(p["chunks"][-1]["labels"]["violence"], "yes")
        m = p["manifest"]
        self.assertEqual(len(m["entries"]), 3 * t["chunks"])
        self.assertEqual(m["entries"][-1]["token_range"][1], t["count"])
        self.assertEqual(len(p["publication"]["anchors"]), 3 * t["chunks"])
        self.assertTrue(c.post(f"/api/posts/{pid}/verify-manifest").json()["accepted"])
        st = c.get("/api/status").json()
        self.assertEqual(st["deploy"]["effective_chunk_tokens"], 31)

    def test_one_chunk_without_proof_fails_closed(self):
        c = self.client
        safe = ("We walked along the quiet harbour at dawn and watched the fishing boats come home with the morning catch. "
                "The cafe on the corner opened early, and the bakery smelled of fresh bread and cinnamon rolls. ")
        text = safe + "Then " + provers.FakeProver.REFUSE_MARK
        pid = self.submit_as(data={"author": "lea", "kind": "text", "text": text}).json()["post_id"]
        self.drain()
        p = c.get(f"/api/posts/{pid}").json()
        private_chunks = self.appmod.S.store.q('SELECT * FROM chunk_proofs WHERE post_id=? ORDER BY chunk', (pid,))
        self.assertEqual(private_chunks[0]['status'], 'done')
        self.assertEqual(private_chunks[-1]['status'], 'failed')
        self.assertEqual(p, {'id': pid, 'status': 'failed', 'status_message': 'Could not be verified.'})
        self.assertFalse(self.appmod.S.publisher.anchors_of(pid))
        for audience in ('adult', 'minor'):
            self.assertNotIn(pid, [x['id'] for x in c.get(f'/api/feed?audience={audience}').json()['posts']])

    def test_image_pending_verification_author_only(self):
        import io

        from PIL import Image
        buf = io.BytesIO()
        Image.new("RGB", (64, 48), (200, 30, 30)).save(buf, "PNG")
        r = self.submit_as(data={"author": "dana", "kind": "image"},
                             files={"file": ("a.png", buf.getvalue(), "image/png")})
        self.assertEqual(r.status_code, 200, r.text)
        pid = r.json()["post_id"]
        p = self.client.get(f"/api/posts/{pid}").json()
        self.assertEqual(p["status"], "in-development")
        self.assertEqual(p["media"]["width"], 64)
        self.assertEqual(p["media"]["canvas_px"], 224)
        self.assertEqual(len(p["media"]["salted_commitment"]), 64)
        self.assertNotIn(pid, [x["id"] for x in self.client.get("/api/feed").json()["posts"]])   # clean content only
        self.assertEqual(self.client.get(f"/api/posts/{pid}/canvas.png").status_code, 200)
        self.login_as('eve')
        self.assertEqual(self.client.get(f"/api/posts/{pid}/canvas.png?author=dana").status_code, 404)
        r2 = self.submit_as(data={"author": "eve", "kind": "image"},
                              files={"file": ("b.png", buf.getvalue(), "image/png")})
        self.assertEqual(r2.status_code, 409)                              # proved once: no repeat
        r3 = self.submit_as(data={"author": "dana", "kind": "video"},
                              files={"file": ("v.mp4", b"\x00\x00\x00\x14ftypisom", "video/mp4")})
        self.assertEqual(r3.status_code, 400)                              # video deferred

    def test_bad_upload_type(self):
        r = self.submit_as(data={"author": "erin", "kind": "image"},
                             files={"file": ("x.png", b"not an image at all", "image/png")})
        self.assertEqual(r.status_code, 400)


if __name__ == "__main__":
    unittest.main()
