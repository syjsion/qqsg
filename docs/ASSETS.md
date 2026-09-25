# 素材来源与生成记录

## 参考素材

来源：<https://github.com/Time1996/QQSanGuo>。`assets/manifest.json` 记录固定 commit、每个文件的上游路径和 SHA-256。
原图直接复制并在 Godot 内布局/缩放，未复制上游 `.import` 缓存。引用角色运动帧、怪物动画、巴郡与野外/营寨组件、NPC、技能图标、字体与音效。

上游 README 说明素材源自《QQ三国》，用于个人学习研究，并禁止二次买卖；仓库代码附 CC0 文本（保留在 `docs/sources/QQSanGuo-LICENSE.txt`）。该代码许可证不被视为商业游戏美术素材的独立授权。本项目按用户的个人局域网学习场景使用，原素材来源标记保留。

字体随参考工程取得 `PuHuiTi-Regular.otf`。客户端字体直接引用，无运行时下载。背景音乐与攻击音效随原项目取得，设置中可静音。

## 生成素材

- 文件：`assets/generated/healer-sheet.png`
- 工具：imagegen 内置工具；未使用 API/CLI fallback。
- 用途：仙术士客户端动作图，4×4 帧，实际输出 1254×1254，RGBA，alpha 范围 0–255。
- 参考图：`assets/motion/idle2/Sprite_1.png`，仅参考角色比例和绘画风格。
- 检查：透明背景和 16 帧已确认；Godot 按图像实际宽高划分，缩放到场景角色大小。生成动作与原版仙术士并不相同，帧间锚点仍需持续打磨。

### 最终提示词

```text
Use case: stylized-concept
Asset type: transparent 2D game character animation sprite sheet, 1024x1024 square.
Reference image role: visual style and chibi proportions only. Create a distinct ancient Chinese female healer (仙术士), cream and jade green robe, dark hair in two small buns with jade ribbons, holding a short wooden staff with a small jade ornament. Same hand-painted pre-rendered 2000s Chinese side-scrolling MMORPG look as the reference, crisp dark outlines, large head, very short legs, appealing readable silhouette. Full body profile facing RIGHT, no perspective camera changes.
Composition: exactly a 4 column by 4 row evenly spaced sprite sheet, 16 cells, each cell 256x256. Character centered horizontally at local x=128, feet anchored at local y=220 in EVERY cell. Entire character and staff fit inside each cell with padding. Consistent character scale, hair, outfit and weapon throughout.
Row 1: four subtle idle breathing poses.
Row 2: four running cycle poses, alternating legs, same feet baseline.
Row 3: four spell-casting poses, raising staff and extending arm; no large particles.
Row 4: jumping pose, climbing pose, recoiling hurt pose, fallen defeated pose.
Constraints: genuinely transparent alpha background; absolutely no grid lines, no labels, no text, no shadows outside the character, no scenery, no extra characters within cells. Do not copy the reference warrior costume. This is a production game sprite sheet, not a concept art collage.
```

## 替换约定

新图先保存独立版本，验收后更新 `data/art.json` 或生成素材引用。补充角色、图标、地图时保持大小、方向、脚底锚点和颜色一致。上游新增素材同步更新 manifest；生成素材记录完整提示词及生成日期。
