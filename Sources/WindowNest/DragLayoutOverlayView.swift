import SwiftUI

enum DragLayoutTileKind: CaseIterable, Identifiable {
    case leftRight
    case fullscreen
    case topBottom

    var id: Self { self }

    var title: String {
        switch self {
        case .leftRight: return "左 / 右屏"
        case .fullscreen: return "全屏"
        case .topBottom: return "上 / 下屏"
        }
    }
}

enum DragLayoutDropTarget: Equatable {
    case leftHalf
    case rightHalf
    case maximize
    case topHalf
    case bottomHalf

    var preset: WindowLayoutPreset {
        switch self {
        case .leftHalf: return .leftHalf
        case .rightHalf: return .rightHalf
        case .maximize: return .maximize
        case .topHalf: return .topHalf
        case .bottomHalf: return .bottomHalf
        }
    }

    var tileKind: DragLayoutTileKind {
        switch self {
        case .leftHalf, .rightHalf: return .leftRight
        case .maximize: return .fullscreen
        case .topHalf, .bottomHalf: return .topBottom
        }
    }
}

struct DragLayoutOverlayView: View {
    let hoveredTarget: DragLayoutDropTarget?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear

                ForEach(DragLayoutTileKind.allCases) { kind in
                    tile(for: kind, in: geometry.size)
                }
            }
        }
    }

    private func tile(for kind: DragLayoutTileKind, in size: CGSize) -> some View {
        let frame = DragLayoutOverlayMetrics.tileFrame(for: kind, in: size)
        let tileActive = hoveredTarget?.tileKind == kind

        return RoundedRectangle(cornerRadius: 18)
            .fill(Color(red: 0.10, green: 0.18, blue: 0.27).opacity(tileActive ? 0.94 : 0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        Color(red: 0.57, green: 0.75, blue: 1.0).opacity(tileActive ? 1.0 : 0.72),
                        lineWidth: tileActive ? 4 : 2
                    )
            )
            .overlay {
                tileContent(for: kind)
                    .padding(14)
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .shadow(color: .black.opacity(tileActive ? 0.35 : 0.2), radius: tileActive ? 18 : 12, y: 8)
            .scaleEffect(tileActive ? 1.04 : 1.0)
            .animation(.easeOut(duration: 0.08), value: tileActive)
    }

    @ViewBuilder
    private func tileContent(for kind: DragLayoutTileKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind.title)
                .font(.system(size: 14, weight: .semibold))
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
                hintCapsule("左", active: hoveredTarget == .leftHalf)
                Spacer()
                hintCapsule("右", active: hoveredTarget == .rightHalf)
            }
        case .fullscreen:
            HStack {
                Spacer()
                hintCapsule("铺满", active: hoveredTarget == .maximize)
                Spacer()
            }
        case .topBottom:
            HStack {
                hintCapsule("上", active: hoveredTarget == .topHalf)
                Spacer()
                hintCapsule("下", active: hoveredTarget == .bottomHalf)
            }
        }
    }

    private func hintCapsule(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(active ? .white : .white.opacity(0.76))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
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

    private func splitPreview(
        primaryAxis: Axis,
        highlightFirst: Bool,
        highlightSecond: Bool,
        size: CGSize
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.72, green: 0.85, blue: 1.0).opacity(0.45), lineWidth: 1.5)

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
    }

    private func splitSegment(highlighted: Bool) -> some View {
        Rectangle()
            .fill(previewFill(highlighted))
            .overlay(
                Rectangle()
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
    static func tileFrame(for kind: DragLayoutTileKind, in size: CGSize) -> CGRect {
        let width = min(280, max(180, size.width * 0.2))
        let height = width * 0.64
        let gap = width * 0.16
        let centerX = size.width / 2
        let y = size.height - height / 2 - 54

        switch kind {
        case .leftRight:
            return CGRect(x: centerX - width - gap - width / 2, y: y - height / 2, width: width, height: height)
        case .fullscreen:
            return CGRect(x: centerX - width / 2, y: y - height / 2, width: width, height: height)
        case .topBottom:
            return CGRect(x: centerX + gap + width / 2, y: y - height / 2, width: width, height: height)
        }
    }
}
