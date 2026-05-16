---
layout: ../layouts/BaseLayout.astro
title: 权限说明
description: Rolume permissions, accessibility access, DDC/CI display control, and first-run notes.
---

# 权限说明

Rolume 是一个本地运行的 macOS 菜单栏应用。它不会把你的设备信息上传到服务器，官网也不承担任何远程控制功能。

## 辅助功能权限

只有当你启用以下功能时，Rolume 才需要辅助功能权限：

- 鼠标滚轮反转
- 鼠标滚动拦截
- 触控板滑动拦截
- 按住修饰键滚动调节音量时需要全局拦截的场景

这些功能需要在系统层读取或拦截滚动事件，所以 macOS 会要求你在系统设置里授予 Accessibility 权限。

## DDC/CI 显示器控制

Rolume 通过 DDC/CI 尝试控制外接显示器音量。这个能力取决于显示器、线材、转接器、接口和 macOS 显示链路。

如果某台显示器无法控制，通常不是 Rolume 单独能完全修复的问题。你可以尝试：

- 确认显示器菜单中 DDC/CI 已开启
- 尝试直连而不是通过复杂扩展坞
- 更换线材或接口
- 在 GitHub Issues 中提供显示器型号和连接方式

## 首次运行提示

当前公开测试版尚未使用 Developer ID 签名和 notarization。首次运行时，macOS 可能会提示应用来自未验证开发者。

你可以在系统设置中手动允许打开。后续如果项目继续维护，签名和 notarization 可以作为单独阶段处理。
