import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: WindowNestModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("窗口巢")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Text(model.versionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("退出") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            statusRow

            dragGuideCard

            manualSection

            controlsRow

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 360)
        .onAppear {
            model.refreshPermissions()
        }
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            Label(
                model.accessibilityGranted ? "已就绪" : "需要权限",
                systemImage: model.accessibilityGranted ? "checkmark.shield.fill" : "hand.raised.fill"
            )
            .font(.subheadline.weight(.medium))

            Spacer()

            HStack(spacing: 8) {
                Text("开机启动")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.toggleLaunchAtLogin($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var controlsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Text(model.accessibilityCheckLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(model.windowControlLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("调试状态：\(model.debugStatus)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(model.accessibilityGranted ? "打开设置" : "请求授权") {
                    if model.accessibilityGranted {
                        model.openAccessibilitySettings()
                    } else {
                        model.requestPermissions()
                    }
                }
                .controlSize(.small)

                Button("刷新") {
                    model.refreshPermissions()
                }
                .controlSize(.small)

                Button("测试浮层") {
                    model.showTestOverlay()
                }
                .controlSize(.small)

                Spacer()
            }
        }
    }

    private var dragGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("拖动窗口即可呼出布局板", systemImage: "rectangle.on.rectangle")
                .font(.headline)

            Text("拖住任意窗口后，屏幕中间会显示三个目标区：左 / 右屏、全屏、上 / 下屏。把窗口移到目标区后松手即可贴靠。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                miniTile(title: "左 / 右屏")
                miniTile(title: "全屏")
                miniTile(title: "上 / 下屏")
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("手动布局")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                ForEach(model.layouts) { layout in
                    Button(layout.shortTitle) {
                        model.apply(layout)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!model.accessibilityGranted && !model.windowControlReady)
                }
            }
        }
    }

    private func miniTile(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.06))
            )
    }
}
