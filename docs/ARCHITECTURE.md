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

## 协议 v1

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

请求操作：`skill(skill,target)`、`pickup(drop)`、`equip(item)`、`use(item)`、`buy(item)`、`sell(item)`、`quest(quest)`、`portal()`、`respawn()`、`invite(target)`、`accept()`、`leave_party()`。

各连接请求序号递增，缓存最近 64 个回执；重复请求回发原结果，过期请求拒绝重做。断线重连后的幂等依靠持久任务状态和掉落 ID，不沿用旧连接序号。
客户端只上传意图。距离、职业、技能等级、冷却、体力、库存、价格、掉落归属等均由服务端检查。

## 数据与身份

`data/content.json` 包含 classes/skills/items/monsters/quests/maps；稳定 ID 为内容引用键，中文名称只用于显示。`data/progression.json` 为来源可追溯的属性/经验；`data/art.json` 为视图资源映射，不被服务端规则依赖。

Catalog 中协议、内容和存档版本分别是 `PROTOCOL=1`、`CONTENT=0.1.0`、`SAVE_VERSION=1`。改变结构时升级对应版本，并提供迁移或明确拒绝旧数据。

角色 ID 为服务端生成的随机 96 位十六进制串；登录凭据为随机 256 位值。客户端按服务器地址/端口/本地档案保存令牌，服务端仅保存令牌 SHA-256 到角色 ID 的索引。无公网账号系统，凭据不可分享。首次建立角色后网络在凭据到达客户端前中断可能留下未领取角色，重新创建将产生新角色，管理员可离线清理。

## 持久化和故障

存档外层为 `{payload: JSON字符串, sha256: 校验摘要}`。payload 含 version/content、records、令牌摘要索引、drops、next_drop、loot_turn。记录保留等级、经验、金钱、装备、背包、任务、击杀、生命/体力和所在地图；临时输入、在线 peer、队伍、邀请、冷却不跨服务端重启。

每个成功的客户端状态操作执行：备份内存状态 → 检查并修改 → 更新 revision → 保存整体快照 → 返回成功。写盘失败恢复角色、怪物、掉落、邀请、随机状态等；不会先发成功再失败。代价是每次技能也落盘，当前只面向 4 人，扩容前需实现事务日志。

写入 `.tmp` 后 flush/close，再原子 rename；备份仅来自校验有效的主文件。磁盘强制断电的文件系统持久保证取决于操作系统，当前不是数据库级 WAL。存档目录禁止共享给多个同时运行的服务器。

重启后角色回所在地图安全点，保留生命体力；死亡角色需要回城复活。怪物重新刷新，已保存掉落仍保留原归属。服务端周期保存非关键状态，已完成关键操作逐次保存。停止前建议先让客户端退出。

## 已知设计边界

地图按原素材重建，平台为单向水平表面和梯子，不支持斜坡/复杂导航；怪物在所属地面段追击。没有公网身份认证、主机迁移和分布式服务。小红猪使用上游提供的循环动作，未拆成完整独立战斗动作。玩家死亡播放倒下姿态，怪物死亡立刻移除显示后按刷新计时重生。
