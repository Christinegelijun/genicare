# 安心守护

VeniCare 类居家照护产品：用户 App（子女模式 + 老人模式）、PC 医生端和服务端。

方案文档在 `docs/`，医生端与服务端的设计见 [docs/医生端与服务端方案设计.md](docs/医生端与服务端方案设计.md)。

## 目录

```text
apps/mobile/               用户 App（Flutter iOS/Android/Web，包名 venicare_app）
apps/doctor_pc/            医生工作台（Flutter Web/Windows/macOS，包名 venicare_doctor）
server/                    服务端（Dart + shelf），表结构在 server/db/migrations/
packages/venicare_shared/  三端共享：报告 + 咨询/排班数据结构（纯 Dart）
docs/                      方案与设计文档
```

各工程独立执行 `flutter pub get` / `dart pub get`，通过 `path:` 依赖共享包。

## 用户 App 已实现

- 首页问候、紧急事件卡、快捷操作、今日用药与设备摘要；
- 事件中心：待处理/全部筛选、类型筛选、认领人展示；
- 告警详情：联系老人、再次询问、认领、解除认领、需要继续协助、标记误报、结束事件与时间线；
- 设备列表、设备详情、一键自检、添加设备（演示绑定）与解绑；
- 用药计划确认/撤销，以及未确认时通知家属开关；
- 家庭成员邀请、排序与移除；
- 告警策略、数据共享、访问记录、通知能力检查；
- 帮助 FAQ、反馈入口、外观浅色/深色/跟随系统；
- 关于页可恢复初始演示数据；
- 子女模式 / 老人模式切换（「我的 → 使用模式」），模式保存在本机，重启后保持；老人页面右上角「家人」长按可切回；
- 老人模式单页大字界面：点一下说话记录血压、心率、血糖和用药（支持「血压一百三八十五」「高压130低压85」「晚上的药吃了」等说法，一句话可说多项），保存前大字确认、保存后可撤销；语音不可用时可打字记录；今日用药一键「我吃过了」；
- 老人记录的数据在子女端首页和「健康记录」页可见，高于 140/90 的血压会标出；
- 咨询预约：首页「预约医生」/ 我的 → 按科室看医生空闲与排队，选时段预约图文/电话/视频，查看与取消「我的预约」；
- Riverpod 状态管理与 go_router 路由；
- 本地模拟数据仓库与关键流程测试。

App 目前仍使用本地模拟数据，还没有接入服务端，不会发送真实告警、拨打电话或连接硬件。

## 医生端与服务端已实现

- 服务端：数据同步、报告投递、科室/排班/预约、医生在线状态、超管实时看板与周排班；当前为内存存储，重启后恢复演示数据；
- 医生端：报告收件箱与详情、在线状态切换；管理员（演示账号张医生）可见「排班与接诊」：空闲/接诊/排队看板与周排班负荷；
- 尚未实现：登录鉴权（医生 ID 写在请求路径里，仅供开发）、PostgreSQL 存储、排班编辑、接诊开始/结束、PDF、音视频通话、App 咨询改为调服务端。

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

### 用户 App

下次启动按这个顺序做：

1. 先看 `http://127.0.0.1:8080` 是否已经能打开，并且 Chrome 页面标题是「安心守护」。已经在跑就不要再起一个 `flutter run`。
2. 否则执行：

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd apps/mobile
flutter pub get
flutter run -d chrome --web-port=8080 --no-web-resources-cdn
```

必须带 `--no-web-resources-cdn`。当前网络访问不到 `https://www.gstatic.com` 上的 CanvasKit，不带这个参数时调试服务能连上，页面会一直黑屏。

本机可用设备是 Chrome。没有配置 iOS 模拟器或 Android 模拟器，所以用 Chrome 打开 Web。第一次编译大约一分钟。看到 `Flutter run key commands`，并且页面标题变成「安心守护」，才算启动成功。

停止：在运行 `flutter run` 的终端按 `q`。

### 服务端

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd server
dart pub get
dart run bin/server.dart          # 监听 http://localhost:8081，自带演示数据
```

环境变量：`PORT` 改端口；`VENICARE_SEED_DEMO=false` 不加载演示数据。

### 医生端

先启动服务端，再在另一个终端：

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd apps/doctor_pc
flutter pub get
flutter run -d chrome --web-port=8090 --no-web-resources-cdn
```

页面标题是「安心守护 · 医生工作台」，左侧应能看到「妈妈」的一份未读报告。

服务端地址或医生 ID 不同时，加上 `--dart-define=API_BASE_URL=http://host:port --dart-define=DOCTOR_ID=doctor-zhang`。

Windows 安装包需在 Windows 上执行 `flutter build windows`；macOS 用 `flutter build macos`。

## 测试

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
(cd apps/mobile && flutter analyze && flutter test)
(cd apps/doctor_pc && flutter analyze && flutter test)
(cd server && dart analyze && dart test)
(cd packages/venicare_shared && dart analyze && dart test)
```

如果 App 缺少原生平台目录，可在 `apps/mobile` 中执行：

```bash
flutter create --platforms=android,ios --project-name venicare_app .
```

该命令不会覆盖 `lib/` 中的业务实现。

## 下一步

1. 服务端实现 PostgreSQL 存储（按 `server/db/migrations/0001_init.sql`）和登录鉴权；
2. App 将 `DemoRepository` 替换为远程 Repository，用 Outbox 同步健康记录；
3. App 增加「生成报告发给医生」、扫码绑定医生、查看医生回复；
4. 医生端增加登录、实时提醒、打印/导出 PDF；
5. 接入推送和短信/电话告警状态，实现二维码与 BLE 配网，接入真实设备。
