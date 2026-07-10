import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: WindowNestModel

    static var preferredPopoverWidth: CGFloat {
        switch AppLanguage.current {
        case .english:
            return 338
        case .simplifiedChinese:
            return 348
        case .traditionalChinese:
            return 356
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            statusRow

            VStack(spacing: 8) {
                ForEach(model.layoutKinds) { kind in
                    layoutStrip(kind)
                }
            }

            launchAtLoginRow
            footerRow
        }
        .padding(12)
        .frame(width: Self.preferredPopoverWidth, alignment: .leading)
        .background(backgroundLayer)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            model.refreshPermissions()
        }
    }

    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.10),
                        Color(red: 0.035, green: 0.04, blue: 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
            )
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text(AppStrings.appName)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.98))

            HStack(spacing: 5) {
                Circle()
                    .fill(model.accessibilityGranted ? readyGreen : Color.orange)
                    .frame(width: 6, height: 6)

                Text(model.accessibilityGranted ? AppStrings.ready : AppStrings.accessRequired)
                    .lineLimit(1)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))

            Spacer(minLength: 4)

            headerActionButton(
                systemName: "gearshape",
                help: AppStrings.openSettings,
                action: model.openAccessibilitySettings
            )

            headerActionButton(
                systemName: "power",
                help: AppStrings.quit,
                action: { NSApp.terminate(nil) }
            )
        }
    }

    private var statusRow: some View {
        HStack(spacing: 9) {
            Image(systemName: model.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(model.accessibilityGranted ? readyGreen : Color.orange)

            Text(model.statusMessage)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !model.accessibilityGranted {
                Button(AppStrings.grantAccess) {
                    model.requestPermissions()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(readyGreen)
            }

            Button {
                model.refreshPermissions()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.68))
            .background(Circle().fill(Color.white.opacity(0.07)))
            .help(AppStrings.recheckAccess)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.065), lineWidth: 1)
        )
    }

    private func layoutStrip(_ kind: DragLayoutTileKind) -> some View {
        ZStack(alignment: .trailing) {
            stripBackground(for: kind)

            Image(systemName: symbolName(for: kind))
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.045))
                .offset(x: 10, y: 8)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: symbolName(for: kind))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor(for: kind))
                        .frame(width: 27, height: 27)
                        .background(Circle().fill(Color.black.opacity(0.20)))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(kind.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.94))
                            .lineLimit(1)

                        Text(kind.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.52))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Toggle("", isOn: Binding(
                        get: { model.isLayoutKindEnabled(kind) },
                        set: { model.setLayoutKind(kind, enabled: $0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .tint(readyGreen)
                }

                HStack(spacing: 7) {
                    ForEach(kind.presets) { layout in
                        stripActionButton(layout)
                    }
                }
            }
            .padding(11)
        }
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 1)
        )
        .opacity(model.isLayoutKindEnabled(kind) ? 1.0 : 0.58)
    }

    private func stripActionButton(_ layout: WindowLayoutPreset) -> some View {
        Button {
            model.apply(layout)
        } label: {
            HStack(spacing: 6) {
                layoutIcon(for: layout)

                Text(layout.shortTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.90))
            .frame(maxWidth: .infinity, minHeight: 31)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.black.opacity(0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!model.accessibilityGranted || !isLayoutEnabled(layout))
    }

    private var launchAtLoginRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "power.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))

            Text(AppStrings.launchAtLogin)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.70))

            Spacer()

            Toggle("", isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { model.toggleLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .tint(readyGreen)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 36)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }

    private var footerRow: some View {
        Text(model.versionLabel)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.34))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readyGreen: Color {
        Color(red: 0.35, green: 0.76, blue: 0.31)
    }

    private func headerActionButton(
        systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 27, height: 27)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.72))
        .background(Circle().fill(Color.white.opacity(0.06)))
        .help(help)
    }

    private func stripBackground(for kind: DragLayoutTileKind) -> some View {
        let colors: [Color]

        switch kind {
        case .leftRight:
            colors = [Color(red: 0.10, green: 0.19, blue: 0.30), Color(red: 0.075, green: 0.10, blue: 0.14)]
        case .fullscreen:
            colors = [Color(red: 0.12, green: 0.14, blue: 0.17), Color(red: 0.07, green: 0.08, blue: 0.10)]
        case .topBottom:
            colors = [Color(red: 0.08, green: 0.22, blue: 0.20), Color(red: 0.06, green: 0.11, blue: 0.12)]
        case .center:
            colors = [Color(red: 0.16, green: 0.20, blue: 0.13), Color(red: 0.08, green: 0.10, blue: 0.08)]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func accentColor(for kind: DragLayoutTileKind) -> Color {
        switch kind {
        case .leftRight: return Color(red: 0.40, green: 0.66, blue: 0.98)
        case .fullscreen: return Color.white.opacity(0.78)
        case .topBottom: return Color(red: 0.34, green: 0.78, blue: 0.65)
        case .center: return Color(red: 0.67, green: 0.82, blue: 0.38)
        }
    }

    private func symbolName(for kind: DragLayoutTileKind) -> String {
        switch kind {
        case .leftRight: return "rectangle.split.2x1"
        case .fullscreen: return "arrow.up.left.and.arrow.down.right"
        case .topBottom: return "rectangle.split.1x2"
        case .center: return "square.centered"
        }
    }

    private func isLayoutEnabled(_ layout: WindowLayoutPreset) -> Bool {
        DragLayoutTileKind.allCases.first(where: { $0.presets.contains(layout) })
            .map(model.isLayoutKindEnabled) ?? false
    }

    @ViewBuilder
    private func layoutIcon(for layout: WindowLayoutPreset) -> some View {
        switch layout {
        case .centerLarge:
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(0.92), lineWidth: 1.2)
                    .frame(width: 13, height: 13)

                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .frame(width: 5, height: 5)
            }
        default:
            Image(systemName: layout.symbolName)
                .font(.system(size: 10, weight: .semibold))
        }
    }
}
