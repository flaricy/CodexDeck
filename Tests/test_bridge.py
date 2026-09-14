import importlib.util, pathlib, unittest, time, tempfile, sqlite3, json
from unittest.mock import patch
p=pathlib.Path(__file__).resolve().parents[1]/'Bridge/bridge.py'
spec=importlib.util.spec_from_file_location('bridge',p);b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
class Tests(unittest.TestCase):
    def test_desktop_name_wins_over_raw_prompt(self):
        raw='# Files mentioned by the user:\n## photo.jpg: /tmp/photo.jpg\n## My request:\n帮我做一个 iOS App'
        self.assertEqual(b.display_title({'name':'构建 Codex iOS 快捷盘','title':raw}),'构建 Codex iOS 快捷盘')
        self.assertEqual(b.display_title({'name':' 新名字 ','title':raw}),'新名字')
        self.assertEqual(b.display_title({'title':raw}),'帮我做一个 iOS App')
        self.assertEqual(b.display_title({'title':''}),'未命名会话')
    def test_status(self):
        now=1000
        self.assertEqual(b.classify({'status':'completed'},[],now),'done')
        self.assertEqual(b.classify({'status':'inProgress','started_at':990},[],now),'running')
        self.assertEqual(b.classify({'status':'inProgress','started_at':1},[],now),'running')
        self.assertEqual(b.classify({'status':'interrupted'},[],now),'stopped')
    def test_silence_does_not_change_lifecycle(self):
        turn={'status':'inProgress','started_at':1}
        for elapsed in (180,3600,86400,604800):
            self.assertEqual(b.classify(turn,[],elapsed),'running')
        for status in ('interrupted','cancelled','failed'):
            self.assertEqual(b.classify({'status':status},[],604800),'stopped')
        self.assertEqual(b.classify(None,[],604800),'unknown')
        self.assertEqual(b.classify({'status':'unsupported'},[],604800),'unknown')
    def test_sync_error_retains_session_records(self):
        class Source:
            def sessions(self): return [{'id':'one','state':'running'}]
        deck=b.Deck(Source(),b.Quota('unused'),'token')
        deck.refresh()
        self.assertTrue(deck.snapshot()['historyFresh'])
        with patch.object(deck.history,'sessions',side_effect=OSError('unavailable')):
            deck.refresh()
        result=deck.snapshot()
        self.assertFalse(result['historyFresh'])
        self.assertEqual(result['sessions'],[{'id':'one','state':'running'}])
        self.assertIsNotNone(result['error'])
    def test_question_requires_structured_pending_event(self):
        turn={'status':'inProgress','started_at':990}
        self.assertEqual(b.classify(turn,[{'type':'requestUserInput','status':'pending'}],1000),'question')
        self.assertEqual(b.classify(turn,[{'type':'requestUserInput','status':'completed'}],1000),'running')
        self.assertEqual(b.classify(turn,[{'type':'agentMessage','text':'request_user_input pending'}],1000),'running')
        self.assertEqual(b.classify({'status':'completed'},[{'type':'requestUserInput','status':'pending'}],1000),'done')
    def test_windows_never_replace_missing_core_with_spark(self):
        self.assertEqual(b.windows({'rateLimitsByLimitId':{'spark':{'primary':{'usedPercent':1}}}}),[])
        actual=b.windows({'rateLimitsByLimitId':{'codex':{'primary':{'usedPercent':18,'windowDurationMins':10080,'resetsAt':123}}}})
        self.assertEqual(actual,[{'minutes':10080,'remaining':82,'resetsAt':123}])
        self.assertEqual(b.windows({'rateLimits':{'primary':{'usedPercent':None}}}),[])
    def test_focus_only_known_fresh_uuid(self):
        deck=b.Deck(None,b.Quota('unused'),'x');id='12345678-1234-1234-1234-123456789012';deck.data=[{'id':id}];deck.at=time.time()
        with patch.object(b.subprocess,'run') as run:
            with self.assertRaises(ValueError):deck.focus('$(touch /tmp/bad)')
            with self.assertRaises(ValueError):deck.focus('00000000-0000-0000-0000-000000000000')
            run.assert_not_called();deck.focus(id);run.assert_called_once_with(['/usr/bin/open','codex://threads/'+id],check=True,timeout=5)
            deck.at=0
            with self.assertRaises(ValueError):deck.focus(id)
    def test_readonly_history(self):
        with tempfile.TemporaryDirectory() as d:
            c=sqlite3.connect(d+'/state_5.sqlite');c.execute('create table threads(id,title,cwd,updated_at,source,originator,archived)');c.execute('insert into threads values(?,?,?,?,?,?,?)',('1','Title','/a/project',100,'vscode','Codex Desktop',0));c.commit();c.close()
            c=sqlite3.connect(d+'/thread_history_1.sqlite');c.execute('create table thread_turns(thread_id,turn_id,rollout_ordinal,status,started_at)');c.execute('create table thread_items(thread_id,turn_id,rollout_ordinal,item_json,created_at_ms)');c.execute("insert into thread_turns values('1','t',1,'completed',99)");c.commit();c.close()
            self.assertEqual(b.History(d).sessions()[0]['state'],'done')
            c=sqlite3.connect(d+'/state_5.sqlite')
            c.execute('alter table threads add column name TEXT')
            c.execute("update threads set name='桌面会话名称'");c.commit()
            self.assertEqual(b.History(d).sessions()[0]['title'],'桌面会话名称')
            c.execute("update threads set name='重新命名'");c.commit();c.close()
            self.assertEqual(b.History(d).sessions()[0]['title'],'重新命名')
            with b.History(d).connect('state_5.sqlite') as c:
                with self.assertRaises(sqlite3.OperationalError):c.execute('delete from threads')
if __name__=='__main__':unittest.main()
