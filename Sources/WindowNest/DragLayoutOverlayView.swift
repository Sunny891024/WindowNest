import SwiftUI

enum DragLayoutTileKind: String, CaseIterable, Identifiable {
    case leftRight
    case fullscreen
    case topBottom
    case center

    var id: Self { self }

    var title: String {
        switch self {
        case .leftRight: return AppStrings.tileLeftRight
        case .fullscreen: return AppStrings.tileFullscreen
        case .topBottom: return AppStrings.tileTopBottom
        case .center: return AppStrings.layoutCenterLargeTitle
        }
    }

    var subtitle: String {
        switch self {
        case .leftRight: return AppStrings.tileLeftRightSubtitle
        case .fullscreen: return AppStrings.layoutMaximizeSubtitle
        case .topBottom: return AppStrings.tileTopBottomSubtitle
        case .center: return AppStrings.layoutCenterLargeSubtitle
        }
    }

    var presets: [WindowLayoutPreset] {
        switch self {
        case .leftRight:
            return [.leftHalf, .rightHalf]
        case .fullscreen:
            return [.maximize]
        case .topBottom:
            return [.topHalf, .bottomHalf]
        case .center:
            return [.centerLarge]
        }
    }
}

enum DragLayoutDropTarget: Equatable {
    case leftHalf
    case rightHalf
    case maximize
    case topHalf
    case bottomHalf
    case center

    var preset: WindowLayoutPreset {
        switch self {
        case .leftHalf: return .leftHalf
        case .rightHalf: return .rightHalf
        case .maximize: return .maximize
        case .topHalf: return .topHalf
        case .bottomHalf: return .bottomHalf
        case .center: return .centerLarge
        }
    }

    var tileKind: DragLayoutTileKind {
        switch self {
        case .leftHalf, .rightHalf: return .leftRight
        case .maximize: return .fullscreen
        case .topHalf, .bottomHalf: return .topBottom
        case .center: return .center
        }
    }
}

struct DragLayoutOverlayView: View {
    let hoveredTarget: DragLayoutDropTarget?
    let enabledKinds: Set<DragLayoutTileKind>

    var body: some View {
        GeometryReader { geometry in
            let visibleKinds = DragLayoutTileKind.allCases.filter { enabledKinds.contains($0) }

            ZStack {
                Color.clear

                ForEach(visibleKinds) { kind in
                    tile(for: kind, in: geometry.size, visibleKinds: visibleKinds)
                }
            }
        }
    }

    private func tile(for kind: DragLayoutTileKind, in size: CGSize, visibleKinds: [DragLayoutTileKind]) -> some View {
        let frame = DragLayoutOverlayMetrics.tileFrame(for: kind, visibleKinds: visibleKinds, in: size)
        let tileActive = hoveredTarget?.tileKind == kind

        return RoundedRectangle(cornerRadius: 20)
            .fill(Color(red: 0.10, green: 0.18, blue: 0.27).opacity(tileActive ? 0.94 : 0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        Color(red: 0.57, green: 0.75, blue: 1.0).opacity(tileActive ? 1.0 : 0.72),
                        lineWidth: tileActive ? 4 : 2
                    )
            )
            .overlay {
                tileContent(for: kind)
                    .padding(20)
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .shadow(color: .black.opacity(tileActive ? 0.35 : 0.2), radius: tileActive ? 20 : 14, y: 10)
            .scaleEffect(tileActive ? 1.04 : 1.0)
            .animation(.easeOut(duration: 0.08), value: tileActive)
    }

    @ViewBuilder
    private func tileContent(for kind: DragLayoutTileKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.96))

            GeometryReader { geometry in
                switch kind {
                case .leftRight:
                    splitPreview(
                        primaryAxis: .horizontal,
                        highlightFirst: hoveredTarget == .leftHalf,
                        highlightSecond: hoveredTarget == .rightHalf,
                        size: geometry.size
                    )
                case .fullscreen:
                    fullscreenPreview(highlighted: hoveredTarget == .maximize)
                case .topBottom:
                    splitPreview(
                        primaryAxis: .vertical,
                        highlightFirst: hoveredTarget == .topHalf,
                        highlightSecond: hoveredTarget == .bottomHalf,
                        size: geometry.size
                    )
                case .center:
                    centeredPreview(highlighted: hoveredTarget == .center, size: geometry.size)
                }
            }

            targetHint(for: kind)
        }
    }

    @ViewBuilder
    private func targetHint(for kind: DragLayoutTileKind) -> some View {
        switch kind {
        case .leftRight:
            HStack {
                hintCapsule(AppStrings.leftHint, active: hoveredTarget == .leftHalf)
                Spacer()
                hintCapsule(AppStrings.rightHint, active: hoveredTarget == .rightHalf)
            }
        case .fullscreen:
            HStack {
                Spacer()
                hintCapsule(AppStrings.fillHint, active: hoveredTarget == .maximize)
                Spacer()
            }
        case .topBottom:
            HStack {
                hintCapsule(AppStrings.topHint, active: hoveredTarget == .topHalf)
                Spacer()
                hintCapsule(AppStrings.bottomHint, active: hoveredTarget == .bottomHalf)
            }
        case .center:
            HStack {
                Spacer()
                hintCapsule(AppStrings.layoutCenterLargeTitle, active: hoveredTarget == .center)
                Spacer()
            }
        }
    }

    private func hintCapsule(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(active ? .white : .white.opacity(0.76))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(active ? Color(red: 0.36, green: 0.60, blue: 0.95).opacity(0.9) : Color.white.opacity(0.08))
            )
    }

    private func fullscreenPreview(highlighted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(previewFill(highlighted))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(previewStroke(highlighted), lineWidth: highlighted ? 3 : 1.5)
            )
    }

    private func centeredPreview(highlighted: Bool, size: CGSize) -> some View {
        let innerWidth = size.width * 0.68
        let innerHeight = size.height * 0.62

        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.25, green: 0.37, blue: 0.48).opacity(0.18))

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(previewStroke(highlighted), lineWidth: highlighted ? 2.5 : 1.25)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(previewFill(highlighted))
                .frame(width: innerWidth, height: innerHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(previewStroke(highlighted), lineWidth: highlighted ? 3 : 1.5)
                )
        }
    }

    private func splitPreview(
        primaryAxis: Axis,
        highlightFirst: Bool,
        highlightSecond: Bool,
        size: CGSize
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 0.72, green: 0.85, blue: 1.0).opacity(0.45), lineWidth: 1.5)

            Group {
                if primaryAxis == .horizontal {
                    HStack(spacing: 0) {
                        splitSegment(highlighted: highlightFirst)
                        splitSegment(highlighted: highlightSecond)
                    }
                } else {
                    VStack(spacing: 0) {
                        splitSegment(highlighted: highlightFirst)
                        splitSegment(highlighted: highlightSecond)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func splitSegment(highlighted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(previewFill(highlighted))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(previewStroke(highlighted), lineWidth: highlighted ? 2.5 : 1)
            )
    }

    private func previewFill(_ highlighted: Bool) -> Color {
        highlighted
            ? Color(red: 0.36, green: 0.60, blue: 0.95).opacity(0.52)
            : Color(red: 0.25, green: 0.37, blue: 0.48).opacity(0.34)
    }

    private func previewStroke(_ highlighted: Bool) -> Color {
        highlighted
            ? Color(red: 0.78, green: 0.90, blue: 1.0).opacity(1.0)
            : Color(red: 0.72, green: 0.85, blue: 1.0).opacity(0.55)
    }
}

enum DragLayoutOverlayMetrics {
    static func tileFrame(for kind: DragLayoutTileKind, visibleKinds: [DragLayoutTileKind], in size: CGSize) -> CGRect {
        let visibleKinds = visibleKinds.isEmpty ? DragLayoutTileKind.allCases : visibleKinds
        let visibleCount = max(1, visibleKinds.count)
        let index = max(0, visibleKinds.firstIndex(of: kind) ?? 0)

        let outerPadding = max(24, min(size.width, size.height) * 0.06)
        let gapX = max(14, size.width * 0.02)
        let tileWidth = min(300, max(160, (size.width - outerPadding * 2 - gapX * CGFloat(visibleCount - 1)) / CGFloat(visibleCount)))
        let tileHeight = min(230, max(150, tileWidth * 0.74))
        let totalWidth = tileWidth * CGFloat(visibleCount) + gapX * CGFloat(visibleCount - 1)
        let originX = max(outerPadding, (size.width - totalWidth) / 2)
        let y = min(
            size.height - tileHeight / 2 - 48,
            max(tileHeight / 2 + 40, size.height * 0.74)
        )

        return CGRect(
            x: originX + CGFloat(index) * (tileWidth + gapX),
            y: y - tileHeight / 2,
            width: tileWidth,
            height: tileHeight
        )
    }
}
