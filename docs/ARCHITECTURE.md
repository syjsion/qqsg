# 架构、接口与数据约定

## 入口与模块

`main.gd` 根据 `--server` 或导出 feature `dedicated_server` 选择入口。服务端只创建 Simulation 和 ENet，不创建图形/音频；客户端创建 Game 和 WorldView。

| 模块 | 职责 | 不应承担 |
| --- | --- | --- |
| core/catalog.gd | 内容和属性、经验成长 | 网络和界面 |
| core/movement.gd | 固定步长平台/梯子运动 | 奖励和存档 |
| core/combat.gd | 伤害、治疗纯函数 | 动画触发和网络 |
| core/inventory.gd | 容量、堆叠、装备规则 | UI |
| core/simulation.gd | 世界权威、角色、怪物、组队、任务和事务 | 渲染 |
| core/save_store.gd | 校验、备份和原子写入 | 游戏规则 |
| net/session.gd | 身份握手、RPC、去重、广播 | 直接决定战斗公式 |
| client/game.gd | 输入、界面、本地预测、音效 | 修改权威状态 |
| client/world_view.gd | 原素材绘制、动作、远端插值和飘字 | 战斗结算 |

多人开发时按模块拆分工作；新增静态内容优先修改数据表，新增玩法先在 Simulation/纯函数与测试落地，再接网络和 UI。

## 协议 v4

统一 RPC 节点为 `/root/Session`，服务端 peer ID 为 1。客户端连接后 8 秒握手超时，未握手连接在服务端 5 秒后关闭。最多 4 个已认证角色。

| 调用 | 方向与通道 | 数据 |
| --- | --- | --- |
| hello | C→S，可靠 0 | protocol、content、凭据、名字、职业 |
| welcome / rejected | S→C，可靠 0 | 角色 ID 与凭据 / 失败原因 |
| move_intent | C→S，有序不可靠 1 | 单调输入序号、二维方向、跳跃边沿 |
| intent | C→S，可靠 0 | 请求序号、操作名、参数 Dictionary |
| response | S→C，可靠 0 | seq、ok、message、revision |
| snapshot | S→C，有序不可靠 2 | DEFLATE 压缩的 Variant Dictionary（禁用对象反序列化） |
| state_update | S→C，可靠 0 | 事务后的完整状态 |
| world_event / chat_message | S→C，可靠 0 | 飘字/施法/升级事件、聊天文本 |

正常 20 Hz 快照。压缩包超过 1200 字节时降为可靠 10 Hz，避免 UDP 分片造成整帧丢失。快照只含当前地图实体、自身完整状态与精简队伍名单，不含令牌。客户端丢弃过时快照；本地重放尚未确认的输入，远端位置插值。

请求操作：`skill(skill,target)`、`pickup(drop)`、`equip(gear_id)`、`use(item)`、`buy(item)`、`sell(item)`、`quest(quest)`、`portal()`、`respawn()`、`invite(target)`、`accept()`、`leave_party()`。

各连接请求序号递增，缓存最近 64 个回执；重复请求回发原结果，过期请求拒绝重做。断线重连后的幂等依靠持久任务状态和掉落 ID，不沿用旧连接序号。
客户端只上传意图。距离、职业、技能等级、冷却、体力、库存、价格、掉落归属等均由服务端检查。

## 数据与身份

`data/content.json` 包含 classes/skills/items/monsters/quests/maps；稳定 ID 为内容引用键，中文名称只用于显示。`data/progression.json` 为来源可追溯的属性/经验；`data/art.json` 为视图资源映射，不被服务端规则依赖。

Catalog 中协议、内容和存档版本分别是 `PROTOCOL=4`、`CONTENT=0.3.0`、`SAVE_VERSION=3`。改变结构时升级对应版本，并提供迁移或明确拒绝旧数据。

角色 ID 为服务端生成的随机 96 位十六进制串；登录凭据为随机 256 位值。客户端按服务器地址/端口/本地档案保存令牌，服务端仅保存令牌 SHA-256 到角色 ID 的索引。无公网账号系统，凭据不可分享。首次建立角色后网络在凭据到达客户端前中断可能留下未领取角色，重新创建将产生新角色，管理员可离线清理。

## 持久化和故障

存档外层为 `{payload: JSON字符串, sha256: 校验摘要}`。payload 含 version/content、records、令牌摘要索引、drops、next_drop、loot_turn。记录保留等级、经验、金钱、装备、背包、任务、击杀、生命/体力和所在地图；临时输入、在线 peer、队伍、邀请和玩家技能冷却不跨服务端重启；副将的生命、技能冷却、恢复进度与主人剩余脱战等待单独持久化。

每个成功的客户端状态操作执行：备份内存状态 → 检查并修改 → 更新 revision → 保存整体快照 → 返回成功。写盘失败恢复角色、怪物、掉落、邀请、随机状态等；不会先发成功再失败。代价是每次技能也落盘，当前只面向 4 人，扩容前需实现事务日志。

写入 `.tmp` 后 flush/close，再原子 rename；备份仅来自校验有效的主文件。磁盘强制断电的文件系统持久保证取决于操作系统，当前不是数据库级 WAL。存档目录禁止共享给多个同时运行的服务器。

重启后角色回所在地图安全点，保留生命体力；死亡角色需要回城复活。怪物重新刷新，已保存掉落仍保留原归属。服务端周期保存非关键状态，已完成关键操作逐次保存。停止前建议先让客户端退出。

## 已知设计边界

地图按原素材重建，平台为单向水平表面和梯子，不支持斜坡/复杂导航；怪物在所属地面段追击。没有公网身份认证、主机迁移和分布式服务。小红猪使用上游提供的循环动作，未拆成完整独立战斗动作。玩家死亡播放倒下姿态，怪物死亡动作播放一次并在 1.2 秒内淡出，随后按刷新计时重生。

## 0.1.1 动画、连接和本机控制

快照增加 anim_started、hurt_until、death_started、cast_skill；怪物还包含 windup_started、attack_range。均使用服务器模拟时间，属于临时数据，不写入存档。客户端动画按起始时间选帧，死亡不循环。蓄力期间怪物固定位置，结束后按该位置检查横向半径与纵向 70 像素；首领半径 170，普通怪 85，伤害和间隔不变。已有 v1 存档（含 0.1.0 内容标记）继续可读，旧协议客户端明确拒绝连接。

只有成功登录后的意外断线启动自动重连，间隔为 1、2、4、8、8 秒，单次握手上限 8 秒。取消、主动退出及服务端明确拒绝会结束重试。重连清空旧快照、输入队列和序号，不缓存重发经济操作。Session.reconnecting 通知界面展示状态与取消按钮。

源码启动器通过 --control-dir 和随机 --instance-id 指定私有本机控制目录。服务端监听成功且存档可用后原子写 ready.json；stop.json 的实例标识匹配才处理停服。保存成功写 stop-result.json 后退出；失败写错误结果并继续服务。没有对应远程管理 RPC。启动器验证 PID 命令中的实例标识，只管理自己启动的服务，使用文件锁防止并发启动；端口冲突不修改存档。不要通过其他脚本同时使用同一存档目录开服。

## 0.2.0 装备实例、掉落与强化事务

当前版本为协议 v3 / 内容 0.2.0 / 存档 v2。inventory 仅保存可堆叠物品数量；gear 为实例 ID → `{id,item,enhance,failures,revision}`；equipment 的 weapon/armor 引用 gear 实例 ID。掉落生成时就确定装备实例，拾取原样转移，不能重新生成或改属性。实例在角色和地面间全局唯一。

GearRules 管理装备属性、消耗预览和强化；LootRules 负责掉落抽取，InventoryRules 负责容量和穿戴。UI 不结算概率或奖励。新增 `enhance(gear_id,expected_revision)`、`sell_gear(gear_id)`，equip 改为 gear_id；原 sell(item) 仅用于可堆叠物品。

强化结果放在回执 enhancement 字段中；ok=true 表示事务已落盘，enhanced=false 表示合法的概率失败，资源仍消耗。每次合法结算都提升装备 revision。重复同一 RPC 序号回放缓存回执；换序号或重连后的旧 expected_revision 拒绝执行，避免重复扣费与重新抽取。角色/装备/保底/随机状态按现有整体事务回滚机制处理，保存失败不发成功结果。

v1 迁移使用角色、背包位置、穿戴槽或掉落 ID 派生稳定实例 ID，重复解码结果一致。先校验旧档、保存带摘要文件名的原始副本，转换后再原子写入 v2。独立旧档备份不参与常规轮换。错误引用、重复实例、非法数量、超容量和非法强化等级均拒绝；主文件损坏仍尝试有效常规备份。

## 0.2.1 客户端界面组件

`client/game.gd` 保留会话、输入预测与战斗绑定；`GameInterface` 创建窗口和页面并转换操作为既有请求；`ItemSlot` 处理单击/双击/右键及图标、角标、冷却、提示；`UIArt` 缓存贴图与 AtlasTexture、创建九宫格皮肤并将服务端记录投影成背包格。规则与存档不依赖这些 UI 类。

`data/art.json` 新增 items/skills/portraits/characters/symbols/ui 稳定 ID 映射；值为 res:// 路径或 `{path,region:[x,y,width,height]}`。引用完整原图或图集区域，不修改原始位图；窗口缩放只在运行时完成。缺失当前内容的图标、越界区域、哈希不符由完整检查拒绝。

格子数量按照 InventoryRules 的 24 格及各物品堆叠上限计算；未穿戴装备 key 为原实例 ID，堆叠格 key 为 item ID + 分组序号。不提供位置存档或拖拽。库存 revision 改变时重建页面并保留有效选择/滚动位置；生命、技能冷却、队伍血条和 NPC 距离增量更新。菜单内嵌客户端视口并限制边界，控件消费鼠标事件。

界面经济请求使用一个待处理序号拦截重复点击，匹配回执才解除；断线清空待处理状态，不重放请求。装备强化沿用 expected_revision；失败回执与成功回执显示不同结果。UI 预览规则用于提示及禁用按钮，服务器仍验证职业、等级、容量、距离、资源及事务写盘。服务端结构和握手版本不变。

UI 回归入口为 `tests/ui.tscn`（真实控件输入、请求捕获替身，不是 LAN 测试）；图形截图入口为 `python3 tests/visual.py --godot <Godot> --output <临时目录>`。后者生成模拟页面，须人工检查 PNG，不能代替双机实测。

## 0.3.0 副将接口与存档

`CompanionRules` 负责独立实例、属性成长、经验和校验；Simulation 负责 AI、目标、伤害、治疗及事务。`content.companions` 为三个稳定模板 ID，所有新增数值标 provisional；art 记录独立动作图、头像、技能和招募令。

角色新增 `companions`（实例 ID→记录）、`active_companion`、`companion_mode`（assist/follow）、`companion_revision`、`companion_combat_remaining`。实例字段为 id/kind/level/xp/hp/recovery_remaining/skill_cooldown_remaining；实例 ID 为 comp_ 前缀加随机 128 位串，全档唯一。收藏修订只随获得、部署、模式和放生变化，生命和经验变化不使操作修订无意义地失效。

| intent 操作 | 参数（均需 expected_revision，即收藏修订号） | 附加验证 |
| --- | --- | --- |
| companion_recruit | kind | 简雍双轴距离、令牌、收藏容量 |
| companion_deploy | companion_id | 自有实例、存活、脱战 |
| companion_recall | 无 | 已出战、存活、脱战 |
| companion_mode | mode | assist/follow、存活 |
| companion_release | companion_id | 自有非出战实例、存活、脱战 |

快照新增 `companions` 同图数组，实体含 entity_type=companion、id、owner、owner_name、kind、name、level、map、位置、生命、朝向和动画。self 含完整收藏及 companion_stats；不暴露其他玩家的未出战收藏。运行身体独立放在 companion_bodies，以主人 ID 索引，不写位置/目标/动画到存档。

AI 伤害、治疗和怪物攻击通过内存备份与 checkpoint 提交，写盘失败恢复角色、身体、怪物、奖励、掉落、事件、输入和 RNG，自动动作一秒后再试。只有成功的持久化结果才广播。副将击杀复用一次性 _kill，由主人承担击杀者身份。60 Hz 更新身体，快照频率及大包回退规则沿用。

服务重启保留副将冷却和倒下恢复剩余秒数、主人剩余战斗锁；离线暂停计时。出战换图重建身体，不重置实例状态。收回暂停该副将的恢复与冷却。旧 v1 先转换独立装备再补副将字段；旧 v2 只补空收藏。读取旧档前留存原始字节，迁移备份冲突或失败则停止。

网络只使用客户端↔权威服务器 RPC，SceneMultiplayer 在建立连接前关闭 server_relay；玩家互见由 roster 和地图快照提供。发送前检查 ENet 状态／通道，避免四客户端同时退出时向已关闭连接发送。该配置不提供客户端间 RPC。
