import CoreGraphics
import Foundation

enum WindowLayoutPreset: String, CaseIterable, Identifiable {
    case maximize
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case centerLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maximize: return AppStrings.layoutMaximizeTitle
        case .leftHalf: return AppStrings.layoutLeftHalfTitle
        case .rightHalf: return AppStrings.layoutRightHalfTitle
        case .topHalf: return AppStrings.layoutTopHalfTitle
        case .bottomHalf: return AppStrings.layoutBottomHalfTitle
        case .topLeft: return AppStrings.layoutTopLeftTitle
        case .topRight: return AppStrings.layoutTopRightTitle
        case .bottomLeft: return AppStrings.layoutBottomLeftTitle
        case .bottomRight: return AppStrings.layoutBottomRightTitle
        case .centerLarge: return AppStrings.layoutCenterLargeTitle
        }
    }

    var subtitle: String {
        switch self {
        case .maximize: return AppStrings.layoutMaximizeSubtitle
        case .leftHalf: return AppStrings.layoutLeftHalfSubtitle
        case .rightHalf: return AppStrings.layoutRightHalfSubtitle
        case .topHalf: return AppStrings.layoutTopHalfSubtitle
        case .bottomHalf: return AppStrings.layoutBottomHalfSubtitle
        case .topLeft: return AppStrings.quadrantSubtitle
        case .topRight: return AppStrings.quadrantSubtitle
        case .bottomLeft: return AppStrings.quadrantSubtitle
        case .bottomRight: return AppStrings.quadrantSubtitle
        case .centerLarge: return AppStrings.layoutCenterLargeSubtitle
        }
    }

    var shortTitle: String {
        switch self {
        case .maximize: return AppStrings.fillHint
        case .leftHalf: return AppStrings.leftHint
        case .rightHalf: return AppStrings.rightHint
        case .topHalf: return AppStrings.topHint
        case .bottomHalf: return AppStrings.bottomHint
        case .topLeft: return AppStrings.layoutTopLeftTitle
        case .topRight: return AppStrings.layoutTopRightTitle
        case .bottomLeft: return AppStrings.layoutBottomLeftTitle
        case .bottomRight: return AppStrings.layoutBottomRightTitle
        case .centerLarge: return AppStrings.layoutCenterLargeTitle
        }
    }

    func frame(in visibleFrame: CGRect) -> CGRect {
        let halfWidth = visibleFrame.width / 2
        let halfHeight = visibleFrame.height / 2

        switch self {
        case .maximize:
            return visibleFrame
        case .leftHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: halfWidth, height: visibleFrame.height)
        case .rightHalf:
            return CGRect(x: visibleFrame.minX + halfWidth, y: visibleFrame.minY, width: halfWidth, height: visibleFrame.height)
        case .topHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY + halfHeight, width: visibleFrame.width, height: halfHeight)
        case .bottomHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: visibleFrame.width, height: halfHeight)
        case .topLeft:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY + halfHeight, width: halfWidth, height: halfHeight)
        case .topRight:
            return CGRect(x: visibleFrame.minX + halfWidth, y: visibleFrame.minY + halfHeight, width: halfWidth, height: halfHeight)
        case .bottomLeft:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: halfWidth, height: halfHeight)
        case .bottomRight:
            return CGRect(x: visibleFrame.minX + halfWidth, y: visibleFrame.minY, width: halfWidth, height: halfHeight)
        case .centerLarge:
            let width = visibleFrame.width * 0.72
            let height = visibleFrame.height * 0.66
            return CGRect(
                x: visibleFrame.midX - (width / 2),
                y: visibleFrame.midY - (height / 2),
                width: width,
                height: height
            )
        }
    }
}
