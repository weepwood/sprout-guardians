# Sprout Guardians 开发交接

- Godot 4.7.1 / GDScript / GL Compatibility；默认入口 scenes/main_menu.tscn，生存场景 scenes/main.tscn。
- 默认 90 秒生存后击杀 Boss；保留旧 Greed 和塔防模式，不共用生存敌人数值。
- Git 提交使用中文；日常基础检查，高风险专项验证，正式发布完整跨平台验收。
- 本批：独立 SurvivorBalance、SpawnDirector、三档难度、固定种子生成序列回归。难度仅本进程保留，未做真实胜率测试。
- 测试：godot --headless --path . --editor --quit；godot --headless --audio-driver Dummy --path . --script res://tests/run_survivor_tests.gd；现有 CI 同时运行集成测试。
- 下一批：实际战斗种子仿真、对象池生命周期、空间索引正确性、反馈与许可明确的动画素材。见 docs/ROADMAP_SURVIVORS.md。
- 不将未执行测试标记为通过；素材必须记录来源和许可；不得破坏存档与 Web 导出。

## 集中迭代补充
- 生存模式投射物/经验物品复用池；仅活跃对象在战斗组，旧模式仍释放节点。
- 空间索引用于主角、宠物索敌和范围攻击，新增敌人使战斗缓存失效；需引擎对照测试。
- HUD 定时刷新 10Hz，事件仍立即刷新；命中音效在实际伤害时触发，拾取音效限频。
- 实际战斗胜率仿真、外部美术资源、性能实测仍未完成。合并前核实 CI。

## M2 首批
- 六类额外武器奖励与等级3+伙伴进化；旧祝福系统复用，未更改旧模式奖励表。
- 每局种子控制敌人配置、边缘随机顺序、奖励与暴击；simulation_mode 提供脚本移动入口。
- 快速敌人蓄力冲锋、重型敌人减速、Boss 半血加速；保留既有角色图集，新增原创共生徽章及走路形变。
- 真实胜率测试、完整第三方动画素材、独立六套图标和更深行为机制仍待完成。新增代码等待 CI。

## M2/M3 集中推进
- PR #23 已合并。新增真实场景仿真入口 tests/run_survivor_simulation.gd，运行：godot --headless --audio-driver Dummy --fixed-fps 60 --disable-render-loop --path . --script res://tests/run_survivor_simulation.gd。九组难度与策略样本，非人类胜率；需专项运行后校准。
- 难度持久化、实际伤害/经验/敌群峰值统计、暂停构筑与进化状态、六张原创武器图标。仿真不写战绩并禁用实时停顿。
- 尚未实测仿真输出或检查截图，不宣称数值达标。第三方动画素材、地图、远程/分裂敌人及高级奖励交互仍待完成。
