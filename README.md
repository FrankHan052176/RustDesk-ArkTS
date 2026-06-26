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

## 🧭 功能适配情况

> 这里的“未落地”不是“想做却没做成”，而是基于当前 HarmonyOS 客户端定位和平台安全策略的主动裁剪。摄像头、被控端、文件传输、语音通话等高风险功能均未纳入，重点保障应用不会被用于诈骗、灰产、隐私侵犯或非法入侵场景。

## 🧱 T0 / T1 / T2 功能分级说明

本项目的适配能力按远控客户端使用场景分为三档：

- T0：远控主流程能力，确保应用可构建、安装、启动、连接远端并展示画面
- T1：日常远控核心能力，覆盖输入映射、分辨率适配、会话状态、运行统计、连接偏好等
- T2：平台增强与安全选择，体现 HarmonyOS 原生交互与高风险功能裁剪

### T0 基础能力（远控主流程）

| 能力 | 状态 | 说明 |
|------|------|------|
| HAP 构建 | ✅ 已支持 | `entry` 模块可通过 Hvigor / DevEco 构建 HAP 包 |
| 启动与主界面 | ✅ 已支持 | 真机安装后可正常启动并进入主界面 |
| 远端目标连接 | ✅ 已支持 | 支持输入目标地址、ID、Server 并发起连接 |
| 密码验证 | ✅ 已支持 | 支持密码输入、记住密码与身份验证流程 |
| 远端画面渲染 | ✅ 已支持 | 远端视频流通过原生 `XComponent` 渲染成画面 |

小结：T0 这一层侧重“能用”的基础远控流程，当前项目已覆盖客户端启动、连接、认证与画面展示。

### T1 核心能力（日常远控）

| 能力 | 状态 | 说明 |
|------|------|------|
| 键鼠与手势输入 | ✅ 已支持 | 支持多种输入事件与坐标映射 |
| 分辨率适配 | ✅ 已支持 | 处理远端分辨率与本地显示区域的坐标转换 |
| 远端光标 | ✅ 已支持 | 支持远端光标显示与位置同步 |
| 会话状态监控 | ✅ 已支持 | 轮询远端事件并实时更新连接状态 |
| 运行统计 | ✅ 已支持 | 展示 FPS、延迟、编解码器等指标 |
| 连接偏好 | ✅ 已支持 | 支持保存目标、密码、记住密码等设置 |
| 性能调优 | ✅ 已支持 | 支持 codec 和图像质量调优 |

小结：T1 层覆盖远控日常核心能力，当前项目已实现会话管理与交互控制的完整体验。

### T2 增强能力（平台体验与安全取舍）

| 能力 | 状态 | 说明 |
|------|------|------|
| 全屏预览 | ✅ 已支持 | 切换到预览模式后可进入横屏全屏显示 |
| HarmonyOS 原生适配 | ✅ 已支持 | 使用 ArkTS、ArkUI、原生窗口与 XComponent 集成 |
| 摄像头接入 | ❌ 未落地 | 当前版本不提供摄像头或视频采集能力 |
| 文件传输 | ❌ 未落地 | 当前版本不支持文件传输 |
| 语音通话 | ❌ 未落地 | 当前版本未引入语音通话能力 |
| 被控端能力 | ❌ 未落地 | 仅实现客户端远控终端，不包含被控端部署 |
| 平台交互取舍 | ✅ 已支持 | 未盲目照搬桌面交互，而是保持 HarmonyOS 原生体验 |

小结：T2 层强调平台增强与安全取舍，项目当前已实现全屏预览并主动回避易滥用的高风险能力。

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
