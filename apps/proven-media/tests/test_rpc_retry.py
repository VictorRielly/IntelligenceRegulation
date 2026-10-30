"""RPC throttling recovery retains pinned-chain checks and signed bytes."""
import io
import json
import unittest
import urllib.error
from unittest.mock import patch
from proven_media.base_sepolia import BaseSepoliaRPC, CHAIN_ID
from proven_media.publisher import PublishError


def error(code=429, retry_after='3'):
    return urllib.error.HTTPError('https://rpc.invalid', code, 'controlled error',
                                  {'Retry-After': retry_after}, None)


def response(result):
    return io.BytesIO(json.dumps({'jsonrpc':'2.0','id':1,'result':result}).encode())


class RetryTests(unittest.TestCase):
    def setUp(self):
        self.rpc=BaseSepoliaRPC('https://rpc.invalid','11'*20,'22'*32,'33'*20)

    def test_throttled_read_retries_and_checks_chain(self):
        with patch('urllib.request.urlopen',side_effect=[error(),response(hex(CHAIN_ID))]) as request, \
             patch('proven_media.base_sepolia.time.sleep') as sleep:
            self.rpc.check_chain()
        self.assertEqual(request.call_count,2)
        sleep.assert_called_once_with(3)

    def test_retry_does_not_accept_wrong_chain(self):
        with patch('urllib.request.urlopen',side_effect=[error(),response('0x1')]), \
             patch('proven_media.base_sepolia.time.sleep'):
            with self.assertRaisesRegex(PublishError,'non-Base-Sepolia'):
                self.rpc.check_chain()

    def test_broadcast_reuses_identical_payload(self):
        with patch('urllib.request.urlopen',side_effect=[error(503),response('0xhash')]) as request, \
             patch('proven_media.base_sepolia.time.sleep'):
            self.assertEqual(self.rpc.call('eth_sendRawTransaction',['0xsigned']), '0xhash')
        payloads=[c.args[0].data for c in request.call_args_list]
        self.assertEqual(payloads,[payloads[0]]*2)
        self.assertEqual(json.loads(payloads[0])['params'],['0xsigned'])

    def test_permanent_and_excessive_retry_responses_stop(self):
        for failure in (error(400),error(429,'31')):
            with self.subTest(code=failure.code),patch('urllib.request.urlopen',side_effect=failure) as request, \
                 patch('proven_media.base_sepolia.time.sleep') as sleep:
                with self.assertRaises(PublishError):self.rpc.call('eth_chainId',[])
                self.assertEqual(request.call_count,1)
                sleep.assert_not_called()

    def test_repeated_throttling_is_bounded(self):
        with patch('urllib.request.urlopen',side_effect=[error() for _ in range(4)]) as request, \
             patch('proven_media.base_sepolia.time.sleep') as sleep:
            with self.assertRaises(PublishError):self.rpc.call('eth_chainId',[])
        self.assertEqual(request.call_count,4)
        self.assertEqual([c.args[0] for c in sleep.call_args_list],[3,4,8])


if __name__=='__main__':unittest.main()
