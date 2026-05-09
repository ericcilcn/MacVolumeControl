import SwiftUI
import Combine

// MARK: - Language

enum AppLanguage: String, CaseIterable {
    case chinese = "zh-Hans"
    case english = "en"

    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}

// MARK: - Localized Strings

struct L10n {
    private static var lang: AppLanguage { LanguageManager.shared.current }

    // Tab titles
    static var tabGeneral: String     { lang == .chinese ? "通用" : "General" }
    static var tabMouse: String       { lang == .chinese ? "鼠标" : "Mouse" }
    static var tabTrackpad: String    { lang == .chinese ? "触控板" : "Trackpad" }
    static var tabAbout: String       { lang == .chinese ? "关于" : "About" }

    // General
    static var showOSD: String          { lang == .chinese ? "显示音量调节界面" : "Show volume overlay" }
    static var doubleClickMute: String  { lang == .chinese ? "双击菜单栏图标静音" : "Double-click to mute" }
    static var launchAtLogin: String    { lang == .chinese ? "开机启动" : "Launch at login" }
    static var showDockIcon: String     { lang == .chinese ? "在 Dock 栏显示图标" : "Show in Dock" }
    static var language: String         { lang == .chinese ? "语言" : "Language" }
    static var followSystem: String      { lang == .chinese ? "跟随系统" : "Follow System" }
    static var languageRestartNote: String { lang == .chinese ? "更改即时生效" : "Changes take effect immediately" }

    // Mouse
    static var stepSize: String              { lang == .chinese ? "步进幅度" : "Step size" }
    static var scrollInDock: String          { lang == .chinese ? "在 Dock 区域滚动调节音量" : "Scroll in Dock area" }
    static var scrollInMenuBar: String       { lang == .chinese ? "在菜单栏区域滚动调节音量" : "Scroll in menu bar area" }
    static var scrollWithModifier: String    { lang == .chinese ? "按住修饰键滚动调节音量" : "Hold modifier key to scroll" }
    static var disableSystemScroll: String   { lang == .chinese ? "拦截滚动" : "Intercept scroll" }
    static var modifierKey: String           { lang == .chinese ? "修饰键" : "Modifier key" }
    static var reverseMouseScroll: String    { lang == .chinese ? "反转鼠标滚轮方向" : "Reverse mouse scroll direction" }
    static var manageExclusions: String      { lang == .chinese ? "管理排除" : "Manage Exclusions" }
    static var excludedApps: String          { lang == .chinese ? "排除的 App" : "Excluded Apps" }
    static var addApp: String                { lang == .chinese ? "添加 App" : "Add App" }
    static var done: String                  { lang == .chinese ? "完成" : "Done" }
    static var remove: String                { lang == .chinese ? "移除" : "Remove" }
    static var noExcludedApps: String        { lang == .chinese ? "未添加任何 App，反转对所有 App 生效" : "No apps excluded, reversal applies to all apps" }
    static var reverseScrollNote: String     { lang == .chinese ? "独立反转鼠标滚轮方向，不影响触控板自然滚动" : "Reverse mouse scroll independently, leaving trackpad unaffected" }

    // Trackpad
    static var swipeInDock: String           { lang == .chinese ? "在 Dock 区域滑动调节音量" : "Swipe in Dock area" }
    static var swipeInMenuBar: String        { lang == .chinese ? "在菜单栏区域滑动调节音量" : "Swipe in menu bar area" }
    static var swipeWithModifier: String     { lang == .chinese ? "按住修饰键滑动调节音量" : "Hold modifier key to swipe" }
    static var disableSystemSwipe: String    { lang == .chinese ? "拦截滑动" : "Intercept swipe" }

    // About
    static var version: String        { "1.1" }
    static var copy: String           { lang == .chinese ? "复制" : "Copy" }
    static var feedback: String       { lang == .chinese ? "邮件反馈" : "Email Feedback" }
    static var sponsor: String        { lang == .chinese ? "支持 Rolume" : "Support Rolume" }
    static var resetDefaults: String  { lang == .chinese ? "恢复默认设置" : "Restore Defaults" }
    static var resetAlertTitle: String { lang == .chinese ? "确认恢复默认设置" : "Restore Default Settings" }
    static var resetAlertMessage: String { lang == .chinese ? "此操作将恢复所有设置为默认值" : "This will restore all settings to defaults" }
    static var cancel: String         { lang == .chinese ? "取消" : "Cancel" }
    static var restore: String        { lang == .chinese ? "恢复" : "Restore" }

    // FAQ
    static var faq1: String  { lang == .chinese ? "支持哪些 macOS 版本？" : "Which macOS versions are supported?" }
    static var faq1a: String { lang == .chinese ? "macOS 14.0 及以上，兼容 Intel 和 Apple Silicon。" : "macOS 14.0 or later, compatible with Intel and Apple Silicon." }
    static var faq2: String  { lang == .chinese ? "外接显示器音量无法调节？" : "External display volume not working?" }
    static var faq2a: String { lang == .chinese ? "需要显示器支持 DDC/CI 协议，且通过 DisplayPort 或 HDMI 连接。Apple Silicon 和 Intel Mac 均支持。部分显示器需要在菜单中手动开启 DDC/CI。" : "Your display must support DDC/CI and be connected via DisplayPort or HDMI. Both Apple Silicon and Intel Macs are supported. Some displays require enabling DDC/CI in their OSD menu." }
    static var faq: String   { lang == .chinese ? "常见问题" : "FAQ" }
    static var faq3: String  { lang == .chinese ? "鼠标滚轮反转需要什么权限？" : "Does scroll reversal need permissions?" }
    static var faq3a: String { lang == .chinese ? "需要在 系统设置 → 隐私与安全性 → 辅助功能 中授权本应用。" : "Grant Accessibility permission in System Settings → Privacy & Security → Accessibility." }
    static var faq4: String  { lang == .chinese ? "可以同时控制多个显示器吗？" : "Can I control multiple displays?" }
    static var faq4a: String { lang == .chinese ? "支持。通过 EDID 自动匹配每个显示器对应的 DDC 通道，多显示器各自独立控制。" : "Yes. Each display is matched to its DDC channel via EDID, allowing independent control in multi-monitor setups." }
    static var faq5: String  { lang == .chinese ? "已授权辅助功能权限，功能仍不生效？" : "Granted Accessibility but features still not working?" }
    static var faq5a: String { lang == .chinese ? "请重启应用，或开关一次相关功能开关即可。" : "Restart the app, or toggle the relevant feature switch off and back on." }
    static var faq6: String  { lang == .chinese ? "滚轮反转和自然滚动之间是什么关系？" : "How does scroll reversal work with natural scrolling?" }
    static var faq6a: String { lang == .chinese ? "反转仅作用于鼠标，不影响触控板。开启后鼠标滚轮方向与系统「自然滚动」设置解耦，例如你可以在系统设置中保持触控板自然滚动开启，同时让鼠标恢复传统滚动方向。" : "Reversal only affects the mouse, never the trackpad. When enabled, mouse scroll direction is decoupled from the system Natural Scrolling setting — you can keep natural scrolling for your trackpad while reverting the mouse to classic direction." }
    // Menu
    static var enableApp: String      { lang == .chinese ? "启用" : "Enable" }
    static var preferences: String    { lang == .chinese ? "偏好设置" : "Preferences" }
    static var quit: String           { lang == .chinese ? "退出" : "Quit" }
}

// MARK: - Language Manager

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    private var shouldPersistCurrentLanguage = true

    private static func systemLanguage() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .chinese : .english
    }

    /// nil = 跟随系统，非 nil = 用户手动选择
    var explicitLanguage: AppLanguage? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "appLanguage") else { return nil }
            return AppLanguage(rawValue: raw)
        }
    }

    @Published var current: AppLanguage {
        didSet {
            if shouldPersistCurrentLanguage {
                UserDefaults.standard.set(current.rawValue, forKey: "appLanguage")
            }
            NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
        }
    }

    func followSystem() {
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        shouldPersistCurrentLanguage = false
        current = Self.systemLanguage()
        shouldPersistCurrentLanguage = true
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: raw) {
            current = lang
        } else {
            // 跟随系统语言
            current = Self.systemLanguage()
        }
    }
}
