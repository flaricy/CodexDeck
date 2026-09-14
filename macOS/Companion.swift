import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins
import ServiceManagement

@MainActor final class Companion: ObservableObject {
    @Published var status="正在准备连接…"
    @Published var link=""
    @Published var running=false
    @Published var loginEnabled=SMAppService.mainApp.status == .enabled
    private var child: Process?
    private var timer: Timer?
    private var address=""
    private var wantsRunning=true
    private var sleeping=false
    let runtime=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CodexDeck")
    init() {
        start()
        timer=Timer.scheduledTimer(withTimeInterval:5,repeats:true) { [weak self] _ in Task { @MainActor in self?.check() } }
        NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.sleep() } }
        NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didWakeNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.wake() } }
    }
    func command(_ path:String,_ arguments:[String]) -> String {
        let p=Process();p.executableURL=URL(fileURLWithPath:path);p.arguments=arguments
        let pipe=Pipe();p.standardOutput=pipe;p.standardError=FileHandle.nullDevice
        do {try p.run();let data=pipe.fileHandleForReading.readDataToEndOfFile();p.waitUntilExit();return String(data:data,encoding:.utf8)?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""}catch{return ""}
    }
    func localIP() -> String {
        // Bind only one LAN interface; never expose a wildcard listener.
        for interface in ["en0","en1"] {
            let value=command("/usr/sbin/ipconfig",["getifaddr",interface])
            if !value.isEmpty {return value}
        }
        return ""
    }
    func start() {
        wantsRunning=true
        guard child?.isRunning != true else{return}
        running=false;link=""
        address=localIP()
        guard !address.isEmpty else {status="请先连接 Wi-Fi 或以太网";running=false;return}
        let configured=(Bundle.main.object(forInfoDictionaryKey:"DeckPython") as? String) ?? ""
        let candidates=[configured,"/opt/homebrew/bin/python3","/usr/local/bin/python3","/Library/Frameworks/Python.framework/Versions/Current/bin/python3","/usr/bin/python3"]
        guard let python=candidates.first(where:{!$0.isEmpty && FileManager.default.isExecutableFile(atPath:$0)}),let script=Bundle.main.url(forResource:"bridge",withExtension:"py") else {status="需要 Python 3，请安装后重新打开";return}
        do {
            try FileManager.default.createDirectory(at:runtime,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            let log=runtime.appendingPathComponent("companion.log")
            FileManager.default.createFile(atPath:log.path,contents:Data(),attributes:[.posixPermissions:0o600])
            let output=try FileHandle(forWritingTo:log)
            let hostname=command("/usr/sbin/scutil",["--get","LocalHostName"])
            let p=Process();p.executableURL=URL(fileURLWithPath:python)
            p.arguments=[script.path,"--host",address,"--advertise",hostname.isEmpty ? address : hostname+".local","--runtime",runtime.path,"--parent-pid",String(ProcessInfo.processInfo.processIdentifier)]
            p.standardOutput=output;p.standardError=output
            p.terminationHandler={ [weak self] process in Task { @MainActor in
                guard self?.child === process else{return}
                self?.running=false;self?.status="连接服务已停止 · 点击重新启动"
            }}
            try p.run();child=p;status="正在连接 Codex…"
        }catch{status="无法启动连接服务："+error.localizedDescription}
    }
    func check() {
        guard wantsRunning && !sleeping else{return}
        let current=localIP()
        if current != address {stop();start()}
        guard child?.isRunning == true else {start();return}
        guard let data=try? Data(contentsOf:runtime.appendingPathComponent("ready.json")),
              let ready=try? JSONDecoder().decode(Readiness.self,from:data),
              ready.pid == child?.processIdentifier, !ready.pairing.isEmpty else {
            running=false;link="";return
        }
        link=ready.pairing;running=true;status="已就绪 · iPhone 可连接"
    }
    private struct Readiness: Decodable {let pid:Int32;let pairing:String}
    private func sleep() {
        let resume=wantsRunning
        sleeping=true
        stop()
        wantsRunning=resume
    }
    private func wake() {
        sleeping=false
        if wantsRunning {start()}
    }
    func stop() {wantsRunning=false;child?.terminationHandler=nil;child?.terminate();child?.waitUntilExit();child=nil;running=false;status="已暂停连接"}
    func toggleLogin() {
        do {if loginEnabled {try SMAppService.mainApp.unregister()}else{try SMAppService.mainApp.register()};loginEnabled=SMAppService.mainApp.status == .enabled}
        catch {status="请在系统设置中允许登录项"}
    }
    func copy() {NSPasteboard.general.clearContents();NSPasteboard.general.setString(link,forType:.string)}
    var qr: NSImage? {
        guard !link.isEmpty else{return nil}
        let filter=CIFilter.qrCodeGenerator();filter.message=Data(link.utf8);filter.correctionLevel="M"
        guard let output=filter.outputImage,let cg=CIContext().createCGImage(output.transformed(by:CGAffineTransform(scaleX:8,y:8)),from:output.extent.applying(CGAffineTransform(scaleX:8,y:8))) else{return nil}
        return NSImage(cgImage:cg,size:NSSize(width:220,height:220))
    }
}
@main struct DeckCompanionApp: App {
    @StateObject private var companion=Companion()
    var body: some Scene {
        MenuBarExtra("Codex Deck",systemImage:"square.grid.2x2.fill") {
            VStack(alignment:.leading,spacing:16) {
                HStack {Image(nsImage:NSImage(contentsOf:Bundle.main.url(forResource:"Deck",withExtension:"icns")!) ?? NSImage()).resizable().frame(width:28,height:28);Text("Codex Deck").font(.title2.bold());Spacer()}
                Label(companion.status,systemImage:companion.running ? "checkmark.circle.fill":"wifi.slash").foregroundStyle(companion.running ? .green:.secondary).font(.callout)
                if let qr=companion.qr,companion.running {
                    Image(nsImage:qr).interpolation(.none).resizable().frame(width:220,height:220).padding(16).background(.white,in:RoundedRectangle(cornerRadius:16)).frame(maxWidth:.infinity)
                    Text("打开 iPhone 上的 Codex Deck，\n轻点「扫码连接 Mac」。").font(.callout).frame(maxWidth:.infinity).multilineTextAlignment(.center)
                    Button("复制配对链接") {companion.copy()}.frame(maxWidth:.infinity)
                }
                Divider()
                Toggle("登录 Mac 时启动",isOn:Binding(get:{companion.loginEnabled},set:{_ in companion.toggleLogin()}))
                HStack {
                    Button(companion.running ? "暂停连接":"重新启动") {if companion.running {companion.stop()}else{companion.start()}}
                    Spacer()
                    Button("退出") {companion.stop();NSApplication.shared.terminate(nil)}
                }
                Text("手机与 Mac 连接同一网络。配对二维码仅供你自己的手机使用。").font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(width:310)
        }.menuBarExtraStyle(.window)
    }
}
