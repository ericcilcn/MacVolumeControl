import SwiftUI

struct SettingsView: View {
    @StateObject private var displayManager = DisplayManager.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var showOSD: Bool = DisplayManager.shared.showOSD
    @State private var doubleClickToMute: Bool = DisplayManager.shared.doubleClickToMute
    @State private var selectedModifierKey: DisplayManager.ModifierKey = DisplayManager.shared.selectedModifierKey
    @State private var selectedTab = 0

    // 鼠标设置
    @State private var mouseVolumeStep: DisplayManager.VolumeStep = DisplayManager.shared.mouseVolumeStep
    @State private var mouseScrollInDock: Bool = DisplayManager.shared.mouseScrollInDock
    @State private var mouseScrollInMenuBar: Bool = DisplayManager.shared.mouseScrollInMenuBar
    @State private var mouseScrollWithModifier: Bool = DisplayManager.shared.mouseScrollWithModifier
    @State private var mouseDisableSystemScroll: Bool = DisplayManager.shared.mouseDisableSystemScroll

    // 触控板设置
    @State private var trackpadVolumeStep: DisplayManager.VolumeStep = DisplayManager.shared.trackpadVolumeStep
    @State private var trackpadScrollInDock: Bool = DisplayManager.shared.trackpadScrollInDock
    @State private var trackpadScrollInMenuBar: Bool = DisplayManager.shared.trackpadScrollInMenuBar
    @State private var trackpadScrollWithModifier: Bool = DisplayManager.shared.trackpadScrollWithModifier
    @State private var trackpadDisableSystemScroll: Bool = DisplayManager.shared.trackpadDisableSystemScroll

    // 确认弹窗
    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 自定义标签栏
            HStack(spacing: 0) {
                TabButton(title: "通用", icon: "gearshape", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "鼠标", icon: "computermouse", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabButton(title: "触控板", icon: "hand.draw", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                TabButton(title: "关于", icon: "info.circle", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // 内容区域
            Group {
                switch selectedTab {
                case 0:
                    basicTab()
                case 1:
                    mouseTab()
                case 2:
                    trackpadTab()
                case 3:
                    aboutTab()
                default:
                    basicTab()
                }
            }
        }
        .frame(width: 480, height: 380)
    }

    // 基础标签
    func basicTab() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 音量滑块
            if let activeDisplay = displayManager.activeDisplay {
                VStack(alignment: .leading, spacing: 10) {
                    Text(activeDisplay.name)
                        .font(.headline)
                    HStack(spacing: 12) {
                        Image(systemName: activeDisplay.isExternal ? "display" : "speaker.wave.2")
                            .foregroundColor(.secondary)
                        Slider(
                            value: Binding(
                                get: { Double(activeDisplay.currentVolume) },
                                set: { newValue in
                                    let delta = Int(newValue) - activeDisplay.currentVolume
                                    displayManager.adjustVolume(by: delta)
                                }
                            ),
                            in: 0...Double(activeDisplay.maxVolume),
                            step: 5
                        )
                        Text("\(activeDisplay.currentVolume)")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }

            Divider()

            Toggle("显示音量调节界面", isOn: $showOSD)
                .onChange(of: showOSD) {
                    displayManager.showOSD = showOSD
                }

            Divider()

            Toggle("双击菜单栏图标静音", isOn: $doubleClickToMute)
                .onChange(of: doubleClickToMute) {
                    displayManager.doubleClickToMute = doubleClickToMute
                }

            Divider()

            Toggle("开机启动", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) {
                    LaunchAtLogin.setEnabled(launchAtLogin)
                }

            Spacer()
        }
        .padding(24)
    }

    // 滚轮标签
    func mouseTab() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 步进设置 - 一行显示
            HStack {
                Text("步进幅度")
                Spacer()
                Picker("", selection: $mouseVolumeStep) {
                    ForEach(DisplayManager.VolumeStep.allCases, id: \.self) { step in
                        Text(step.displayName).tag(step)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: mouseVolumeStep) {
                    displayManager.mouseVolumeStep = mouseVolumeStep
                }
            }

            Divider()

            Toggle("在 Dock 区域滚动调节音量", isOn: $mouseScrollInDock)
                .onChange(of: mouseScrollInDock) {
                    displayManager.mouseScrollInDock = mouseScrollInDock
                }

            Divider()

            Toggle("在菜单栏区域滚动调节音量", isOn: $mouseScrollInMenuBar)
                .onChange(of: mouseScrollInMenuBar) {
                    displayManager.mouseScrollInMenuBar = mouseScrollInMenuBar
                }

            Divider()

            HStack {
                Toggle("按住修饰键滚动调节音量", isOn: $mouseScrollWithModifier)
                    .onChange(of: mouseScrollWithModifier) {
                        displayManager.mouseScrollWithModifier = mouseScrollWithModifier
                    }

                if mouseScrollWithModifier {
                    Toggle("按住修饰键禁用系统原生滚动", isOn: $mouseDisableSystemScroll)
                        .onChange(of: mouseDisableSystemScroll) {
                            displayManager.mouseDisableSystemScroll = mouseDisableSystemScroll
                        }
                } else {
                    Toggle("按住修饰键禁用系统原生滚动", isOn: .constant(false))
                        .disabled(true)
                }
            }

            if mouseScrollWithModifier {
                HStack {
                    Text("修饰键")
                    Spacer()
                    Picker("", selection: $selectedModifierKey) {
                        ForEach(DisplayManager.ModifierKey.allCases, id: \.self) { key in
                            Text(key.displayName).tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .onChange(of: selectedModifierKey) {
                        displayManager.selectedModifierKey = selectedModifierKey
                    }
                }
                .padding(.leading, 20)
            }

            Spacer()
        }
        .padding(28)
    }

    // 触控板标签
    func trackpadTab() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 步进设置 - 一行显示
            HStack {
                Text("步进幅度")
                Spacer()
                Picker("", selection: $trackpadVolumeStep) {
                    ForEach(DisplayManager.VolumeStep.allCases, id: \.self) { step in
                        Text(step.displayName).tag(step)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: trackpadVolumeStep) {
                    displayManager.trackpadVolumeStep = trackpadVolumeStep
                }
            }

            Divider()

            Toggle("在 Dock 区域滑动调节音量", isOn: $trackpadScrollInDock)
                .onChange(of: trackpadScrollInDock) {
                    displayManager.trackpadScrollInDock = trackpadScrollInDock
                }

            Divider()

            Toggle("在菜单栏区域滑动调节音量", isOn: $trackpadScrollInMenuBar)
                .onChange(of: trackpadScrollInMenuBar) {
                    displayManager.trackpadScrollInMenuBar = trackpadScrollInMenuBar
                }

            Divider()

            HStack {
                Toggle("按住修饰键滑动调节音量", isOn: $trackpadScrollWithModifier)
                    .onChange(of: trackpadScrollWithModifier) {
                        displayManager.trackpadScrollWithModifier = trackpadScrollWithModifier
                    }

                if trackpadScrollWithModifier {
                    Toggle("按住修饰键禁用系统原生滑动", isOn: $trackpadDisableSystemScroll)
                        .onChange(of: trackpadDisableSystemScroll) {
                            displayManager.trackpadDisableSystemScroll = trackpadDisableSystemScroll
                        }
                } else {
                    Toggle("按住修饰键禁用系统原生滑动", isOn: .constant(false))
                        .disabled(true)
                }
            }

            if trackpadScrollWithModifier {
                HStack {
                    Text("修饰键")
                    Spacer()
                    Picker("", selection: $selectedModifierKey) {
                        ForEach(DisplayManager.ModifierKey.allCases, id: \.self) { key in
                            Text(key.displayName).tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .onChange(of: selectedModifierKey) {
                        displayManager.selectedModifierKey = selectedModifierKey
                    }
                }
                .padding(.leading, 20)
            }

            Spacer()
        }
        .padding(28)
    }

    // 关于标签
    func aboutTab() -> some View {
        VStack(spacing: 20) {
            Spacer()

            Text("MacVolumeControl")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.1")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Text("反馈和建议")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Ericcil@163.com") {
                    if let url = URL(string: "mailto:Ericcil@163.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }

            Divider()
                .padding(.horizontal, 40)

            Button("恢复默认设置") {
                showResetAlert = true
            }
            .buttonStyle(.borderedProminent)
            .alert("确认恢复默认设置", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) { }
                Button("恢复", role: .destructive) {
                    restoreDefaults()
                }
            } message: {
                Text("此操作将恢复所有设置为默认值")
            }

            Spacer()
        }
        .padding()
    }

    func restoreDefaults() {
        // 鼠标默认值
        mouseVolumeStep = .medium
        mouseScrollInDock = true
        mouseScrollInMenuBar = false
        mouseScrollWithModifier = false
        mouseDisableSystemScroll = false

        // 触控板默认值
        trackpadVolumeStep = .medium
        trackpadScrollInDock = true
        trackpadScrollInMenuBar = false
        trackpadScrollWithModifier = false
        trackpadDisableSystemScroll = false

        // 其他默认值
        selectedModifierKey = .option
        showOSD = true
        doubleClickToMute = true
        launchAtLogin = true

        // 保存到 DisplayManager
        displayManager.mouseVolumeStep = mouseVolumeStep
        displayManager.mouseScrollInDock = mouseScrollInDock
        displayManager.mouseScrollInMenuBar = mouseScrollInMenuBar
        displayManager.mouseScrollWithModifier = mouseScrollWithModifier
        displayManager.mouseDisableSystemScroll = mouseDisableSystemScroll

        displayManager.trackpadVolumeStep = trackpadVolumeStep
        displayManager.trackpadScrollInDock = trackpadScrollInDock
        displayManager.trackpadScrollInMenuBar = trackpadScrollInMenuBar
        displayManager.trackpadScrollWithModifier = trackpadScrollWithModifier
        displayManager.trackpadDisableSystemScroll = trackpadDisableSystemScroll

        displayManager.selectedModifierKey = selectedModifierKey
        displayManager.showOSD = showOSD
        displayManager.doubleClickToMute = doubleClickToMute
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 24, height: 24, alignment: .center)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 60)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

