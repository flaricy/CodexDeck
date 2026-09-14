"""Transport regression: an idle TLS peer must not block other clients."""
import importlib.util
import pathlib
import socket
import ssl
import subprocess
import tempfile
import threading
import unittest
import urllib.request

spec = importlib.util.spec_from_file_location('bridge', pathlib.Path(__file__).resolve().parents[1] / 'Bridge/bridge.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)

class TransportTests(unittest.TestCase):
    def test_idle_tls_peer_does_not_block_state(self):
        with tempfile.TemporaryDirectory() as directory:
            cert, key = pathlib.Path(directory) / 'cert.pem', pathlib.Path(directory) / 'key.pem'
            subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(key),'-out',str(cert),'-days','1','-subj','/CN=localhost'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            deck = b.Deck(None, b.Quota('unused'), 'test-token')
            server = b.ThreadingHTTPServer(('127.0.0.1', 0), b.handler(deck))
            server.daemon_threads = True
            server.handle_error = lambda *_: None
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(cert, key)
            server.socket = context.wrap_socket(server.socket, server_side=True, do_handshake_on_connect=False)
            worker = threading.Thread(target=server.serve_forever, daemon=True)
            worker.start()
            try:
                with socket.create_connection(server.server_address, timeout=2):
                    request = urllib.request.Request('https://127.0.0.1:%d/v1/state' % server.server_port, headers={'Authorization':'Bearer test-token'})
                    with urllib.request.urlopen(request, context=ssl._create_unverified_context(), timeout=2) as response:
                        self.assertEqual(response.status, 200)
            finally:
                server.shutdown()
                server.server_close()
                worker.join(timeout=3)
