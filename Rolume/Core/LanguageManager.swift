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
    static var accessibilityRestartTitle: String { lang == .chinese ? "重新打开 Rolume" : "Reopen Rolume" }
    static var accessibilityRestartMessage: String {
        lang == .chinese
            ? "辅助功能权限已开启。请退出并重新打开 Rolume，让滚动拦截和鼠标滚轮反转可靠生效。"
            : "Accessibility permission is now enabled. Quit and reopen Rolume so scroll interception and mouse wheel reversal work reliably."
    }
    static var quitAndReopen: String { lang == .chinese ? "退出并重新打开" : "Quit and Reopen" }
    static var later: String { lang == .chinese ? "以后" : "Later" }
    static var cancel: String         { lang == .chinese ? "取消" : "Cancel" }
    static var restore: String        { lang == .chinese ? "恢复" : "Restore" }

    // FAQ
    static var faq1: String  { lang == .chinese ? "Rolume 会控制什么音量？" : "What volume does Rolume control?" }
    static var faq1a: String { lang == .chinese ? "Rolume 控制当前选中的设备：系统音频设备使用 CoreAudio，显示器扬声器在可用时使用 DDC/CI。" : "Rolume controls the currently selected device. System audio devices use CoreAudio, while display speakers use DDC/CI when available." }
    static var faq2: String  { lang == .chinese ? "外接显示器音量无法调节？" : "External display volume not working?" }
    static var faq2a: String { lang == .chinese ? "请确认显示器支持 DDC/CI，并已在显示器菜单中开启。若要控制显示器扬声器，请在 macOS 声音输出中选择该显示器；部分扩展坞或转接器可能不转发 DDC 命令。" : "Make sure the display supports DDC/CI and that it is enabled in the display's OSD menu. To control display speakers, select that display as the macOS sound output. Some docks or adapters may not forward DDC commands." }
    static var faq: String   { lang == .chinese ? "常见问题" : "FAQ" }
    static var faq3: String  { lang == .chinese ? "哪些功能需要辅助功能权限？" : "Which features need Accessibility permission?" }
    static var faq3a: String { lang == .chinese ? "只有鼠标滚轮反转、拦截滚动和拦截滑动需要辅助功能权限。开启相关开关时，Rolume 会使用 macOS 系统权限提示。" : "Only mouse wheel reversal, scroll interception, and swipe interception need Accessibility permission. Rolume uses the native macOS permission prompt when those options are enabled." }
    static var faq4: String  { lang == .chinese ? "多显示器时会控制哪一个？" : "Which device is controlled with multiple displays?" }
    static var faq4a: String { lang == .chinese ? "Rolume 会优先控制当前声音输出对应的显示器；没有显示器音频目标时，会根据鼠标所在屏幕或系统音频设备选择当前控制对象。" : "Rolume prioritizes the display that matches the current sound output. If there is no display-audio target, it chooses the active device from the screen under the pointer or the system audio device." }
    static var faq5: String  { lang == .chinese ? "已授权辅助功能权限，功能仍不生效？" : "Granted Accessibility but features still not working?" }
    static var faq5a: String { lang == .chinese ? "请按提示退出并重新打开 Rolume。若选择“以后”，也可以关闭再打开相关功能开关，让事件拦截器重新启动。" : "Use the prompt to quit and reopen Rolume. If you choose Later, turn the relevant feature off and back on to restart the event interceptor." }
    static var faq6: String  { lang == .chinese ? "滚轮反转和自然滚动之间是什么关系？" : "How does scroll reversal work with natural scrolling?" }
    static var faq6a: String { lang == .chinese ? "反转仅改变鼠标滚轮方向，不改变触控板自然滚动，也不会接管触控板调音量手感，除非你开启了触控板的“拦截滑动”。" : "Reversal only changes mouse wheel direction. It does not change trackpad natural scrolling or take over trackpad volume sensitivity unless Trackpad Intercept Swipe is enabled." }
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
