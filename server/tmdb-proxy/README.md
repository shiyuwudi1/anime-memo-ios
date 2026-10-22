# AnimeMemo TMDB Proxy

一个免费的 Cloudflare Worker，把 `/3/*` 请求转发到 TMDB，并让 token 只留在服务端。
用来解决中国大陆直连 `api.themoviedb.org` 失败的问题。

- 运行时：Cloudflare Workers，免费计划即可（每天 10 万次请求）
- 只会转发 `/3/` 开头的 TMDB API 路径，不会变成公开代理
- 内置 5 分钟边缘缓存，减少对 TMDB 的调用
- 客户端可传入自己的 token，也可完全依赖服务端 token

## 一键部署

```bash
# 在仓库根目录执行
Scripts/DeployTMDBProxy.sh
```

脚本会：

1. 安装 `wrangler`
2. 需要时打开浏览器让你登录 Cloudflare（免费账号即可）
3. 从根目录 `Secrets.xcconfig` 读取 `TMDB_READ_ACCESS_TOKEN` 并写入 Worker secret
4. 执行 `wrangler deploy`

部署成功后会打印形如：

```text
https://animememo-tmdb-proxy.<your-subdomain>.workers.dev
```

### 浏览器登录失败时改用 API Token

`wrangler login` 依赖 `localhost` 回调，中国大陆网络下经常打不开或回调失败。
可以用一个最小权限的 API Token 代替：

1. 打开 <https://dash.cloudflare.com/profile/api-tokens>
2. **Create Token** → **Create Custom Token**
3. Permissions 加两条：
   - `Account` · `Workers Scripts` · `Edit`
   - `Account` · `Account Settings` · `Read`（用于自动获取 Account ID，可省略）
4. Account Resources 选你的账号，Zone Resources **留空**
5. 复制 token 后写入：

```bash
printf '%s' '你的 token' > server/tmdb-proxy/.cf_token
chmod 600 server/tmdb-proxy/.cf_token
```

再执行 `Scripts/DeployTMDBProxy.sh`，脚本会优先使用这个 token。
`.cf_token` 已被忽略，不会进仓库；部署完成后可以在 dashboard 里 revoke。

## 手动部署

```bash
cd server/tmdb-proxy
npm install
npx wrangler login
npx wrangler secret put TMDB_READ_ACCESS_TOKEN   # 粘贴 TMDB Read Access Token
npx wrangler deploy
```

## 在 App 里启用

设置 → 数据源 → 保持「使用 Bangumi 数据源」关闭（即 TMDB），在
「TMDB 反向代理地址」里填：

```text
https://animememo-tmdb-proxy.<your-subdomain>.workers.dev/3
```

- 也可以省略 `/3` 或 `https://`，App 会自动补齐
- 留空则回到官方 `https://api.themoviedb.org/3`
- 填好后点「测试当前数据源」，能看到延迟和示例条目就说明通了

## 本地调试

```bash
cd server/tmdb-proxy
printf 'TMDB_READ_ACCESS_TOKEN=%s\n' '<你的 token>' > .dev.vars
npm run dev

curl http://127.0.0.1:8787/health
curl "http://127.0.0.1:8787/3/tv/209867?language=zh-CN"
```

`.dev.vars` 已被忽略，不会进仓库。

## 测试

```bash
npm test
```

用 Node 内置 test runner + 假的 `fetch` 覆盖：健康检查、CORS、方法限制、
路径限制、token 注入、客户端 token 优先、上游失败等。

## 关于中国大陆可用性

`*.workers.dev` 域名在中国大陆经常被 DNS 污染，成功率不稳定。如果目标用户
主要在国内，建议给这个 Worker 绑定一个自己的域名：

```toml
# wrangler.toml
routes = [
  { pattern = "tmdb.example.com", custom_domain = true }
]
```

然后用 `https://tmdb.example.com/3`。自有域名 + Cloudflare 免费套餐虽然不保证
速度，但比 `workers.dev` 稳定，也比让用户自己挂 VPN 现实。

## 与 Bangumi 的区别

| | TMDB（经代理） | Bangumi |
| --- | --- | --- |
| 大陆直连 | 需要代理 | 可直连（部分网络环境 DNS 被污染） |
| 中文条目 | 部分有中文译名 | 中文译名、简介完整 |
| 分季 | 原生 season 结构，可自动聚合成多季 | 没有季的概念，续作是独立条目 |
| 海报 | 质量高、尺寸齐全 | 有海报，分辨率一般 |
| 评分 | 全球用户评分 | 国内用户评分 |
| 配额 | 约 50 次/秒 | 建议低于 1 次/秒 |

App 设置页可以随时一键切换，两种数据源共用同一套本地片库结构。
