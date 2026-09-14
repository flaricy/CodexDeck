import SwiftUI

@main struct CodexDeckApp: App {
    @StateObject private var model=DeckModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            DeckView().environmentObject(model).preferredColorScheme(.dark)
                .onAppear {UIApplication.shared.isIdleTimerDisabled=model.keepAwake}
                .onChange(of:phase) { _,p in UIApplication.shared.isIdleTimerDisabled = p == .active && model.keepAwake }
                .task(id:phase) {
                    guard phase == .active else{return}
                    model.becameActive()
                    while !Task.isCancelled {
                        await model.refresh()
                        try? await Task.sleep(for:.seconds(2))
                    }
                }
        }
    }
}
struct DeckView: View {
    @EnvironmentObject var model: DeckModel
    @State private var settings=false
    private let bg=Color(red:0.035,green:0.044,blue:0.055)
    var body: some View {
        GeometryReader { geo in
            let landscape=geo.size.width>geo.size.height
            VStack(spacing:landscape ? 8 : 14) {
                header
                if landscape {
                    HStack(spacing:12) {
                        quota(landscape:true).frame(width:180)
                        keys(landscape:true)
                    }
                } else {
                    if model.snapshot != nil {quota(landscape:false)}
                    keys(landscape:false)
                }
                footer
            }
            .padding(.horizontal,12).padding(.top,8).padding(.bottom,6)
            .background(bg.ignoresSafeArea())
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented:$settings) { PairingView().environmentObject(model) }
    }
    var header: some View {
        HStack(alignment:.center,spacing:10) {
            Image("Icon60").resizable().frame(width:26,height:26).clipShape(RoundedRectangle(cornerRadius:6))
            Text("CODEX").font(.system(size:23,weight:.black,design:.rounded)).tracking(1)
            Text("DECK").font(.system(size:13,weight:.semibold,design:.monospaced)).foregroundStyle(.gray)
            Spacer(minLength:0)
            Text("\(model.visibleSessions.count) 个会话").font(.system(size:11,weight:.medium)).foregroundStyle(.gray)
            Button {settings=true} label: {Image(systemName:"slider.horizontal.3").frame(width:44,height:44)}.accessibilityLabel("配对与设置").accessibilityIdentifier("deck-settings")
        }.foregroundStyle(.white).buttonStyle(.plain)
    }
    func quota(landscape:Bool) -> some View {
        let usage=(model.snapshot?.usage ?? []).filter{[300,10080].contains($0.minutes)}
        let stale=model.snapshot?.usageError != nil || Date().timeIntervalSince1970-(model.snapshot?.usageUpdatedAt ?? 0)>120
        return VStack(alignment:.leading,spacing:10) {
            HStack {Text("CODEX 剩余额度").font(.system(size:10,weight:.bold,design:.monospaced)).tracking(1);Spacer();if model.demo {Text("DEMO").font(.system(size:10,weight:.heavy))} else if stale {Text("未同步").font(.system(size:10))}}
                .foregroundStyle(.gray)
            if usage.isEmpty {
                HStack {Image(systemName:"clock");Text("正在获取额度…").font(.subheadline)}.foregroundStyle(.secondary)
            } else if landscape {
                ForEach(usage) {window in usageMeter(window,label:window.minutes == 300 ? "5 小时":"7 天",stale:stale)}
                Spacer(minLength:0)
            } else {
                HStack(alignment:.top,spacing:18) {
                    ForEach(usage) {window in usageMeter(window,label:window.minutes == 300 ? "5 小时":"7 天",stale:stale)}
                }
            }
        }.padding(16).background(Color.white.opacity(0.045),in:RoundedRectangle(cornerRadius:20))
    }
    func usageMeter(_ window: UsageWindow?,label:String,stale:Bool) -> some View {
        VStack(alignment:.leading,spacing:5) {
            HStack(alignment:.firstTextBaseline,spacing:3) {
                Text(window.map{String(Int($0.remaining.rounded()))} ?? "—").font(.system(size:38,weight:.bold,design:.rounded)).monospacedDigit()
                if window != nil {Text("%").font(.system(size:17,weight:.bold))}
                Spacer(minLength:2)
                Text(label).font(.system(size:11,weight:.medium)).foregroundStyle(.gray)
            }.foregroundStyle(stale ? Color.gray : Color(red:0.30,green:0.83,blue:0.98))
            GeometryReader {g in
                ZStack(alignment:.leading) {
                    Capsule().fill(.white.opacity(0.09))
                    Capsule().fill(stale ? Color.gray : Color.cyan).frame(width:g.size.width*min(1,max(0,(window?.remaining ?? 0)/100)))
                }
            }.frame(height:4)
            if let date=window?.resetsAt {
                Text("重置 "+Date(timeIntervalSince1970:date).formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute())).font(.system(size:10,design:.monospaced)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.7)
            } else {Text("未提供").font(.system(size:10)).foregroundStyle(.gray)}
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    func keys(landscape:Bool) -> some View {
        let visible=model.visibleSessions
        let layout=landscape ? AnyLayout(HStackLayout(spacing:12)) : AnyLayout(VStackLayout(spacing:12))
        return Group {
            if visible.isEmpty {
                VStack(spacing:18) {
                    Image(systemName:"rectangle.connected.to.line.below").font(.system(size:54,weight:.light)).foregroundStyle(.blue)
                    Text(model.pairing == nil && !model.demo ? "你的 Mac，一触即达。" : (!model.hasSynced && !model.demo ? "正在连接你的 Mac":"只留你关心的会话")).font(.title2.bold())
                    Text(model.pairing == nil && !model.demo ? "状态一眼可见，会话一点即开。" : (!model.hasSynced && !model.demo ? "连接后，会话会自动出现在这里。":"在 Mac 开始新会话，或从列表中添加。")).font(.subheadline).foregroundStyle(.gray).multilineTextAlignment(.center)
                    Button(model.pairing == nil && !model.demo ? "连接我的 Mac" : "管理会话") {settings=true}.buttonStyle(.borderedProminent).tint(.blue).controlSize(.large)
                    #if DEBUG
                    if model.pairing == nil && !model.demo {Button("预览键盘") {model.showDemo()}.foregroundStyle(.gray)}
                    #endif
                }.padding(20).frame(maxWidth:.infinity,maxHeight:.infinity).background(.white.opacity(0.025),in:RoundedRectangle(cornerRadius:24))
            } else {
                layout {
                    ForEach(Array(visible.enumerated()),id:\.element.id) {index,s in
                        ZStack(alignment:.topTrailing) {
                            Button {Task {await model.focus(s)}} label: {
                                KeyFace(session:s,number:index+1,count:visible.count,dense:!landscape && visible.count==3,opening:model.opening==s.id)
                            }
                            .buttonStyle(KeyPressStyle()).disabled(!model.canFocus || model.opening != nil)
                            .accessibilityLabel("\(s.title)，\(s.label)，在 Mac 打开").accessibilityIdentifier("session-key-\(s.id)")
                            if s.canHide {
                                Button {withAnimation(.easeInOut(duration:0.2)){model.hide(s)}} label: {
                                    Label("不看",systemImage:"eye.slash").font(.system(size:12,weight:.semibold)).padding(.horizontal,12).frame(height:44)
                                }
                                .buttonStyle(.plain).foregroundStyle(s.color.opacity(0.8))
                                .background(.black.opacity(0.18),in:Capsule()).padding(12)
                                .accessibilityLabel("隐藏闲置会话：\(s.title)").accessibilityIdentifier("hide-session-\(s.id)")
                            }
                        }.frame(maxWidth:.infinity,maxHeight:.infinity)
                    }
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
            }
        }
    }
    var footer: some View {
        HStack(spacing:8) {
            Circle().fill(model.canFocus ? Color.green : Color.orange).frame(width:6,height:6)
            VStack(alignment:.leading,spacing:3) {
                Text(model.message).font(.system(size:10,weight:.medium)).lineLimit(1).accessibilityIdentifier("connection-status")
                if let help=model.connectionHelp {
                    Button("查看连接帮助") {settings=true}.font(.system(size:11,weight:.medium)).accessibilityHint(help)
                }
            }
            Spacer(minLength:0)
            Button {model.toggleKeepAwake()} label: {
                Image(systemName:model.keepAwake ? "sun.max.fill":"sun.max").font(.system(size:20,weight:.medium)).foregroundStyle(model.keepAwake ? Color(red:0.78,green:0.90,blue:0.54):Color.gray).frame(width:44,height:44).background(.white.opacity(model.keepAwake ? 0.07:0.025),in:Circle())
            }.buttonStyle(KeyPressStyle()).accessibilityLabel("手机常亮").accessibilityValue(model.keepAwake ? "开启":"关闭").accessibilityHint("轻点切换，仅影响 iPhone 自动锁屏").accessibilityIdentifier("keep-awake")
        }.foregroundStyle(.white.opacity(0.7)).frame(minHeight:35)
    }
}
struct KeyFace: View {
    let session: DeckSession
    let number: Int
    let count: Int
    let dense: Bool
    let opening: Bool
    var body: some View {
        VStack(alignment:.leading,spacing:dense ? 6 : 14) {
            HStack(alignment:.top) {
                Image(systemName:session.icon).font(.system(size:dense ? 24 : (count == 1 ? 60 : 34),weight:.semibold))
                Text(String(format:"%02d",number)).font(.system(size:13,weight:.bold,design:.monospaced)).opacity(0.45)
                Spacer()
            }
            Spacer(minLength:0)
            Text(session.title).font(.system(size:dense ? 23 : (count == 1 ? 40 : (count == 2 ? 32 : 26)),weight:.bold)).lineLimit(2).minimumScaleFactor(0.8).multilineTextAlignment(.leading)
            HStack(spacing:4) {
                Text(opening ? "正在打开…" : session.label).font(.system(size:dense ? 13 : 15,weight:.heavy))
                Spacer(minLength:0)
                Image(systemName:"arrow.up.right").font(.system(size:10,weight:.bold))
            }
            Text(session.project).font(.system(size:dense ? 10 : 12,weight:.medium,design:.monospaced)).opacity(0.6).lineLimit(1)
        }
        .padding(dense ? 12 : 22).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.leading)
        .foregroundStyle(session.color)
        .background(LinearGradient(colors:[session.color.opacity(0.18),session.color.opacity(0.08)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:20))
        .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(session.color.opacity(0.32),lineWidth:1))
        .overlay(alignment:.top) {Capsule().fill(session.color).frame(width:38,height:3).padding(.top,0)}
        .background(Color(red:0.035,green:0.044,blue:0.055),in:RoundedRectangle(cornerRadius:20))
        .compositingGroup()
        .shadow(color:.black.opacity(0.4),radius:1,x:0,y:4)
    }
}
struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration:Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1).offset(y:configuration.isPressed ? 3 : 0).brightness(configuration.isPressed ? 0.08 : 0).animation(.easeOut(duration:0.1),value:configuration.isPressed)
    }
}
struct PairingView: View {
    @EnvironmentObject var model: DeckModel
    @Environment(\.dismiss) var dismiss
    @State private var link=""
    @State private var error:String?
    @State private var scanning=false
    @State private var confirmUnpair=false
    @State private var search=""
    func connect(_ value:String) {
        do {try model.pair(value);scanning=false;dismiss();Task{await model.refresh()}}
        catch {scanning=false;self.error=error.localizedDescription}
    }
    var body: some View {
        NavigationStack {
            Form {
                if let help=model.connectionHelp {
                    Section("恢复连接") {
                        Text(help)
                        Button("打开 iPhone 设置") {if let url=URL(string:UIApplication.openSettingsURLString){UIApplication.shared.open(url)}}
                        Button("立即重试") {Task{await model.refresh()}}
                    }
                }
                if let p=model.pairing {
                    Section("我的 Mac") {
                        Label(model.snapshot?.host ?? p.host,systemImage:"desktopcomputer")
                        LabeledContent("连接",value:model.canFocus ? "已连接":"正在重连")
                        Button("重新扫码配对") {scanning=true}.accessibilityIdentifier("scan-pairing")
                        DisclosureGroup("使用配对链接") {linkInput}
                    }
                } else {
                    Section {
                        Label("打开 Mac 上的 Codex Deck",systemImage:"1.circle.fill")
                        Label("点击菜单栏的四方格图标",systemImage:"2.circle.fill")
                        Label("扫描配对二维码",systemImage:"3.circle.fill")
                        Button {scanning=true} label:{Label("扫码连接 Mac",systemImage:"qrcode.viewfinder").font(.headline).frame(maxWidth:.infinity).padding(.vertical,8)}.accessibilityIdentifier("scan-pairing")
                    } footer: {Text("手机和 Mac 连接同一 Wi-Fi。配对后会自动重连。")}
                    Section {DisclosureGroup("使用配对链接") {linkInput}}
                }
                if let error {Section {Text(error).foregroundStyle(.orange)}}
                if !model.sessions.isEmpty {
                    Section {
                        ForEach(model.visibleSessions) { s in
                            HStack {
                                VStack(alignment:.leading,spacing:4) {Text(s.title);Text(s.label).font(.caption).foregroundStyle(s.color)}
                                Spacer()
                                if s.canHide {Button("不看") {withAnimation{model.hide(s)}}.buttonStyle(.borderless)}
                            }
                        }
                        DisclosureGroup("添加会话（\(model.otherSessions.count)）") {
                            TextField("搜索会话",text:$search)
                            ForEach(model.otherSessions.filter{search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.project.localizedCaseInsensitiveContains(search)}) {s in
                                Button {model.show(s)} label: {
                                    HStack {VStack(alignment:.leading,spacing:4){Text(s.title).foregroundStyle(.primary);Text(s.project).font(.caption).foregroundStyle(.secondary)};Spacer();Image(systemName:"plus.circle")}
                                }.disabled(model.visibleSessions.count >= 3)
                            }
                        }
                    } header:{Text("键盘 · \(model.visibleSessions.count)/3")} footer:{Text("最多三个。新会话自动加入；点“不看”后会一直隐藏，可从这里重新添加。")}
                }
                Section("使用方式") {
                    Toggle(isOn:Binding(get:{model.keepAwake},set:{_ in model.toggleKeepAwake()})) {Label("iPhone 屏幕常亮",systemImage:"sun.max")}
                    Text("仅在此 App 前台生效，不影响 Mac 睡眠。也可以点键盘右下角的太阳切换。").font(.footnote).foregroundStyle(.secondary)
                    Label("轻点会话，在 Mac 继续工作",systemImage:"arrow.up.right")
                    DisclosureGroup("状态说明") {
                        Label("蓝色 · 运行中",systemImage:"waveform").foregroundStyle(.blue)
                        Label("绿色 · 完成 / STOP",systemImage:"checkmark").foregroundStyle(.green)
                        Text("状态跟随 Codex 保存的记录。断线不会把会话改成停止；Mac 睡眠或退出后，可能保留最后状态。当前仅支持本机任务。")
                        Text("当前 Codex 尚未提供可供此 App 可靠读取的待回答事件，因此本版不保证提示所有提问或审批。")
                    }.font(.subheadline)
                }
                if model.pairing != nil {
                    Section {Button("移除此 Mac",role:.destructive){confirmUnpair=true}}
                }
                #if DEBUG
                Section("开发预览") {
                    Button("查看演示键盘") {model.showDemo();dismiss()}
                    if model.demo && model.pairing != nil {Button("返回我的 Mac") {model.exitDemo();dismiss();Task{await model.refresh()}}}
                }
                #endif
                Section {Text("Codex Deck 1.0.1").font(.footnote).foregroundStyle(.secondary)}
            }.navigationTitle("我的键盘").toolbar {ToolbarItem(placement:.confirmationAction){Button("完成"){dismiss()}}}
            .confirmationDialog("移除后需要重新扫码连接",isPresented:$confirmUnpair,titleVisibility:.visible) {Button("移除此 Mac",role:.destructive){model.unpair()}}
            .sheet(isPresented:$scanning) {
                NavigationStack {
                    ZStack(alignment:.bottom) {
                        PairingScanner(found:connect,failed:{error=$0;scanning=false}).ignoresSafeArea(edges:.bottom)
                        Text("对准 Mac 菜单栏里的配对二维码").font(.headline).padding().background(.ultraThinMaterial,in:Capsule()).padding(.bottom,35)
                    }.navigationTitle("连接 Mac").navigationBarTitleDisplayMode(.inline)
                    .toolbar {ToolbarItem(placement:.cancellationAction){Button("取消"){scanning=false}}}
                }
            }
        }.preferredColorScheme(.dark)
    }
    var linkInput: some View {
        Group {
            SecureField("粘贴配对链接",text:$link).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("pairing-link")
            PasteButton(payloadType:String.self) {values in if let first=values.first {link=first} }
            Button("连接") {connect(link)}.disabled(link.isEmpty).accessibilityIdentifier("pairing-connect")
        }
    }
}
#Preview {DeckView().environmentObject(DeckModel())}
