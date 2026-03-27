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
        case .maximize: return "全屏"
        case .leftHalf: return "左半屏"
        case .rightHalf: return "右半屏"
        case .topHalf: return "上半屏"
        case .bottomHalf: return "下半屏"
        case .topLeft: return "左上"
        case .topRight: return "右上"
        case .bottomLeft: return "左下"
        case .bottomRight: return "右下"
        case .centerLarge: return "居中"
        }
    }

    var subtitle: String {
        switch self {
        case .maximize: return "铺满当前屏幕可用区域"
        case .leftHalf: return "贴靠到左侧"
        case .rightHalf: return "贴靠到右侧"
        case .topHalf: return "贴靠到上半部分"
        case .bottomHalf: return "贴靠到下半部分"
        case .topLeft: return "四分之一布局"
        case .topRight: return "四分之一布局"
        case .bottomLeft: return "四分之一布局"
        case .bottomRight: return "四分之一布局"
        case .centerLarge: return "居中显示"
        }
    }

    var shortTitle: String {
        switch self {
        case .maximize: return "全屏"
        case .leftHalf: return "左屏"
        case .rightHalf: return "右屏"
        case .topHalf: return "上屏"
        case .bottomHalf: return "下屏"
        case .topLeft: return "左上"
        case .topRight: return "右上"
        case .bottomLeft: return "左下"
        case .bottomRight: return "右下"
        case .centerLarge: return "居中"
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
            let width = visibleFrame.width * 0.7
            let height = visibleFrame.height * 0.78
            return CGRect(
                x: visibleFrame.midX - (width / 2),
                y: visibleFrame.midY - (height / 2),
                width: width,
                height: height
            )
        }
    }
}
