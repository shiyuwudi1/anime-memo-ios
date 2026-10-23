# AGENTS.md

番忆 / AnimeMemo 的协作说明。给在本仓库工作的编码代理和贡献者使用。

## 项目概览

- 纯本地、免登录、中文优先的追番进度记录 iOS App。
- SwiftUI + Swift 6（`SWIFT_STRICT_CONCURRENCY: complete`），最低 iOS 18，iPhone 竖屏。
- 3 个主 Tab：首页 / 搜索 / 片库。数据源支持 TMDB 与 Bangumi，可随时切换。
- 片库只用本地 JSON 持久化，没有账号、后端数据库或云同步。
- 唯一服务端组件是 `server/tmdb-proxy`：可选的 Cloudflare Worker，用于在中国大陆代理 TMDB。
- V1 定位免费、无广告、无内购。TMDB 免费额度仅适用于 non-commercial 使用，引入商业化前必须先确认授权。

## 环境与命令

依赖：Xcode 27.1、`xcodegen`、Node 18+（仅代理 Worker 需要）。

```bash
# 首次配置（token 只放在本地，已被 git 忽略）
cp Secrets.example.xcconfig Secrets.xcconfig
# 编辑 Secrets.xcconfig，填入 TMDB_READ_ACCESS_TOKEN

# project.yml 是工程定义的唯一来源，改完必须重新生成
xcodegen generate

# 构建
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project AnimeMemo.xcodeproj \
  -scheme AnimeMemo \
  -destination 'platform=iOS Simulator,name=iPhone Duo,OS=27.1' \
  build

# 单元测试 + UI 测试
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project AnimeMemo.xcodeproj \
  -scheme AnimeMemo \
  -destination 'platform=iOS Simulator,name=iPhone Duo,OS=27.1' \
  test

# 代理 Worker 测试
cd server/tmdb-proxy && npm test
```

- 模拟器名称/系统版本以本机为准，可用 `xcrun simctl list devices available` 查看后替换 destination。
- 仓库没有配置 SwiftLint / SwiftFormat，按现有风格手写即可。
- 不要手改 `AnimeMemo.xcodeproj/project.pbxproj`。新增文件、target、编译设置一律改 `project.yml` 后执行 `xcodegen generate`。

## 目录结构

```text
AnimeMemo/
  App/                  入口、RootTabView、AppRouter、ProviderLaunchGate
  Core/
    Bangumi/            Bangumi actor client 与 DTO
    Components/         海报组件与图片缓存
    DesignSystem/       AppTheme、GlassSurface、GlassButton、GlassChip、GlassBar、GlassToast
    Media/              MetadataProvider、ProviderProbe（连通性探测）
    Models/             MockAnime 与状态枚举（也是持久化模型）
    Store/              LibraryStore（本地 JSON 片库、导入导出）
    TMDB/               TMDBClient、DTO、AppConfiguration
  Features/             Home / Search / Library / Detail / Settings / GlassLab
  Resources/            Assets、AppIcon、Info.plist
AnimeMemoTests/         Swift Testing 单元测试
AnimeMemoUITests/       XCTest UI 测试
server/tmdb-proxy/      Cloudflare Worker（纯 ESM JavaScript）
Scripts/                AppIcon 生成、代理部署脚本
docs/                   GitHub Pages 落地页与隐私政策
```

## 架构要点

### 启动流程

`AnimeMemoApp` → `ProviderLaunchGate` → `RootTabView`。

- 每次冷启动都会并发探测 TMDB 与 Bangumi，探测超时为 5 秒。
- 当前数据源可用就保持；不可用但另一个可用时静默切换，不弹窗。
- 两者都失败才停留在排查页，允许填写代理地址并重试。
- 不要在启动路径上引入会无限等待的请求；现有探测逻辑在 `Core/Media/ProviderProbe.swift`。

### 状态与依赖注入

- `AppRouter` 与 `LibraryStore` 都是 `@MainActor @Observable`，通过 `.environment(...)` 注入，读取用 `@Environment(Type.self)`。
- 偏好设置用 `@AppStorage`，主要 key：`appearance`、`metadataProvider`、`tmdbAPIBaseURL`、`tab`。
- 不引入 `ObservableObject` / `@Published` 新代码，保持 `@Observable` 风格。

### 本地片库

- `MockAnime` 是正式持久化模型（名字有历史原因，不是测试专用）。
- `LibraryStore` 把片库写到 `Application Support/AnimeMemo/library.json`，写入使用 atomic。
- `MockAnime` 的手写 `init(from:)` 为所有字段提供默认值，用于兼容旧 JSON。新增字段时同步更新：
  1. 属性声明与默认值
  2. `CodingKeys`
  3. `decodeIfPresent(...) ?? 默认值`
  4. 相关测试
- 导出格式 `LibraryBackup`（`version: 1`，含 `exportedAt`），导入同时兼容备份包装和裸数组。
- 条目 ID 约定，改动会影响已有用户数据：
  - TMDB 剧集：`tv-<tmdbID>-s<seasonNumber>`
  - TMDB 电影：`movie-<tmdbID>`
  - Bangumi：`bgm-<subjectID>`
- 多季是独立条目：每一季有自己的进度、状态、评分。新增逻辑不要假设“一个 TMDB ID 只有一条记录”。

### 数据源

- `MetadataProvider` 只有 `.tmdb` 和 `.bangumi` 两种；设置页切换后写 `@AppStorage("metadataProvider")`，搜索页据此重新拉取。
- `TMDBClient` / `BangumiClient` 都是 `actor`，使用 `async/await`，错误枚举提供中文 `errorDescription`。
- TMDB 请求统一带 `language=zh-CN`；客户端约 10 秒超时，Bangumi 约 12 秒。
- `AppConfiguration.normalizedTMDBBaseURL` 负责把用户输入规范成以 `/3` 结尾的地址；修改时保留现有容错（省略 scheme、尾部斜杠、query/fragment）。
- 代理模式下 App 可以不配置 token，token 由 Worker 在服务端注入；官方 API 模式下没有 token 视为未配置。
- 新增数据源需要同时改：`MetadataProvider`、client、模型转换、`ProviderProbe`、设置页文案与启动探测。

### UI 与设计系统

- 用户可见文案一律简体中文，直接写在 SwiftUI 里；项目没有本地化资源文件。
- 代码注释使用英文，与现有文件保持一致。
- 颜色、间距、圆角统一走 `AppTheme`，不要散落魔法数字。
- 玻璃效果统一走 `Core/DesignSystem` 的封装：`glassSurface`、`GlassButton`、`GlassIconButton`、`GlassChip`、`GlassBar`、`GlassToast`。
- iOS 26+ 使用原生 Liquid Glass，iOS 18 回退到 `ultraThinMaterial`。新增效果必须用 `#available(iOS 26.0, *)`，并处理 `accessibilityReduceTransparency` / `accessibilityReduceMotion`。
- 页面结构沿用现有模式：`NavigationStack` + `ScrollView`/`List`，背景用 `AppBackground()`。
- 为 UI 测试保留稳定的中文 accessibility label 或 `accessibilityIdentifier`（如 `launchGate.retry`）。

### 图片

- 海报统一使用 `PosterArtwork` / `PosterStyle`，已有内存 + 磁盘双层缓存。
- 不要为单个页面另建图片加载器；优先复用现有缓存组件。

## 测试约定

- 单元测试使用 Swift Testing（`import Testing`、`@Test`、`#expect`、`#require`）。
- UI 测试使用 XCTest（`XCTestCase`、`XCUIApplication`），断言中文界面文案。
- 单元测试要并发安全、可重复：使用 `FileManager.default.temporaryDirectory` + UUID 构造独立的 `library.json` 路径，不要读写真实 App 数据。
- 修 bug 或改核心逻辑（片库、分季、ID、编码、代理地址解析、provider 回退）时补回归测试。
- Debug 专用启动参数（同时用于 UI 测试）：
  - `-screen home|search|library|detail|detailShort|detailLong|detailSeasons|remoteDetail|settings|glasslab`
  - `-resetLibrary`：用种子数据重建片库，保证 UI 测试可重复
  - `-failProviderProbes YES`：模拟两个数据源都失败，验证启动拦截页
- 只有 Debug 构建会注入 Mock 种子数据；Release 初始片库为空。

## 代理 Worker 约定

- 纯 ESM JavaScript，无框架；测试用 Node 内置 test runner（`node --test`）。
- 仅转发 `/3/*` 到 TMDB，不做公开代理；保留 CORS、方法限制、5 分钟边缘缓存。
- token 优先级：客户端 `Authorization: Bearer` > Worker secret `TMDB_READ_ACCESS_TOKEN`。
- 不要把 token 写进源码、日志或响应；`env.TMDB_READ_ACCESS_TOKEN` 只通过 `wrangler secret put` 管理。
- 修改 `src/index.js` 时同步更新 `test/worker.test.js`，并在 `server/tmdb-proxy` 下跑 `npm test`。
- 部署：仓库根目录执行 `Scripts/DeployTMDBProxy.sh`；脚本会复用 `Secrets.xcconfig` 的 token。
- `*.workers.dev` 在中国大陆常被 DNS 污染，长期使用建议在 `wrangler.toml` 绑定自有域名。

## 安全与仓库卫生

以下文件/目录已在 `.gitignore` 中，禁止提交，也不要读取后写入任何输出：

- `Secrets.xcconfig`、`server/tmdb-proxy/.dev.vars`、`server/tmdb-proxy/.cf_token`
- `node_modules/`、`.wrangler/`、`DerivedData/`、`build/`、`.build/`、`xcuserdata/`

TMDB token 只能存在于：
1. 本地 `Secrets.xcconfig`（经 `Info.plist` 注入 Debug/Release 构建）
2. Cloudflare Worker secret

不要把 token 直接硬编码到 Swift 或 JavaScript 源码。

## 提交前检查

1. 改了 `project.yml` / 新增文件 → `xcodegen generate`，确认工程能打开。
2. `xcodebuild ... build` 通过。
3. 相关单元测试与 UI 测试通过（至少跑改动涉及的测试）。
4. 改了 `server/tmdb-proxy` → `npm test` 通过。
5. 用户可见文案为中文，没有泄露密钥，没有手改生成的 `.pbxproj`。
6. UI 改动在 iOS 26 与 iOS 18 回退路径下都检查过（至少确认没有使用未加 availability 判断的新 API）。

## 已知约束

- 中国大陆通常无法直连 `api.themoviedb.org`；App 依赖用户自填代理或切换到 Bangumi。
- Bangumi 建议请求频率低于 1 次/秒；当前实现未做全局限流，新增批量请求时要谨慎。
- 片库是纯本地数据，没有迁移框架；结构变更必须靠 `MockAnime` 的默认解码保持向后兼容。
- 当前不做通知、小组件、iCloud；相关需求先确认产品范围。
- `docs/` 是 GitHub Pages 静态站点，直接部署，没有构建步骤。
