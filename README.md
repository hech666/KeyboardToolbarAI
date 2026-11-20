# 键盘工具栏 AI · 独立源码工程 v2

包名/偏好域：`com.haoge.keyboardtoolbarai`  
目标：iOS 15+，SDK 16.5，arm64 + arm64e。只含**键盘工具栏＋AI 问答**，不含键盘美化。

本版不再是 v1 的接口/伪代码资料包：`Sources/` 和 `HaogeKeyboardToolbarAIPrefs/` 是已经衔接的 Objective-C / Objective-C++ 实现，附有 Theos Makefile、PreferenceLoader 入口和构建脚本。不链接原 KeyboardTools 二进制。它是依据已核验行为独立补齐的源码，不是原作者的原始工程，也不声称 UI/私有 API 的所有边缘行为与原版完全一致。

## 直接编译

使用你自己的 Theos 环境，并将 iPhoneOS 16.5 SDK 放在 `$THEOS/sdks/iPhoneOS16.5.sdk`。

```sh
export THEOS="$HOME/theos"
cd KeyboardToolbarAI_v2
sh build.sh roothide
```

- **Roothide**：必须用兼容的 `roothide/theos` 和配套头文件/库；不能仅把普通 Rootless 包改架构标签。
- **Rootless**：`sh build.sh rootless`。
- **Rootful**：`sh build.sh rootful`。
- 输出在 `packages/`；脚本只构建，不安装、不注销、不上传仓库。
- 主工程显式包含 `Sources/*.m` 和 `Sources/*.mm`；不要漏掉工具栏的 `.mm`，也不要再加入 v1 的 `KT*.xm` 或伪 C。
- 默认总开关关闭，安装后需要在设置中打开；新包不读写旧 `com.axs.*` 的配置。

## 已补齐

### 工具栏

- 总开关、键盘上方/底部、文字/图标、震动。
- 工具栏背景独立浅/深色配置，颜色支持透明度；按原已核验分支，**顶部可自定义背景、底部透明**。
- 18 个动作目录；默认 12 个非复合按钮，AI 与外部截图动作可以手动添加。
- 按钮添加、删除、拖动排序、恢复默认；点击与四向滑动分别绑定动作，自定义动作名称。
- 动作执行、代理转发、输入框目标跟踪、跨输入进程通知、配置重载和前台补刷。
- 停用时移除工具栏，设置变化保留宿主 App 自有 accessory；底栏避让系统按钮，窄空间做边界裁剪。
- 全选/复制/粘贴/剪切/撤销/清空/光标/换行/表情/收键盘。剪贴板、Snapper 和 ScreenShell 项是兼容桥，仍需要对应第三方插件，不是内置了那些插件的功能。

### AI

- 多引擎配置、8 个预设选项（含自定义）、API Key、手动模型列表/当前模型、选中引擎、流式开关。
- 可编辑人设；聊天面板切换服务、模型、人设，可加载模型列表和手动输入模型。
- 文本对话、流式回复、停止/取消、重试、清空、复制、插入原输入框。
- PhotosUI 与粘贴图片，最多 4 张 JPEG/用户消息；预览、移除、压缩及请求体积限制。
- 完整请求准备/NSURLSession delegate/HTTP与JSON错误/重定向限制/取消收尾；返回 block 是取消句柄，不是启动 block。
- 90 秒请求超时、300 秒资源超时；1..41 条网络消息；HTTPS 校验，拒绝跨源/降级重定向；回调回主线程，关闭/切换后用 generation 丢弃过时结果。
- 配置只有设置面板写入；聊天中的服务/模型/人设临时选择只在内存，聊天内容也不写入磁盘。

## 源码布局

- `Sources/*Model*`：动作、五向绑定、AI 配置规范化和颜色/端点算法；设置与主插件共享纯函数。
- `Sources/*Config*` / `*Preferences.h` / `*Paths.h`：单一配置文件、原子写入、只读快照与通知；损坏文件不被直接覆盖。
- `Sources/*Actions*` / `*ActionProxy*` / `*Hooks*`：动作执行、代理、实际 ABI 检查与 MSHookMessageEx 注册。
- `Sources/*Toolbar.mm` / `*Geometry.h` / `*Color.m`：上下附着、真实布局和工具栏自身颜色。
- `Sources/*Network*` / `*Chat*`：AI 网络状态机、SSE 解析、聊天和图片 UI。
- `HaogeKeyboardToolbarAIPrefs/`：完整设置控制器，不把主插件 Config/Chat 类重复编进面板。
- `Validation/`：此次实际编译/链接和本机测试记录；`SOURCE_MAP.md` 说明独立实现与已恢复证据的关系。

## 这次实际验证了什么

实际结果以 `Validation/verification.json` 为准：
- 用真实 iOS 16.5 SDK 交叉编译主插件与面板；arm64/arm64e 目标对象分别核验。
- 主插件与设置 Bundle 都执行了严格符号链接检查，不靠 undefined dynamic lookup 隐藏缺失函数。
- 与实际工具栏共用的 C 几何代码已在本机运行，含窄屏、空按钮、极端/无效尺寸的回归断言。
- `Tests/NativeTests.m` 提供模型、绑定、端点、ARGB 和 SSE 的无网络原生测试；Mac + 已启动的 iOS 模拟器可运行 `sh Tests/run_native_tests.sh`。本次只交叉编译这些原生测试，**没有在 iOS 运行它们**。

**本机 Linux LLD 19 会把 arm64e 链接输出标成 arm64。** 因此这次只将其作为符号完整性检查；没有伪造 Mach-O 头、没有合成假双架构包、没有交付可安装 deb。正式 arm64e / Roothide 成品请用 Apple/Theos 工具链构建，再核对 `lipo -info` 和包内路径。

尚未安装、注入、访问真实 AI 服务或进行真机 UI 验收；Rootless/Roothide 沙盒配置读取、第三方输入框、横屏/分屏和与其他键盘插件并存，仍须用你的目标设备验证。原版复杂 Markdown 排版没有逐像素复刻，本版用可选择正文展示；不把这些运行态兼容性说成已经测试通过。
