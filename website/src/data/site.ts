export const SITE = {
  name: "Rolume",
  title: "Rolume - 滚动调节 macOS 音量",
  description:
    "Rolume 是一款轻量 macOS 菜单栏工具，用鼠标滚轮、触控板滑动或修饰键快速调节当前声音输出。",
  repositoryUrl: "https://github.com/ericcilcn/Rolume",
  releasesUrl: "https://github.com/ericcilcn/Rolume/releases",
  downloadUrl: "https://github.com/ericcilcn/Rolume/releases/latest/download/Rolume.dmg",
  issueUrl: "https://github.com/ericcilcn/Rolume/issues",
  email: "Ericcil@163.com",
  version: "1.1",
  sha256: "371257a69d585e51b78d425961d14f6df6545fc6954b23cddaf398e2bd62aa63",
};

export const FEATURES = [
  {
    title: "系统与显示器音量",
    description:
      "在一个菜单栏工具里控制系统音频和支持 DDC/CI 的外接显示器音量。",
    accent: "blue",
  },
  {
    title: "滚轮与触控板控制",
    description:
      "在 Dock、菜单栏或按住修饰键时滚动调节音量，鼠标和触控板独立设置。",
    accent: "green",
  },
  {
    title: "鼠标滚动反转",
    description:
      "独立反转鼠标滚轮方向，不影响触控板，并支持为特定 App 设置排除列表。",
    accent: "orange",
  },
  {
    title: "开源且轻量",
    description:
      "Swift 和 SwiftUI 编写，菜单栏常驻；代码、发布包和更新记录都放在 GitHub 上。",
    accent: "ink",
  },
];

export const HIGHLIGHTS = [
  {
    title: "滚动调音量",
    description: "在菜单栏、Dock 区域，或按住修饰键时滚动调节。",
    accent: "blue",
  },
  {
    title: "设备跟随输出",
    description: "MacBook、耳机、AirPlay、外接显示器，都从当前输出开始。",
    accent: "green",
  },
  {
    title: "鼠标触控板分开",
    description: "鼠标可以更直接，触控板可以更克制。",
    accent: "ink",
  },
  {
    title: "鼠标单独反转",
    description: "只反转鼠标滚轮方向，不影响触控板自然滚动。",
    accent: "orange",
  },
];

export const PERMISSIONS = [
  "大部分音量控制不需要额外权限，只有启用鼠标滚轮反转、滚动拦截或滑动拦截时，才需要辅助功能权限。",
  "当你开启相关功能时，Rolume 使用 macOS 原生权限提示。授权完成后，重新打开 App 可以让事件拦截逻辑可靠生效。",
  "DDC/CI 控制取决于显示器、线材、转接器和 macOS 显示链路；Rolume 会在可用时尽量保持菜单栏、滑条和 OSD 同步。",
];
