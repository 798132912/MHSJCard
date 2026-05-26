# 魔法少女卡牌项目协作规范

日期：2026-05-25

本文档是本项目给 AI 和协作者使用的工作规范。进入项目后，先读本文档，再根据任务类型读取对应设计文档。

## 必读文档

按任务相关性优先阅读：

- `工程说明.md`：当前工程状态、目录结构、主场景、脚本和表格管线。
- `游戏设定文档.md`：世界观、主题、资源含义和设计语境。
- `规则机制文档.md`：战斗资源、牌区、回合流程、伤害结算和形态规则。
- `卡牌效果文档.md`：卡牌字段、效果库和基础卡牌设计。
- `CardEffect机制文档.md`：`CardEffect` 表字段、枚举和 `value` 解析规则。
- `效果时机流程文档.md`：效果实例、触发时机、持续时间和移除流程。
- `敌人设计文档.md`：敌人字段、敌人行动、意图和 AI 逻辑。
- `数据表结构说明.md`：Excel/CSV 表格结构和当前数据管线。
- `表格规范文档.md`：三行表头、枚举、ID 和导出规则。
- `最低战斗UI清单.md`：最低战斗 demo 的 UI 信息位和交互要求。
- `美术资源规范.md`：图片尺寸、命名、目录和表格接入规范。
- `项目讨论记录_2026-05-19.md`：早期讨论和设计背景。

## 项目结构

```text
project.godot
  Godot 工程入口

scenes/
  Godot 场景

scripts/
  Godot 脚本

assets/
  美术资源

design_tables/excel/
  策划 Excel 源表

data/tables/
  Godot 读取用 CSV 导出表

docs/
  设计文档、规范和协作说明

tools/
  工具脚本
```

## 工作流程

功能开发或修改时：

1. 先读用户当前需求。
2. 根据任务类型阅读 `docs/` 下的相关设计文档。
3. 检查相关场景、脚本、表格和资源的当前实现。
4. 说明计划后再做大范围改动。
5. 小步实现，避免把无关重构混入同一次改动。
6. 修改后运行可行的验证命令。
7. 汇报修改文件、验证结果和剩余风险。

## Godot 规则

- 当前 Godot 版本：`4.6.2`。
- 本机命令行 Godot：

```text
D:\Godot\Godot_v4.6.2-stable_win64_console.exe
```

- GUI Godot：

```text
D:\Godot\Godot_v4.6.2-stable_win64.exe
```

- 主场景：

```text
scenes/combat/CombatScene.tscn
```

- 不要为了自动验证直接依赖 `%APPDATA%` 或 `user://logs`。
- 自动验证日志和临时用户数据放在项目内：

```text
.codex_tmp/logs/
.codex_tmp/userdata/
```

`.codex_tmp/` 必须保持在 `.gitignore` 中。

推荐无头启动检查：

```powershell
New-Item -ItemType Directory -Force -Path ".codex_tmp\logs" | Out-Null
& "D:\Godot\Godot_v4.6.2-stable_win64_console.exe" --headless --path "D:\魔法少女卡牌" --log-file "D:\魔法少女卡牌\.codex_tmp\logs\godot.log" --quit-after 3
```

通过标准：

- 进程退出码为 `0`。
- 输出和日志中没有 `SCRIPT ERROR`、`Parse Error`、`ERROR:`。

后续如果新增 `tools/verify_demo.gd`，正式验证应输出：

```text
VERIFY_DEMO_OK
```

## 表格规则

- Excel 源表位于 `design_tables/excel/`。
- CSV 导出表位于 `data/tables/`。
- 正常修改流程：

```text
修改 design_tables/excel/*.xlsx
运行 导出策划表到CSV.bat
Godot 读取 data/tables/*.csv
```

- 不要只手改 CSV 而不更新 Excel 源表。
- 表格字段和枚举规则以 `数据表结构说明.md`、`表格规范文档.md`、`CardEffect机制文档.md` 为准。
- 资源路径使用 Godot 路径，例如：

```text
res://assets/characters/player_star_battle.png
```

## 美术资源规则

- 资源放在 `assets/`。
- 文件名使用英文小写、数字和下划线。
- 具体尺寸和命名见 `美术资源规范.md`。
- 缺资源时，程序应显示占位图或文字，不应让 demo 崩溃。

## Git 规则

- 不提交以下目录：

```text
.godot/
.godot_user/
.git_upload/
.codex_tmp/
```

- 不提交临时日志：

```text
*.tmp
*.log
```

- 修改前注意工作区可能已有用户改动；不要回滚自己没做的改动。
- 大范围整理、表格迁移、资源改名需要在最终说明中列出影响范围。

## 当前 Demo 重点

当前最低战斗 demo 目标是验证：

- 从表格读取玩家、敌人、牌组、怪物行动和效果。
- 玩家可以点击手牌出牌。
- 敌人可以根据 AI 行动。
- 战斗日志能说明规则结算。
- 缺少非关键资源时仍能运行。

后续重点包括：

- 正式 CardView。
- 敌人意图图标。
- 胜利/失败界面。
- 更完整的效果系统拆分。
- `tools/verify_demo.gd` 自动验证脚本。
