import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: WindowNestModel
    @State private var showMoreOptions = false

    static var preferredPopoverWidth: CGFloat {
        switch AppLanguage.current {
        case .english:
            return 410
        case .simplifiedChinese:
            return 426
        case .traditionalChinese:
            return 438
        }
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if showMoreOptions {
                expandedContent
            } else {
                compactContent
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            model.refreshPermissions()
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            accessCard
            layoutModesSection
            quickActionsSection
            moreOptionsSection
            footerRow
        }
        .padding(14)
        .frame(width: Self.preferredPopoverWidth, alignment: .leading)
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            accessCard
            layoutModesSection
            quickActionsSection
            footerRow
        }
        .padding(14)
        .frame(width: Self.preferredPopoverWidth, alignment: .leading)
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.13),
                    Color(red: 0.10, green: 0.12, blue: 0.15),
                    Color(red: 0.06, green: 0.07, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.26, green: 0.53, blue: 0.95).opacity(0.18))
                .frame(width: 210, height: 210)
                .blur(radius: 24)
                .offset(x: 116, y: -152)

            Circle()
                .fill(Color(red: 0.32, green: 0.74, blue: 0.48).opacity(0.12))
                .frame(width: 170, height: 170)
                .blur(radius: 22)
                .offset(x: -120, y: 186)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.appName)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.98))

                HStack(spacing: 8) {
                    statusCapsule
                    controlCapsule
                }
            }

            Spacer()

            Button(AppStrings.quit) {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.42, green: 0.77, blue: 0.28),
                                Color(red: 0.27, green: 0.58, blue: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 10, y: 4)
        }
    }

    private var accessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.84))
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
        }
        .softCard(accent: true)
    }

    private var layoutModesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.layoutModesTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Text(AppStrings.layoutModesHint)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.layoutKinds) { kind in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.white.opacity(0.92))

                            Text(kind.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.58))
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
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var dragGuideCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(AppStrings.guideTitle, systemImage: "rectangle.on.rectangle")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.96))

            Text(AppStrings.guideDescription)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.64))

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
        .softCard()
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppStrings.quickActionsTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))

            VStack(spacing: 10) {
                ForEach(quickActionRows.indices, id: \.self) { index in
                    quickActionRow(quickActionRows[index])
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var quickActionRows: [[WindowLayoutPreset]] {
        stride(from: 0, to: model.layouts.count, by: 2).map { startIndex in
            Array(model.layouts[startIndex..<min(startIndex + 2, model.layouts.count)])
        }
    }

    private var moreOptionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    showMoreOptions.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppStrings.moreOptionsTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.96))

                        Text(AppStrings.moreOptionsHint)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: showMoreOptions ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.top, 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showMoreOptions {
                VStack(alignment: .leading, spacing: 12) {
                    launchAtLoginRow
                    dragGuideCard
                }
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .softCard()
    }

    private var launchAtLoginRow: some View {
        HStack(spacing: 10) {
            Text(AppStrings.launchAtLogin)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.76))
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

    private var footerRow: some View {
        HStack {
            Text(model.versionLabel)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.46))

            Spacer()

            Text(model.accessibilityGranted ? model.windowControlLabel : model.accessibilityCheckLabel)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var statusCapsule: some View {
        Label(
            model.accessibilityGranted ? AppStrings.ready : AppStrings.accessRequired,
            systemImage: model.accessibilityGranted ? "checkmark.shield.fill" : "hand.raised.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(model.accessibilityGranted ? Color.white : Color.white.opacity(0.82))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(
                    model.accessibilityGranted
                        ? Color(red: 0.31, green: 0.62, blue: 0.23).opacity(0.92)
                        : Color.white.opacity(0.08)
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(model.accessibilityGranted ? 0.12 : 0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func quickActionRow(_ layouts: [WindowLayoutPreset]) -> some View {
        switch layouts.count {
        case 0:
            EmptyView()
        case 1:
            HStack {
                Spacer(minLength: 0)
                layoutActionTile(layouts[0])
                    .frame(maxWidth: 170)
                Spacer(minLength: 0)
            }
        default:
            HStack(spacing: 10) {
                layoutActionTile(layouts[0])
                layoutActionTile(layouts[1])
            }
        }
    }

    private var controlCapsule: some View {
        Text(model.accessibilityGranted ? model.windowControlLabel : model.accessibilityCheckLabel)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.66))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func miniTile(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.86))
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    private func layoutActionTile(_ layout: WindowLayoutPreset) -> some View {
        Button {
            model.apply(layout)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.34, green: 0.59, blue: 0.95),
                                    Color(red: 0.18, green: 0.31, blue: 0.52)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)

                    layoutIcon(for: layout)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(layout.shortTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))

                    Text(layout.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!model.accessibilityGranted)
        .opacity(model.accessibilityGranted ? 1.0 : 0.62)
    }

    @ViewBuilder
    private func layoutIcon(for layout: WindowLayoutPreset) -> some View {
        switch layout {
        case .centerLarge:
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.white.opacity(0.92), lineWidth: 1.6)
                    .frame(width: 17, height: 17)

                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .frame(width: 7, height: 7)
            }
        default:
            Image(systemName: layout.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

private struct SoftCardStyle: ViewModifier {
    let accent: Bool

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(accent ? 0.10 : 0.07),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(accent ? 0.18 : 0.10),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(accent ? 0.24 : 0.18), radius: accent ? 18 : 14, y: 6)
    }
}

private extension View {
    func softCard(accent: Bool = false) -> some View {
        modifier(SoftCardStyle(accent: accent))
    }
}
