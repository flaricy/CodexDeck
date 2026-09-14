"""Exercise the actual Apple URLSession delegate, not a duplicated policy."""
import pathlib
import platform
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

@unittest.skipUnless(platform.system() == 'Darwin', 'Requires Apple URLSession and Security')
class RedirectTests(unittest.TestCase):
    def test_pairing_delegate_does_not_follow_redirect(self):
        hits=[]
        class Handler(BaseHTTPRequestHandler):
            def log_message(self,*args): pass
            def do_GET(self):
                hits.append(self.path)
                self.send_response(302 if self.path == '/state' else 200)
                self.send_header('Location','/unexpected')
                self.send_header('Content-Length','0')
                self.end_headers()
        server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
        worker=threading.Thread(target=server.serve_forever,daemon=True);worker.start()
        try:
            model=(pathlib.Path(__file__).resolve().parents[1]/'iOS/CodexDeck/Model.swift').read_text()
            delegate=model.split('final class PinnedTrust:',1)[1].split('\nenum Vault',1)[0]
            source='import Foundation\nimport Security\nimport CryptoKit\nfinal class PinnedTrust:'+delegate
            source+='''
let done=DispatchSemaphore(value:0)
let session=URLSession(configuration:.ephemeral,delegate:PinnedTrust(pin:"unused"),delegateQueue:nil)
let url=URL(string:CommandLine.arguments[1])!
session.dataTask(with:url) { _,response,error in
    guard error == nil, let http=response as? HTTPURLResponse, http.statusCode == 302 else {exit(2)}
    done.signal()
}.resume()
if done.wait(timeout:.now()+10) == .timedOut {exit(3)}
session.invalidateAndCancel()
'''
            with tempfile.TemporaryDirectory() as directory:
                swift=pathlib.Path(directory)/'Redirect.swift';swift.write_text(source)
                subprocess.run(['xcrun','swift',str(swift),f'http://127.0.0.1:{server.server_port}/state'],check=True,timeout=60,capture_output=True)
            self.assertEqual(hits,['/state'])
        finally:
            server.shutdown();server.server_close();worker.join(timeout=3)
