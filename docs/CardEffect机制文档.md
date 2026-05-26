# CardEffect 机制文档

日期：2026-05-20

本文档专门记录 `CardEffect` 的设计过程、最终结构、字段含义、枚举含义和样例数据。

相关文档：

- 表格基础规范：`表格规范文档.md`
- 效果时机流程：`效果时机流程文档.md`
- 卡牌效果总览：`卡牌效果文档.md`

## 今日讨论过程摘要

最初的理解是：

```text
一张卡牌由一个或多个效果组成。
玩家使用卡牌时，卡牌把效果给予目标。
效果按触发时机生效。
瞬间效果生效后立刻移除。
持续效果会保留在目标身上，等待后续时机触发。
```

之后确定：

```text
战斗底层以时机为核心。
效果不是简单函数调用，而是可以生成效果实例。
效果实例可以拥有持续时间、层数、触发时机、移除规则和离场处理。
```

后来进一步修正：

```text
value 不是单一数值，而是复合参数字段。
effect_type 决定 value 如何解析。
一维参数使用英文逗号 ,
二维参数使用英文分号 ;
```

最终结论：

```text
CardEffect 一张表同时表达：
  - 瞬间效果
  - 持续效果
  - 附加效果
  - 层数效果
```

## 表格基础格式

`CardEffect.xlsx` 使用三行表头。

```text
第 1 行：英文字段名，给程序读取
第 2 行：字段类型，给输入限制和程序解析参考
第 3 行：中文注释，给策划查看
第 4 行开始：正式数据
```

导出 CSV 时：

```text
保留第 1 行英文字段名
跳过第 2 行字段类型
跳过第 3 行中文注释
第 4 行开始作为正式数据导出
```

## 最终字段

```text
id
effect_type
value
target
target_source
trigger_timing
duration_type
duration_value
duration_apply_policy
stack_initial
stack_max
stack_change_on_trigger
expire_policy
on_remove
comment
```

## 字段说明

### id

效果 ID。

使用数字，并按区间保持规律。

暂定：

```text
100000-199999：玩家基础卡牌效果
200000-299999：敌人行动效果
300000-399999：可复用持续效果
400000-499999：道具效果
```

### effect_type

效果类型枚举。

它决定这条效果做什么，也决定 `value` 字段如何解析。

示例：

```text
100：修改资源
200：造成伤害
300：附加效果
```

### value

复合参数字段。

`value` 不是单一数值，而是一组由 `effect_type` 解释的参数。

规则：

```text
一维参数使用英文逗号 ,
二维参数使用英文分号 ;
```

示例：

```text
20,5
```

如果 `effect_type = 200 造成伤害`，则表示：

```text
20：魔力伤害
5：伤害数值
```

示例：

```text
300001,1
```

如果 `effect_type = 300 附加效果`，则表示：

```text
300001：要附加的效果 ID，也就是冰甲
1：附加层数
```

二维示例：

```text
20,5;30,2
```

表示两组参数：

```text
第 1 组：20,5
第 2 组：30,2
```

第一版暂时不强制使用二维参数，但保留规范。

### target

目标类型枚举。

它描述效果最终作用于什么类型的目标。

### target_source

目标来源枚举。

它描述目标由哪里决定。

示例：

```text
玩家选择目标
继承卡牌目标
卡牌固定目标
来源自身
```

### trigger_timing

触发时机枚举。

它决定效果什么时候生效。

示例：

```text
附加时
受到伤害前
玩家回合结束时
```

### duration_type

持续时间类型枚举。

示例：

```text
瞬间
N 回合
直到条件满足
永久
```

### duration_value

持续时间数值。

示例：

```text
duration_type = N 回合
duration_value = 3
```

表示持续 3 回合。

如果是瞬间效果，则：

```text
duration_value = 0
```

### duration_apply_policy

重复附加同一个效果时，持续时间如何处理。

示例：

```text
刷新持续时间
持续时间不变
取较大持续时间
增加持续时间
```

### stack_initial

初始层数。

效果第一次附加到目标身上时，拥有多少层。

瞬间效果通常为 0。

### stack_max

最大层数。

同一目标重复获得同一效果时：

```text
当前层数 = min(当前层数 + 新增层数, stack_max)
```

### stack_change_on_trigger

每次触发后层数变化。

示例：

```text
-1：每次触发后减少 1 层
0：触发后层数不变
```

### expire_policy

生命周期结束规则。

它描述这条效果什么时候从目标身上移除。

示例：

```text
生效后移除
持续时间结束移除
层数归零移除
持续时间结束或层数归零移除
条件满足移除
```

### on_remove

离场处理枚举。

它描述效果移除时是否触发额外处理。

示例：

```text
无
来源卡牌进入弃牌堆
魔力上限回到人类形态基础值
```

### comment

策划备注。

用于写中文解释，不参与程序逻辑。

## effect_type 的 value 解析

### 100：修改资源

格式：

```text
resource_type,amount
```

示例：

```text
40,70
```

含义：

```text
40：魔力防御
70：数量
```

### 200：造成伤害

格式：

```text
damage_type,amount
```

示例：

```text
20,5
```

含义：

```text
20：魔力伤害
5：伤害数值
```

### 300：附加效果

格式：

```text
effect_id,stack
```

示例：

```text
300001,1
```

含义：

```text
300001：冰甲
1：附加 1 层
```

### 400：抽牌

格式：

```text
count
```

示例：

```text
2
```

含义：

```text
抽 2 张牌
```

### 500：弃牌

格式：

```text
count
```

示例：

```text
1
```

含义：

```text
弃 1 张牌
```

## 样例效果

### 星光射击

```text
id = 100101
effect_type = 200
value = 20,5
target = 单个敌人
target_source = 继承卡牌目标
trigger_timing = 附加时
duration_type = 瞬间
expire_policy = 生效后移除
```

解释：

```text
造成 5 点魔力伤害。
```

### 魔力防御

```text
id = 100201
effect_type = 100
value = 50,5
target = 自身
target_source = 继承卡牌目标
trigger_timing = 附加时
duration_type = 瞬间
expire_policy = 生效后移除
```

解释：

```text
获得 5 点魔力护盾。
```

### 冰甲

```text
id = 300001
effect_type = 100
value = 50,5
target = 自身
target_source = 来源自身
trigger_timing = 受到伤害前
duration_type = N 回合
duration_value = 3
duration_apply_policy = 刷新持续时间
stack_initial = 1
stack_max = 3
stack_change_on_trigger = -1
expire_policy = 持续时间结束或层数归零移除
```

解释：

```text
冰甲挂在目标身上。
目标受到伤害前，冰甲为持有者提供 5 点魔力护盾。
然后冰甲层数 -1。
持续 3 回合，或者层数归零时移除。
最大 3 层。
```

### 附加冰甲

```text
id = 100301
effect_type = 300
value = 300001,1
target = 自身
target_source = 继承卡牌目标
trigger_timing = 附加时
duration_type = 瞬间
expire_policy = 生效后移除
```

解释：

```text
给目标附加 1 层冰甲。
如果目标已经有冰甲，则层数叠加，但不超过冰甲的 stack_max。
持续时间按冰甲的 duration_apply_policy 处理。
```

## 层数规则

同一目标重复获得同一效果时：

```text
当前层数 = min(当前层数 + 新增层数, stack_max)
```

层数是否减少由效果自己的规则决定。

例如冰甲：

```text
stack_change_on_trigger = -1
```

表示每次触发后减少 1 层。

## 持续时间规则

持续时间由三个字段共同决定：

```text
duration_type
duration_value
duration_apply_policy
```

例如：

```text
duration_type = N 回合
duration_value = 3
duration_apply_policy = 刷新持续时间
```

表示重复附加时刷新为 3 回合。

## 导出结果要求

`CardEffect.csv` 应该满足：

```text
第 1 行是英文字段名
第 2 行开始是正式数据
不包含字段类型行
不包含中文注释行
value 中的英文逗号必须被正确保留
```
