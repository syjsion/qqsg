# 三国 · 同游

Godot 4.7.2 开发的 QQ 三国风格局域网合作游戏。Windows / macOS 客户端，macOS / Linux 独立常驻服务器，最多 4 人。

首版：剑侍、仙术士，1–10 级，巴郡、江陵西郊、营寨前门；组队、攻击治疗、怪物首领、背包装备、商店、六个任务和服务端存档。
使用原参考素材重建小篇章，已接入研究资料中的等级基础属性与经验。部分技能、怪物、装备、掉落与任务参数为暂定设计，不宣称完整复现原版。

## 下载与游玩

在仓库 **Actions → Test and package → 成功运行 → Artifacts** 下载对应平台包。服务端只需要其中一位玩家运行，其他人输入该电脑的局域网 IP。详细说明见 [游玩与部署](docs/PLAYING.md)。

## 源码运行

安装 Godot 4.7.2 Standard（无需 .NET），用编辑器导入 `project.godot`。

```bash
# 设置为本机 Godot 可执行文件路径
export GODOT=/path/to/Godot
# 终端一：独立服务器
./scripts/server.sh
# 终端二：客户端；也可在编辑器按 F6/F5 运行主场景
./scripts/client.sh
```

客户端连接 `127.0.0.1:24567`；室友连接服务器的局域网 IP。键位：方向键、空格、A/S/D、C、Tab、E、B/Q/T；设置中可修改。

## 验证与打包

```bash
python3 tools/check.py --godot "$GODOT"
# 自动下载固定版本引擎与桌面导出模板
python3 tools/engine.py --templates
# 对应平台 runner 执行；输出 build/qqsg-<target>.zip
python3 tools/package.py macos --godot "$GODOT"
```

CI 自动测试及生成 `windows`、`macos`、`macos-server`、`linux-server` 四个包。

## 开发资料

- [开发计划](docs/PLAN.md)
- [开发手册与进度](docs/DEVELOPMENT.md)
- [协议、数据与存档](docs/ARCHITECTURE.md)
- [数值来源和差异](docs/DATA.md)
- [素材来源与生成记录](docs/ASSETS.md)

素材参考 [Time1996/QQSanGuo](https://github.com/Time1996/QQSanGuo)，数值参考 [WanderingQuantum/qqsganalysis](https://github.com/WanderingQuantum/qqsganalysis)，领域结构参考 [qqsg_struct](https://github.com/ziwenhahaha/qqsg_struct)。参考素材的原始声明与代码许可分开记录在素材文档中。本项目用于个人局域网学习游玩。
