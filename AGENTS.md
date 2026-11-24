# Sprout Guardians 开发交接

- Godot 4.7.1 / GDScript / GL Compatibility；默认入口 scenes/main_menu.tscn，生存场景 scenes/main.tscn。
- 默认 90 秒生存后击杀 Boss；保留旧 Greed 和塔防模式，不共用生存敌人数值。
- Git 提交使用中文；日常基础检查，高风险专项验证，正式发布完整跨平台验收。
- 本批：独立 SurvivorBalance、SpawnDirector、三档难度、固定种子生成序列回归。难度仅本进程保留，未做真实胜率测试。
- 测试：godot --headless --path . --editor --quit；godot --headless --audio-driver Dummy --path . --script res://tests/run_survivor_tests.gd；现有 CI 同时运行集成测试。
- 下一批：实际战斗种子仿真、对象池生命周期、空间索引正确性、反馈与许可明确的动画素材。见 docs/ROADMAP_SURVIVORS.md。
- 不将未执行测试标记为通过；素材必须记录来源和许可；不得破坏存档与 Web 导出。
