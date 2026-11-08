# Resk 鸿蒙客户端前端视觉矫正交接文档 (HANDOFF)

## 1. 任务背景与目标
依据操作者指令与 `taste-skill`（前端设计品味规范 / app screens），针对 Resk 在横屏平板（TGR-W10，物理分辨率 2800x1840）以及紧凑视口下暴露的前端视觉缺陷进行系统化矫正。
重点解决：
1. **安全区与状态栏贴合**：原先顶部内容间距极窄（部分仅 15vp），导致标题与图标紧贴甚至穿透鸿蒙状态栏与居中摄像头药丸区。
2. **卡片、输入框与按钮的对齐节奏**：原先存在大量任意负平移（如 `.translate({ x: -6 })`）、阴影扣除导致的宽度差（40px 参差右缘），导致同一竖直轴线上的控件左右边缘无法对齐。
3. **信息层级与留白节奏**：将原本孤立悬浮的状态文案收拢为统一规范的状态展示组件（StatusNotice），建立清晰视觉层级与呼吸感。

---

## 2. 修改文件清单与 SHA-256 校验码

| 文件路径 | SHA-256 哈希 |
| :--- | :--- |
| `entry/src/main/ets/pages/rustdesk/RustDeskLayoutTokens.ets` | `c098fcb3f8db16aa12b7917bfb77ac266acaa93774bb73422b4fa788daff274d` |
| `entry/src/main/ets/pages/rustdesk/components/ViewedHostPage.ets` | `ce2f7da51d7d368878e121b38bfc1f33821445774ef360edb18f857c58fa0991` |
| `entry/src/main/ets/pages/rustdesk/components/ViewedHostCard.ets` | `4cce08f5e90d5dec58c81dc06c8feb220c9ae62d556b3965fc7e4262eadbe13b` |
| `entry/src/main/ets/pages/rustdesk/components/ConnectTab.ets` | `c9baac3797e444a51d2d5b08b289d4ac9e690033a7452ca6b8dd5038daa0c3fa` |
| `entry/src/main/ets/pages/rustdesk/components/DeviceDirectoryPanel.ets` | `31f33d5c1b65e2330ebda5de9d61460c47f67570b899272ecb250878dba3039e` |
| `entry/src/main/ets/pages/rustdesk/components/SettingsTab.ets` | `6fc5b2c4e613a2b533bbd3b9122a56d30d6c344f3fafa44de971653bce2040a1` |

---

## 3. 具体修改内容与对应 taste-skill 原则

### 3.1 `RustDeskLayoutTokens.ets`
- **修改内容**：
  1. 将 `HOME_TWO_COLUMN_MIN_WIDTH` 从 `980` 调整为 `880`，使平板横屏下内容区（约 900–960vp）可自然启用两列均衡工作区，消除单列时右侧大片空白荒漠。
  2. 将 `useWideContentAnchor` 阈值提升为 `viewportWidth >= 1200`，避免在平板视口下强行左贴靠导致视觉失衡。
- **依据 taste-skill 原则**：
  - *Viewport Proportions & Wide Layouts*：宽屏内容不可在单列时强行顶死左侧而留出 60% 荒废空白；多列适配需匹配真实可用视口。

### 3.2 `ViewedHostPage.ets`
- **修改内容**：
  1. 新增 `contentTitleSpacerHeight()` 逻辑：宽屏下顶部预留 `Math.max(this.titleSpacerHeight + 36, 56)`（之前为仅 15vp），彻底拉开与鸿蒙平板顶部状态栏/摄像头药丸的距离。
  2. 约束 `contentWidth()` 在宽屏下上限为 `600vp`（原为 760vp），消除卡片扁长过度拉伸感。
  3. 滚动容器外层纵向留白由 `space: 8` 扩充为 `space: 16`。
- **依据 taste-skill 原则**：
  - *Generous Top Safe Area*：工作台页面首屏元素严禁贴合状态栏或打孔区，至少保留 24–32vp 以上安全呼吸间距。
  - *Form & Card Measure*：表单卡片不应横向无限铺展，需符合人体扫视线宽（480–640vp）。

### 3.3 `ViewedHostCard.ets`
- **修改内容**：
  1. **左右宽度彻底对齐**：
     - `fullActionWidth()` 直接返回 `this.innerWidth()`，修正原先减去 2 倍 shadowPadding 导致“启动/停止服务”按钮比上方“设备 ID / 密码”卡片短 40px 的锯齿边缺陷。
     - `actionWidth()` 修正为 `(this.innerWidth() - 12) / 2`，使“同意/拒绝”双按钮之和与上方卡片宽度完全对齐。
     - `SectionHeading` 宽度约束为 `this.innerWidth()`，使标题图标与下方输入框左缘严格对齐。
  2. **信息层级结构化**：
     - 新增 `StatusNotice` 结构化状态卡片，替换原本在按钮间孤立裸置的纯文本，带上语义图标（`sys.symbol.display` / `sys.symbol.info_circle`）与柔和背景边框。
  3. **控件触控与间距节奏**：
     - `InsetValue` 与 `PasswordInsetValue` 高度统一定为 `56vp`，内边距规范为 `16vp`。
     - 复制与刷新操作按钮统一为 `36x36vp`。
- **依据 taste-skill 原则**：
  - *Strict Visual Alignment*：同轴线表单与按钮必须共享同一左右边界，严禁参差不齐。
  - *Information Grouping & Semantic Badges*：状态提示不可作为孤儿文本随意悬挂，需具备规整的容器感与清晰层级。

### 3.4 `ConnectTab.ets`
- **修改内容**：
  1. **消除异常横向位移**：
     - 将 `compactControlVisualOffsetX()` 归零，移除 SegmentedControl、TextField、Button、SecondaryMenu 上的所有 `.translate({ x: -6 })` 补丁，让所有组件的物理中心与左右边界归位。
  2. **组件宽度统一与手柄对齐**：
     - `ConnectionStage` 容器宽度设为 `this.controlWidth()`。
     - `secondaryMenuControlWidth()` 设为 `this.controlWidth() - 50`，与外部独立手柄（40 + 10 = 50vp）精准结合，使整个组件的右边缘与主连接按钮完全对齐。
  3. **最近设备卡片网格严谨对齐**：
     - 每张卡片宽度定为 `(this.controlWidth() - 12) / 2`，以 `space: 12` 并排，总宽严格等于 `this.controlWidth()`，彻底终结此前卡片左右各内缩 20px 的错位现象。
  4. **顶部安全区**：
     - 引入 `pageTopClearance()`（宽屏 56vp，紧凑 40vp），移除外层重复的 top padding，确保与“服务端”页面顶部基线精确一致。
- **依据 taste-skill 原则**：
  - *Eliminate Ad-hoc Tweaks*：禁止通过局部 magic translate 修正对齐，应从容器和尺寸网格根治。
  - *Consistent Rhythm Across Tabs*：首页与服务端页面切换时，页面标题与首控件的 Y 轴起始高度必须一致，不产生跳动。

### 3.5 `DeviceDirectoryPanel.ets` 与 `SettingsTab.ets`
- **修改内容**：
  1. 统一顶部基线间距为 `pageTopClearance()`（宽屏 56vp，紧凑 40vp），消除原有 33vp 偏低贴栏问题。
  2. 移除重复的 top padding，保持与 ConnectTab、ViewedHostPage 的首屏 horizon 统一。
- **依据 taste-skill 原则**：
  - *Cohesive Horizon*：应用内所有顶级 Tab 在相同设备形态下必须保持统一的顶部节奏。

---

## 4. 契约与功能完整性验证

1. **services/ 与 services/controlled/ 未作任何修改**：完全保证 NAPI 契约、协调器状态机与数据源不变。
2. **功能行为事实保持**：
   - 临时密码保持常显状态（`state.temporaryPassword || '等待生成'`）。
   - 密码复制后 1.5 秒内保持切换为 `sys.symbol.checkmark`，超时自动复原。
   - 刷新临时密码回调 `onRefreshPassword()` 正常保留。
   - `ViewedHostCard` 保留 `canIUse(INPUT_SIMULATOR_SYSCAP)` 门控及对应的“授权并启用远程控制”按钮。
   - “被控端”历史遗留的分段控件维持已移除状态。
3. **ArkTS 图标符号合规**：
   - 全程仅使用合法已存在的符号：`sys.symbol.display`、`sys.symbol.info_circle`、`sys.symbol.rectangle_on_rectangle`、`sys.symbol.checkmark`、`sys.symbol.arrow_clockwise`、`sys.symbol.link`、`sys.symbol.square`、`sys.symbol.folder`、`sys.symbol.clock`。未引入任何不存在的 symbol。
4. **横屏与紧凑视口自适应**：
   - 所有卡片与页面均保留并在逻辑上严密支持 `compact()` / `isCompact()` 分支。

---

## 5. 无真实设备条件下的视觉核查不确定点（需父会话在真机复核）

1. **状态栏避让区域的动态高度**：
   若鸿蒙系统未来版本或特定设置下全局状态栏缩放比例改变（导致避让高度超出 48vp），请确认 56vp 的顶部间距是否依然留有 8vp 以上的纯净透气空间。
2. **Luminous Neo 拟态阴影在真机 GPU 渲染的物理感**：
   `LuminousSurface` 在真机上依赖双层彩色柔光阴影（Raised / Inset）。在卡片宽度对齐后，请在真机屏幕上观察卡片右缘与按钮右缘的高光边缘是否在同一条垂直光照线上。
3. **平板横屏下双列模式切换点**：
   在 2800x1840 平板（扣除侧边栏后约 900–960vp）下，ConnectTab 预期将平滑呈现双列（左侧控制、右侧最近设备）；如需调整左右分栏比例，可在此交接基础上微调。
