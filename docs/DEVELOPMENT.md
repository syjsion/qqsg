# 开发手册与进展

## 当前状态

0.3.0：赵云、黄忠、华佗副将的任务获取、招募、收藏、助战、成长及 v3 存档已实现；完整检查、图形复查与四平台 CI 构建和导出后启动全部通过；交付结果见文末。

0.2.1：现有页面、物品格子、技能栏、NPC 和掉落标记已完成图像改版；本机完整检查及 16 场景截图复查通过；四平台 CI 构建、导出后启动全部通过。交付结果见本轮记录。

0.2.0：掉落、独立装备、强化及旧档迁移已实现；最终完整回归及四平台构建、导出后启动全部通过。

2026-09-29：0.1.1 体验完善已交付；完整检查已通过：96 项单元检查、原四客户端联机、真实重启重连及源码启动器测试；四平台 CI 构建与启动检查全部通过。

2026-09-25：首版 0.1.0 已提交到目标仓库；四平台 CI 构建和导出后启动检查全部通过。SSH 推送正常。Windows + macOS 两台真实电脑合作游玩待验证。

## 开发入口

先阅读 PLAN.md、ARCHITECTURE.md 和本文件。规则修改在 core 中实现并补充 tests/unit.gd；网络修改同时检查 tests/network.py；展示逻辑放在 client，静态内容使用 data 中稳定 ID。数值来源见 DATA.md，素材清单、许可边界和生成提示词见 ASSETS.md。

每次功能、协议、数据、素材或部署修改，与代码同一提交更新本文件，写明命令、实际结果、问题和下一步。不要提交 .godot、.tools、build、玩家凭据或存档。

## 2026-09-25 / 首版实现与验收

- Godot 4.7.2 / GDScript 工程，独立 ENet 服务端，服务器唯一结算伤害、库存、经验和奖励；60 Hz 模拟、20 Hz 常规快照、本地预测和远端插值。
- 剑侍、仙术士，三地图、三类小怪和邓茂；移动、跳跃、攀爬、换图、攻击治疗、死亡复活、归属掉落、背包装备、补给商店、六任务、组队、聊天与重新连接。
- 带校验和有效备份的版本化存档；关键操作写盘失败回滚；重复 RPC 不重复发奖；协议、凭据及四人容量限制。
- 复用参考项目图像、音频与字体，记录路径和 SHA-256；生成仙术士动作图并保存提示词。未复制上游导入缓存。来源属性/经验与暂定战斗、装备、任务数值分别标记。
- 客户端支持键位设置、目标选择、生命/体力/经验数字、任务追踪和常用面板。修复断线后的握手计时器、旧 revision 快照、组队面板反复刷新和无界面音频退出问题。
- 四目标打包脚本、服务启动脚本及 systemd 示例、GitHub Actions 已配置；macOS 包处理中文可执行文件名和临时签名。

### 验证记录

本机引擎路径：`/private/tmp/qqsg-engine/Godot.app/Contents/MacOS/Godot`。其他开发者将下列 `$GODOT` 替换为自己的路径。

| 命令/检查 | 实际结果 |
| --- | --- |
| `"$GODOT" --version` | `4.7.2.stable.official.ed1daf0bf` |
| `python3 tools/check.py --godot "$GODOT"` | PASS：数据引用、引擎导入、81 个单元检查，0 失败；四客户端网络测试通过 |
| 网络测试内容 | 实际服务端 + 四客户端进程；移动、互见、任务、重复请求、组队、聊天、重连及磁盘奖励检查通过；另验证版本错误、凭据错误、第五玩家拒绝 |
| 单元测试内容 | 属性/经验/战斗、库存事务、掉落归属、完整六任务链、满包/体力/距离/死亡边界、写盘失败回滚、重启恢复与损坏存档备份恢复通过 |
| `python3 tools/package.py macos --godot "$GODOT"` 与 `python3 tests/export_smoke.py macos` | 最终版本本机与 macOS runner 均成功导出并通过无界面启动检查 |
| `python3 tools/package.py macos-server --godot "$GODOT"` 与 `python3 tests/export_smoke.py macos-server` | 已成功导出；独立服务端就绪和存档检查通过 |
| `"$GODOT" --path . tests/render.tscn -- --preview=world --map=west --output=/private/tmp/qqsg-final.png` | 使用真实图形窗口截图检查；场景为模拟数据，不作为实机联机证据 |
| Windows 客户端、Linux 服务端 | 对应 Windows / Ubuntu runner 构建和启动检查均 PASS |
| Windows + macOS 两台机器局域网 | 待验证：连接、防火墙、完整合作篇章、断线及服务重启 |

存档损坏测试会有一条“已从有效备份恢复”预期警告；该测试通过不代表忽略其他引擎错误。完整检查脚本将 SCRIPT ERROR / ERROR 视为失败。

### 已知问题与下一步

- 目前是可游玩原型，地图连接、怪物、装备和多数技能参数仍为暂定设计。1–10 级基础成长有来源，不能将暂定数据称为官方数值。
- 简化平台碰撞、怪物追击和动作动画；部分技能表现未还原完整原版。每次技能落盘只适用于当前四人规模。
- 客户端凭据按 IP/端口/本地档案保存；更换服务器地址需迁移对应凭据。备份服务端存档和客户端凭据的操作见 PLAYING.md。
- 下一步进行两机联机验收；后续按实际反馈调整战斗节奏、动作与地图内容。

## 2026-09-25 / Windows 构建编码修复

首次 CI 的 Ubuntu 完整检查及 Linux 服务端构建/启动通过，Windows 在读取中文 JSON 时因系统默认 CP1252 失败。所有 Python 工具和测试显式使用 UTF-8 读取数据、解析引擎输出并输出日志，避免依赖系统语言；构建记录和 GITHUB_ENV 同样固定 UTF-8。

本机最终 macOS 客户端与服务端重新导出、启动检查均通过；营寨背包面板完成图形窗口检查。编码修复后 `python3 tools/check.py --godot "$GODOT"` 再次 PASS（81 项单元检查及四客户端网络测试）；Python 编译检查通过。推送触发四目标复验。跨 Windows/Mac 实机联机仍待验证。

## 2026-09-25 / 四平台交付结果

提交 `d958fde` 的 [GitHub Actions #2](https://github.com/syjsion/qqsg/actions/runs/36086831903) 全部成功：Ubuntu 完整检查（81 项单元检查、四客户端网络测试）、Windows 客户端、macOS 客户端、macOS 服务端、Linux 服务端。各构建任务执行 `tools/check.py --skip-network`、`tools/package.py <target>`、`tests/export_smoke.py <target>`，结果均 PASS。四个 zip artifact 已上传，保留 14 天。

开发者可在该运行的 Artifacts 下载同一提交的全套包。当前提交仅记录验收结果，无运行时代码修改。Windows + macOS 两台真实电脑联机、防火墙及完整合作流程仍为待验证，不以 CI 无界面启动替代。

## 2026-09-29 / 0.1.1 体验与统一源码启动

- 根目录 start.command 集中实现引擎查找/版本检查、资源导入、服务端就绪等待、客户端启动、状态查询和保存后停止。默认沿用旧存档；客户端退出后保持开服。进程实例身份校验、启动锁与双栈端口预检避免误用其他进程及重复开服。
- 服务端新增私有控制目录，停服存档失败继续运行并回报；监听失败时不写存档。协议升 v2，内容和包版本 0.1.1，存档 v1 不变，测试覆盖旧 content 标记读取。
- 攻击按施法时间播放，受击变色，技能效果区分；怪物死亡一次性播放并淡出、不可选中；奖励只结算一次。首领预警位置锁定，范围与真实判定一致。
- 登录后的意外断线支持五次自动重连和取消；明确拒绝终止重试。恢复角色及新快照，不重发经济请求。
- 已执行：完整引擎导入、96 项单元检查（0 失败）、原四客户端网络测试、真实服务重启/角色和奖励恢复、重试取消/耗尽/版本凭据拒绝、停服保存失败；分别 PASS。
- `python3 tests/launcher.py --godot "$GODOT"` PASS：真实服务进程启动、并发、复用、中文空格路径、缺少引擎、配置冲突、端口冲突不改存档、状态与安全停服。客户端子进程启动参数使用捕获替身验证，不冒充实际客户端游玩。
- 真实图形窗口已检查营寨战斗特效、受击、死亡、首领预警截图；重连状态与取消按钮也已完成截图检查。截图使用模拟场景，不替代双机联机。
- 已知边界：启动器面向本机 macOS 源码，依赖 Python 3；下载包启动方式保留。Linux CI 可以测试其 Unix 进程逻辑，Windows 不运行此脚本。未新增位图，复用素材和程序效果记录在 ASSETS.md。
- 下一步：Windows/Mac 两台真实电脑的联机验收仍待验证，重点检查防火墙、长时间合作、网络中断和安全停服。

最终本机验证命令：`python3 tools/check.py --godot .tools/Godot.app/Contents/MacOS/Godot`，结果 CHECK_RESULT PASS（96 项、NETWORK_RESULT、RECONNECT_RESULT、LAUNCHER_RESULT 全部 PASS）。`python3 -m py_compile start.command tests/launcher.py tests/reconnect.py tools/check.py` 通过。重连保留当前服务会话的技能冷却，避免断线刷新冷却。

### 0.1.1 交付结果

提交 `11bb4a7` 的 [Actions #3](https://github.com/syjsion/qqsg/actions/runs/36550407858) 全部成功：Ubuntu 完整测试（含 96 项单元检查、四客户端网络、服务重启重连、启动器）、Windows/macOS 客户端与 macOS/Linux 服务端构建和导出后启动。四份 artifact 已上传。

本机 `python3 tools/package.py macos --godot "$GODOT"` / `macos-server` 及相应 `python3 tests/export_smoke.py <target>` 均 PASS，build 中两份 macOS zip 已更新至 0.1.1。此处无界面启动及模拟场景截图不代表两台实机合作验收。

## 0.2.0 / 掉落与装备强化

- 新增 GearRules、LootRules。装备按实例管理，背包容量仍 24 格；买入装备/掉落生成实例，拾取转移原 ID，换装不丢强化状态。新装备八级精良、强化石与 Boss 每人独立产物均使用暂定数值。
- 巴郡商人强化页支持属性预览、消耗、真实成功率、三败保底与结果；失败扣费但不降级，达到 +6 停止。强化出售有确认，已穿戴不能直接卖出。
- 协议 v3 / 内容 0.2.0 / 存档 v2。旧档转换前独立保存原始字节备份，稳定实例 ID 防止重复迁移；非法状态拒绝加载。强化 expected_revision 防止跨请求和重连重放扣费，磁盘失败恢复装备、资源、保底与 RNG。
- `python3 tools/check.py --godot .tools/Godot.app/Contents/MacOS/Godot` 最终完整 PASS：157 项单元检查、原四客户端网络、重连、真实网络强化（同 RPC 重放、新序号旧修订、服务重启后旧修订拒绝与准确扣费）、启动器测试。100% 判定包含显式保证分支；装备满包、职业等级限制和迁移备份冲突均纳入最终检查。
- 迁移往返测试按装备字段核对语义，避免 JSON 整数/浮点表示造成误报；数据完整性仍校验。强化页已用真实图形窗口截图检查，模拟场景显示属性变化、100% 保底和资源消耗，无引擎错误。
- 下一步：双机 Windows/Mac 实际合作仍待验证；副将未纳入本轮。

### 0.2.0 交付结果

提交 `2db6a77` 的 [GitHub Actions](https://github.com/syjsion/qqsg/actions/runs/36582320439) 全部成功：Ubuntu 完整测试（157 项单元检查、四客户端网络、重连、强化经济事务、启动器）、Windows/macOS 客户端及 macOS/Linux 服务端构建与导出后启动。四份 artifact 已上传，保留 14 天。

本机 `python3 tools/package.py macos --godot "$GODOT"` / `macos-server` 及各自 `python3 tests/export_smoke.py <target>` 均 PASS，build 中两份 macOS zip 已更新至 0.2.0。旧档迁移用隔离测试样本验证，未自动改动玩家实际存档；正式启动旧档时会执行迁移并备份。跨 Windows/Mac 两台实机联机仍待验证。

## 2026-10-01 / 0.2.1 现有界面与物品表现

- 暂停新玩法，改版所有已有页面及交互标记。木框/蓝绿底板九宫格、职业头像、技能与药品栏、24 格背包和两个实际装备位、购买/出售商店、强化、任务目标/奖励、队伍血条、设置、聊天、登录/重连、死亡回城与交易确认均接入图像。地面物品用对应贴图、品质/归属标记，邻近掉落名称避让；补齐原先未显示的装备商人。
- GameInterface、ItemSlot、UIArt 分离页面绑定、交互组件和资源投影。单击查看，双击药品/装备，材料不发送使用请求，右键只提供适用操作；模板装备不显示虚构实例编号。界面选择绑定稳定实例 ID，库存 revision 刷新保留有效选择/滚动；队伍血条、冷却与 NPC 距离增量更新，不按快照重建整页。
- 商店保留每次一件及强化装备出售确认。等待匹配服务端回执期间禁用重复提交，不预扣资源或应用装备。客户端提示职业/等级、容量、距离（包括高度）、金币与材料限制；服务端仍唯一验证和结算。断线清空待处理，不重放经济请求。包/展示版本 0.2.1，协议 v3 / 内容 0.2.0 / 存档 v2 不变，无迁移。
- 复用原药品/铁剑/格子/技能/NPC，新增三张 imagegen 内置生成图。源文件、生成提示词、尺寸及 SHA-256 均记录；未复制上游导入缓存。提示框和右键菜单内嵌视口，菜单限制边界，长角色名省略显示并保留完整悬停提示。

### 验证记录

引擎：`.tools/Godot.app/Contents/MacOS/Godot`（4.7.2）。

| 命令/检查 | 实际结果 |
| --- | --- |
| `python3 -m py_compile tools/import_ui_assets.py tests/visual.py tools/check.py tools/package.py` | PASS |
| `git diff --check` | PASS |
| `"$GODOT" --headless --path . tests/ui.tscn` | UI_RESULT：64 检查，0 失败；真实单击/双击/右键输入、选择/失效、待处理、NPC 双轴距离、药品/职业限制、交易确认、强化回执/保底/上限、队伍增量和重连取消 |
| `python3 tools/check.py --godot "$GODOT"` | 最终 CHECK_RESULT PASS：资源/图集/来源哈希、157 项单元检查、64 项 UI、四客户端网络、重连、强化事务、启动器 |
| `python3 tests/visual.py --godot "$GODOT" --output /private/tmp/qqsg-visual-021-final` | 最终 16 场景截图成功并人工复查：含空包/满包、长名字、仙术士与 960×700 窗口、交易确认、断线、死亡、掉落及右键菜单；无引擎错误。修正按钮图标空间、菜单图标尺寸、弹窗边界、掉落名称遮挡和退出时 Ogg 音频释放 |
| `python3 tools/package.py <target> --godot "$GODOT"` | Windows/macOS 客户端、macOS/Linux 服务端最终提交 `1638f88` 本机导出成功，BUILD.txt 记录该提交；CI 各平台构建和启动均 PASS |
| `python3 tests/export_smoke.py macos` / `macos-server` | 本机导出后启动均 PASS；服务端就绪及存档检查通过 |
| Windows + macOS 两台机器 LAN | 待验证，不以 UI 请求捕获替身、模拟截图或导出启动检查代替 |

界面预览：[背包](screenshots/bag-0.2.1.png)、[商店](screenshots/shop-0.2.1.png)、[强化](screenshots/enhance-0.2.1.png)。截图使用模拟角色与库存，不是实机联机证据。

### 已知边界与下一步

- 这是原版风格的界面改版，生成图标和窗口不等同于官方资源。装备仅支持现有武器与护甲；不新增拖拽整理、卸装、批量交易或副将。
- 背包网格按装备实例排序，再按材料/药品 ID 分组。物品数量变化可能移动格子，选择以 ID 保留，位置不写入存档。选中失效时清除详情，不自动对另一个实例执行操作。
- 生成素材部分细节和原像素素材精细度不同；今后替换图标只需稳定 ID 资源映射并同步来源/哈希。新物品/技能必须增加贴图，完整检查拒绝缺图。
- 下一步根据实际游玩反馈调整可读性；跨 Windows/Mac 双机合作、防火墙和长时间断线恢复继续待验证。

### 0.2.1 交付结果

提交 `1638f88` 的 [GitHub Actions](https://github.com/syjsion/qqsg/actions/runs/36820326570) 全部成功：Ubuntu 完整检查（157 项规则检查、64 项 UI 检查、四客户端网络、重连、强化事务及启动器），Windows/macOS 客户端与 macOS/Linux 服务端构建、导出后启动。四份 artifact 已上传，保留至 2026-10-15。

本机四目标包已更新，macOS 客户端及服务端最终导出包启动均 PASS。截图目录添加 `.gdignore`，文档预览图不作为游戏资源导入。本次交付记录提交只补充文档和文档目录导入标记，无运行时代码修改；未修改实际玩家存档或凭据。双机局域网合作仍待验证。

## 2026-10-01 / 0.3.0 名将副将

- 增加 CompanionRules 与三个固定技能模板：赵云近战、黄忠远程、华佗治疗；收藏最多 12 名，同名独立实例，出战 1 名。独立引导任务赠赵云，Boss 每个人每个奖励轮次有 50% 概率掉落招募令，简雍附近自选招募，满栏不扣令牌。
- 副将由服务端跟随和助战，不主动搜寻未交战怪物；怪物可选副将，Boss 同时检查玩家和副将范围。治疗优先主人／自身／同图队员，阈值 70%，不复活目标。击杀复用主人奖励链，只结算一次，额外 20% 经验培养出战副将，等级不超过主人／10 级。
- 受伤、倒下恢复、技能冷却与剩余战斗锁持久化；收回／切换／断线／重启不刷新状态。出战、收回和放生需要存活且脱战，放生确认显示精确实例，无返还；模式可在战斗中切换。事务回滚包含副将身体、生命、经验、事件及所有原有奖励和 RNG，失败后自动动作一秒后再试。
- 12 格图像收藏页、角色预览、能力／技能图标、状态、招募和放生确认；默认 G 可改键，HUD 展示当前副将。三张 4×4 名将动作图和一张 4×2 图标图集使用 imagegen 内置工具生成；完整提示词、尺寸与哈希入 manifest。场景显示紧凑姓名／等级，悬停显示主人，不混入玩家敌方目标列表。
- 协议 v4／内容及包 0.3.0／存档 v3。v1 先迁移装备，v2 补空收藏，保留凭据与所有旧进度；独立保留原始旧档字节，版本或备份冲突拒绝加载。未修改实际玩家存档、凭据；测试全部使用隔离目录。
- 新四客户端测试暴露同时退出时 ENet 内部转发向关闭通道发送错误。关闭本项目不需要的 SceneMultiplayer server_relay，并在发送／模拟前清理已关闭 peer；客户端互见继续通过权威快照。修正后新增网络测试及原联机／重连测试均无此错误。

### 验证记录

引擎 `.tools/Godot.app/Contents/MacOS/Godot`，4.7.2。

| 命令／场景 | 实际结果 |
| --- | --- |
| `python3 -m py_compile tests/companions_network.py tests/visual.py tools/check.py` | PASS |
| `git diff --check` | PASS |
| `"$GODOT" --headless --path . --script tests/unit.gd` | 222 项规则检查，0 失败；含收藏／容量／任务／实例／成长／跟随／治疗／普通怪物与 Boss／迁移，以及自动击杀、治疗、受伤写盘失败的完整回滚 |
| `"$GODOT" --headless --path . tests/ui.tscn` | 79 项 UI 检查，0 失败；副将 12 格、重复实例选择、血量增量、待处理／脱战／距离限制、放生确认、不预先删除、选择失效、HUD 和改键 |
| `python3 tests/companions_network.py --godot "$GODOT"` | PASS：4 个真实客户端、副将互见、同序号重放／旧收藏修订、Boss 个人招募令拾取、真实服务重启恢复，严格拒绝日志中的引擎错误 |
| `python3 tools/check.py --godot "$GODOT"` | CHECK_RESULT PASS：资源／图集／来源校验，222 项规则、79 项 UI、原四客户端网络、重连、新副将四客户端、强化事务、启动器均 PASS |
| `python3 tests/visual.py --godot "$GODOT" --output /private/tmp/qqsg-visual-030-complete` | 26 场景图形截图成功，无引擎错误；新增副将场景及受影响页面人工复查。修正长名称重叠、倒下文字、图集边缘串色和小窗口详情高度；最终截图另存 docs/screenshots |
| `python3 tools/package.py <target> --godot "$GODOT"` / `python3 tests/export_smoke.py <target>` | 四目标本机导出成功，BUILD.txt 记录 `88882b8`；本机 macOS 客户端／服务端启动 PASS，Windows／Linux 启动由对应 CI runner 验证 PASS |
| Windows + macOS 双机实际 LAN | 待验证，不以模拟截图或本机进程测试代替 |

网络副将测试为确定性夹具，强制 Boss 招募令概率为 100% 以核对四份个人掉落；正式内容仍为 50%，规则测试另外覆盖 0%／100%。存档损坏测试的有效备份恢复警告属于预期，其他引擎错误不会忽略。

预览：[副将页](screenshots/companions-0.3.0.png)、[小窗口倒下状态](screenshots/companions-down-0.3.0.png)、[三名将助战](screenshots/companions-battle-0.3.0.png)。均为模拟数据的真实图形窗口截图，不是双机联机证据。

### 已知边界与下一步

- 固定技能与全部副将数值为暂定设计；无随机资质、装备、洗练、合成、技能书或附体加成。三名角色是原创风格素材，帧间锚点仍有细微差异。
- 跟随复用简化平台／梯子控制，越距一秒归位；不提供复杂寻路、玩家手动指定副将目标或阵型。只有出战副将推进恢复和冷却，离线与收回暂停。
- 事务逐次写全档，支持当前最多四人；自动战斗也增加落盘次数，扩容前需要重新评估存储策略。
- 下一步两机 LAN 验收及实际战斗平衡反馈；长时间四人合作、网络抖动和防火墙仍待实机验证。

### 0.3.0 交付结果

提交 `88882b8` 的 [GitHub Actions](https://github.com/syjsion/qqsg/actions/runs/36824192554) 全部成功：Ubuntu 完整检查（222 项规则、79 项 UI、原四客户端网络、重连、新副将四客户端、强化事务及启动器），Windows/macOS 客户端与 macOS/Linux 服务端构建、导出后启动。四份 artifact 已上传，保留至 2026-10-15。

本机 build 中四目标包已更新为 0.3.0，macOS 客户端与独立服务端最终启动检查均 PASS。此处只补充交付记录，无运行时代码变化；两台真实 Windows/macOS 机器的合作游玩仍待验证。更新常驻源码服务端需先 `./start.command stop`，再 `./start.command`，使用相同存档路径执行兼容迁移。
