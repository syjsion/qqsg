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

## 2026-09-29 / 0.1.1 表现补全

复用现有 manifest 中的攻击、受击和死亡帧，不新增外部或 AI 生成位图。技能弧线、水瀑线条、治疗十字/圆环、受击颜色与首领预警由 Godot 绘图 API 实时绘制，属于本项目程序效果。死亡帧按时间播放一次，无死亡序列的素材回退已有 idle 帧并淡出。未改变原素材许可说明。

## 0.2.0 掉落与强化界面

复用现有地图、NPC 和装备展示资源，没有新增外部或 AI 位图。精良装备使用蓝色掉落名称、背包品质文字/颜色和强化等级区分；强化石沿用程序绘制的地面物品标记。原素材来源与许可记录继续适用。

## 2026-10-01 / 0.2.1 图标与窗口

新增参考图像来自同一固定提交 `96db41b95dbae673aeba1c8365aa8da4c459dfe8`：`UI/item_icons` 中金疮药、清心露、铁剑，根目录三种 item_slot 背景，以及 `assets/map/bajun/npc/铁匠/Sprite_5.png`。来源/许可沿用上文，仅用于个人局域网学习。`tools/import_ui_assets.py` 可重新下载并更新 `assets/manifest.json` 中的 SHA-256，不下载任何上游 Godot 缓存。

其余图标和窗口为 imagegen **内置工具**生成，未使用 CLI/API fallback。原始输出直接复制到项目，保留 RGBA；三张均为 1254×1254，alpha 范围 0–255。它们是本项目生成的近似风格素材，不宣称是官方原图。

| 文件 | 用途与布局 |
| --- | --- |
| `assets/generated/item-icons-v1.png` | 4×4 图集：药瓶、清心瓶、草叶、铁剑；桃木杖、青铜剑、青玉杖、布衣；皮甲、令牌、强化石、营寨长剑；玉纹法杖、精制战甲、金币、经验。药品与铁剑在最终映射中优先使用原图，生成版本保留作为同一图集的组成。 |
| `assets/generated/ui-symbols-v1.png` | 4×4 图集：水瀑、回春、续命、背包；卷轴、同伴、店铺、强化；战斗、治疗、确认、取消；回城、门、声音、设置。 |
| `assets/generated/window-frame-v1.png` | 无文字的木框、金边、蓝绿底板。Godot 在运行时缩放至 256×256 作为九宫格皮肤，不改源文件。 |

完整最终提示词、日期、工具模式、尺寸与哈希保存在 `assets/generated/manifest.json`。图集按实际尺寸划分 4×4 区域，AtlasTexture 开启区域裁切；原角色图以区域引用作为头像与预览。按钮文字、数量、品质、强化、任务状态及冷却均由 Godot 绘制，未烘焙进贴图。JS 技能复用已有 19768/19769/19770 图像作为当前三个技能的表现映射，不将此映射声明为官方技能资源编号。

检查方式：实际图形窗口查看图标在 30/54/66 像素下的轮廓、透明背景、两职业、满格、空格、右键菜单、强化和奖励；完整检查验证所有内容都有图标、区域不越界、源文件哈希匹配。截图使用模拟状态，不代替 LAN 实测。
