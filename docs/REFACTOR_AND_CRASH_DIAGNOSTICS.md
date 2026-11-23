# Sprout Guardians 重构路线与闪退排查（2026-11）

> 本文的判断基于目前仓库代码与 Actions；**尚未获得用户出现闪退时的本机错误日志**。因此不宣称所有实际闪退已经修复。

## 1. 已确认的问题

1. **混合渲染**：生存模式各实体既有 Sprite2D 贴图，也保留 Node2D._draw 的身体、弹道和露珠绘制，同一实体同时渲染两套美术；连 UI 背景也有大量代码中的颜色/形状常量。
2. **战斗数字节点泄漏**：旧 `GreedCombatFeedback._acquire_label()` 在活跃列表不满上限时持续新建 Label，而过期后的 Label 只设为隐藏、不归还复用池。长时间持续输出伤害会导致节点数量累积。已修复并加入压力测试；它可能加重卡顿或内存开销，但不能仅凭静态分析断言是某台机器闪退的直接原因。
3. **测试覆盖缺口**：此前导出后的 Linux/macOS 启动测试只有 30 帧，测试的是主菜单而不是进入生存关卡。新增自动进入实际关卡的测试参数，以及完整 90 秒逻辑、Boss、奖励、暂停与对象池的集成测试。
4. **继承链过深**：`greed_game.gd → greed_game_balanced.gd → greed_game_mouse.gd → survivor_game.gd → survivor_pixel_game.gd`。业务、场景创建、输入、HUD、奖励、运行状态经由多层 `super` 联动；同名回调、运行状态与游戏模式难以定位。
5. **内容完成度**：主菜单「植物图鉴」仍是文案占位；构筑选择和永久进度没有构成完整循环；敌人行为与 Boss 阶段仍较单一。
6. **多端差异**：渲染器、显卡驱动、全屏切换、原生窗口、Godot 导出模板与代码签名问题，均无法仅凭 Ubuntu headless 测试排除。

## 2. 本次落地（PR #20）

### 素材层

- `assets/toy/sprout_toy_atlas.png`：原创 3×3 透明 RGBA/索引 PNG 图集，共 9 个格子，每格 56×56。
- 顺序：英雄、向日葵随从、嫩芽随从 / 甲虫、史莱姆、Boss / 种子弹丸、经验露珠、命中星形。
- `PixelArtAssets` 统一按 ID 映射到 AtlasTexture；旧 SVG HUD 图标继续保留。
- 角色、敌人、弹丸和经验露珠在对应 `.tscn` 文件中直接拥有 Sprite2D 贴图节点，编辑器可预览，运行时只更新贴图、缩放、旋转、颜色。
- 当前玩法场景设置 `render_with_sprite=true`，跳过旧 `_draw()` 身体/弹丸绘制；旧模式仍可使用其遗留绘制。
- `PixelImpactSystem` 改用带上限的纹理 Sprite 池，不再每帧 `draw_rect` / `draw_line`。
- 下一阶段补充方向行走/攻击/受击帧、武器特殊效果、UI icon、TileSet 与背景层。当前静态素材**不等于已完成逐帧动画素材生产**。

### 运行与诊断

- `SurvivorRunState`：独立生命周期阶段 `READY → RUNNING ↔ REWARD / PAUSED → VICTORY / DEFEAT`。目前作为兼容期的权威阶段记录，与旧标志同步；后续逐步把所有状态写操作迁入状态机。
- `SurvivorRunTrace`：本机保存最近 80 条阶段变更，写入 `user://diagnostics/survivor-session.log`；不发送网络请求。
- Godot 原生日志写入 `user://logs/godot.log`，最多保留 5 个；引擎崩溃堆栈的丰富程度取决于二进制调试符号。
- 伤害数字改为有容量上限的 Label 池，命中特效同样使用 Sprite 池。
- `tests/run_session_integration.gd` 测试完整生命周期、90 秒里程碑、Boss、状态切换、压力下对象池容量。
- Windows/macOS/Linux 导出程序添加 `-- --ci-survivors-smoke` 测试路径，自动进入生存场景，而不仅仅验证菜单能显示。

## 3. 推荐的通用 Godot 架构

建议采用 **Godot Scene + Resource + Signal + 少量单例服务** 的组合式架构，而不是把整个游戏迁进一套重型外部模板。Godot 官方推荐场景自治和按模块就近存放资源。

```text
game/
├── app/
│   ├── app_root.tscn            # 入口/导航（后续）
│   ├── scene_router.gd          # 场景切换
│   └── settings_service.gd
├── core/
│   ├── game_events.gd           # 跨子系统事件（必要时）
│   ├── run_state.gd             # 一局游戏的状态
│   └── diagnostics.gd
├── features/
│   └── survivors/
│       ├── survivor_run.tscn
│       ├── survivor_run_controller.gd
│       ├── wave_spawn_controller.gd
│       ├── combat_controller.gd
│       ├── reward_controller.gd
│       ├── input_controller.gd
│       ├── hud/
│       │   ├── survivor_hud.tscn
│       │   ├── reward_dialog.tscn
│       │   └── pause_dialog.tscn
│       └── data/
│           ├── weapons/
│           ├── enemies/
│           └── upgrades/
├── actors/                        # Hero / Familiar / Enemy scene
├── assets/                        # png / svg / sound / font
└── tests/                         # state, game flow, exported smoke
```

以上是**目标结构**，并非声称本次已将所有旧文件移动完成。先让单元测试与新旧行为在迁移过程中同时成立，再逐级收缩 `greed_game*.gd` 的继承链。保留 `scenes/main.tscn` 与已发布的 `v0.2.0` 兼容，最后再切换入口。

### 现成参考

| 参考 | 优势 | 取舍 |
| --- | --- | --- |
| [Godot 官方 Scene Organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) | 场景自治、Signals 和清晰主入口 | 没有现成游戏业务 |
| [GDQuest Modular Game Architecture](https://www.gdquest.com/library/modular_game_architecture/) | 按插件/系统/游戏内容拆分边界 | 需要结合当前项目裁剪 |
| [crystal-bit/godot-game-template](https://github.com/crystal-bit/godot-game-template) | 场景管理、设置、调试模式和工程组织参考 | 不适合连同所有逻辑直接覆盖当前工程 |
| [Maaack's Game Template](https://github.com/maaack/Godot-Game-Template) | 菜单、暂停、设置和场景切换模板 | 与现有主菜单、存档系统重复，需要择优移植 |
| [ChristianWSmith/godot4-template](https://github.com/ChristianWSmith/godot4-template) | 较完善的 Manager/EventBus/Save 分层 | 对当前个人小体量游戏偏重 |

## 4. 下一阶段按风险推进

**P0：运行稳定**
- 获取用户本机 `godot.log` + `survivor-session.log`，结合复现时间确认具体脚本、GPU/驱动或导出问题；
- 测试 Web/Windows/macOS 真正进入关卡、长时间击杀、重启和窗口切换；
- 持续监测内存、Label、Sprite、Enemy、Projectile 节点数量；
- 消除所有错误日志再合并到 main。

**P1：真正组件化**
- `SurvivorRunController` 不再继承 Greed 旧管理器，改为组装 HUD、Input、Spawn、Combat、Reward 子组件；
- 将 `GreedBalance` 字典和奖励规则迁移到 `.tres` 数据；
- 统一运行时事件和生命周期，避免同时写多个布尔标志；
- 保留完整单局的回归测试作迁移保护。

**P2：玩法完整**
- 完整三系成长：主武器、浮游宠物和被动遗物；可读的构筑面板；
- 至少 3 种敌人 AI、Boss 分阶段行为、关卡地形与掉落；
- 图鉴、战绩、设置与长局存档；
- 控制器/触控输入适配、低动效模式和音量控制。

**P3：成品体验**
- 可编辑的角色方向/状态动画、统一的 UI 主题资源、原创音效/反馈；
- 720p/1080p/Retina 安全区域适配、手柄焦点；
- 性能预算与独立 Windows/Mac 回归测试及版本回滚。

## 5. 如何拿到闪退证据

建议在 Windows 或 macOS 最新构建下重现后，收集以下文件（关闭程序后）：

- **Windows**：`%APPDATA%\\Godot\\app_userdata\\Sprout Guardians\\logs\\godot.log`
- **macOS**：`~/Library/Application Support/Godot/app_userdata/Sprout Guardians/logs/godot.log`
- 本次新版本的状态轨迹：同一应用数据目录下 `diagnostics/survivor-session.log`。

请记录是“启动就闪退”“按开始进入关卡闪退”“暂停/升级后闪退”，以及 Godot 版本、操作系统、架构、显卡型号。系统级原生崩溃可能需要 Windows 事件查看器或 macOS Console 的崩溃报告；`godot.log` 不能保证覆盖一切 GPU/驱动级别问题。

**发布纪律**：现有正式版 `v0.2.0` 不会因本次 PR 自动被覆盖。必须先确保主分支外的完整回归测试通过，再考虑合并和新的补丁发行。
