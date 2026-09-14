# 安装与使用 / Installation

## Mac

1. 从 [Releases](https://github.com/flaricy/CodexDeck/releases) 下载 Apple Silicon Mac 配套程序，解压后放到“应用程序”。
2. 需要 macOS 14+、Python 3.10+，以及已安装、登录的 Codex 桌面版。Python 可从 [python.org](https://www.python.org/downloads/macos/) 安装；启动程序会检查常见安装位置。
3. 打开 **Codex Deck Mac**，在菜单栏找到三键图标。它会在本机网络启动连接服务。
4. 下载版尚未公证。若系统阻止首次打开，可在“系统设置 → 隐私与安全性”核对应用名称后选择“仍要打开”。不要关闭整个系统的安全保护。

The companion requires macOS 14+, Python 3.10+ and a signed-in Codex desktop app. The download is for Apple Silicon and is not notarized. Move it into Applications and follow macOS's per-app “Open Anyway” flow if needed.

## iPhone

1. 下载源码，用 Xcode 打开 `iOS/CodexDeck.xcodeproj`。
2. 在 Signing & Capabilities 选择自己的 Team，必要时修改 Bundle Identifier。
3. 连接并信任 iPhone，按 Xcode 提示启用 Developer Mode；选择设备运行。
4. 日常使用建议在 scheme 的 Run 设置选择 **Release**，不显示开发预览入口。
5. 打开手机 App 的设置，选择“扫码连接 Mac”，扫描 Mac 菜单栏中的配对二维码。也可复制、粘贴配对链接。
6. 允许本地网络访问；扫码需要相机权限。手机与 Mac 必须处于相互可访问的局域网。

Build the iOS project in Xcode, select your own development team and run on your device. Use Release for everyday use. Pair using the QR code in the Mac menu bar and allow local network access. Camera access is only needed for scanning.

**Apple 签名说明：** 免费 Personal Team 的安装会定期失效，届时需重新签名；具体有效期以 Xcode 生成的描述文件为准。本项目当前没有 App Store、TestFlight 或通用签名 IPA。

## 日常使用

- 打开 iPhone App 并放在手边，默认保持手机前台常亮。点右下角太阳可以开关，选择会保存；仅影响 iPhone，不影响 Mac 睡眠。
- 点会话键在 Mac 打开对应任务；标题跟随桌面名称。
- 完成或停止的任务可点“不看”，从设置的“添加会话”恢复。
- Mac 菜单栏中可暂停连接，或启用登录时启动。
- Mac 与手机之间不传输完整对话；额度读取仍复用 Mac 已有的 Codex 登录。

## 连接问题

- 手机网络不可用：检查 Wi-Fi、设置 → App → Codex Deck → 本地网络及无线数据权限。
- 无法扫描：允许相机访问，或使用配对链接。
- Mac 睡眠：唤醒后等待自动重连。
- 网络不支持 `.local` 名称：退出 Mac 配套程序，以 IP 启动桥接并重新配对。

```sh
python3 Bridge/bridge.py --host 192.168.1.20 --advertise 192.168.1.20
```

将示例 IP 换成 Mac 的局域网地址。程序只绑定指定接口；不要与菜单栏程序同时占用端口。

证书和令牌位于 `~/Library/Application Support/CodexDeck/`，iPhone 凭据保存在设备 Keychain。二维码包含配对权限，不要公开分享。删除 Mac 凭据会使旧配对失效。

## Build from source

```sh
python3 macOS/build.py
```

This creates `Codex Deck Mac.app`. The build script uses Apple's `swiftc` and an ad-hoc local signature. No paid developer account is needed for the Mac source build.
