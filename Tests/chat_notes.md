# Chat agent 交付与验证记录

## 来源与范围

这是本工程**新补齐的独立 UIKit 实现，不是作者原源码**，不宣称复刻复杂 Markdown、原 UI 细节或原聊天私有类。
只新增 `Sources/HaogeKeyboardToolbarAIChat.h`、`Sources/HaogeKeyboardToolbarAIChat.m`、本文件。未修改其他模块。
遵守 iOS 15+ / ARC，直接引用契约的 Model、Config、Network；没有读取其他 App、逆向、下载、编译、安装、注入或发起真实网络。

## 集成要求

- tweak target 编入 `Sources/HaogeKeyboardToolbarAIChat.m`，链接 UIKit、PhotosUI（Foundation 为基础依赖）。
- 同 target 提供 Model 的 `haoge_keyboardtoolbarai_normalizeAIConfiguration`、Config singleton/valueForKey API、Network 的 `haoge_keyboardtoolbarai_startAIJob`；不使用旧 KTAI 类或外部 helper。
- 唯一入口：`[HaogeKeyboardToolbarAIChatPanel haoge_keyboardtoolbarai_openForInput:input]`，input 必须是有活动 UIWindowScene/window 的 UIView + UITextInput。
- `containsResponder:` 判断本面板及其 presented 菜单 / PHPicker 后代，不把共享同一 UIWindow 的宿主输入算进面板。
- `hasFocusedInput` 包含聊天框、可选择的消息正文及手动模型 alert 内部 first responder；`isVisible` 覆盖展示到关闭动画结束。
- 选择读取归一化配置的 `profiles` / `personas` / `stream`；`selected` 指定初始服务，角色默认不启用。persona 使用 `id,name,prompt`，profile 使用契约字段。
- 面板内服务、模型、角色选择、加载出的模型缓存、会话与草稿均为内存态，关闭销毁；不会写 prefs、NSUserDefaults 或磁盘。

## 已实现行为

- over-full-screen 暗色外侧遮罩 + 圆角卡片，在原 input.window 的 root / 已呈现 VC 链上展示，不扫描别的 scene/keyWindow。
- 关闭按钮、点击卡片外、下拉标题交互关闭；对系统/外部 dismissal 也有生命周期兜底。
- 原 input/window 都 weak；仅最初已聚焦、仍在原活动 keyWindow、可见可交互可编辑、仍属于顶层宿主、没有另一 first responder 时恢复焦点。
- 多行 UITextView 动态高度 44–120pt；键盘 frame/hide 通知通过所属 screen 坐标换算，动画调整卡片底边；table 支持 interactive keyboard dismiss。
- UITableView 自适应消息高度，正文为 selectable + noneditable UITextView，整段复制和插入按钮。插入使用原 UITextInput selectedTextRange（无 selection 时 fallback 文档末尾）及 replaceRange:withText:，随后关闭并按条件恢复焦点。
- 发送 / 流式累积文本 / 错误显示 / 停止 / 最后一轮重试 / 清空。重试复用最后 user，不额外追加一条 user。
- 生成中禁用服务、模型、角色与附件更改；停止保留部分正文。停止、清空、关闭先增加 generation，再取出并释放取消 block，然后取消，旧更新/完成不会污染新状态。
- models job 独立 generation + cancel；选择另一服务、开始聊天、清空、关闭取消旧模型加载。没有配置模型列表时可用 profile.model；菜单额外支持手动模型名称和 Network kind=models 加载。
- PHPicker 限制剩余可选张数 <=4；使用 UIImage provider，后台 JPEG 压缩，保持选择顺序；支持剪贴板图片。缩略图可删除，消息里有 UIImageView 预览，不依赖 Markdown。
- 每图最长边 <=1280px，JPEG 优先 0.78/0.58/0.38 质量，失败再缩小，目标 <=512KiB；压缩失败显示状态，不上传损坏数据。
- 多模态 messages 使用 OpenAI `[{type:"text",text:...},{type:"image_url",image_url:{url:"data:image/jpeg;base64,..."}}]`；无附件的 content 是 string。只发 JPEG，每个 user <=4 图。
- UI 最多保存 40 条 user/assistant；请求取最近连续后缀，最多 40 条 + 1 条 persona system。按保守 JSON 开销预算 6MiB、文本 196608 UTF-16 单位裁切旧上下文；persona 单独最多 16000；输入单条最多 16000。草稿图片不进入请求，pending/error assistant 不进入上下文。
- 图片异步导入也有 generation；clear/close 增代并取消 NSProgress；过时 completion 不会重新添加附件。
- 所有自定义类名前缀 HaogeKeyboardToolbarAI；C helpers、自定义 selectors 都以 haoge_keyboardtoolbarai_ 开头。UIKit overrides / delegate callbacks 保留原名。自定义初始化方法显式 NS_METHOD_FAMILY(init) 兼容 ARC。

## 本次执行的验证

仅做源码级检查、契约核对和人工生命周期审阅。未运行编译器、模拟器、真机 UI、真实服务请求。以下为父集成后应执行的验证清单，不表示已经通过运行态验证。

## 无真实网络的验收清单

将 Network entry 在测试 target 内替换成主线程回调 fake，收集 options 并返回可计数 cancel block：

1. 基础：UITextField、UITextView、已呈现宿主 VC 各打开；只在该 input 的 window/scene 出现。另一 scene 不被覆盖。
2. 归属：原 input、宿主其他输入返回 contains=NO；聊天 input、消息正文、模型名称 field、PHPicker 搜索栏返回 YES；自身 first responder 时 hasFocusedInput=YES。
3. 动态布局：长短草稿、中文组合输入、粘贴到 16000 边界、Dynamic Type、旋转、iPad split view、浮动/硬件键盘；查看无约束冲突及发送可达。
4. 回调竞争：job A 更新后 stop；start B；再投递 A update/completion。B 的消息与状态不变，A cancel 一次；clear/close 后同理。
5. 同步验证错误：fake 可在函数返回 cancel 前同步 completion；不得留下 busy 或多余 cancel 持有。真实 Network 契约为异步，这里仍处理同步完成。
6. 取消：标题下拉过阈值、外侧关闭、按钮关闭、外部 dismiss、clear 均取消活动 chat/models；dealloc 不继续持有任务。
7. 重试：失败/停止/完成都可重试最后 user，保留同一轮图片、无 user 重复；draft 文字/附件不被 retry 消耗。
8. 选择：切 profile，按该 profile.models + model fallback 选择；无列表时手动输入；models fake 成功/空/错误；切换 profile 后旧列表结果无效；prefs 文件 hash 始终不变。
9. 请求：文本和含 1–4 JPEG 的 options 精确检查；JPEG magic FF D8 FF、data URL；第 5 张不可添加；大尺寸透明/方向图片经过 renderer 后可显示；超限图片可读错误。
10. 图片竞争：导入中 clear/close；旧 provider/压缩完成不得回填；picker cancel 不清掉已有附件。缩略图删除后发送内容与剩余顺序一致。
11. 消息预算：连续 25 轮、每轮多图，UI <=40，messages <=41，最早请求不以 assistant 开头，且保留最新 user；预算超出仅裁剪最旧上下文。
12. 插入/焦点：原 selection 替换、无 selection 末尾、原 input dealloc/离窗/disabled、原宿主模态层、用户已经聚焦另一输入；不插到面板，不夺取其他输入焦点。全文复制与文本选择分别检查。

## 已知运行态缺口 / 设计边界

- 编译与所有 UI/服务运行态验证由父集成负责，当前不能声称构建或测试通过。
- 极小横屏/分屏叠加键盘、大字号下的卡片/附件条布局仍须真机验收。
- 这是单面板单会话的纯文本 UI，不带完整 Markdown、会话持久化、放大图片查看器或历史会话管理；图片预览为消息/附件条的缩略图。
- 交互关闭采用标题 pan，不冒充系统 page-sheet。已实现 presentation delegate 的外部 dismissal 取消兜底。
- 服务是否支持图像、特定模型和 persona 上下文由服务决定；最终端点、key、请求体限制和响应解析交由 Network 校验，UI 展示其 error。
- 原 input 的第三方 UITextInput replaceRange 行为、undo/业务代理通知与安全字段限制仍需宿主实测；不模拟宿主私有通知。
