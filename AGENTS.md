# HDay / fitness_counter

## 项目概览

这是一个 Android 优先的 Flutter 健身计划与训练记录应用。Flutter 应用位于
`app/`；仓库根目录同时保留 HTML 原型、设计/实现计划和验收证据。

当前生产应用使用：

- Flutter/Dart（见 `app/pubspec.yaml`，Dart SDK `>=3.6.0 <4.0.0`）
- Riverpod 管理应用状态，GoRouter 管理导航
- 通过 `AppDatabase` 和各 feature 自有 repository 使用 SQLite
- Android 平台网关实现通知、振动和唤醒锁
- 基于注册表的主题系统，以及持久化设置

当前代码采用 feature-first 结构。各 feature 通常划分为
`domain/`、`data/`、`application/`、`presentation/` 四层：

`today`、`plans`、`history`、`exercises`、`settings`、`workout` 位于
`app/lib/features/`。共享基础设施位于 `app/lib/core/`，应用壳位于
`app/lib/app/`，复用组件位于 `app/lib/widgets/`，主题定义位于
`app/lib/theme/`。

## 权威资料

- 产品与实现历史：`.superpowers/sdd/`
- 当前 Flutter 重写计划：`docs/plans/2026-09-15-flutter-rewrite.md`
- 应用命令与操作注意事项：`app/README.md`
- 最新验收边界：`docs/verification/2026-09-15-flutter-acceptance.md`
- React/HTML 参考原型：`prototype/` 和 `app_pages/`

文档出现不一致时，优先以当前生产代码和最新验收文档为准，并在任务报告中
记录尚未解决的歧义。

## 开发约束

- Flutter 命令从 `app/` 目录执行。
- 保持 feature-first 分层。domain 类型和 repository 接口不得暴露 SQLite
  map 或数据库句柄。
- 优先复用现有主题、间距、字体、本地化和共享组件。已有 token/helper 可用
  时，不要在页面中硬编码颜色、尺寸或用户可见字符串。
- 持久化设置与训练/计划快照必须分离。设置写入不得隐式改写进行中的训练或已
  保存的计划快照。
- 排查写入问题时不要清空应用数据或删除 SQLite 数据库；写入失败应保留草稿并
  提供重试行为。
- 遇到 SQLite 或异步宿主环境不稳定时，使用串行测试执行。
- 没有对应设备证据时，不得声称已验证 Android 硬件行为、实体振动、锁屏/后台
  提醒或最终设备视觉验收。

## 标准验证

在 `app/` 目录执行：

```powershell
flutter analyze
flutter test --concurrency=1 -r expanded
flutter build apk --release
```

Android 集成测试需要先确认在线设备 ID：

```powershell
adb devices -l
$env:HDAY_ANDROID_DEVICE_ID = 'the-observed-device-id'
flutter test integration_test -d $env:HDAY_ANDROID_DEVICE_ID -r expanded
```

进程丢失探针独立于 Flutter VM-service 测试运行器：

```powershell
powershell -ExecutionPolicy Bypass `
  -File integration_test/run_android_workout_process_probe.ps1 `
  -Device $env:HDAY_ANDROID_DEVICE_ID
```

发布 APK 位于 `app/build/app/outputs/flutter-apk/app-release.apk`，当前用于本地
侧载验证，不代表商店生产签名配置。

## 当前验收边界

最新记录显示宿主端 analyzer 和串行 Flutter 测试通过，发布构建/安装/启动以及
adb 进程丢失探针已有模拟器证据。完整 Android 集成测试曾因 Flutter VM-service
WebSocket 在测试启动前断开而受阻；实体振动、锁屏/后台提醒和最终 Android 视觉
对比仍未验证。除非取得新的证据，不得将项目描述为已完成全部验收。
