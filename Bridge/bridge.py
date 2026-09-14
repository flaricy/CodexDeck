#!/usr/bin/env python3
"""Codex Deck: read-only local history + allowlisted session focus, HTTPS only."""
import argparse, hashlib, hmac, json, os, re, secrets, socket, sqlite3, ssl, subprocess, threading, time, uuid
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlencode, urlparse

QUESTION_TYPES = {'requestUserInput', 'userInputRequest', 'approvalRequest'}

def display_title(row):
    # Desktop sidebar name is distinct from `title`, which may contain raw input.
    name = (row.get('name') or '').strip()
    if name: return name
    text = row.get('title') or ''
    if '## My request:' in text: text = text.split('## My request:', 1)[1]
    text = re.sub(r'<[^>]+>[\s\S]*?</[^>]+>', '', text)
    for line in text.splitlines():
        line = line.strip().lstrip('#').strip()
        if not line or line.startswith(('Files mentioned', 'Distinguish instructions', '/', '<')): continue
        if re.search(r'\.(jpg|png|pdf|jpeg):\s*/', line, re.I): continue
        return line[:100]
    return '未命名会话'

def classify(turn, items, now):
    if not turn: return 'unknown'
    status = turn.get('status')
    if status == 'completed': return 'done'
    if status in ('failed', 'interrupted', 'cancelled'): return 'stopped'
    if status != 'inProgress': return 'unknown'
    for item in items:
        # Never infer a question from arbitrary command strings or agent prose.
        if item.get('type') in QUESTION_TYPES and item.get('status') in ('pending','inProgress','waiting'):
            return 'question'
        if item.get('type') == 'mcpToolCall' and item.get('tool') in ('request_user_input','request_user_input_async') and item.get('status') == 'inProgress':
            return 'question'
    # Output silence is not a lifecycle event. Preserve the recorded turn state.
    return 'running'

def windows(payload):
    buckets = payload.get('rateLimitsByLimitId')
    core = buckets.get('codex') if buckets else payload.get('rateLimits')
    result = []
    for value in ((core or {}).get('primary'), (core or {}).get('secondary')):
        if not value or value.get('usedPercent') is None: continue
        minutes = value.get('windowDurationMins')
        result.append({'minutes': minutes or 0, 'remaining': max(0,min(100,100-value['usedPercent'])), 'resetsAt': value.get('resetsAt')})
    return result

class History:
    def __init__(self, home): self.home = Path(home)
    def connect(self, name):
        conn = sqlite3.connect((self.home/name).as_uri()+'?mode=ro', uri=True, timeout=2)
        conn.row_factory = sqlite3.Row
        return conn
    def sessions(self):
        now = time.time()
        with self.connect('state_5.sqlite') as db:
            columns = {x[1] for x in db.execute('PRAGMA table_info(threads)')}
            name = 'name' if 'name' in columns else 'NULL AS name'
            rows = db.execute(f"SELECT id,title,{name},cwd,updated_at,source,originator FROM threads WHERE archived=0 AND source NOT LIKE '%subagent%' ORDER BY updated_at DESC LIMIT 60").fetchall()
        result = []
        with self.connect('thread_history_1.sqlite') as db:
            for row in rows:
                # Local desktop/extension threads only; remote hosts require their own bridge.
                if row['source'] != 'vscode': continue
                turn = db.execute('SELECT * FROM thread_turns WHERE thread_id=? ORDER BY rollout_ordinal DESC LIMIT 1',(row['id'],)).fetchone()
                items = []
                if turn:
                    for x in db.execute('SELECT item_json,created_at_ms FROM thread_items WHERE thread_id=? AND turn_id=? ORDER BY rollout_ordinal DESC LIMIT 32',(row['id'],turn['turn_id'])):
                        item = json.loads(x['item_json']); item['_at'] = (x['created_at_ms'] or 0)/1000; items.append(item)
                state = classify(dict(turn) if turn else None,items,now)
                result.append({'id':row['id'],'title':display_title(dict(row)),'project':Path(row['cwd']).name,'state':state,'updatedAt':row['updated_at']})
        return result

class Quota:
    def __init__(self, binary): self.binary=binary; self.value=[]; self.at=None; self.error=None; self.lock=threading.Lock()
    def refresh(self):
        # A separate read-only app-server client. Never resumes or starts a thread.
        request='\n'.join(json.dumps(x) for x in [
            {'id':1,'method':'initialize','params':{'clientInfo':{'name':'codex_deck','version':'0.1.0'}}},
            {'method':'initialized','params':{}},
            {'id':2,'method':'account/rateLimits/read','params':{}}])+'\n'
        p=None
        try:
            p=subprocess.Popen([self.binary,'app-server'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
            p.stdin.write(request);p.stdin.flush()
            timer=threading.Timer(20,p.kill);timer.start()
            try:
                for line in p.stdout:
                    data=json.loads(line)
                    if data.get('id')==2:
                        if 'error' in data: raise RuntimeError('额度接口暂不可用')
                        with self.lock:self.value=windows(data['result']);self.at=time.time();self.error=None
                        return
                raise RuntimeError('额度接口未返回数据')
            finally: timer.cancel()
        except Exception as e:
            with self.lock:self.error=str(e)
        finally:
            if p:
                if p.poll() is None:p.terminate()
                try:p.wait(timeout=3)
                except subprocess.TimeoutExpired:p.kill();p.wait()
    def loop(self):
        while True:self.refresh();time.sleep(60)

class Deck:
    def __init__(self, history, quota, token):
        self.history=history;self.quota=quota;self.token=token;self.lock=threading.Lock();self.data=[];self.at=None;self.error=None;self.last_focus=0
    def refresh(self):
        try:
            data=self.history.sessions()
            with self.lock:self.data=data;self.at=time.time();self.error=None
        except Exception:
            with self.lock:self.error='无法读取本机 Codex 会话记录；请检查版本和本地权限'
    def loop(self):
        while True:self.refresh();time.sleep(2)
    def snapshot(self):
        with self.lock:
            result={'sessions':self.data,'updatedAt':self.at,'error':self.error,'historyFresh':self.error is None and self.at is not None and time.time()-self.at<10,'host':socket.gethostname(),'source':'localHistory','questionDetection':'limited'}
        with self.quota.lock:result.update(usage=self.quota.value,usageUpdatedAt=self.quota.at,usageError=self.quota.error)
        return result
    def focus(self, thread_id):
        try: uuid.UUID(thread_id)
        except (ValueError,TypeError): raise ValueError('无效会话')
        with self.lock:
            if self.error or self.at is None or time.time()-self.at>10:raise ValueError('状态已过期，请等待重新连接')
            if not any(s['id']==thread_id for s in self.data):raise ValueError('会话已不可用')
            if time.monotonic()-self.last_focus<0.3:raise ValueError('点击过快')
            self.last_focus=time.monotonic()
        subprocess.run(['/usr/bin/open','codex://threads/'+thread_id],check=True,timeout=5)

def handler(deck):
    class Handler(BaseHTTPRequestHandler):
        def setup(self):
            super().setup(); self.connection.settimeout(5)
        def log_message(self,*args):pass  # Never log pairing credentials or conversation titles.
        def reply(self,code,data):
            b=json.dumps(data,ensure_ascii=False).encode();self.send_response(code);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Content-Length',str(len(b)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(b)
        def authorized(self):
            a=self.headers.get('Authorization','')
            return not self.headers.get('Origin') and hmac.compare_digest(a,'Bearer '+deck.token)
        def do_GET(self):
            if not self.authorized():return self.reply(401,{'error':'配对凭据无效'})
            if self.path!='/v1/state':return self.reply(404,{'error':'Not found'})
            self.reply(200,deck.snapshot())
        def do_POST(self):
            if not self.authorized():return self.reply(401,{'error':'配对凭据无效'})
            if self.path!='/v1/focus':return self.reply(404,{'error':'Not found'})
            try:
                n=int(self.headers.get('Content-Length','0'))
                if not 0<n<=1024:raise ValueError('无效请求')
                data=json.loads(self.rfile.read(n));deck.focus(data.get('threadId'));self.reply(200,{'ok':True})
            except (ValueError,subprocess.SubprocessError):self.reply(400,{'error':'无法打开会话，请检查 Mac 上的 Codex'})
    return Handler

def main():
    p=argparse.ArgumentParser();p.add_argument('--host');p.add_argument('--port',type=int,default=7643);p.add_argument('--advertise');p.add_argument('--codex-home',default=str(Path.home()/'.codex'));p.add_argument('--runtime',default=str(Path.home()/'Library/Application Support/CodexDeck'));p.add_argument('--codex');p.add_argument('--check',action='store_true');p.add_argument('--parent-pid',type=int);args=p.parse_args()
    if not args.codex:
        args.codex=next((str(x) for x in [Path('/Applications/Codex.app/Contents/Resources/codex'),Path('/Applications/ChatGPT.app/Contents/Resources/codex')] if x.exists()),'codex')
    if args.parent_pid:
        def watch_parent():
            while os.getppid()==args.parent_pid: time.sleep(2)
            os._exit(0)
        threading.Thread(target=watch_parent,daemon=True).start()
    history=History(args.codex_home)
    if args.check:
        rows=history.sessions();print(json.dumps({'sessions':len(rows),'states':{s:sum(x['state']==s for x in rows) for s in ('running','question','done','unknown','stopped')}}));return
    runtime=Path(args.runtime);runtime.mkdir(parents=True,exist_ok=True);runtime.chmod(0o700);os.umask(0o077)
    key=runtime/'key.pem';cert=runtime/'cert.pem';tokenfile=runtime/'token'
    if not key.exists() or not cert.exists():subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(key),'-out',str(cert),'-days','3650','-subj','/CN=CodexDeck'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    if not tokenfile.exists():tokenfile.write_text(secrets.token_urlsafe(32))
    token=tokenfile.read_text().strip();pin=hashlib.sha256(ssl.PEM_cert_to_DER_cert(cert.read_text())).hexdigest()
    host=args.advertise
    if not host:
        try:
            with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:s.connect(('192.0.2.1',80));host=s.getsockname()[0]
        except OSError:host=socket.gethostname()
    pairing='codexdeck://pair?'+urlencode({'host':host,'port':args.port,'token':token,'pin':pin})
    (runtime/'pairing.txt').write_text(pairing)
    print('\nCodex Deck · 在 iPhone 配对页粘贴下方链接（仅分享给自己的手机）：\n'+pairing+'\n',flush=True)
    quota=Quota(args.codex);deck=Deck(history,quota,token);deck.refresh()
    threading.Thread(target=deck.loop,daemon=True).start();threading.Thread(target=quota.loop,daemon=True).start()
    server=ThreadingHTTPServer((args.host or host,args.port),handler(deck));server.daemon_threads=True
    ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.minimum_version=ssl.TLSVersion.TLSv1_2;ctx.load_cert_chain(cert,key);server.socket=ctx.wrap_socket(server.socket,server_side=True)
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:server.server_close()
if __name__=='__main__':main()
