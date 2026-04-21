import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: WindowNestModel

    static var preferredPopoverWidth: CGFloat {
        switch AppLanguage.current {
        case .english:
            return 392
        case .simplifiedChinese:
            return 408
        case .traditionalChinese:
            return 420
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            accessCard
            layoutModesSection
            dragGuideCard
            quickActionsSection
            footerRow
        }
        .padding(12)
        .frame(width: Self.preferredPopoverWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            model.refreshPermissions()
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.appName)
                    .font(.system(size: 20, weight: .semibold))

                Label(
                    model.accessibilityGranted ? AppStrings.ready : AppStrings.accessRequired,
                    systemImage: model.accessibilityGranted ? "checkmark.shield.fill" : "hand.raised.fill"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(model.accessibilityGranted ? .secondary : .primary)
            }

            Spacer()

            Button(AppStrings.quit) {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var accessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(model.accessibilityGranted ? AppStrings.openSettings : AppStrings.grantAccess) {
                    if model.accessibilityGranted {
                        model.openAccessibilitySettings()
                    } else {
                        model.requestPermissions()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(AppStrings.recheckAccess) {
                    model.refreshPermissions()
                }
                .controlSize(.small)

                Spacer()
            }

            HStack(spacing: 10) {
                Text(AppStrings.launchAtLogin)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.toggleLaunchAtLogin($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var layoutModesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.layoutModesTitle)
                    .font(.subheadline.weight(.semibold))

                Text(AppStrings.layoutModesHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.layoutKinds) { kind in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title)
                                .font(.footnote.weight(.medium))

                            Text(kind.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { model.isLayoutKindEnabled(kind) },
                            set: { model.setLayoutKind(kind, enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var dragGuideCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(AppStrings.guideTitle, systemImage: "rectangle.on.rectangle")
                .font(.headline)

            Text(AppStrings.guideDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                miniTile(title: AppStrings.tileLeftRight)
                miniTile(title: AppStrings.tileFullscreen)
                miniTile(title: AppStrings.tileTopBottom)
                miniTile(title: AppStrings.layoutCenterLargeTitle)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppStrings.quickActionsTitle)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                ForEach(model.layouts) { layout in
                    Button(layout.shortTitle) {
                        model.apply(layout)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!model.accessibilityGranted)
                }
            }
        }
    }

    private var footerRow: some View {
        HStack {
            Text(model.versionLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(model.accessibilityGranted ? model.windowControlLabel : model.accessibilityCheckLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func miniTile(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.06))
            )
    }
}
