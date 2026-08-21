# HarmonyOS 2in1 被控端能力落地与方案审计

## 1. 审计结论

### 1.1 一句话结论

**技术上可以推进“用户在场授权的 2in1 被控端 MVP”，但当前仓库并没有被控端实现，不能在现状上直接宣称支持；“API 23 上静默、开机自启、锁屏后仍可完整控制的无人值守被控端”目前不具备可交付证据，应作为条件性 No-Go。**

### 1.2 审计判定

| 目标 | 判定 | 说明 |
|---|---|---|
| 2in1 单屏、用户在场确认、视频被控 | 条件可行 | C/C++ AVScreenCapture 支持原始码流和 Surface 方式，适合远程桌面，但仓库未实现 |
| 2in1 用户授权后的键鼠/触控控制 | 条件可行，必须先 PoC | API 20 起 NDK 提供注入授权与注入接口，仅 PC/2in1 生效；目标固件行为必须实测 |
| API 23 ArkTS 直接注入 | 不可采用 | ArkTS inputEventClient 与 CONTROL_DEVICE 均从 API 26.0.0 起提供，当前工程 target API 23 |
| 免除每次录屏隐私告警 | 受限可行，但不等于全流程静默 | API 22 起 PC/2in1 可申请 CUSTOM_SCREEN_RECORDING；它是受限开放、手动设置授权，需 AGC 审核，且不自动取消 Picker、用户停止入口或其他授权 |
| 无人值守完整控制 | 当前不通过 | 输入授权、录屏隐私提示、后台保活、开机启动、锁屏安全界面均未形成可验证闭环 |
| 当前仓库“被控端已落地” | 不通过 | README 明确未落地；HAR、ArkTS bridge、manifest、测试均无 host/server 能力闭环 |

### 1.3 当前成熟度

当前应用的**可达代码与产品闭环是主控/客户端（controller/client）**，尚不是可运行的**本机被控端（host/controlled endpoint）**。闭源 HAR 二进制是否包含未导出的 host 代码无法仅靠类型声明断言；成熟度建议评为：

- 主控端：已有完整连接、渲染、输入发送与文件传输链路。
- 被控端：**M0（需求/技术预研阶段）**。
- 不应把 sessionSendMouse、sessionInputKey、INTERCEPT_INPUT_EVENT 或 runtimeGetServerConfig 误认成被控端能力：前两者是向远端发送控制事件，拦截权限用于采集本地主控输入，ServerConfig 是 RustDesk rendezvous/relay 配置，不是本机监听并接受控制的 host server。

---

## 2. 审计范围与证据基线

### 2.1 仓库证据

1. README.md:3 将项目定义为“跨端远程控制客户端”。
2. README.md:80 说明摄像头、被控端等高风险功能未纳入；README.md:125 明确“仅实现客户端远控终端，不包含被控端部署”。
3. entry/src/main/module.json5:7-11 已声明 2in1 设备类型，但这只代表可安装设备范围，不代表被控能力。
4. entry/src/main/module.json5:34-36 仅声明 dataTransfer 后台模式。
5. entry/src/main/module.json5:75-106 当前仅有 KEEP_BACKGROUND_RUNNING、INTERNET、READ_PASTEBOARD、INTERCEPT_INPUT_EVENT；没有录屏、录音或被控输入注入相关声明。
6. rustdesk-ohrs 的 libs/index.d.ts 以主控会话接口为主，也包含 mainGetMyId、mainGetTemporaryPassword、mainIsCanScreenRecording 等 host-adjacent/common 声明；但静态检索未发现 hostStart/hostStop/hostAccept、AVScreenCapture、input injection 或被控帧入口，因此无法形成被控端闭环，也不能据此断言闭源 HAR 内完全没有 host 代码。
7. entry/src/main/ets/pages/rustdesk/NativeSessionBridge.ets:9-37 的接口全部围绕主控会话、远端目录、向远端发送输入与剪贴板。
8. entry/src/main/ets/services/DataTransferBackgroundService.ets:143-145 固定申请 dataTransfer 长时任务；378-380 又把普通远控会话也视为应保活会话，不能直接复用为录屏被控端后台方案。
9. DataTransferBackgroundService.ets:296-307 在没有文件传输时用周期性心跳进度更新通知；官方长时任务会校验实际业务类型和负载，不能把“更新进度”当作合法保活依据。
10. RustDeskPreferences.ets:61-84,162-174 已主动清除历史明文密码且不持久化客户端连接密码；被控端若增加无人值守凭据，不得退回普通 Preferences 明文存储。
11. entry/src/main/module.json5:65-73 的 StatusBarBackgroundAbility 被标记为 exported；被控端引入更多跨进程入口前应缩小导出面并增加调用方校验。
12. entry/src/ohosTest/ets/test/List.test.ets:1-13 注册 13 组业务测试，但没有被控端测试；BackgroundTaskState.test.ets:2 引用了当前工作树中不存在的 services/BackgroundTaskState，说明 ohosTest 基线本身需要先修复或确认。
13. build-profile.json5:6-7,18-19 当前实际 target/compatible SDK 是 6.1.0(API 23)，而 README.md:5,137 仍写 API 22，文档已漂移。
14. 最近留存的默认构建报告 .hvigor/report/report-202608172257505010.json 显示 default HAP 构建成功，但不能证明 ohosTest、真机录屏、输入注入或后台能力通过；当前 shell PATH 没有 hvigor/hdc，故本次未执行新构建或真机测试。
15. README.md:123 仍称文件传输未落地，但当前代码已有 TransferManager、文件桥接和后台服务，说明 README 存在漂移；因此“被控端未闭环”的主证据是当前可达代码、manifest、bridge 和测试，README 只作辅助证据。

### 2.2 HarmonyOS 官方能力证据

以下引用均为华为开发者官方文档：

- [AVScreenCapture 屏幕录制（C/C++）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avscreencapture-screen-recording-c)：C/C++ 支持文件和原始码流两种形式，原始码流方案适合直播、远程桌面；支持 OH_ORIGINAL_STREAM 和 OH_AVScreenCapture_StartScreenCaptureWithSurface。
- [AVScreenCapture 屏幕录制（ArkTS）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avscreencapture-screen-recording-arkts)：ArkTS 录屏只支持文件输出，无法获取原始码流，实时性不适合延迟敏感场景。
- [窗口级录屏](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/using-avscreencapture-for-file-with-window)：API 20 起 PC/2in1 支持录屏 Picker；API 22 起 PC/2in1 可使用 TIMEOUT_SCREENOFF_DISABLE_LOCK；CUSTOM_SCREEN_RECORDING 可取消每次隐私告警，但属于受限权限。
- [AVScreenCapture 自定义场景](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/avscreencapture-c-custom-scenarios)：API 20 起支持跟随旋转，API 14 起可设置最大帧率，启动后可 ResizeCanvas，但分辨率受编码能力范围限制。
- [视频编码](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/video-encoding)：视频编码支持 Surface 与 Buffer 两种输入；Surface 适合屏幕录制直接对接，运行中可动态请求 IDR、调整码率和帧率。
- [输入事件注入 NDK](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/capi-oh-input-manager-h)：API 20 起 OH_Input_RequestInjection、OH_Input_QueryAuthorizedStatus 仅在 PC/2in1 生效；按键、鼠标、触控注入及全局坐标注入均有明确接口。
- [ArkTS 输入事件注入](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/api/js-apis-inputeventclient)：从 API 26.0.0 起，要求 CONTROL_DEVICE，仅 PC/2in1 支持。
- [受限开放权限](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/restricted-permissions)：CUSTOM_SCREEN_RECORDING 从 API 22 起支持 PC/2in1；CONTROL_DEVICE 从 API 26.0.0 起面向远程登录器被控端开放，两者均为 system_basic、manual_settings。
- [申请受限权限](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/declare-permissions-in-acl)：受限权限需在 AGC 申请 Profile、提交场景说明和视频；未获证书却声明可能导致安装失败或上架被驳回。
- [长时任务](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/continuous-task)：录屏可使用 audioRecording；音视频播放、录制或通话也可按实际场景使用 avPlaybackAndRecord。dataTransfer 面向非托管上传或下载，taskKeeping 面向计算任务。系统会校验实际业务、负载和通知，用户删除通知会停止任务。

> 版本注意：官方在线文档已包含 API 26.0.0 能力，而仓库当前 target API 23。设计必须同时标明“当前 API 23 路径”和“未来 API 26 路径”，不能混用接口。

---

## 3. 难点与风险分级

### 3.1 P0：不关闭就不能立项或承诺交付

#### P0-1：当前不是“补齐一个开关”，而是新增完整 host 产品面

**证据**：README 明确裁剪被控端；ArkTS bridge、HAR 类型声明和测试没有 host 生命周期。

**影响**：需要同时新增协议服务、会话准入、采集、编码、输入注入、后台任务、安全状态和真机测试；不能按普通 UI 功能估算。

**关闭条件**：

- Native HAR 至少提供 hostStart、hostStop、hostPollEvents、hostAccept、hostReject。
- 能注册 RustDesk ID，经过 hbbs/hbbr 接受来自标准 RustDesk 主控端的连接。
- 断网重连、拒绝、超时、进程退出均能回收采集、编码、注入和按键状态。

#### P0-2：RustDesk host 核心与 Harmony 采集/编码之间没有合同

官方文档证明 AVScreenCapture 可通过 Surface 与视频编码器直接对接，且 Surface 模式适合屏幕录制；本审计将其作为优先验证的低拷贝路径。现有 HAR 没有可达的 host 闭环。RustDesk host 需要知道编码类型、SPS/PPS/VPS、关键帧、时间戳、分辨率变化和拥塞反馈。

若直接把系统 H.264 码流塞入 RustDesk 协议，可能在 packetization、关键帧、色彩格式或码率控制上不兼容；若先取 RGBA/YUV 再交给 RustDesk 原编码器，可能引入多次拷贝和高 CPU。

**关闭条件**：在 PoC 中二选一并量化：

1. **外部编码帧适配器（优先性能）**：AVScreenCapture → encoder Surface → H.264/H.265 packet → RustDesk host codec adapter。
2. **原始帧提供器（优先协议复用）**：AVScreenCapture Buffer → 像素转换和 stride 处理 → RustDesk 既有编码链路。

必须用标准 RustDesk 主控端连续解码 30 分钟，并验证首帧、IDR 请求、动态码率、旋转、分辨率变化和重连。

#### P0-3：API 23 输入注入的可用性与授权语义存在版本门槛

**已证实**：

- ArkTS inputEventClient 和 CONTROL_DEVICE 是 API 26.0.0 路径，当前 API 23 不能采用。
- NDK OH_Input_RequestInjection 从 API 20 起仅 PC/2in1 生效，可查询 AUTHORIZED 状态；全局鼠标和触控注入从 API 20 起提供。
- 官方当前接口页同时保留“需要 CONTROL_DEVICE”的新版本注解与“API 20 起先请求用户授权”的兼容说明，目标 API 23 必须按对应 SDK 头文件和实际固件验证。

授权可能要求本机用户操作、可能被其他应用占用、可能在重启、注销或睡眠后失效；这直接决定是否只能做“有人值守”。

**关闭条件**：API 23 真机 PoC 覆盖键盘、修饰键、IME、鼠标绝对和相对移动、滚轮、触控、多点、授权拒绝和撤销、其他应用占用、应用退后台、睡眠恢复、外接屏和锁屏。

#### P0-4：静默录屏与无人值守不是默认能力

普通录屏会出现系统 Picker 或隐私告警和可停止胶囊；用户可以主动停止。API 22 起 CUSTOM_SCREEN_RECORDING 的官方效果是“不再每次弹出隐私告警”，并不自动取消 Picker、共享内容选择或用户停止入口。该权限属于受限权限、手动设置授权且需 AGC 审核；共享本设备桌面属于官方列出的申请场景，但不代表一定获批。

没有该权限时，不能把远端无人到场时自动采集作为承诺；即使权限获批，也不能自动推导出输入注入、开机启动和锁屏控制均可用。

产品需求必须分轨：

- Attended：每次会话本机确认录屏和控制，MVP 可接受。
- Unattended：只有在 AGC、系统设置、输入注入、启动策略和锁屏边界全部获得书面或实机证据后才能承诺。

### 3.2 P1：可开发，但不解决会导致不稳定或安全事故

#### P1-1：后台模式与现有保活实现不匹配

当前只声明 dataTransfer，而屏幕录制应按实际场景申请 audioRecording，或在确有音视频播放、录制、通话组合时使用 avPlaybackAndRecord。taskKeeping 官方定位为计算任务，不能用于空闲监听或通用保活；dataTransfer 面向非托管上传或下载，也不能因为远控存在网络流量就自动套用。现有“没有文件传输时递增心跳进度”的策略不得复制到被控端。

建议：

- 空闲等待连接：不得用 taskKeeping 或伪进度通用保活；只能采用平台明确允许且与真实业务一致的 PC 生命周期机制，并以目标机和上架审核结果为准。
- 活跃会话：录屏使用 audioRecording；若同时存在符合定义的音视频播放、录制或通话可评估 avPlaybackAndRecord；只有真实符合非托管上传或下载语义时才申请 dataTransfer。
- 收到 continuousTaskCancel、用户停止录屏、授权撤销时，建议目标是在 1 秒内 fail-closed：停止发帧、释放输入、关闭会话。

#### P1-2：零拷贝、背压和热稳定性

不能把持续帧通过 ArkTS Uint8Array 轮询。推荐 Surface 到硬件编码器，编码回调只在 Native 内完成 packetization 和网络发送。

必须设计：

- 输出队列上限 2 帧；拥塞时丢旧帧，不无限堆积。
- 编码输出 buffer 使用后立即释放。
- 网络抖动触发动态码率和 FPS，严重丢包请求 IDR。
- 旋转或分辨率变化时先冻结输入映射，完成 encoder 和协议更新后再恢复。
- 编码器 Error、Flush、Reset、Destroy 不能在错误回调内死锁调用。

#### P1-3：输入状态机容易造成卡键和误操作

远端事件必须维护 pressedKeys、pressedButtons 和 touch pointer ledger；断连、切屏、失焦、授权撤销、进程后台或异常退出时统一 releaseAll。修饰键 DOWN 后必须保证 UP，重复 DOWN 或孤立 UP 要去重或拒绝。

禁止仅做“键码直译”：需要覆盖 Harmony keycode、RustDesk keycode、扫描码、布局、大小写、组合键、IME 文本输入和系统保留快捷键。

#### P1-4：多屏、缩放、旋转和 2in1 形态切换

显示 ID、全局坐标、屏内坐标、逻辑 vp 和物理 px 不能混用。必须维护每块屏的 displayId、物理 bounds、rotation、DPI/scale、capture size、encoder size，以及主控逻辑桌面到本机全局桌面的变换。

每个输入消息携带 display epoch；旧 epoch 事件直接丢弃，防止变屏后点击错误窗口。

#### P1-5：被控端安全边界必须独立设计

最低要求：

- 默认“每次本机接受”，无人值守单独开关且二次确认。
- 接入频控、失败锁定、IP 或设备黑白名单和可撤销受信设备。
- 会话 UI 和通知持续显示主控身份、连接时长和一键断开。
- 剪贴板、文件、音频、输入控制按能力单独授权，默认最小权限。
- 不控制锁屏、支付、密码保险箱等安全界面；平台是否自动屏蔽必须实测，应用侧也要 fail-closed。
- 长期身份密钥和无人值守秘密放 HUKS 或系统密钥服务；Preferences 只存非秘密配置。
- NAPI 对所有 JSON、长度、坐标、displayId、sessionId 做边界校验；Rust 层不得信任 ArkTS 或网络输入。
- 日志禁止输出密码、token、剪贴板、文件路径和完整设备 ID。

#### P1-6：测试与可重复验证基线不足

现有 14 个 test 文件没有任何被控端用例，且有一个测试引用缺失源文件。默认 HAP 历史构建成功不能替代 ohosTest、Native sanitizer、真机长稳和跨版本测试。

### 3.3 P2：后续功能和产品风险

- 系统内录、受保护内容和 DRM 画面或音频可能为空或被系统屏蔽，需定义降级，不可绕过。
- 文件传输和剪贴板会扩大数据外泄面，不应进入第一版被控 MVP。
- 多会话并发会显著增加编码资源与准入复杂度，第一版限制单会话。
- 普通三方应用的开机自启或登录前服务能力未在当前方案中获得证据；若是硬需求，应切换企业 MDM 或厂商合作轨道，不应通过隐蔽保活规避平台策略。
- README 对高风险能力的主动裁剪是既有产品承诺；重新引入被控端需要隐私政策、上架说明、反诈骗风控和用户教育同步评审。

---

## 4. 推荐落地架构

### 4.1 分层

~~~text
ArkUI Host Console
  ├─ HostSessionCoordinator（状态机、权限编排、通知、接受或拒绝）
  ├─ HostCapabilityStore（非秘密配置；秘密转交 HUKS）
  └─ HostBackgroundCoordinator（真实业务模式与取消处理）
          │ NAPI：低频控制与事件，不传逐帧大块数据
Native Harmony Adapter
  ├─ CaptureAdapter：AVScreenCapture / display / rotation
  ├─ EncoderAdapter：OH_VideoEncoder / capability / bitrate / IDR
  ├─ InputInjectionAdapter：Request / Query / Inject / Cancel
  └─ AudioAdapter（第二阶段）
          │ Native 内存或 Surface，带背压
RustDesk Host Core
  ├─ rendezvous/relay 注册与重连
  ├─ inbound admission/authentication
  ├─ codec packet adapter
  ├─ control/clipboard/file capability policy
  └─ audit events（不含秘密）
~~~

关键原则：

1. ArkTS 负责授权流程和用户可见状态，不负责逐帧搬运。
2. Native 负责采集、编码、输入注入和资源生命周期。
3. Rust 负责 RustDesk 协议、认证、加密、NAT 或 relay 和会话策略。
4. 任何系统授权或资源失效都沿单一状态机向上汇报并 fail-closed。

### 4.2 建议状态机

~~~text
Disabled
  -> PreparingPlatform
  -> WaitingCaptureConsent
  -> WaitingInputConsent
  -> RegisteringHost
  -> Ready
  -> IncomingPending
  -> Active
  -> Suspending / Reconfiguring
  -> Ready
  -> Stopping
  -> Disabled

任意状态 -> Failed（随后统一 cleanup）
~~~

不得用多个布尔值拼状态。每次 start 生成 generation 或 epoch，异步回调只允许修改自己持有的 generation；旧回调只释放自己的资源，不得重新拉起已停止会话。

### 4.3 Native bridge 最小合同

~~~text
hostGetCapabilities() -> JSON
hostStart(config) -> result
hostStop(generation) -> result
hostPollEvents(generation, limit) -> events
hostAccept(connectionId, grants) -> result
hostReject(connectionId, reason) -> result
hostSetDisplay(displayId, epoch) -> result
hostSetVideoPolicy(fps, bitrate, codec) -> result
hostRequestIdr() -> result
inputRequestDialogAuthorization() -> async event
inputGetDialogAuthorization() -> unauthorized/authorizing/authorized
inputGetControlDeviceCapability() -> unavailable/denied/granted
inputCanInject() -> effective boolean + reason
inputReleaseAll(sessionId) -> result
~~~

事件至少包括 hostRegistered、incomingConnection、authenticated、captureStarted、captureStoppedByUser、inputAuthorizationChanged、displayChanged、encoderError、networkDegraded、continuousTaskCancelled、peerDisconnected。

### 4.4 屏幕采集与编码细节

1. 查询可采集 display 或 window 和编码能力，再确定 width、height、fps、codec；不要硬编码 4K 或 60。
2. Attended MVP 使用系统 Picker 或隐私提示；CUSTOM_SCREEN_RECORDING 走独立权限申请，不阻塞 MVP。
3. 设置旋转跟随或明确手动 ResizeCanvas 策略，不能两套同时抢状态。
4. 优先 Surface 直连视频编码器；如果 RustDesk host 不能接外部编码帧，再使用 Buffer 路径并量化 copy 和颜色转换成本。
5. 每个编码 packet 附带 codec、PTS、keyframe、display epoch；格式变化前发协议级分辨率变更并请求 IDR。
6. 用户从系统胶囊停止录屏时，收到 STOPPED_BY_USER 后立即结束远端画面，不允许继续发送最后一帧伪装在线。
7. 固定释放顺序：停止接收新输入 → releaseAll → 停网络帧生产 → encoder EOS 或 Stop → stop capture → free buffers/window → destroy encoder/capture。

### 4.5 输入注入细节

**API 23 路径**：仅 NDK；先 RequestInjection，回调 AUTHORIZED 后才能接收可执行输入。每次事件注入返回值必须检查，201、801 或服务异常立即降级为仅观看。

**API 26 路径**：ArkTS inputEventClient 和 NDK OH_Input_Inject 系列均可在获得 CONTROL_DEVICE 后使用；仍建议保持 Native 单一实现，避免两套注入状态机。CONTROL_DEVICE 需 AGC 和手动设置。API 26 的 OH_Input_QueryAuthorizedStatus 只反映弹窗授权状态，不反映 CONTROL_DEVICE 所带来的注入能力，因此必须分别维护“受限权限能力”和“弹窗授权状态”，再计算 effective canInject。

输入消息处理顺序：认证 → 会话 grants → effective canInject → display epoch → 范围裁剪 → 状态机去重 → 注入 → 记录结果。任何一步失败都不注入。

### 4.6 后台与生命周期

- manifest 增加的 backgroundModes 必须与真实业务一致；禁止为了保活虚构类型。
- 录屏活跃期按真实业务使用 audioRecording，或在符合音视频组合定义时评估 avPlaybackAndRecord。不得把 taskKeeping 用于 host 空闲等待；不得仅因存在网络流量就申请 dataTransfer。
- 用户删除长时任务通知、系统取消任务、录屏被停止、应用销毁、睡眠或注销时统一调用幂等 stop。
- 恢复后不自动继承旧输入授权和旧连接；重新查询授权、显示拓扑和会话 token。
- 无会话时不保持编码器或采集器；空闲 CPU 目标接近 0。

---

## 5. 分阶段实施与准入门

### Phase 0：能力 Spike（必须先做，不进入正式 UI）

交付 4 个可独立运行的 Native PoC：

1. **输入 PoC**：API 23 2in1 上完成用户授权与键鼠或触控注入，记录所有错误码与授权持久性。
2. **采集编码 PoC**：1080p30 Surface 到 H.264，持续 2 小时，支持用户停止、旋转和分辨率变化。
3. **RustDesk host PoC**：标准 RustDesk 主控端经 ID 或 relay 连接，看到视频并发送一个经过授权的点击。
4. **后台 PoC**：前后台、通知删除、睡眠或唤醒、网络切换、外接屏热插拔均能正确停止或恢复。

**Go 条件**：四项全部通过，且无绕过系统授权的实现。

**No-Go 条件**：产品硬性要求 API 23 静默无人值守，但输入或录屏仍要求本机交互；或 RustDesk host 无法接入 Harmony 编码输出且原始帧方案无法达到性能门槛。

### Phase 1：Attended MVP

- 单会话、单屏、H.264、1080p30。
- 本机每次接受，系统录屏和输入授权可见。
- 仅视频和键鼠；触控可随后打开。
- 不做音频、文件、剪贴板、无人值守、开机自启、锁屏控制。
- 任一能力失败自动降级为仅观看或断开，UI 明确显示原因。

### Phase 2：产品化

- 动态码率和 FPS、重连、多屏、旋转、2in1 姿态切换。
- HUKS 身份密钥、受信设备、频控与审计。
- audioRecording 或 avPlaybackAndRecord 的正式生命周期闭环；dataTransfer 仅在真实符合非托管上传或下载语义时接入。
- 复核现有 INTERCEPT_INPUT_EVENT 的 ACL（主控物理输入场景），并仅在确需免除每次录屏隐私告警时申请 CUSTOM_SCREEN_RECORDING，完成对应 AGC 审核材料。

### Phase 3：条件性 Unattended

只有 API 或固件、AGC、启动策略、锁屏边界、安全评审全部通过后开启。建议优先面向受管企业设备，不与大众版 attended 功能默认捆绑。

---

## 6. 测试矩阵与验收指标

### 6.1 自动化

| 层 | 必测项 |
|---|---|
| ArkTS 单元 | host 状态机、generation 防陈旧回调、权限组合、通知取消、配置迁移 |
| Native 单元 | key/button/touch ledger、releaseAll、坐标裁剪、stride 和色彩转换、队列背压 |
| Rust 单元 | 准入、认证失败频控、grants、codec packetization、断线清理 |
| 集成 | capture 到 encoder 到 RustDesk 主控解码；远端输入到权限检查到注入；取消通知到全链路停止 |
| 模糊测试 | NAPI JSON、网络输入事件、异常 displayId 和坐标、重复 DOWN/UP、恶意分辨率 |

先修复 BackgroundTaskState.test.ets 的缺失依赖，并保证 ohosTest target 在 CI 实际编译和执行；不能只构建 default HAP。

### 6.2 真机矩阵

- 至少两台真实 PC/2in1，覆盖项目最低 API 23 与计划中的 API 26（若升级）。
- 笔记本态或平板态、触摸屏、触控板、鼠标、物理键盘。
- 单屏、扩展屏、主屏切换、热插拔、100%、125%、150%、200% 缩放。
- 中英文布局、Caps/Num/Scroll Lock、Ctrl/Alt/Shift/Meta、组合键、IME。
- 前后台、最小化、关闭窗口、通知删除、熄屏、睡眠或唤醒、锁屏或解锁、网络切换。
- 录屏拒绝或撤销、输入拒绝或撤销、另一注入应用占用、编码器异常、relay 断开。

### 6.3 建议验收门槛

- 1080p30 LAN 端到端交互延迟 p95 不高于 180 ms；Native capture 到 encoded callback p95 不高于 50 ms。
- 编码或网络队列不超过 2 帧；30 分钟稳定会话丢帧率不高于 1%（不含主动拥塞降帧）。
- 2 小时会话无崩溃、无 FD 或 Native buffer 单调增长；稳定后内存增长不高于 5%。
- 断连、撤权或通知取消后 1 秒内停止采集和注入；100 ms 内发出所有可发出的键鼠 UP。
- 无会话空闲 CPU 平均低于 1%；持续会话温控降频时主动降 FPS 或码率而非堆积。
- 安全测试确认锁屏和受保护界面不会被远端绕过；不满足则强制断开或仅观看。

---

## 7. 整改优先级

### 立即执行

1. 统一 README 与 build-profile 的 API 基线，明确 API 23 和 API 26 两条能力路径。
2. 修复 ohosTest 缺失依赖并在 CI 编译测试 target。
3. 先完成四个 Phase 0 PoC，再估算正式排期。
4. 为 rustdesk-ohrs 定义 host bridge，不在 ArkTS 里拼装 RustDesk server。
5. 将“有人值守 MVP”和“无人值守”拆成两个产品里程碑。

### Phase 0 通过后

1. 新建 HostSessionCoordinator 与严格状态机。
2. Native 实现 CaptureAdapter、EncoderAdapter、InputInjectionAdapter。
3. 改造后台任务为真实业务模式；删除或隔离任何伪进度保活逻辑。
4. 加入 HUKS、安全准入、通知和一键断开。
5. 完成真机兼容、性能、安全和 AGC 评审。

---

## 8. 最终审批建议

- **批准**：Phase 0 技术 Spike；Attended MVP 的详细设计。
- **有条件批准**：Phase 1，前提是 API 23 真机输入授权和 RustDesk host 视频链路 PoC 通过。
- **暂不批准**：当前直接对外宣称“2in1 被控已支持”；基于现有 dataTransfer 保活直接上线；API 23 静默无人值守；文件、剪贴板、音频与首版一并开放。

当前最准确的对外口径应为：**“仓库已支持 2in1 主控客户端；被控端处于平台能力验证与安全方案设计阶段。”**
