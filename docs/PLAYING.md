# 游玩与服务器部署

## 本机源码一键启动（macOS）

在仓库根目录双击 `start.command`，或终端运行 `./start.command`：自动找到 Godot 4.7.2、导入资源、启动后台服务器，等就绪后打开客户端并连接本机。需要 Python 3；若缺少引擎，运行 `python3 tools/engine.py`，或通过 `--godot /path/to/Godot` 指定。脚本不会自动下载工具。

```bash
./start.command                         # 开服并进入
./start.command client --profile=roommate --name=室友 --job=XS
./start.command client --connect=192.168.1.10
./start.command server                  # 仅后台开服
./start.command status                  # 查看 PID、端口、存档、日志
./start.command stop                    # 保存后停止本脚本管理的服务器
```

关闭客户端或启动器终端后服务器继续运行。相同配置再次启动会复用服务器；不同配置须先 stop。可指定 `--port`、`--config` 和 `--data-dir`，默认沿用 deploy/server.json 的端口与 user://server 存档，不创建替代空档。状态与日志保存在 `.runtime`，实际存档绝对路径由 status 显示。stop 保存失败时保持开服，处理磁盘或权限问题后再次 stop；脚本不强杀进程。

此入口用于源码开发，不随下载包要求玩家安装 Python；下载包仍按以下说明启动。不要同时用其他启动方式打开同一份服务端存档。

## 选择下载包

客户端：Windows 下载 `qqsg-windows`，Mac 下载 `qqsg-macos`。服务器任选一台 Mac 或 Linux x64 电脑常驻运行，下载对应 `server` 包。先解压 GitHub artifact，再解压里面的游戏 zip。

## 启动服务器

Mac：解压 `qqsg-macos-server.zip`，双击 `start-server.command`。Linux：解压 `qqsg-linux-server.zip`，执行 `chmod +x start-server.sh SanguoServer.x86_64` 后运行 `./start-server.sh`。

出现 `SERVER_READY port=24567` 表示成功。保持该进程运行，关闭客户端不会结束服务器。数据保存在启动脚本旁的 `server-data`。
停止服务前，尽量让客户端先退出。关键交易每次保存，非关键战斗状态每 30 秒保存；强制终止可能回退最近的非关键状态。

修改同目录 `server.json` 后重启生效：

| 设置 | 默认 | 范围 |
| --- | --- | --- |
| port | 24567 | 1024–65535，UDP |
| max_players | 4 | 1–4 |
| xp_multiplier | 1 | 大于 0，不超过 100 |
| drop_multiplier | 1 | 0–10；小数部分按概率多掉一次 |
| bind_address | * | 所有本机接口，也可填指定接口 IP |

两端在同一局域网；系统防火墙允许服务端的 UDP 24567。路由器开启无线客户端隔离时需关闭隔离或连接同一可互访网络。无需公网端口映射。

## 启动客户端

Windows：运行 `Sanguo.exe`。Mac：打开 `Sanguo.app`。Mac 包采用本机签名，无 Apple 公证；若系统提示未识别开发者，可在“系统设置 → 隐私与安全性”中对本次下载选择“仍要打开”。

输入服务器电脑的局域网 IP。与服务端同机时可用 `127.0.0.1`。初次连接填写名字并选择剑侍或仙术士；后续同一 IP、端口和本地档案名自动恢复原角色，不会因改名字/职业选项重建角色。

每个本地档案对应一个角色。需要在一台电脑开两个客户端时使用不同档案名，并通过 `-- --profile=roommate` 区分。

## 旅途流程

1. 前往巴郡简雍处按 E 或点击 NPC。领取“初到巴郡”，再交付任务。
2. 在装备商人处购买药品，B 打开行囊使用或装备。
3. 向右走到传送点，按 ↑ 前往江陵西郊。Tab 选择怪物，A/S/D 施放技能，C 拾取自己的掉落。
4. T 打开伙伴列表，邀请同伴；对方在 T 面板接受。仙术士在队伍面板选择队友作为治疗目标，也可点击场景中的队友。
5. 依次完成除蛇、采药、清理山道、营寨探路任务，合作挑战邓茂，再回巴郡交付。

技能随等级解锁。地图木梯处按上下攀爬；首领蓄力时可跳跃或离开地面预警范围。倒下后点击“回巴郡复活”，不丢装备。城镇恢复速度高于野外。

同图、距怪物 900 像素内的存活队友共享经验和击杀任务进度；经验均分。掉落轮流归属，角色名字不同并不影响归属。材料需各自拾取，满背包时掉落保留，其他人不能代领。

## 备份与恢复

服务端停机后备份完整 `server-data`，包括 `world.json` 和 `world.backup.json`。主文件校验失败时自动尝试上一份有效备份，两份均无效则拒绝启动，避免覆盖原数据。禁止同时启动两个服务端使用同一数据目录。

客户端 `credentials.json` 是角色登录凭据，需要随本机档案备份，不要分享。它位于 Godot 用户数据目录：

- Windows：`%APPDATA%\Godot\app_userdata\三国 · 同游\`
- macOS：`~/Library/Application Support/Godot/app_userdata/三国 · 同游/`

更换客户端电脑时复制凭据文件；若服务器 IP 或端口改变，需要将该文件中对应旧地址的键改为新地址，保留值。它不是角色存档，不能用客户端文件改等级或装备。

## Linux 常驻服务

将包放在 `/opt/qqsg`，创建 `qqsg` 系统用户并授予目录写权限，将示例 `qqsg.service` 放到 `/etc/systemd/system/`，执行 `systemctl daemon-reload` 和 `systemctl enable --now qqsg`。使用 `journalctl -u qqsg -f` 查看日志。修改路径时同时修改 service 的 WorkingDirectory 与 ExecStart。

## 版本与排障

连接失败先检查服务端终端、IP、UDP、防火墙。版本不匹配时从同一 Actions 运行下载全套客户端和服务端；不要混用不同版本。
“角色已经在线”时关闭旧客户端并稍候重试；“凭据无效”时恢复正确凭据，或换新的本地档案名创建角色。
“保存失败，操作已撤销”时检查服务器磁盘空间和目录权限；此次操作不会消耗物品或金钱。

## 自动重连

成功登录后短暂断网或服务重启，客户端会按 1、2、4、8、8 秒间隔最多重连五次，并显示取消按钮。单次握手最多等待 8 秒。重连保留连接信息，用已有凭据恢复角色，不重新发送断线前的交易或任务请求。版本/凭据错误、人数限制等明确拒绝需要处理后手动连接。0.1.1 客户端和服务端应一起更新，已有角色存档继续兼容。
