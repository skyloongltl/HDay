# Task 1 修复记录

## 问题

`PlanDay` 构造函数直接保存调用方传入的 `exercises` 列表。构造实体后，调用方仍可通过原列表追加或移除项目，导致实体内容发生非预期变化。

## 修复

- `PlanDay` 构造函数改为先复制 `exercises`，再包装为不可变列表。
- 保持 `PlanDay.exercises` getter 不可变，且实体不再受外部列表后续修改影响。
- 新增 domain 回归测试覆盖该行为。

## 验证

执行 `flutter test test/domain`，16 项测试全部通过。
