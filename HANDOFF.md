# WindowNest Handoff

## 目标与验收标准

- Chrome 标签页拖出为独立窗口并继续拖到布局目标时，只调整新窗口，原窗口保持不变。
- 普通窗口拖拽与同一应用已有多窗口场景不发生目标误切换。
- 菜单栏弹窗保留权限、布局开关、快捷布局、开机启动、设置和退出，并采用窄长条带式结构。
- 正式版本号与 build 号递增，发布 ZIP、DMG、Git tag，并同步 GitHub。

## 当前状态

- 已完成同一应用窗口快照与新窗口身份识别。
- 已在拖动阶段和松手后的延迟应用阶段两次优先解析新窗口，覆盖 Chrome AX 窗口注册延迟。
- 已完成条带式弹窗：繁中约 356pt 宽，四条布局带分别整合说明、开关和快捷动作。
- 正式版为 `0.4.37`，build `23`，已安装到 `/Applications/WindowNest.app` 并启动。
- README 和下载链接已更新，发布包为 `WindowNest-0.4.37-Installer.dmg` 与 `WindowNest-0.4.37-macOS.zip`。
- 发布提交将同步到 GitHub `main`，并以 `v0.4.37` 标记。

## 关键文件与验证方式

- `Sources/WindowNest/WindowDragLayoutService.swift`：拖拽会话、新窗口切换、释放时二次解析。
- `Sources/WindowNest/WindowManager.swift`：应用窗口列表、新窗口候选选择、窗口布局应用。
- `Sources/WindowNest/ContentView.swift`：简化后的菜单栏弹窗。
- `Sources/WindowNest/StatusBarController.swift`：弹窗初始尺寸。
- `Sources/WindowNest/WindowNestModel.swift`、`WindowNest.xcodeproj/project.pbxproj`：版本 `0.4.37` / build `23`。
- 构建：`swift build`
- App 构建：`xcodebuild -project WindowNest.xcodeproj -scheme WindowNest -configuration Debug -derivedDataPath .derivedData build`
- 签名验证：`codesign --verify --deep --strict /Applications/WindowNest.app`
- 版本验证：`plutil -extract CFBundleShortVersionString raw /Applications/WindowNest.app/Contents/Info.plist`
- DMG SHA-256：`989b30720258fd2c2bfcf948a737ec4e46014f468ba9315dc6c65e59e7dae96d`
- ZIP SHA-256：`af87a4b1ee658c1e6b567b8c5b3a2c7010cff2462fe11af8f5e74533f7d91d11`

## 已知问题与风险

- Chrome 标签页栏的原生拖拽无法在当前自动化环境可靠执行；核心目标解析逻辑和构建已验证，完整场景需要人工拖动一次确认。
- SwiftUI 静态预览已验证尺寸与文本布局；原生 Toggle 在离屏 `ImageRenderer` 中不能正确绘制，但 App 编译、签名和启动正常。
- 工作区包含未提交改动，不要覆盖或回退现有修改。

## 下一步行动

1. 人工验证 Chrome：同一窗口至少两个标签页，拖出一个标签页形成新窗口，继续拖到布局目标并松手，确认只调整新窗口。
2. 验证普通 Chrome 窗口拖拽和其他应用窗口拖拽没有回归。
3. 后续发版继续保持版本号、README 下载链接、DMG、ZIP 和 Git tag 一致。
