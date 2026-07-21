# Sprout Guardians 像素素材包选择与接入方案

## 目标

项目需要的是高细节、深绿色森林、可爱植物角色、密集敌群和明亮战斗特效，而不是简单的几何占位图。第三方素材必须作为正式美术生产的起点，并通过统一尺寸、描边、调色板和动画节奏进行二次整理。

## 推荐方案 A：免费原型组合

适合先完善玩法，不产生素材采购成本。

### 地图与自然环境

- Anokolisa：Free Pixel Art Asset Pack - Topdown Tileset - 16x16 Sprites
- Shaade：Pixel Plants - 16x16 top down pixelart asset pack
- OpenGameArt：Flowers / Trees & Bushes / CC0 Plant Clutter

用途：草地、树木、灌木、花朵、石块、蘑菇和地图装饰。

### 植物敌人

- OpenGameArt：Plant and Mushroom Enemies charset and battlers（CC0）
- OpenGameArt：Spring Monster Pack（CC0）

用途：普通敌人、蘑菇敌人、植物敌人和前期精英。

### UI

- Kenney：Pixel UI Pack（CC0）

用途：按钮、面板、进度条、图标框、暂停按钮和设置界面。

### 法术与掉落

- DeepDiveGameStudio：Magical Asset Pack 16x16
- Kenney：Pattern Pack Pixel（CC0）

用途：弹道、祝福图标、拾取物、状态图标和简单像素特效。

## 推荐方案 B：更接近概念图的组合

适合制作正式试玩版，角色和敌人的动画完整度更高。

### 地图

- Admurin：Monster Architect Tileset
- Admurin：Nature Outdoors Tileset

Monster Architect 包含顶视角森林、植物怪物、地形和装饰，整体视觉方向与植物幸存者更接近。

### 植物敌人与 Boss

- Elthen's Pixel Art Shop：2D Pixel Art Flower Monster
- Elthen's Pixel Art Shop：2D Pixel Art Giant Mushroom
- Akari21：One Dollar Monsters - Flower Monster

优先用于食人花、蘑菇精英、花兽 Boss。应选择包含 Idle、Move、Attack、Hit、Death 的包。

### 战斗特效

- CreativeKind：Magic Spell Effects
- CreativeKind：Magic Spell Effects 2

用于冰晶、孢子爆炸、光束、陨落攻击和 Boss 技能。正式接入前需要缩放并重新调色，使其与植物色板一致。

### UI

- Kenney：Pixel UI Pack
- Vennril：Pixel Art RPG UI Starter Kit
- Roupiks：Tiny Dungeons UI

免费阶段优先 Kenney；需要更浓厚奇幻边框时再替换为后两者。

## 当前项目推荐组合

建议采用：

1. Admurin Monster Architect 作为地图和普通环境基础；
2. Elthen Flower Monster / Giant Mushroom 作为植物敌人与 Boss；
3. Kenney Pixel UI Pack 作为 UI 基础；
4. DeepDive Magical Asset Pack 作为早期弹道和图标；
5. 后续由自制素材统一主植物、浮游宠物和核心武器。

原因：地图、敌人、UI 和特效可以分别替换，且当前场景重构已经把这些内容拆分到独立容器和 PackedScene 中。

## 像素规格

- 逻辑视口：640 × 360；
- 地图基础图块：16 × 16，游戏中以 2 倍显示；
- 主植物：48 × 48；
- 浮游宠物：32 × 32；
- 普通敌人：32 × 32；
- 精英敌人：48 × 48；
- Boss：64 × 64 或 96 × 96；
- UI 基础单位：8px 或 16px；
- 所有纹理关闭 Filter 和 Mipmaps，使用 Nearest；
- 不允许非整数缩放。

## 风格统一检查

第三方素材导入后必须完成：

- 描边统一为深绿色或深棕色，避免纯黑和灰黑混用；
- 高光方向统一为左上；
- 阴影方向统一为右下；
- 饱和度统一到项目色板；
- 普通敌人最多使用 4 至 6 个主体颜色；
- 投射物使用高亮色，敌人主体避免过亮；
- 角色动画帧率统一到 6、8 或 12 FPS；
- 所有图集保留透明边距，避免纹理串色。

## 许可证管理

每个素材包下载后都需要：

1. 保留原始压缩包和 `LICENSE` / `README`；
2. 在 `third_party/licenses/<作者>/<素材包>/` 保存许可证文本；
3. 在 `THIRD_PARTY_ASSETS.md` 记录作者、来源、版本、下载日期和署名要求；
4. 禁止把原始素材单独重新分发或打包出售；
5. 即使页面写明可商用，也以压缩包内许可证为最终依据；
6. CC0 素材仍建议记录来源，方便后续审计和替换。

## Godot 接入位置

- 地图图块：`assets/pixel/environment/`
- 主植物与宠物：`assets/pixel/characters/`
- 敌人和 Boss：`assets/pixel/enemies/`
- 弹道与特效：`assets/pixel/effects/`
- UI：`assets/pixel/ui/`
- 原始下载包：不提交到玩家导出目录，可单独保存在美术源文件归档中。

当前 `main.tscn` 已包含世界层、运行容器和 HUD；角色、敌人、投射物与经验晶体已拆成独立场景。替换素材时，应优先修改这些独立场景或对应的 `SpriteFrames`，不要重新把图片加载逻辑塞回战斗脚本。
