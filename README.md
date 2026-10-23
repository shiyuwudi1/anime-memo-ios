# 番忆 / AnimeMemo

一个纯本地、免登录、中文优先的追番进度记录 iOS app。

- 项目主页：<https://shiyuwudi1.github.io/anime-memo-ios/>
- 源码仓库：<https://github.com/shiyuwudi1/anime-memo-ios>
- 隐私政策：<https://shiyuwudi1.github.io/anime-memo-ios/privacy.html>

## 当前状态

- SwiftUI + Swift 6，最低 iOS 18
- 3 个主 Tab：首页 / 搜索 / 片库
- Liquid Glass 设计系统：iOS 26+ 原生，iOS 18 材质回退
- 首页 / 搜索 / 片库 / 详情 / 编辑 / 设置 / Glass Lab 界面
- TMDB 真实搜索、TV/电影详情、海报与分季数据已接入
- **多季独立进度**：每一季都是独立条目，进度/状态/评分互不影响
- **Bangumi 数据源**：设置页一键切换，中文条目更贴近国内
- **TMDB 反向代理**：自带免费 Cloudflare Worker，设置页可填代理地址
- **数据源连通性测试**：设置页直接对比代理与 Bangumi 的延迟和结果
- **首页课程表**：按星期展示当季热播，今天优先，可展开查看当天全部作品
- 片库本地 JSON 持久化，支持 JSON 导出/导入
- 32 个单元测试 + 6 个 UI 测试通过
- 仍待完善：追番更新通知、小组件、iCloud

## 数据源与商用

V1 定位为**免费、无广告、无内购、纯本地**。按 TMDB 的定义，这类项目属于
non-commercial 使用，可以继续使用 TMDB 免费 API。

如果以后加入广告、订阅、内购、付费下载或带佣金的推荐，需要先确认 TMDB
商业授权，或者把数据层切换到其他 provider。

上架时请在“关于”页保留：

> This product uses the TMDB API but is not endorsed or certified by TMDB.

## 数据源对比

设置 → 数据源 里有一个「使用 Bangumi 数据源」开关，改完立即生效，两种数据源
共用同一套本地片库结构，可以随时来回对比。

| | TMDB（经代理） | Bangumi |
| --- | --- | --- |
| 大陆直连 | 需要反向代理 | 可直连（部分网络 DNS 被污染） |
| 中文条目 | 部分有中文译名 | 中文译名、简介完整 |
| 分季 | 原生 season 结构，自动聚合成多季 | 没有季的概念，续作是独立条目 |
| 海报 | 质量高、尺寸齐全 | 有海报，分辨率一般 |
| 评分 | 全球用户评分 | 国内用户评分 |
| 配额 | 约 50 次/秒 | 建议低于 1 次/秒 |

切换后回到搜索页会自动重新拉取；设置页的「测试当前数据源」会显示延迟、
本次返回条目数和示例标题。

## 配置 TMDB

1. 打开 <https://www.themoviedb.org/settings/api>
2. 申请 API Read Access Token
3. 编辑根目录的 `Secrets.xcconfig`：

```xcconfig
TMDB_READ_ACCESS_TOKEN = 你的_token
```

4. 重新生成工程并运行：

```bash
xcodegen generate
open AnimeMemo.xcodeproj
```

`Secrets.xcconfig` 已被 `.gitignore` 忽略，不要提交到仓库。

## 部署 TMDB 反向代理（免费）

`server/tmdb-proxy` 是一个 Cloudflare Worker，把 `/3/*` 转发到 TMDB 并把 token
留在服务端。Cloudflare Workers 免费计划每天 10 万次请求，个人使用足够。

```bash
# 需要 Node 18+ 和一个免费 Cloudflare 账号
Scripts/DeployTMDBProxy.sh
```

脚本会自动安装 wrangler、打开浏览器登录、复用 `Secrets.xcconfig` 里的 token
并完成部署。部署完成后把地址填到 App：

```text
https://<worker 名称>.<子域>.workers.dev/3
```

细节、手动步骤和自定义域名见 [server/tmdb-proxy/README.md](server/tmdb-proxy/README.md)。

> `*.workers.dev` 在中国大陆经常被 DNS 污染，长期使用建议绑定自己的域名。

## 真机网络（中国大陆）

`api.themoviedb.org` 在中国大陆通常无法直连。App 会在 10 秒超时后自动回退到
本地示例并显示提示，不会无限转圈。

三种可选方案：

1. 在设置里填自己的反向代理地址（推荐，用户无感）。
2. 设置里切到 Bangumi 数据源（国内可直连，但没有 TMDB 式分季聚合）。
3. 真机开发时让 iPhone 走 Mac 代理，或 iPhone 直接连 VPN。

不要把 TMDB token 直接放进公开客户端。

## 开发

```bash
# 生成 Xcode 工程
xcodegen generate

# 命令行构建
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project AnimeMemo.xcodeproj \
  -scheme AnimeMemo \
  -destination 'platform=iOS Simulator,name=iPhone Duo,OS=27.1' \
  build

# 测试
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project AnimeMemo.xcodeproj \
  -scheme AnimeMemo \
  -destination 'platform=iOS Simulator,name=iPhone Duo,OS=27.1' \
  test

# 代理 Worker 测试
cd server/tmdb-proxy && npm test
```

> 如果 `xcode-select` 仍指向 Command Line Tools，可以临时用 `DEVELOPER_DIR`，
> 或执行 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。

### 调试入口

Debug 构建支持通过启动参数直接打开某个页面（用于截图和快速验证）：

```bash
xcrun simctl launch booted com.shiyu.animememo -screen glasslab
xcrun simctl launch booted com.shiyu.animememo -screen detail
xcrun simctl launch booted com.shiyu.animememo -screen detailSeasons   # 多季
xcrun simctl launch booted com.shiyu.animememo -screen detailShort     # 短简介
xcrun simctl launch booted com.shiyu.animememo -screen detailLong      # 长简介
xcrun simctl launch booted com.shiyu.animememo -tab library
```

`-resetLibrary` 可以让 App 用种子数据重新开始（UI 测试也用它保证可重复）。

## 结构

```text
AnimeMemo/
  App/                  应用入口、RootTabView、AppRouter
  Core/
    Bangumi/            Bangumi API client 与 DTO
    Components/         海报占位等通用视图
    DesignSystem/       GlassSurface / GlassButton / GlassChip / GlassBar / GlassToast
    Media/              MetadataProvider 与数据源连通性探测
    Models/             Mock 数据与状态枚举
    Store/              本地 JSON 片库
    TMDB/               API client、DTO、配置
  Features/
    Home/ Search/ Library/ Detail/ Settings/ GlassLab/
  Resources/            Assets、AppIcon、Info.plist
server/
  tmdb-proxy/           Cloudflare Worker 反向代理
Scripts/                AppIcon、代理部署脚本
```

## 下一步

1. 给代理 Worker 绑定自有域名，提升大陆可用性
2. 课程表支持只显示在追作品
3. 通知 / 小组件
4. iCloud 同步与年度统计
5. 真机 / TestFlight 验证 Liquid Glass
