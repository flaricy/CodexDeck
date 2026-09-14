# 测试记录

设备：iPhone 12，iOS 26.5.2；Mac：Apple Silicon；SDK：iOS 26.5。

- 桥接回归：8 项通过。覆盖桌面名称优先、附件提示回退处理、状态事件、静默不改色、失败保留记录、额度归属、只读数据库及跳转白名单。
- Swift 会话选择：10 项检查通过，覆盖新增、隐藏、恢复、持久化、上限和旧任务重新运行。
- Debug 真机：3 个用例通过，覆盖 1/2/3 键、横竖屏、隐藏、真实标题与连接、点击反馈、设置入口、重启保留。
- 前台常亮：真机读取 `UIApplication.isIdleTimerDisabled` 为 YES。
- Release 真机：3 个用例全部通过，覆盖真实标题、主机名连接、点击、设置、重启和真实断线恢复。Mac 退出后保持按键和原状态、禁用点击；重新启动后恢复连接和点击。
- Mac 最终程序：HTTPS 连接通过，桥接子进程被终止后自动拉起，无重复进程。

扫码相机流程已实现；本次没有进行手机对准 Mac 二维码的人工扫描验收。触感需本人体验。橙色待回答状态不在已完成能力内。

## 本地回归

```sh
python3 -m unittest discover -s Tests -v
swiftc iOS/CodexDeck/SessionSelection.swift Tests/SelectionTests.swift -o /tmp/deck-selection-tests
/tmp/deck-selection-tests
```

日常 Xcode UI 测试需跳过 `test04DisconnectRecovery`。该用例专用于主机协调的故障注入：看到 `DECK_READY_FOR_OUTAGE` 后退出本 App 的 Mac 配套程序，14 秒后重新打开。它验证断线不改色、不丢按键、禁止点击以及恢复连接后重新启用点击。Release 中应跳过仅支持 Debug 示例数据的 `test01AdaptiveKeysAndHide`。

## Public website

The Chinese and English pages pass browser checks at 1440, 768, 390 and 320 CSS pixels. The checks cover overflow, session count changes, focus selection, hiding, reset, FAQ expansion, fragment links, JavaScript errors and the keyboard skip link. Product art uses fictional sample data and is labeled as an illustration.

```sh
npm ci
npx playwright install chromium
npm run test:site
```
