# Flutter → HarmonyOS 功能对齐差距审计

## 1. 范围、方法与日期

- **审计日期**：2026-08-30。
- **范围**：RustDesk Flutter 客户端与当前 HarmonyOS ArkTS / HAR / Core 工作树，覆盖首页目标输入与设备目录、账户和地址簿、远控工具栏与输入、显示/画质/编解码、剪贴板/聊天/音频/隐私、文件传输、终端/隧道/录制、LAN 与设备操作、安全与提权。
- **方法**：合并所给分域审计，按用户可达路径去重；以当前源码及未提交差异为准，核对 Flutter UI → 绑定 → Core 与 ArkTS UI → HAR → Core 的完整调用链。README 不作为功能证据。
- **判定口径**：只有用户可达、状态/权限门控合理且调用真实原生能力时才算完成；Core/HAR 中存在但 ArkTS 无入口或无工作区，仍记为缺失或部分完成。
- **工作树保护**：本轮仅生成本文档；未修改、清理或回退现有 ArkTS/资源改动，未提交。

## 2. 本轮已完成并核实

1. **官网与隐私声明链接**：`SettingsTab.ets:30-31,165-188,789-792` 定义 RustDesk 官网和隐私声明 URL，点击后调用 `UIAbilityContext.openLink()`，失败时显示 Toast。不是静态文本。
2. **仅连接态的当前显示器手动刷新**：`SessionToolbar.ets:696-745` 提供“刷新画面”并按实测工具栏宽度切换布局；`RustDeskIndex.ets:7430-7438,7943-7950` 在启用和执行两处都要求 `sessionPhase === 'connected'`，随后调用 `NativeSessionBridge.refresh(activeSessionId, currentDisplay)`。此实现刷新**当前显示器**；未宣称 Flutter 全显示器模式的扇出行为。
3. **VP8 编解码首选项**：`SessionDefaultsCard.ets:203-235,604-637` 在宽/窄布局均提供 VP8；首选项经能力解析、持久化和 HAR/Core 会话路径应用。**VP8 只是可选项，不是默认值；默认仍为 `auto`。**

以上三项均为 `already-present`，不得再次列为差距。

## 3. 真实缺失/部分功能优先级矩阵

> 优先级含义：P0 为数据目标、安全或渲染正确性风险；P1 为主要 Flutter 能力缺口；P2 为体验、管理效率或较窄场景差距。难度/风险沿用审计结论；同一底层边界的重复项目已合并。

| 优先级 | 功能与状态 | Flutter 证据 | 当前 ArkTS/HAR/Core 状态 | 难度 / 风险 | 推荐下一边界 |
|---|---|---|---|---|---|
| P0 | **远端目录响应乱序保护（缺失）** | `file_model.dart:487-515` 用请求 generation 丢弃过期成功/错误响应 | `TransferManager.ets:102-107,411-438` 对后到的 `file_dir(id=0)` 无条件覆盖当前目录 | 低 / 高 | 先在 `TransferManager` 增加 generation + expected-path，成功与错误都校验；补快速进入/返回的乱序测试 |
| P0 | **运行中 H.264/H.265 解码器的 Surface 重建重绑（部分）** | Flutter 渲染器拥有纹理/RGBA 生命周期并在渲染变化时重建几何状态 | ArkTS 会重新存 Surface ID 并请求刷新，但 HAR 只更新查找表；既有 OH_AVCodec 解码器仍可能持有旧 NativeWindow | 高 / 高 | Core 定义显式 decoder surface rebind/reset 契约，经 HAR 暴露；验证旋转、窗口重建和 XComponent generation 变化 |
| P0 | **文件夹上传/下载、空目录保留（缺失）** | `file_model.dart:592-663` 以 `isDir` 建任务并递归创建空目录 | ArkTS 排除本地目录且仅下载文件；HAR 虽有 `isDir`，Core 当前丢弃；无递归/空目录路径 | 高 / 高 | 先统一 Core 目录任务语义、路径安全、冲突与取消，再扩 HAR，最后接 ArkTS 树/批量 UI |
| P0 | **文件项创建、重命名、删除（缺失）** | Flutter 移动/桌面文件管理器提供新建、重命名、确认删除及批量处理 | Core 有 create/remove/rename 原语，HAR 和 ArkTS 无公开绑定/交互 | 高 / 高 | 从 HAR 提供区分本地/远端的窄语义 API；删除必须有不可逆确认、递归边界和逐项错误 |
| P0 | **地址簿新增、编辑、删除（缺失）** | `address_book.dart:423-502` 与 `peer_card.dart:755-837,1142-1243` 支持字段、标签、备注、共享密码和权限门控 | 当前仅同步/列表；PeerCard、MainBridge、HAR 均无 mutation API | 高 / 高 | 先在 HAR 实现鉴权、共享簿权限和服务端 mutation，禁止在 ArkTS 近似处理密码/哈希；写后强制同步缓存 |
| P0 | **地址簿组织与权限：多簿、标签筛选/CRUD（部分）** | `address_book.dart:144-420,680-869` 提供簿切换、owner/rule、交并筛选和标签管理 | HAR 已取回书、GUID、标签/颜色；ArkTS 将其扁平化成单一 `addressBook`，无权限模型和管理 UI | 高 / 高 | 扩展缓存/schema 保留 profile/rule/owner；先做只读多簿与标签筛选，再在同一权限模型上开放写操作 |
| P0 | **双向语音通话/麦克风（缺失）** | `remote_page.dart:814-856`、`audio_input.dart:28-62` 支持请求/结束语音；Core 有通用入口 | OHOS Core 明确排除录音器；无 HAR API、ArkTS UI、麦克风权限 | 高 / 高 | 先实现 OHOS 音频采集与传输生命周期，再加瞬时授权、前后台/路由/关闭即停语义，最后接远控与摄像头会话 UI |
| P0 | **Windows 控制端提权请求（缺失）** | Flutter 按 Windows/SAS/键盘权限门控，支持远端用户确认或临时管理员凭据并等待 UAC | Core 有 direct/logon 协议；HAR/ArkTS 无导出、结果事件和 UI | 高 / 高 | 先定义无持久化、无日志的瞬时凭据边界及结果事件；再补严格平台/权限/会话门控和 UAC 等待态 |
| P1 | **本地目录浏览与目标选择（部分）** | Flutter 两侧完整 `FileController`，支持目录、面包屑、后退和父级 | ArkTS 固定一个 DOWNLOAD 根，仅列直接子文件，丢弃目录 | 高 / 中 | 在 `DownloadRootManager` 授权边界内建立可测试的本地路径模型，再开放子目录导航和会话内目标选择 |
| P1 | **多选、批量传输/删除与批量冲突策略（缺失/部分）** | Flutter 支持复选、全选、批量任务及“全部冲突采用此决定” | ArkTS 每侧仅一个选中名称；冲突仅逐项覆盖/跳过，`remember=false`，无提示内取消 | 中 / 中 | 先把选择和批次注册独立成模型；随后传递 `remember`、批量取消和批次级冲突策略 |
| P1 | **目录发现控件（部分）** | Flutter 有历史、面包屑/路径、home、刷新、搜索、排序、隐藏文件 | ArkTS 远端仅路径文本、上级和下载；`includeHidden=false` 固定 | 中 / 中 | 基于 generation-safe 目录模型逐步增加刷新、面包屑、搜索/排序/隐藏状态，避免先堆 UI |
| P1 | **原始/自适应/自定义画布视图样式（缺失）** | `model.dart:2355-2417` 提供 DPI-aware Original、Adaptive、Custom 与滚动/偏移语义 | ArkTS 仅 0.5–4.0 手势缩放/平移/旋转和 aspect-fit 坐标；无持久语义模式 | 高 / 中 | 在 `RustDeskViewportModel` 建立可测试的 view-style/scale/overflow 模型，再接设置与活动会话切换 |
| P1 | **实时编解码切换与协商态选项（缺失）** | `toolbar.dart:712-765` 展示 negotiated codec/alternatives 并触发 renegotiation | 默认设置可选编解码；活动 `QualityControlSheet` 无 codec，HAR 已具备活跃会话重协商 | 中 / 中 | 先暴露会话协商 codec 和 alternatives 状态，再在画质面板按能力列出选项并处理失败回滚 |
| P1 | **画质滑杆去抖与兼容门控（部分）** | Flutter 对质量/FPS 写入 1 秒去抖，并按 peer version/public server 门控 | ArkTS 范围和调用完整，但每次滑杆事件立即发命令，缺少兼容门控 | 低 / 中 | 在 display controller 上层加入尾触发去抖和 peer capability gate；保持最终值可见且可取消 |
| P1 | **远程终端（部分）** | Peer action 可创建 terminal；`terminal_model.dart` 提供 open/input/resize/close | HAR/Core 能识别 terminal 会话且 Core 有协议，ArkTS 无启动标志、typed API、事件消费和终端表面 | 高 / 高 | 先完善 HAR 终端 API/事件契约，再实现独立终端 controller 与 ArkUI 终端组件，避免塞入主页面 |
| P1 | **TCP 隧道/本地端口转发（部分）** | Flutter peer/toolbar 可创建和管理 port forward | HAR 解析标志，但 OHOS Core 的 listener/dispatch 被 cfg 排除；ArkTS 无管理 UI | 高 / 高 | 先设计 OHOS 安全 listener、后台与端口生命周期并恢复 Core 支持；再加 HAR 状态/增删接口和 ArkTS 管理页 |
| P1 | **会话录制（部分）** | Flutter 移动/桌面工具栏调用 `sessionRecordScreen`；Core 按 codec 选择 WebM/MP4 | Core 录制引擎存在，HAR/ArkTS 无 record/status；存储、短损坏文件与 codec 切换未验证 | 中 / 中 | 先暴露 record/status/error，并确定 app-private/导出存储与 stop-on-close；随后补权限、状态 UI 和容器验证 |
| P1 | **重启、锁屏、Ctrl+Alt+Del（缺失）** | Flutter 按平台/权限/SAS 门控；重启有确认 | Core 有语义方法，HAR/ArkTS 无明确导出和工具栏动作 | 中 / 中–高 | 提供窄语义 HAR 包装，禁止模拟任意按键；复用 peer capability/keyboard/view-only 门控，重启必须确认并处理断连 |
| P1 | **阻止远端输入、断开后锁定（部分）** | Flutter 提供 Windows-only block/unblock 与 lock-after-session-end | generic toggle/peer option 已贯通 Core，但 ArkTS 无状态、平台与权限门控 | 中 / 高 | 先把已知 option 映射成 typed capability/state，分别实现 Windows block-input 和非 Android 断开锁定，避免通用开关面板 |
| P1 | **My Group / 可访问用户与设备组（缺失）** | `my_group.dart` / `group_model.dart` 请求 accessible users/device-groups/peers | ArkTS 目录仅 recent/addressBook/lan；HAR 无 group listing API | 高 / 中 | 在 HAR 建分页、鉴权、错误明确的 group 模型，再增加独立目录 source 和筛选 UI；不要与共享地址簿混同 |
| P1 | **高级首页/Peer 启动动作（部分）** | Flutter 有 terminal、tunnel、WOL、rename、relay、add-to-address-book 等 | ArkTS 首页仅控制、观看、摄像头、文件；Core/HAR 对部分模式已有底座但无对应工作区 | 高 / 中 | 按能力分别交付，先做低耦合 peer action，再做需要独立工作区的 terminal/tunnel；不要做无功能入口 |
| P2 | **独立 Favorites 目录（部分）** | Flutter 有 `PeerTabIndex.fav` 和 `FavoritePeersView` | 收藏加载/切换已完成，但仅在 recent/addressBook/lan 内置顶，无聚合页 | 低 / 低 | 增加只读派生 `favorites` source，复用现有 PeerCard 与 favorite persistence |
| P2 | **远端系统音频真实状态（部分）** | Core OHOS 音频输出记录真实 active/error | HAR 只要有 session 就合成 `available=true`、`rendererActive=!muted`，掩盖初始化失败 | 中 / 中 | HAR 读取 Core `ohos_audio::status`，与 mute 状态组合；ArkTS 区分不可用、启动中、活动和错误 |
| P2 | **富文本剪贴板的本地 HTML 发送（部分）** | Android Flutter 同步 Text 与 Html 两种格式 | ArkTS 能检测 HTML，却 `toPlainText()` 后仅发送 Text；图像、文件及接收侧较完整 | 中 / 中 | 给 HAR 增加明确 HTML 发送类型并保留 plain fallback；保持现有权限、会话、大小和生命周期门控 |
| P2 | **Android 音量/电源动作（部分）** | Flutter Android peer 菜单含 Back/Home/Apps/Volume±/Power，并按版本/权限门控 | ArkTS 已有 Back/Home/Recent 及 fallback/长按，缺 Volume±/Power | 低 / 中 | 复用 session key-event，沿用现有 Android、版本、键盘权限门控并补 payload 测试 |
| P2 | **WOL、持久 relay、peer alias（缺失/部分）** | Flutter peer card 调用 `mainWol`、持久 `force-always-relay`、`mainSetPeerAlias` | Core 已有 WOL/alias/peer option；ArkTS/HAR 目录接口未暴露。一次性 `forceRelay` 不等于持久设置 | 低 / 低–中 | 在 HAR 提供窄 getter/setter/WOL；PeerCard 增加明确动作、异步结果与失败回滚 |
| P2 | **活动/已保存 peer options（部分）** | Flutter 提供 cursor、clipboard、lock、privacy、i444、follow-window 等受门控选项 | ArkTS 已有音频、clipboard 默认、质量、codec、view-only；generic options 可用但多数 UI/状态缺失 | 中 / 中 | 建 typed option registry 与 capability dependency；优先 clipboard/lock/cursor，privacy mode 单独做安全设计 |

## 4. 有意延期

### 将剪贴板文本作为远端按键输入

分类：**`intentional-defer`，中等难度，高风险**。

Flutter 的 `toolbar.dart:240-328,375-407` 并非简单调用 `sessionInputString`：对 Wayland peer，它包含明确警告、同意范围、可记忆选择、当前连接输入抑制及撤销/重置语义。ArkTS/HAR 虽已有 `NativeSessionBridge.inputString()` / `sessionInputString` 原语，但当前没有 Wayland 判别、`allow-wayland-keyboard` 同意状态、每连接抑制/重置或等价的 keyboard-input-allowed gate。

因此继续延期，直到 Wayland 同意语义能够端到端复现。不得因为底层原语存在就增加读取本地剪贴板并注入远端键盘的快捷按钮。

## 5. 平台不适用与明确非差距

- **RDP convenience mode：`platform-not-applicable`**。Flutter 该入口是桌面 RDP 客户端便利层，依赖 port forwarding；Core 对 OHOS 明确排除对应分支。除非未来另行设计 HarmonyOS RDP 客户端集成，否则不应声称直接 RDP 对齐。TCP tunneling 仍是独立真实差距。
- **HarmonyOS 被控端“接受并提权”：`platform-not-applicable`**。该功能属于 Windows portable host/UAC；HarmonyOS 被控模式按当前设计为观看/受限权限。它不影响 HarmonyOS 作为控制端向 Windows 请求提权。
- **Windows 桌面快捷方式/窗口管理特性**不计入移动 HarmonyOS 差距。
- **官网/隐私链接、连接态当前显示器刷新、VP8 可选项**为本轮已完成项；再次强调默认 codec 仍是 `auto`。
- **设备目录消息横幅方案已拒绝**：它没有闭合文件传输目录错误对齐。文件传输错误发生在独立 transfer workspace、异步目录请求及目标路径状态中；在设备目录增加 banner 既不能阻止过期响应覆盖，也不能保证错误归属当前目录/请求，更不能修复后续上传下载指向错误目录的问题。正确边界是 `TransferManager` 的请求 generation/expected-path、错误归属与传输工作区内反馈。

## 6. 已存在的主要能力

以下能力已有真实 UI/状态/原生调用链，应防止在后续规划中被误报为缺失：

- 账户密码登录、邮箱码/TOTP 验证、OIDC、身份显示、地址簿同步和注销。
- 地址簿只读同步/搜索浏览；收藏切换与最近设备删除。
- LAN 扫描和列表。
- 远控指针、物理键盘、软键盘、系统 IME，含 view-only/会话状态门控。
- 独立文件传输会话模式及单文件上传、下载、取消、逐项覆盖/跳过。
- 独立 view-camera 会话。
- 会话文本聊天：接收、未读、发送状态、失败重试和原生传输。
- 剪贴板纯文本、PNG 图像和文件双向流程，以及前台、权限、会话类型和 view-only 隐私门控。
- 远端系统音频播放与静音控制（仅“真实 renderer 状态”仍为部分差距）。
- 画质预设、自定义质量/FPS 的功能调用链。
- H.264/H.265 硬件 Surface 渲染，以及 VP8/VP9/AV1 软件 RGBA/PixelMap fallback。
- 不安全传输显式同意、challenge-bound 2FA 和 trusted-device 查询流程。
- AppGallery 隐私协议门控的 motion sensor 生命周期：默认关闭、同意后启用、撤销/后台停用。

## 7. 验证与限制

### 已执行

- 检查 `pwd`、`git status -sb`、`git diff --check`、最近 5 条提交及当前日期。
- 阅读当前未提交差异，确认四个既有 ArkTS 源文件和一个资源文件包含官网/隐私、connected guard 刷新和 VP8 选择器改动。
- 通过当前源码索引复核关键调用链与文件传输目录状态；确认目标文档此前不存在。
- 使用 Java 17、HarmonyOS API 23 工具链完成 `assembleApp product=default buildMode=debug` 签名构建。
- 在 `192.168.108.106:36237` 覆盖安装并验证：Resk 版本/关于页、官网浏览器跳转、VP8 紧凑网格及选中状态；安装包为 debug provision。
- 审计写作阶段未修改 HAR、Core 或 Flutter 源码；文档和本轮 ArkTS/资源改动尚未提交。

### 限制

- 未执行 ohosTest、Surface 重建、音频 renderer、文件传输竞态或网络服务端 mutation 验证。
- 远控会话启动后 Wi-Fi HDC 端口出现间歇掉线，刷新按钮的连接态展示与点击结果未完成截图闭环；当前确认范围是源码调用链、connected 双门禁、编译及其他真机页面交互。
- Flutter 证据和跨仓路径来自所给审计并做去重；本轮重点复核当前 ArkTS 未提交变化及高风险边界，不能替代后续逐项实现时对 Core/HAR 最新接口、服务端版本和真机行为的再次验证。
- `already-present` 表示当前源码存在完整或实质调用链，不等于所有设备、服务端版本和异常分支均已完成真机验收。
