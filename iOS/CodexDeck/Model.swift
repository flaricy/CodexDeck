import SwiftUI
import CryptoKit
import Security

struct DeckSession: Codable, Identifiable {
    let id: String
    let title: String
    let project: String
    let state: String
    let updatedAt: Double
    var color: Color {
        switch state {
        case "running": return Color(red: 0.30, green: 0.64, blue: 1.0)
        case "question": return Color(red: 1, green: 0.60, blue: 0.29)
        case "done", "stopped", "idle": return Color(red: 0.33, green: 0.80, blue: 0.57)
        default: return Color(red: 0.51, green: 0.55, blue: 0.61)
        }
    }
    var canHide: Bool { ["done", "stopped", "idle", "unknown"].contains(state) }
    var label: String {
        ["running":"运行中", "question":"等你回答", "done":"已完成", "stopped":"STOP", "idle":"闲置"][state] ?? "状态待确认"
    }
    var icon: String {
        ["running":"waveform", "question":"questionmark.bubble.fill", "done":"checkmark", "stopped":"stop.fill"][state] ?? "ellipsis"
    }
}
struct UsageWindow: Codable, Identifiable {
    var id: Int { minutes }
    let minutes: Int
    let remaining: Double
    let resetsAt: Double?
}
struct Snapshot: Codable {
    let sessions: [DeckSession]
    let updatedAt: Double?
    let error: String?
    let host: String
    var historyFresh: Bool? = nil
    let usage: [UsageWindow]
    let usageUpdatedAt: Double?
    let usageError: String?
}
struct Pairing: Codable {
    let host: String
    let port: Int
    let token: String
    let pin: String
    init(_ text: String) throws {
        guard let parts = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), parts.scheme == "codexdeck", parts.host == "pair" else { throw DeckError.message("请粘贴 Mac 桥接程序显示的配对链接") }
        func value(_ name: String) -> String? { parts.queryItems?.first(where: { $0.name == name })?.value }
        guard let h = value("host"), !h.isEmpty, h.rangeOfCharacter(from: CharacterSet(charactersIn: "/@?# ")) == nil,
              let p = Int(value("port") ?? ""), (1...65535).contains(p),
              let t = value("token"), t.count >= 32,
              let f = value("pin"), f.count == 64, f.allSatisfy({ $0.isHexDigit }) else { throw DeckError.message("配对链接不完整，请重新复制") }
        host=h;port=p;token=t;pin=f.lowercased()
    }
    func url(_ path: String) -> URL? {
        var c=URLComponents(); c.scheme="https";c.host=host;c.port=port;c.path=path;return c.url
    }
}
enum DeckError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let s)=self { return s }; return nil }
}
final class PinnedTrust: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil) // Pairing authorizes one endpoint; never forward its bearer token.
    }
    let pin: String
    init(pin: String) { self.pin=pin }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust=challenge.protectionSpace.serverTrust,
              let certificates=SecTrustCopyCertificateChain(trust) as? [SecCertificate], let cert=certificates.first else { completionHandler(.cancelAuthenticationChallenge,nil);return }
        let hash=SHA256.hash(data: SecCertificateCopyData(cert) as Data).map { String(format:"%02x",$0) }.joined()
        guard hash == pin else { completionHandler(.cancelAuthenticationChallenge,nil);return }
        completionHandler(.useCredential,URLCredential(trust:trust))
    }
}
enum Vault {
    static let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"dev.codexdeck.pairing",kSecAttrAccount as String:"mac"]
    static func load() -> Pairing? {
        var q=query;q[kSecReturnData as String]=true
        var r:CFTypeRef?;guard SecItemCopyMatching(q as CFDictionary,&r)==errSecSuccess,let d=r as? Data else{return nil}
        return try? JSONDecoder().decode(Pairing.self,from:d)
    }
    static func save(_ p: Pairing) throws {
        let d=try JSONEncoder().encode(p)
        let status=SecItemUpdate(query as CFDictionary,[kSecValueData as String:d] as CFDictionary)
        if status == errSecItemNotFound {
            var q=query;q[kSecValueData as String]=d;q[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(q as CFDictionary,nil)==errSecSuccess else {throw DeckError.message("无法保存配对")}
        } else if status != errSecSuccess {throw DeckError.message("无法保存配对")}
    }
    static func clear() {SecItemDelete(query as CFDictionary)}
}
@MainActor final class DeckModel: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var sessions: [DeckSession]=[]
    @Published var connected=false
    @Published var message="等待连接 Mac"
    @Published var pairing=Vault.load()
    @Published var opening: String?
    @Published var demo=false
    @Published var keepAwake = UserDefaults.standard.object(forKey:"deck.keepAwake") as? Bool ?? true
    @Published var connectionHelp: String?
    @Published var hasSynced=false
    private var refreshing=false
    private var transport: URLSession?
    private var epoch=0
    private var feedbackUntil=Date.distantPast
    @Published private var selection=SessionSelection()
    var visibleSessions: [DeckSession] {
        let byID=Dictionary(uniqueKeysWithValues:sessions.map { ($0.id,$0) })
        return selection.selected.compactMap { byID[$0] }
    }
    var otherSessions: [DeckSession] { sessions.filter { !selection.selected.contains($0.id) } }
    private var selectionKey: String { "deck.selection.v3." + (pairing?.pin ?? "unpaired") }
    private func loadSelection() {
        let legacyKey="deck.selection.v2."+(pairing.map{"\($0.host):\($0.port)"} ?? "unpaired")
        let saved=UserDefaults.standard.data(forKey:selectionKey) ?? UserDefaults.standard.data(forKey:legacyKey)
        selection=saved.flatMap {try? JSONDecoder().decode(SessionSelection.self,from:$0)} ?? SessionSelection()
        saveSelection()
    }
    private func saveSelection() {
        guard !demo, let data=try? JSONEncoder().encode(selection) else{return}
        UserDefaults.standard.set(data,forKey:selectionKey)
    }
    private func reconcileSelection() {
        selection.reconcile(sessions.map { SessionCandidate(id:$0.id,active:["running","question"].contains($0.state),updatedAt:$0.updatedAt) })
        saveSelection()
    }
    func hide(_ s: DeckSession) {
        guard sessions.first(where:{$0.id==s.id})?.canHide == true else{return}
        selection.hide(s.id);saveSelection()
    }
    func show(_ s: DeckSession) { selection.show(s.id);saveSelection() }
    func exitDemo() {epoch+=1;demo=false;sessions=[];snapshot=nil;loadSelection()}

    var canFocus: Bool { connected && !demo && snapshot != nil && snapshot?.error == nil && snapshot?.historyFresh != false }
    init() {
        loadSelection()
        if let pairing { configure(pairing);loadCache() }
        #if DEBUG
        // Test credentials are supplied only through the launch environment, never shipped.
        let environment=ProcessInfo.processInfo.environment
        if let link=environment["CODEX_DECK_TEST_PAIRING"] { try? pair(link) }
        if let count=environment["CODEX_DECK_DEMO_COUNT"].flatMap(Int.init) { showDemo(count:count) }
        #endif
    }
    private var cacheKey: String {selectionKey+".snapshot"}
    private func loadCache() {
        if let data=UserDefaults.standard.data(forKey:cacheKey),let cached=try? JSONDecoder().decode(Snapshot.self,from:data) {snapshot=cached;sessions=cached.sessions;message="正在重新连接 Mac…"}
    }
    func toggleKeepAwake() {
        keepAwake.toggle()
        UserDefaults.standard.set(keepAwake,forKey:"deck.keepAwake")
        UIApplication.shared.isIdleTimerDisabled=keepAwake && UIApplication.shared.applicationState == .active
        let feedback=UIImpactFeedbackGenerator(style:.rigid)
        feedback.prepare();feedback.impactOccurred(intensity:1.0)
        feedbackUntil=Date().addingTimeInterval(3)
        message=keepAwake ? "常亮已开启 · 仅作用于 iPhone":"常亮已关闭 · 跟随系统锁屏"
    }
    func becameActive() {if !demo {connected=false;message=pairing == nil ? "等待连接 Mac":"正在连接 Mac…"}}
    func configure(_ p: Pairing) {
        transport?.invalidateAndCancel()
        let config=URLSessionConfiguration.ephemeral;config.timeoutIntervalForRequest=5;config.timeoutIntervalForResource=8
        transport=URLSession(configuration:config,delegate:PinnedTrust(pin:p.pin),delegateQueue:nil)
    }
    func pair(_ text: String) throws {
        let p=try Pairing(text);try Vault.save(p);epoch+=1;pairing=p;demo=false;connected=false;sessions=[];snapshot=nil;hasSynced=false;connectionHelp=nil;message="正在连接 Mac…";loadSelection();configure(p)
    }
    func unpair() { UserDefaults.standard.removeObject(forKey:cacheKey);connectionHelp=nil;hasSynced=false;epoch+=1;transport?.invalidateAndCancel();transport=nil;Vault.clear();pairing=nil;connected=false;snapshot=nil;sessions=[];demo=false;selection=SessionSelection();message="等待连接 Mac" }
    func request(_ path: String, body: Data?=nil) async throws -> Data {
        guard let p=pairing,let url=p.url(path),let transport else {throw DeckError.message("请先配对 Mac")}
        var r=URLRequest(url:url);r.setValue("Bearer "+p.token,forHTTPHeaderField:"Authorization")
        if let body {r.httpMethod="POST";r.httpBody=body;r.setValue("application/json",forHTTPHeaderField:"Content-Type")}
        let (d,response)=try await transport.data(for:r)
        guard let h=response as? HTTPURLResponse,h.statusCode==200 else {throw DeckError.message("Mac 拒绝连接，请检查配对或会话状态")}
        return d
    }
    func refresh() async {
        guard pairing != nil,!demo,!refreshing else{return};let generation=epoch
        refreshing=true;defer{refreshing=false}
        do {
            let data=try await request("/v1/state");let value=try JSONDecoder().decode(Snapshot.self,from:data)
            guard generation==epoch, !Task.isCancelled else{return}
            guard Set(value.sessions.map(\.id)).count == value.sessions.count else {throw DeckError.message("Mac 返回了重复会话，请稍后重试")}
            snapshot=value
            // A valid reply proves bridge connectivity, not that the agent is alive.
            connected=true;hasSynced=true;connectionHelp=nil
            if value.error == nil && value.historyFresh != false {
                let byID=Dictionary(uniqueKeysWithValues:value.sessions.map{($0.id,$0)})
                let oldIDs=Set(sessions.map(\.id))
                sessions=sessions.compactMap{byID[$0.id]}+value.sessions.filter{!oldIDs.contains($0.id)}
                reconcileSelection()
                if let cached=try? JSONEncoder().encode(value) {UserDefaults.standard.set(cached,forKey:cacheKey)}
                if Date() >= feedbackUntil {message=keepAwake ? "Mac 已连接 · 手机常亮":"Mac 已连接 · 系统锁屏"}
            } else {
                // Keep the last session records; never recolor a task because sync failed.
                message="正在同步会话…"
                connectionHelp="Mac 已连接，但暂时读不到 Codex 会话。请打开 Mac 上的 Codex，稍后会自动恢复。"
            }
        } catch {
            #if DEBUG
            print("Deck sync failure: \((error as NSError).domain) \((error as NSError).code): \(error.localizedDescription)")
            #endif
            guard generation==epoch, !Task.isCancelled else{return};connected=false;message="正在重新连接 Mac…"
            let ns=error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorNotConnectedToInternet {
                connectionHelp="请连接 Wi-Fi，并在 iPhone 设置中允许 Codex Deck 访问本地网络。"
            } else if ns.domain == NSURLErrorDomain && [NSURLErrorServerCertificateUntrusted,NSURLErrorCancelled].contains(ns.code) {
                connectionHelp="配对信息可能已更新，请从 Mac 菜单栏重新扫码连接。"
            } else {connectionHelp="请确认 Mac 已唤醒、Codex Deck 菜单栏程序正在运行，且两台设备连接同一网络。"}
        }
    }
    func focus(_ s: DeckSession) async {
        guard canFocus,opening==nil else{return};let generation=epoch;opening=s.id;defer{opening=nil}
        UIImpactFeedbackGenerator(style:.rigid).impactOccurred()
        do {
            _=try await request("/v1/focus",body:JSONEncoder().encode(["threadId":s.id]))
            guard generation==epoch, !Task.isCancelled else{return}
            feedbackUntil=Date().addingTimeInterval(3)
            message="已发送到 Mac";UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {guard generation==epoch, !Task.isCancelled else{return};message="跳转失败，请检查 Mac";UINotificationFeedbackGenerator().notificationOccurred(.error)}
    }
    #if DEBUG
    func showDemo(count: Int = 3) {
        epoch+=1;demo=true;connected=false;message="演示模式 · 按键不控制 Mac"
        let now=Date().timeIntervalSince1970
        sessions=Array([DeckSession(id:"1",title:"登录流程重构",project:"orbit / iOS",state:"question",updatedAt:now),DeckSession(id:"2",title:"搭建数据看板",project:"console / web",state:"running",updatedAt:now),DeckSession(id:"3",title:"修复同步问题",project:"sync / core",state:"done",updatedAt:now)].prefix(max(1,min(3,count))))
        selection=SessionSelection(selected:sessions.map(\.id),initialized:true)

        snapshot=Snapshot(sessions:sessions,updatedAt:now,error:nil,host:"My Mac",usage:[UsageWindow(minutes:300,remaining:82,resetsAt:now+7200),UsageWindow(minutes:10080,remaining:58,resetsAt:now+172800)],usageUpdatedAt:now,usageError:nil)
    }
    #endif
}
