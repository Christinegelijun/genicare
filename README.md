# 安心守护 App

VeniCare 类居家照护产品的家属端 Flutter 演示版。

## 已实现

- 首页问候、紧急事件卡、快捷操作、今日用药与设备摘要；
- 事件中心：待处理/全部筛选、类型筛选、认领人展示；
- 告警详情：联系老人、再次询问、认领、解除认领、需要继续协助、标记误报、结束事件与时间线；
- 设备列表、设备详情、一键自检、添加设备（演示绑定）与解绑；
- 用药计划确认/撤销，以及未确认时通知家属开关；
- 家庭成员邀请、排序与移除；
- 告警策略、数据共享、访问记录、通知能力检查；
- 帮助 FAQ、反馈入口、外观浅色/深色/跟随系统；
- 关于页可恢复初始演示数据；
- Riverpod 状态管理与 go_router 路由；
- 本地模拟数据仓库与关键流程测试。

当前版本使用模拟数据，不会发送真实告警、拨打电话或连接硬件。

## 运行

需要 Flutter 3.47 或兼容 Dart 3.12 的稳定版本。本机是 Intel Mac（x86_64），Flutter 不在 `PATH` 里。

本机 SDK：

- 路径：`~/development/flutter`
- 版本：Flutter 3.47.8，Dart 3.13.7

`flutter` 找不到时，先执行：

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

`~/development/flutter` 不存在时，下载 macOS Intel 稳定包并解压到该目录。不要改用只执行 `flutter run` 的方式代替下面的启动命令。

```bash
curl -L --fail -o /tmp/flutter_macos_stable.zip \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.47.8-stable.zip
mkdir -p "$HOME/development"
unzip -q /tmp/flutter_macos_stable.zip -d "$HOME/development"
```

下次启动按这个顺序做：

1. 先看 `http://127.0.0.1:8080` 是否已经能打开，并且 Chrome 页面标题是「安心守护」。已经在跑就不要再起一个 `flutter run`。
2. 否则在项目根目录执行：

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter pub get
flutter run -d chrome --web-port=8080 --no-web-resources-cdn
```

必须带 `--no-web-resources-cdn`。当前网络访问不到 `https://www.gstatic.com` 上的 CanvasKit，不带这个参数时调试服务能连上，页面会一直黑屏。

本机可用设备是 Chrome。没有配置 iOS 模拟器或 Android 模拟器，仓库里也没有 `macos/` 目录，所以用 Chrome 打开 Web。第一次编译大约一分钟。看到 `Flutter run key commands`，并且页面标题变成「安心守护」，才算启动成功。

停止：在运行 `flutter run` 的终端按 `q`。

测试：

```bash
flutter analyze
flutter test
```

如果仓库缺少原生平台目录，可在项目根目录执行：

```bash
flutter create --platforms=android,ios --project-name venicare_app .
```

该命令不会覆盖 `lib/` 中的业务实现。

## 下一步

1. 接入登录和家庭 API；
2. 将 `DemoRepository` 替换为远程 Repository；
3. 接入 WebSocket、推送和短信/电话告警状态；
4. 实现二维码与 BLE 配网；
5. 使用 Drift/SQLCipher 保存离线事件与 Outbox；
6. 接入真实设备状态和用药计划。
