# RustDesk HarmonyOS NEXT

> 基于 HarmonyOS 原生壳工程 + RustDesk Rust 内核 HAR 的跨端远程控制客户端

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-6.0.2%20(API%2022)-8A2BE2)](https://developer.harmonyos.com)
[![ArkTS](https://img.shields.io/badge/ArkTS-Native-blue)](https://developer.harmonyos.com)
[![RustDesk Core](https://img.shields.io/badge/RustDesk-Rust%20HAR-green)](https://github.com/rustdesk/rustdesk)
[![License](https://img.shields.io/badge/License-AGPL--3.0-yellow)](#许可证)

## 📖 项目简介

本项目采用 **HarmonyOS 原生壳工程 + RustDesk Rust 内核 HAR** 的混合架构：

- **HarmonyOS 壳工程**：使用 ArkTS、ArkUI 和 HarmonyOS SDK 构建完整客户端界面，负责连接管理、输入映射、渲染控制、系统权限和设备适配
- **RustDesk 内核层**：通过 `rustdesk-ohrs` HAR 集成 Rust 原生核心，提供 RustDesk 协议处理、编解码桥接、数据同步与远程控制能力
- **渲染与输入**：通过 `XComponent` 接入系统原生渲染表面，并结合精密的手势与键盘映射算法，在鸿蒙设备上提供流畅的远控体验

这种架构让 RustDesk 的高性能 Rust 内核能够以原生 HAR 形式嵌入鸿蒙应用，同时让 UI、交互、权限和系统深度集成完全走 HarmonyOS 原生能力。

## 🏗️ 项目结构

```bash
rustdesk_arkts_app/
│
├── AppScope/                         # 应用级配置（包名、图标、版本）
│   ├── app.json5                     # 应用元信息 (bundleName = top.frankhan.resk)
│   └── resources/
│       └── base/
│           ├── element/              # 应用级字符串资源
│           └── media/                # 应用图标 (app_icon.svg)
│
├── entry/                            # 鸿蒙模块：RustDesk 客户端入口
│   ├── src/main/ets/
│   │   ├── entryability/             # Ability 扩展入口
│   │   │   └── EntryAbility.ets      # 主 UIAbility，应用启动与生命周期
│   │   │
│   │   ├── pages/                    # 页面入口
│   │   │   ├── RustDeskIndex.ets     # 首页（连接控制台）
│   │   │   └── rustdesk/             # RustDesk 业务逻辑
│   │   │       ├── components/       # ArkUI 组件（连接页、设置页、状态页、弹窗）
│   │   │       ├── RustDeskInputMapper.ets      # 输入映射（键盘、鼠标、触摸手势映射）
│   │   │       ├── RustDeskPreferences.ets      # 配置持久化与偏好设置
│   │   │       ├── RustDeskSurfaceController.ets # XComponent 渲染表面控制器
│   │   │       └── RustDeskTypes.ets            # 内核桥接类型与常量定义
│   │   │
│   │   └── resources/                # 模块资源
│   │       ├── base/
│   │       │   ├── element/          # 字符串、颜色、资源定义
│   │       │   ├── media/            # 图标与媒体资源
│   │       │   └── profile/          # 页面路由与权限配置
│   │
│   ├── build-profile.json5           # 模块构建配置
│   ├── hvigorfile.ts                 # 模块构建脚本
│   └── oh-package.json5              # 模块依赖配置
│
├── package.har                       # RustDesk Rust 内核 HAR（项目内本地依赖）
├── hvigor/                           # Hvigor 配置
│   └── hvigor-config.json5
├── build-profile.json5               # 应用产品、SDK 和模块定义
├── hvigorfile.ts                     # 应用构建脚本入口
├── oh-package.json5                  # 项目级 ohpm 依赖
└── README.md
```

## ✨ 核心功能

| 功能 | 说明 |
|------|------|
| 🖥️ **远端桌面连接** | 通过 Rust 内核发起 RustDesk 协议连接，支持 ID 与密码验证 |
| ⚡ **原生视频渲染** | 使用 `XComponent` 结合 Rust 内核实现高性能视频流渲染 |
| ⌨️ **精密输入映射** | 支持物理键盘、鼠标以及触控板手势（单击、双击、长按、滚动）映射 |
| 📱 **多分辨率适配** | 自动处理远端分辨率与本地显示区域的坐标转换（Canvas/Screen/Window） |
| 📊 **实时运行统计** | 展示 FPS、延迟、帧耗时及已渲染帧数等性能指标 |
| 🔧 **编解码能力检测** | 自动识别系统硬件与软件解码器能力（H.264/H.265/VP9 等） |
| 💾 **连接偏好管理** | 支持保存历史连接目标、密码记录及记住密码功能 |
| 🎨 **HDS 原生视觉** | 采用 HarmonyOS Design System 视觉规范与动效体系 |

## 🚀 构建与运行

### 环境要求

| 工具 | 版本 |
|------|------|
| DevEco Studio | 建议使用当前最新版 |
| HarmonyOS SDK | target `6.0.2(22)` |
| ohpm / hvigor | 使用 DevEco Studio 随附版本 |
| RustDesk 内核 HAR | `package.har` |

### 安装依赖

```bash
# 在项目根目录执行
ohpm install
```

当前项目级依赖中，RustDesk 内核使用项目内本地 HAR：

```json5
"rustdesk-ohrs": "file:package.har"
```

### 构建 HAP 包

```bash
# 在工程根目录执行
hvigorw --mode module -p module=entry@default assembleHap

# 产物路径
entry/build/default/outputs/default/entry-default-signed.hap
```

也可以在 DevEco Studio 中打开项目，执行 `Build → Build Hap(s)`。

### 真机测试

1. 连接 HarmonyOS NEXT 设备或启动模拟器
2. 在 DevEco Studio 中选择 `entry` 模块运行
3. 输入远端设备 ID 和密码即可开始远程控制

```bash
hdc install entry/build/default/outputs/default/entry-default-signed.hap
```

## 🧩 RustDesk 内核 HAR 开发说明

### 内核集成

本项目通过 `rustdesk-ohrs` 模块集成 Rust 核心逻辑。内核 HAR 文件通常位于项目根目录：

```bash
rustdesk_arkts_app/package.har
```

### 开发流程

1. **修改 ArkTS 代码**：在 `entry/src/main/ets/` 下开发 UI、交互和业务逻辑
2. **更新内核接口**：如 Rust 层接口有变动，需替换 `package.har` 并重新执行 `ohpm install`
3. **调试渲染**：重点关注 `RustDeskSurfaceController` 与 Rust 层的交互，确保 SurfaceId 正确传递

## 📄 许可证

本项目基于 **AGPL-3.0 License** 开源。RustDesk 内核和相关依赖遵循各自上游许可证。
