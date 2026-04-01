import Foundation

enum AppLanguage {
    case english
    case simplifiedChinese
    case traditionalChinese

    static var current: AppLanguage {
        for identifier in Locale.preferredLanguages {
            let normalized = identifier.lowercased()
            guard normalized.hasPrefix("zh") else {
                continue
            }

            if normalized.contains("hant") || normalized.contains("tw") || normalized.contains("hk") || normalized.contains("mo") {
                return .traditionalChinese
            }

            return .simplifiedChinese
        }

        return .english
    }
}

enum AppStrings {
    static let appName = "WindowNest"

    static var quit: String { value(en: "Quit", zhHans: "退出", zhHant: "退出") }
    static var versionPrefix: String { value(en: "Version", zhHans: "版本", zhHant: "版本") }
    static func versionLabel(_ version: String) -> String { "\(versionPrefix) \(version)" }

    static var ready: String { value(en: "Ready", zhHans: "已就绪", zhHant: "已就緒") }
    static var accessRequired: String { value(en: "Accessibility Access Required", zhHans: "需要辅助功能权限", zhHant: "需要輔助使用權限") }
    static var launchAtLogin: String { value(en: "Launch at Login", zhHans: "开机启动", zhHant: "開機啟動") }
    static var grantAccess: String { value(en: "Grant Access", zhHans: "请求授权", zhHant: "要求授權") }
    static var openSettings: String { value(en: "Open Settings", zhHans: "打开设置", zhHant: "打開設定") }
    static var recheckAccess: String { value(en: "Check Again", zhHans: "重新检查", zhHant: "重新檢查") }

    static var guideTitle: String { value(en: "Drag a window to show layout targets", zhHans: "拖动窗口即可呼出布局板", zhHant: "拖動視窗即可呼出版面板") }
    static var guideDescription: String {
        value(
            en: "When you drag a window, WindowNest shows three targets in the middle of the current screen: left or right, maximize, and top or bottom.",
            zhHans: "拖住窗口后，WindowNest 会在当前屏幕中间显示三个目标区：左 / 右屏、全屏、上 / 下屏。",
            zhHant: "拖住視窗後，WindowNest 會在目前螢幕中央顯示三個目標區：左 / 右屏、全螢幕、上 / 下屏。"
        )
    }
    static var quickActionsTitle: String { value(en: "Quick Actions", zhHans: "快速布局", zhHant: "快速版面") }

    static var tileLeftRight: String { value(en: "Left / Right", zhHans: "左 / 右屏", zhHant: "左 / 右屏") }
    static var tileFullscreen: String { value(en: "Maximize", zhHans: "全屏", zhHant: "全螢幕") }
    static var tileTopBottom: String { value(en: "Top / Bottom", zhHans: "上 / 下屏", zhHant: "上 / 下屏") }
    static var leftHint: String { value(en: "Left", zhHans: "左", zhHant: "左") }
    static var rightHint: String { value(en: "Right", zhHans: "右", zhHant: "右") }
    static var fillHint: String { value(en: "Fill", zhHans: "铺满", zhHant: "鋪滿") }
    static var topHint: String { value(en: "Top", zhHans: "上", zhHant: "上") }
    static var bottomHint: String { value(en: "Bottom", zhHans: "下", zhHant: "下") }

    static var initialStatus: String {
        value(
            en: "Drag a window to show layout targets, then release to snap it into place.",
            zhHans: "拖动窗口时会显示浮动布局板，松手后即可自动贴靠。",
            zhHant: "拖動視窗時會顯示浮動版面板，放開後即可自動貼靠。"
        )
    }
    static var dragReadyStatus: String {
        value(
            en: "Drag a window to show the three targets: left or right, maximize, and top or bottom.",
            zhHans: "拖动窗口时会显示“左/右屏、全屏、上/下屏”三个浮动区域。",
            zhHant: "拖動視窗時會顯示「左 / 右屏、全螢幕、上 / 下屏」三個浮動區域。"
        )
    }
    static var waitingForTargetStatus: String {
        value(
            en: "Accessibility is enabled. Click the window you want to move, then drag again.",
            zhHans: "辅助功能已授权。当前只是还没锁定目标窗口，先点一下要操作的窗口再试。",
            zhHant: "輔助使用已授權，但目前還沒鎖定目標視窗，先點一下要操作的視窗再試。"
        )
    }
    static var missingAccessStatus: String {
        value(
            en: "Accessibility access is not enabled yet. The overlay may appear, but snapping will not be applied.",
            zhHans: "当前辅助功能未开启。浮层可能出现，但贴靠不会真正生效。",
            zhHant: "目前輔助使用未開啟。浮層可能出現，但貼靠不會真正生效。"
        )
    }
    static func layoutApplied(_ title: String) -> String {
        value(
            en: "Applied \(title).",
            zhHans: "已应用\(title)。",
            zhHant: "已套用\(title)。"
        )
    }
    static func movedWindow(to title: String) -> String {
        value(
            en: "Moved the window to \(title).",
            zhHans: "已将窗口移动到\(title)。",
            zhHant: "已將視窗移動到\(title)。"
        )
    }
    static var cannotControlWindows: String {
        value(
            en: "WindowNest still cannot control system windows. Make sure Accessibility is enabled for WindowNest.",
            zhHans: "当前还不能真正控制系统窗口。请确认“辅助功能”已对 WindowNest 生效。",
            zhHant: "目前還不能真正控制系統視窗。請確認「輔助使用」已對 WindowNest 生效。"
        )
    }
    static var launchAtLoginEnabledStatus: String { value(en: "Launch at login is enabled.", zhHans: "已开启开机启动。", zhHant: "已開啟開機啟動。") }
    static var launchAtLoginDisabledStatus: String { value(en: "Launch at login is disabled.", zhHans: "已关闭开机启动。", zhHant: "已關閉開機啟動。") }

    static func accessibilityLabel(_ granted: Bool) -> String {
        let state = granted
            ? value(en: "On", zhHans: "已开启", zhHant: "已開啟")
            : value(en: "Off", zhHans: "未开启", zhHant: "未開啟")
        return value(
            en: "Accessibility: \(state)",
            zhHans: "辅助功能授权：\(state)",
            zhHant: "輔助使用授權：\(state)"
        )
    }

    static func windowControlLabel(accessibilityGranted: Bool, ready: Bool) -> String {
        if !accessibilityGranted {
            return value(
                en: "Window Control: Access Required",
                zhHans: "窗口控制状态：权限未开启",
                zhHant: "視窗控制狀態：權限未開啟"
            )
        }

        let state = ready
            ? value(en: "Ready", zhHans: "已找到目标窗口", zhHant: "已找到目標視窗")
            : value(en: "Waiting for a target window", zhHans: "等待目标窗口", zhHant: "等待目標視窗")

        return value(
            en: "Window Control: \(state)",
            zhHans: "窗口控制状态：\(state)",
            zhHant: "視窗控制狀態：\(state)"
        )
    }

    static var noAvailableScreen: String { value(en: "No available screen", zhHans: "没有可用屏幕", zhHant: "沒有可用螢幕") }
    static var permissionsCheckFailedButListening: String { value(en: "Permissions not confirmed, still listening", zhHans: "权限检测未通过，仍继续监听", zhHant: "權限檢查未通過，仍繼續監聽") }
    static var waitingDrag: String { value(en: "Waiting for drag", zhHans: "等待拖动", zhHant: "等待拖動") }
    static var eventTapCreationFailed: String { value(en: "Failed to start event listener", zhHans: "事件监听创建失败", zhHant: "事件監聽建立失敗") }
    static var eventTapStarted: String { value(en: "Event listener started", zhHans: "事件监听已启动", zhHant: "事件監聽已啟動") }
    static var noDraggableWindowRegionHit: String { value(en: "Did not hit a draggable window region", zhHans: "未命中可拖动窗口区域", zhHant: "未命中可拖動視窗區域") }
    static var dragRegionRecognizedAwaitingWindow: String { value(en: "Drag region detected, waiting to lock the window", zhHans: "已识别拖动区域，等待锁定窗口", zhHant: "已識別拖動區域，等待鎖定視窗") }
    static var hitWindowTitlebar: String { value(en: "Window title area detected", zhHans: "已命中窗口顶部区域", zhHant: "已命中視窗頂部區域") }
    static var dragCapturedWindow: String { value(en: "Window captured during drag", zhHans: "拖动中已补抓目标窗口", zhHant: "拖動中已補抓目標視窗") }
    static var dragStartedWindowNotLocked: String { value(en: "Drag started, but the window is still not locked", zhHans: "拖动已开始，但仍未锁定窗口", zhHant: "拖動已開始，但仍未鎖定視窗") }
    static var dragStartedButNoWindowMovement: String { value(en: "Drag started, but no window movement was detected", zhHans: "拖动已开始，但还未识别为窗口移动", zhHant: "拖動已開始，但尚未識別為視窗移動") }
    static func overlayShowing(_ title: String?) -> String {
        if let title {
            return value(
                en: "Overlay visible: \(title)",
                zhHans: "浮层显示中：\(title)",
                zhHant: "浮層顯示中：\(title)"
            )
        }

        return value(en: "Overlay visible", zhHans: "浮层显示中", zhHant: "浮層顯示中")
    }
    static var releasedWithoutLayout: String { value(en: "Released, but no layout target was selected", zhHans: "已松手，但没有命中任何布局", zhHant: "已放開，但沒有命中任何版面") }
    static var releaseFailedNoWindowLocked: String {
        value(
            en: "A layout target was selected, but the window could not be locked when you released it. Start dragging from the window title area and try again.",
            zhHans: "已命中布局，但松手时没能锁定目标窗口。请从窗口顶部区域开始拖动后再试。",
            zhHant: "已命中版面，但放開時沒能鎖定目標視窗。請從視窗頂部區域開始拖動後再試。"
        )
    }
    static func preparingToApply(_ title: String) -> String {
        value(
            en: "Selected \(title), preparing to apply layout",
            zhHans: "已命中\(title)，准备应用布局",
            zhHant: "已命中\(title)，準備套用版面"
        )
    }
    static func releasedTo(_ title: String) -> String {
        value(
            en: "Released on \(title)",
            zhHans: "已释放到\(title)",
            zhHant: "已放開到\(title)"
        )
    }
    static var releaseFailedPermission: String { value(en: "Release failed: window control permission is not active", zhHans: "释放失败：窗口控制权限未生效", zhHant: "放開失敗：視窗控制權限未生效") }
    static func releaseFailed(_ description: String) -> String {
        value(
            en: "Release failed: \(description)",
            zhHans: "释放失败：\(description)",
            zhHant: "放開失敗：\(description)"
        )
    }
    static var windowMovedNotificationReceived: String { value(en: "Window move notification received", zhHans: "已收到窗口移动通知", zhHant: "已收到視窗移動通知") }

    static var noFrontmostApplicationError: String { value(en: "No frontmost app was found.", zhHans: "未找到当前前台应用。", zhHant: "未找到目前前景應用程式。") }
    static var noFocusedWindowError: String { value(en: "No focused window was found.", zhHans: "未找到当前聚焦窗口。", zhHant: "未找到目前焦點視窗。") }
    static var unsupportedWindowError: String { value(en: "The selected window cannot be resized.", zhHans: "当前窗口不支持调整大小。", zhHant: "目前視窗不支援調整大小。") }
    static var failedToReadWindowFrameError: String { value(en: "Unable to read the current window frame.", zhHans: "无法读取当前窗口位置。", zhHant: "無法讀取目前視窗位置。") }
    static var failedToMoveWindowError: String { value(en: "Unable to move the selected window.", zhHans: "无法移动当前窗口。", zhHant: "無法移動目前視窗。") }

    static var layoutMaximizeTitle: String { value(en: "Maximize", zhHans: "全屏", zhHant: "全螢幕") }
    static var layoutLeftHalfTitle: String { value(en: "Left Half", zhHans: "左半屏", zhHant: "左半屏") }
    static var layoutRightHalfTitle: String { value(en: "Right Half", zhHans: "右半屏", zhHant: "右半屏") }
    static var layoutTopHalfTitle: String { value(en: "Top Half", zhHans: "上半屏", zhHant: "上半屏") }
    static var layoutBottomHalfTitle: String { value(en: "Bottom Half", zhHans: "下半屏", zhHant: "下半屏") }
    static var layoutTopLeftTitle: String { value(en: "Top Left", zhHans: "左上", zhHant: "左上") }
    static var layoutTopRightTitle: String { value(en: "Top Right", zhHans: "右上", zhHant: "右上") }
    static var layoutBottomLeftTitle: String { value(en: "Bottom Left", zhHans: "左下", zhHant: "左下") }
    static var layoutBottomRightTitle: String { value(en: "Bottom Right", zhHans: "右下", zhHant: "右下") }
    static var layoutCenterLargeTitle: String { value(en: "Center", zhHans: "居中", zhHant: "置中") }

    static var layoutMaximizeSubtitle: String { value(en: "Fill the current screen", zhHans: "铺满当前屏幕可用区域", zhHant: "鋪滿目前螢幕可用區域") }
    static var layoutLeftHalfSubtitle: String { value(en: "Snap to the left side", zhHans: "贴靠到左侧", zhHant: "貼靠到左側") }
    static var layoutRightHalfSubtitle: String { value(en: "Snap to the right side", zhHans: "贴靠到右侧", zhHant: "貼靠到右側") }
    static var layoutTopHalfSubtitle: String { value(en: "Snap to the upper half", zhHans: "贴靠到上半部分", zhHant: "貼靠到上半部") }
    static var layoutBottomHalfSubtitle: String { value(en: "Snap to the lower half", zhHans: "贴靠到下半部分", zhHant: "貼靠到下半部") }
    static var quadrantSubtitle: String { value(en: "Quarter layout", zhHans: "四分之一布局", zhHant: "四分之一版面") }
    static var layoutCenterLargeSubtitle: String { value(en: "Show centered", zhHans: "居中显示", zhHant: "置中顯示") }

    private static func value(en: String, zhHans: String, zhHant: String) -> String {
        switch AppLanguage.current {
        case .english:
            return en
        case .simplifiedChinese:
            return zhHans
        case .traditionalChinese:
            return zhHant
        }
    }
}
