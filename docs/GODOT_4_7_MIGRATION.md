# Godot 4.7.1 迁移说明

## 目标版本

项目统一使用 **Godot 4.7.1-stable Standard**：

- 本地编辑器：Godot 4.7.1 Standard；
- GitHub Actions 编辑器：Godot 4.7.1-stable Linux x86_64；
- 导出模板：Godot 4.7.1-stable；
- 项目特性声明：Godot 4.7；
- 渲染方式：GL Compatibility。

选择 4.7.1 而不是 4.7.0，是因为 4.7.1 是 4.7 分支的首个维护版本，包含关键回归和崩溃修复。

## 已修改内容

- `project.godot` 的 `config/features` 从 `4.6` 更新为 `4.7`；
- `.github/workflows/build.yml` 从 Godot 4.6.3 更新为 4.7.1；
- CI 下载并安装匹配版本的编辑器和导出模板；
- CI 输出 `godot --version`，防止变量配置与实际执行版本不一致；
- README 的本地开发要求更新为 Godot 4.7.1；
- Windows、Web 和内部 Linux 冒烟构建均由同一套 4.7.1 模板生成。

## 本地升级步骤

1. 提交或备份当前工作区；
2. 安装 Godot 4.7.1 Standard；
3. 使用 4.7.1 打开仓库根目录的 `project.godot`；
4. 等待首次资源重新导入完成；
5. 打开 `scenes/main_menu.tscn` 和 `scenes/main.tscn`，确认编辑器可视结构正常；
6. 按 F5 运行项目；
7. 不要再使用 Godot 4.6 保存已经由 4.7 打开的场景和资源。

## 兼容性验证清单

- 项目无解析错误地完成编辑器导入；
- 主菜单和生存场景能够实例化；
- 六组自动化测试全部通过；
- 隐藏脚本和运行时错误扫描通过；
- Windows 与 Web 玩家构建成功；
- Linux 内部构建能够无界面启动并正常退出；
- 玩家制品仍只包含 Windows 与 Web。

## 回退方案

版本升级在独立分支和 Draft PR 中进行。发生兼容问题时，可以回退到升级前提交：

```text
6ed87750edf35110bde8f26a563b39e171f23cc0
```

Godot 导入缓存位于 `.godot/`，该目录不应提交。需要重新导入时可关闭编辑器、删除本地 `.godot/` 后重新打开项目。
