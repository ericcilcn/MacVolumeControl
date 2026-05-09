import SwiftUI
import UniformTypeIdentifiers

// MARK: - Switch Row

struct SwitchRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(.accentColor)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var displayManager = DisplayManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var showOSD: Bool = DisplayManager.shared.showOSD
    @State private var doubleClickToMute: Bool = DisplayManager.shared.doubleClickToMute
    @State private var mouseModifierKey: DisplayManager.ModifierKey = DisplayManager.shared.mouseModifierKey
    @State private var trackpadModifierKey: DisplayManager.ModifierKey = DisplayManager.shared.trackpadModifierKey
    @State private var selectedTab = 0

    @State private var mouseVolumeStep: DisplayManager.VolumeStep = DisplayManager.shared.mouseVolumeStep
    @State private var mouseScrollInDock: Bool = DisplayManager.shared.mouseScrollInDock
    @State private var mouseScrollInMenuBar: Bool = DisplayManager.shared.mouseScrollInMenuBar
    @State private var mouseScrollWithModifier: Bool = DisplayManager.shared.mouseScrollWithModifier
    @State private var mouseDisableSystemScroll: Bool = DisplayManager.shared.mouseDisableSystemScroll

    @State private var trackpadVolumeStep: DisplayManager.VolumeStep = DisplayManager.shared.trackpadVolumeStep
    @State private var trackpadScrollInDock: Bool = DisplayManager.shared.trackpadScrollInDock
    @State private var trackpadScrollInMenuBar: Bool = DisplayManager.shared.trackpadScrollInMenuBar
    @State private var trackpadScrollWithModifier: Bool = DisplayManager.shared.trackpadScrollWithModifier
    @State private var trackpadDisableSystemScroll: Bool = DisplayManager.shared.trackpadDisableSystemScroll

    @State private var reverseMouseScroll: Bool = DisplayManager.shared.reverseMouseScroll
    @State private var excludedApps: [String] = DisplayManager.shared.reversalExcludedApps
    @State private var showDockIcon: Bool = DisplayManager.shared.showDockIcon
    @State private var selectedLanguage: AppLanguage? = LanguageManager.shared.explicitLanguage
    @State private var showFAQ = false
    @State private var showExclusionSheet = false
    @State private var showResetAlert = false
    @State private var showAccessibilityRestartAlert = false
    @State private var isWaitingForAccessibilityPermission = false
    @State private var accessibilityPermissionCheckTimer: Timer?
    @State private var accessibilityPermissionMonitorDeadline: TimeInterval = 0
	
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TabButton(title: L10n.tabGeneral, icon: "gearshape", isSelected: selectedTab == 0) { selectedTab = 0 }
                TabButton(title: L10n.tabMouse, icon: "computermouse", isSelected: selectedTab == 1) { selectedTab = 1 }
                TabButton(title: L10n.tabTrackpad, icon: "hand.draw", isSelected: selectedTab == 2) { selectedTab = 2 }
                TabButton(title: L10n.tabAbout, icon: "info.circle", isSelected: selectedTab == 3) { selectedTab = 3 }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            Divider().padding(.horizontal)

            Group {
                switch selectedTab {
                case 0: basicTab()
                case 1: mouseTab()
                case 2: trackpadTab()
                case 3: aboutTab()
                default: basicTab()
                }
            }
            .id(languageManager.current)
        }
        .frame(minWidth: 370, minHeight: 435)
        .sheet(isPresented: $showExclusionSheet) {
            ExclusionListView(excludedApps: $excludedApps)
                .onChange(of: excludedApps) {
                    displayManager.reversalExcludedApps = excludedApps
                }
        }
        .alert(L10n.accessibilityRestartTitle, isPresented: $showAccessibilityRestartAlert) {
            Button(L10n.quitAndReopen) {
                relaunchApp()
            }
            Button(L10n.later, role: .cancel) {}
        } message: {
            Text(L10n.accessibilityRestartMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkAccessibilityPermissionAfterRequest()
        }
    }

    // MARK: - 通用

    func basicTab() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let active = displayManager.activeDisplay {
                VStack(alignment: .leading, spacing: 10) {
                    Text(active.name).font(.headline)
                    HStack(spacing: 12) {
                        Image(systemName: active.isExternal ? "display" : "speaker.wave.2").foregroundColor(.secondary)
                        Slider(value: volumeBinding(for: active), in: 0...Double(active.maxVolume))
                        Text("\(active.currentVolume)%")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }

            Divider()
            SwitchRow(label: L10n.showOSD, isOn: $showOSD).onChange(of: showOSD) { displayManager.showOSD = showOSD }
            Divider()
            SwitchRow(label: L10n.doubleClickMute, isOn: $doubleClickToMute).onChange(of: doubleClickToMute) { displayManager.doubleClickToMute = doubleClickToMute }
            Divider()
            SwitchRow(label: L10n.showDockIcon, isOn: $showDockIcon).onChange(of: showDockIcon) { displayManager.showDockIcon = showDockIcon }
            Divider()
            SwitchRow(label: L10n.launchAtLogin, isOn: $launchAtLogin).onChange(of: launchAtLogin) { LaunchAtLogin.setEnabled(launchAtLogin) }

            Divider()
            HStack {
                Text(L10n.language)
                Spacer()
                Picker("", selection: $selectedLanguage) {
                    Text(L10n.followSystem).tag(AppLanguage?.none)
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(AppLanguage?.some(lang))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
                .onChange(of: selectedLanguage) {
                    if let lang = selectedLanguage {
                        languageManager.current = lang
                    } else {
                        languageManager.followSystem()
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
    }

    // MARK: - 鼠标

    func mouseTab() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.stepSize); Spacer()
                Picker("", selection: $mouseVolumeStep) {
                    ForEach(DisplayManager.VolumeStep.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 160)
                .onChange(of: mouseVolumeStep) { displayManager.mouseVolumeStep = mouseVolumeStep }
            }

            Divider()
            SwitchRow(label: L10n.scrollInDock, isOn: $mouseScrollInDock).onChange(of: mouseScrollInDock) { displayManager.mouseScrollInDock = mouseScrollInDock }
            Divider()
            SwitchRow(label: L10n.scrollInMenuBar, isOn: $mouseScrollInMenuBar).onChange(of: mouseScrollInMenuBar) { displayManager.mouseScrollInMenuBar = mouseScrollInMenuBar }
            Divider()
            SwitchRow(label: L10n.scrollWithModifier, isOn: $mouseScrollWithModifier).onChange(of: mouseScrollWithModifier) { displayManager.mouseScrollWithModifier = mouseScrollWithModifier }

            SwitchRow(label: L10n.disableSystemScroll, isOn: $mouseDisableSystemScroll)
                .disabled(!mouseScrollWithModifier)
                .onChange(of: mouseDisableSystemScroll) {
                    displayManager.mouseDisableSystemScroll = mouseDisableSystemScroll
                    requestAccessibilityPermissionIfNeeded(for: mouseDisableSystemScroll)
                }
                .padding(.leading, 20)
            HStack {
                Text(L10n.modifierKey); Spacer()
                Picker("", selection: $mouseModifierKey) {
                    ForEach(DisplayManager.ModifierKey.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu).frame(width: 130)
                .disabled(!mouseScrollWithModifier)
                .onChange(of: mouseModifierKey) { displayManager.mouseModifierKey = mouseModifierKey }
            }
            .padding(.leading, 20)

            Divider()
            VStack(alignment: .leading, spacing: 6) {
                SwitchRow(label: L10n.reverseMouseScroll, isOn: $reverseMouseScroll)
                    .onChange(of: reverseMouseScroll) {
                        displayManager.reverseMouseScroll = reverseMouseScroll
                        requestAccessibilityPermissionIfNeeded(for: reverseMouseScroll)
                    }
                HStack {
                    Button(L10n.manageExclusions) { showExclusionSheet = true }
                        .buttonStyle(.link)
                        .font(.caption)
                    Spacer()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
    }

    // MARK: - 触控板

    func trackpadTab() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.stepSize); Spacer()
                Picker("", selection: $trackpadVolumeStep) {
                    ForEach(DisplayManager.VolumeStep.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 160)
                .onChange(of: trackpadVolumeStep) { displayManager.trackpadVolumeStep = trackpadVolumeStep }
            }

            Divider()
            SwitchRow(label: L10n.swipeInDock, isOn: $trackpadScrollInDock).onChange(of: trackpadScrollInDock) { displayManager.trackpadScrollInDock = trackpadScrollInDock }
            Divider()
            SwitchRow(label: L10n.swipeInMenuBar, isOn: $trackpadScrollInMenuBar).onChange(of: trackpadScrollInMenuBar) { displayManager.trackpadScrollInMenuBar = trackpadScrollInMenuBar }
            Divider()
            SwitchRow(label: L10n.swipeWithModifier, isOn: $trackpadScrollWithModifier).onChange(of: trackpadScrollWithModifier) { displayManager.trackpadScrollWithModifier = trackpadScrollWithModifier }

            SwitchRow(label: L10n.disableSystemSwipe, isOn: $trackpadDisableSystemScroll)
                .disabled(!trackpadScrollWithModifier)
                .onChange(of: trackpadDisableSystemScroll) {
                    displayManager.trackpadDisableSystemScroll = trackpadDisableSystemScroll
                    requestAccessibilityPermissionIfNeeded(for: trackpadDisableSystemScroll)
                }
                .padding(.leading, 20)
            HStack {
                Text(L10n.modifierKey); Spacer()
                Picker("", selection: $trackpadModifierKey) {
                    ForEach(DisplayManager.ModifierKey.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu).frame(width: 130)
                .disabled(!trackpadScrollWithModifier)
                .onChange(of: trackpadModifierKey) { displayManager.trackpadModifierKey = trackpadModifierKey }
            }
            .padding(.leading, 20)

            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
    }

    // MARK: - 关于

    func aboutTab() -> some View {
        VStack(spacing: 14) {
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon).resizable().frame(width: 64, height: 64)
            }
            Text("Rolume").font(.title2).fontWeight(.bold)
            Text("Version \(appVersion)").foregroundColor(.secondary)

            Divider().padding(.horizontal, 30)

            Button(L10n.sponsor) {
                if let url = URL(string: sponsorURLString) { NSWorkspace.shared.open(url) }
            }
            .buttonStyle(.link)

            Divider().padding(.horizontal, 30)

            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    Button("GitHub") {
                        if let url = URL(string: "https://github.com/ericcilcn/Rolume") { NSWorkspace.shared.open(url) }
                    }
                    .buttonStyle(.link)
                    Text(" · ").foregroundColor(.secondary)
                    Button(L10n.faq) { showFAQ = true }
                        .buttonStyle(.link)
                        .popover(isPresented: $showFAQ) { faqContent() }
                }

                Text("Ericcil@163.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            Divider().padding(.horizontal, 30)

            Button(role: .destructive) { showResetAlert = true } label: {
                Text(L10n.resetDefaults)
            }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .alert(L10n.resetAlertTitle, isPresented: $showResetAlert) {
                    Button(L10n.cancel, role: .cancel) { showResetAlert = false }
                    Button(L10n.restore, role: .destructive) {
                        showResetAlert = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            restoreDefaults()
                        }
                    }
                } message: { Text(L10n.resetAlertMessage) }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
    }

    func faqContent() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            faqRow(q: L10n.faq1, a: L10n.faq1a)
            Divider()
            faqRow(q: L10n.faq2, a: L10n.faq2a)
            Divider()
            faqRow(q: L10n.faq3, a: L10n.faq3a)
            Divider()
            faqRow(q: L10n.faq4, a: L10n.faq4a)
            Divider()
            faqRow(q: L10n.faq5, a: L10n.faq5a)
            Divider()
            faqRow(q: L10n.faq6, a: L10n.faq6a)
        }
        .frame(width: 360)
        .padding(16)
    }

    func faqRow(q: String, a: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(q).font(.caption).fontWeight(.medium).padding(.vertical, 4)
            Text(a).font(.caption2).foregroundColor(.secondary).padding(.bottom, 4)
        }
        .padding(.horizontal, 4)
    }

    func restoreDefaults() {
        mouseVolumeStep = .medium; mouseScrollInDock = true; mouseScrollInMenuBar = false
        mouseScrollWithModifier = false; mouseDisableSystemScroll = false
        trackpadVolumeStep = .medium; trackpadScrollInDock = true; trackpadScrollInMenuBar = false
        trackpadScrollWithModifier = false; trackpadDisableSystemScroll = false
        mouseModifierKey = .option; trackpadModifierKey = .option
        showOSD = true; doubleClickToMute = true
        launchAtLogin = true; reverseMouseScroll = false; showDockIcon = false
        excludedApps = []
        displayManager.reversalExcludedApps = []

        displayManager.mouseVolumeStep = mouseVolumeStep
        displayManager.mouseScrollInDock = mouseScrollInDock
        displayManager.mouseScrollInMenuBar = mouseScrollInMenuBar
        displayManager.mouseScrollWithModifier = mouseScrollWithModifier
        displayManager.mouseDisableSystemScroll = mouseDisableSystemScroll
        displayManager.mouseModifierKey = mouseModifierKey
        displayManager.trackpadVolumeStep = trackpadVolumeStep
        displayManager.trackpadScrollInDock = trackpadScrollInDock
        displayManager.trackpadScrollInMenuBar = trackpadScrollInMenuBar
        displayManager.trackpadScrollWithModifier = trackpadScrollWithModifier
        displayManager.trackpadDisableSystemScroll = trackpadDisableSystemScroll
        displayManager.trackpadModifierKey = trackpadModifierKey
        displayManager.showOSD = showOSD; displayManager.doubleClickToMute = doubleClickToMute
        displayManager.reverseMouseScroll = reverseMouseScroll
        displayManager.showDockIcon = showDockIcon
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L10n.version
    }

    private var sponsorURLString: String {
        languageManager.current == .chinese ? "https://ifdian.net/a/Rolume" : "https://ko-fi.com/rolume"
    }

    private var isAnyAccessibilityFeatureEnabled: Bool {
        reverseMouseScroll || mouseDisableSystemScroll || trackpadDisableSystemScroll
    }

    private func requestAccessibilityPermissionIfNeeded(for enabledFeature: Bool) {
        guard enabledFeature,
              !isWaitingForAccessibilityPermission,
              !EventInterceptor.hasAccessibilityPermission()
        else { return }

        EventInterceptor.requestAccessibilityPermission()
        startAccessibilityPermissionMonitoring()
    }

    private func startAccessibilityPermissionMonitoring() {
        guard !isWaitingForAccessibilityPermission else { return }

        isWaitingForAccessibilityPermission = true
        accessibilityPermissionMonitorDeadline = ProcessInfo.processInfo.systemUptime + 180
        accessibilityPermissionCheckTimer?.invalidate()
        accessibilityPermissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                checkAccessibilityPermissionAfterRequest()
            }
        }
    }

    private func checkAccessibilityPermissionAfterRequest() {
        guard isWaitingForAccessibilityPermission else { return }

        if EventInterceptor.hasAccessibilityPermission() {
            stopAccessibilityPermissionMonitoring()
            if isAnyAccessibilityFeatureEnabled {
                showAccessibilityRestartAlert = true
            }
            return
        }

        if ProcessInfo.processInfo.systemUptime > accessibilityPermissionMonitorDeadline {
            stopAccessibilityPermissionMonitoring()
        }
    }

    private func stopAccessibilityPermissionMonitoring() {
        accessibilityPermissionCheckTimer?.invalidate()
        accessibilityPermissionCheckTimer = nil
        isWaitingForAccessibilityPermission = false
        accessibilityPermissionMonitorDeadline = 0
    }

    private func relaunchApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "sleep 0.5; /usr/bin/open -n \"$1\"",
            "relaunch",
            Bundle.main.bundlePath
        ]
        try? process.run()
        NSApp.terminate(nil)
    }

    private func volumeBinding(for active: Display) -> Binding<Double> {
        Binding(
            get: {
                Double(displayManager.activeDisplay?.currentVolume ?? active.currentVolume)
            },
            set: { newValue in
                let targetVolume = Int(newValue.rounded())
                let currentVolume = displayManager.activeDisplay?.currentVolume ?? active.currentVolume
                let delta = targetVolume - currentVolume
                guard delta != 0 else { return }
                displayManager.adjustVolume(by: delta)
            }
        )
    }
}

// MARK: - Tab Button

// MARK: - Exclusion List

struct ExclusionListView: View {
    @Binding var excludedApps: [String]
    @State private var showFilePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.excludedApps).font(.headline)
                Spacer()
                Button(L10n.done) { dismiss() }
                    .buttonStyle(.link)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()

            if excludedApps.isEmpty {
                Text(L10n.noExcludedApps)
                    .font(.caption).foregroundColor(.secondary)
                    .padding(16)
            } else {
                List {
                    ForEach(excludedApps, id: \.self) { bundleID in
                        HStack(spacing: 8) {
                            if let icon = appIcon(for: bundleID) {
                                Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                            }
                            Text(appName(for: bundleID)).font(.caption)
                            Spacer()
                            Button { removeApp(bundleID) } label: {
                                Image(systemName: "xmark.circle.fill").font(.caption).foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("\(L10n.remove) \(appName(for: bundleID))"))
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 100)
            }

            Divider()
            HStack {
                Button(L10n.addApp) { showFilePicker = true }
                    .buttonStyle(.link)
                    .font(.caption)
                Spacer()
            }
            .padding(10)
        }
        .frame(width: 280)
        .frame(minHeight: 140)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls {
                    if let bundleID = Bundle(url: url)?.bundleIdentifier,
                       bundleID != "com.personal.Rolume",
                       !excludedApps.contains(bundleID) {
                        excludedApps.append(bundleID)
                    }
                }
            }
        }
    }

    private func removeApp(_ bundleID: String) {
        excludedApps.removeAll { $0 == bundleID }
    }

    private func appName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    private func appIcon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 36, height: 30, alignment: .center)

                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(height: 16, alignment: .center)
            }
            .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(isSelected ? 0.1 : 0))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
