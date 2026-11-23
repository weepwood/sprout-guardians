# 跨平台桌面包与圆润游戏 UI（2026-11）

## 设计定位

从《猛兽派对》等轻松派对游戏的**圆角控件、温暖色彩、低门槛操作反馈与角色展示方式**中提取通用设计原则，为芽芽守卫战实现独立的「花园玩具」UI 语言。不使用、复制或打包其他游戏的商标、角色、截图、图标、音频或 UI 贴图。

- **色彩**：奶油白 #FFF9ED、纸张米黄 #FFF1D9、阳光黄 #FFD36D、粉珊瑚 #FFA49A、薄荷绿 #B8E5B6。
- **几何**：约 10–17 像素圆角，2 像素软棕描边，约 2–4 像素柔和阴影。
- **交互**：默认操作焦点、键盘/手柄焦点轮廓、轻微缩放反馈、按钮颜色区分角色，避免 UI 原地跳动。
- **游戏信息**：生命、等级、倒计时、击败数顶部集中；左侧构筑状态面板；底部经验条；清晰的三选一奖励弹层。
- **页面**：主菜单左侧角色展台/右侧行动卡；设置、暂停、奖励和结算统一卡片系统。
- **可维护性**：所有交互按钮仍是 Godot `Button`；核心控件在编辑器内可见，主题可通过 `scripts/ui/playful_ui_theme.gd` 集中调整。

## 玩家下载

打开 GitHub 仓库的 **Actions → Build and Package → 最新成功的运行 → Artifacts**：

| 系统 | 产物 | 安装方式 |
| --- | --- | --- |
| Windows x86-64 | `SproutGuardians-Windows-x86_64.zip` | 解压并双击 `SproutGuardians.exe`（免安装） |
| macOS Intel + Apple Silicon | `SproutGuardians-macOS-Universal.dmg` | 打开 DMG，将 `.app` 拖入“应用程序” |
| macOS Intel + Apple Silicon | `SproutGuardians-macOS-Universal.zip` | 解压并将 `.app` 放入“应用程序” |
| Web | `SproutGuardians-Web.zip` | 静态网页部署包 |

推送 `v*` 标签时，所有用户包将作为 GitHub Release 附件发布（含 Windows、macOS ZIP/DMG 和 Web）。Linux 构建只用于验证，不是玩家下载包。

### macOS 的安全提示

当前构建使用 macOS GitHub Actions Runner 对 Universal 2 .app **ad-hoc 临时签名**，并验证二进制架构、代码签名以及本机无界面启动。它不是 Apple Developer ID 正式签名/公证。

因此在较新的 macOS 上，网络下载应用第一次打开时 **Gatekeeper 仍可能拦截**。可以在确认来源后通过“系统设置 → 隐私与安全性 → 仍要打开”操作；如需无额外提示的公开分发，需后续配置 Apple Developer ID 证书、notarytool 公证和 stapling 流程。不要将用户的 Apple ID、证书私钥或公证凭据提交进仓库。

Windows EXE 当前也没有商业代码签名证书，首次下载可能出现 SmartScreen 提示。

## CI 验证步骤

1. Ubuntu 导入 Godot 4.7.1 工程，执行核心游戏、Greed、Survivors 和 UI smoke 测试。
2. 导出 Windows 可执行文件、Web 页面、macOS 通用架构应用与内部 Linux 验证包。
3. 启动 Linux 验证包，确保引擎、脚本与初始场景能正常加载。
4. `macos-15` Runner 解压 .app，检查 Intel/Apple Silicon 架构，设置可执行权限并执行 ad-hoc 签名。
5. 使用 `codesign --verify --deep --strict` 验证应用，再启动 macOS CLI smoke test。
6. 生成完整 `.app` 的 ZIP 和 DMG，保留结构并上传产物；发布标签时合并到 Release。

通过自动构建并不等于已经完成人工视觉检查。建议在 Windows 100%/150% 缩放和 macOS Retina 下人工查看主菜单、弹窗、首屏 90 秒完整跑局及输入响应。

## 进一步的 UI 工作

- 1280×720、16:10、超宽显示屏下的 HUD 容器锚点与安全区布局
- 独立手柄导航映射、触屏设备虚拟摇杆
- 辅助阅读、降低动画效果、色盲模式
- 植物角色动画、主菜单独立立绘和按钮原创微音效
