# Rolume

<p align="center">
  <img src="Rolume/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png" width="200" alt="Rolume Icon">
</p>

<p align="center">
  <strong>优雅的 macOS 音量控制工具</strong>
</p>

<p align="center">
  专为外接显示器和系统音频设计的轻量级音量管理应用
</p>

---

## ✨ 特性

- 🖥️ **外接显示器音量控制** - 通过 DDC/CI 协议精准控制外接显示器音量，支持 Apple Silicon 和 Intel
- 🖱️ **鼠标滚轮调节** - 在 Dock 区域、菜单栏区域或按住修饰键滚动调节音量
- 🎨 **触控板滑动支持** - 独立的触控板手势设置，更符合使用习惯
- 📊 **动态菜单栏图标** - 实时显示当前音量，滚轮图标随音量动态填充
- 🎯 **多种控制方式** - 灵活的音量调节选项，适应不同使用场景
- 🔇 **双击静音** - 快速静音/取消静音
- 🎛️ **自定义步进** - 支持 2%、5%、10% 三种音量调节幅度
- 💫 **OSD 显示** - 美观的音量调节界面提示
- 🔄 **鼠标滚轮反转** - 独立反转鼠标滚轮方向，不影响触控板，支持 App 排除列表
- 🚀 **开机自启** - 默认开机启动，无需手动运行
- ⏸️ **一键暂停** - 右键菜单随时启用/暂停所有功能
- 🌐 **中英双语** - 界面完全支持中文和 English

## 📦 安装

### 下载安装

1. 从 [Releases](../../releases) 页面下载最新的 `Rolume.dmg`
2. 打开 DMG 文件
3. 将 Rolume 拖到应用程序文件夹
4. 首次运行时授予必要的权限

### 从源码编译

```bash
git clone https://github.com/ericcilcn/Rolume.git
cd Rolume
open Rolume.xcodeproj
```

在 Xcode 中按 `Cmd+R` 运行

### 生成安装 DMG

```bash
chmod +x scripts/create_dmg.sh
./scripts/create_dmg.sh
```

## 🎮 使用方法

### 基本操作

- **鼠标滚轮**：在 Dock 区域或菜单栏区域滚动调节音量
- **触控板**：在 Dock 区域或菜单栏区域双指滑动调节音量
- **修饰键**：按住 Option（或其他修饰键）+ 滚动/滑动调节音量
- **双击图标**：快速静音/取消静音
- **单击图标**：打开偏好设置
- **右键图标**：显示快捷菜单（启用/暂停、偏好设置、退出）

### 设置选项

1. **通用** - 音量滑块、OSD 显示、双击静音、Dock 图标、开机启动、语言
2. **鼠标** - 步进幅度、滚动区域、修饰键设置、滚轮反转及排除列表
3. **触控板** - 步进幅度、滑动区域、修饰键设置
4. **关于** - 版本信息、GitHub、邮件反馈、常见问题、恢复默认设置

## 🔧 系统要求

- macOS 14.0 或更高版本
- 支持 Apple Silicon 和 Intel 处理器

## ⚠️ 权限说明

- **辅助功能权限**：滚轮反转和"禁用系统原生滚动"功能需要。在 系统设置 → 隐私与安全性 → 辅助功能 中授权

## 🛠️ 技术栈

- Swift + SwiftUI
- DDC/CI 协议（外接显示器控制）
- CoreAudio（系统音频控制）
- IOKit 私有 API（DDC/CI 显示器控制）

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📧 反馈

如有问题或建议，请发送邮件至：Ericcil@163.com

## 📄 许可证

MIT License

---

<p align="center">
  Made with ❤️ for macOS
</p>
