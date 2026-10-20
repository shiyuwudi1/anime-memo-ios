# 番忆 / AnimeMemo

一个纯本地、免登录、中文优先的追番进度记录 iOS app。

- 项目主页：<https://shiyuwudi1.github.io/anime-memo-ios/>
- 源码仓库：<https://github.com/shiyuwudi1/anime-memo-ios>
- 隐私政策：<https://shiyuwudi1.github.io/anime-memo-ios/privacy.html>

## 当前状态

- SwiftUI + Swift 6，最低 iOS 18
- 3 个主 Tab：首页 / 搜索 / 片库
- Liquid Glass 设计系统：iOS 26+ 原生，iOS 18 材质回退
- 首页 / 搜索 / 片库 / 详情 / 编辑 / 设置 / Glass Lab 的模拟数据界面已完成
- TMDB client、DTO、错误处理和模型测试已接入
- 当前 UI 仍使用 Mock 数据；下一步把搜索、详情和片库切到 TMDB + SwiftData

## 数据源与商用

V1 定位为**免费、无广告、无内购、纯本地**。按 TMDB 的定义，这类项目属于
non-commercial 使用，可以继续使用 TMDB 免费 API。

如果以后加入广告、订阅、内购、付费下载或带佣金的推荐，需要先确认 TMDB
商业授权，或者把数据层切换到其他 provider。UI 不直接依赖 TMDB DTO，
后续可以增加 `AniListProvider` / `BangumiProvider` / `AnnictProvider`。

上架时请在“关于”页保留：

> This product uses the TMDB API but is not endorsed or certified by TMDB.

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
```

> 如果 `xcode-select` 仍指向 Command Line Tools，可以临时用 `DEVELOPER_DIR`，
> 或执行 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。

### 调试入口

Debug 构建支持通过启动参数直接打开某个页面（用于截图和快速验证）：

```bash
xcrun simctl launch booted com.shiyu.animememo -screen glasslab
xcrun simctl launch booted com.shiyu.animememo -screen detail
xcrun simctl launch booted com.shiyu.animememo -tab library
```

## 结构

```text
AnimeMemo/
  App/                  应用入口、RootTabView、AppRouter
  Core/
    Components/         海报占位等通用视图
    DesignSystem/       GlassSurface / GlassButton / GlassChip / GlassBar / GlassToast
    Models/             Mock 数据与状态枚举
    TMDB/               API client、DTO、配置
  Features/
    Home/ Search/ Library/ Detail/ Settings/ GlassLab/
  Resources/            Assets、AppIcon、Info.plist
```

## 下一步

1. SwiftData 模型 + 片库持久化
2. 搜索 / 详情接入 TMDB 真实数据
3. 分季记录、今日更新、JSON 导出/导入
4. 真机 / TestFlight 验证 Liquid Glass
