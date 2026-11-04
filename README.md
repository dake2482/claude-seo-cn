# claude-seo-cn

> claude-seo 的中文增强发行版:上游 v2.5.0 全量 + SimilarWeb 免费数据扩展 + 中文文档。
> [English upstream README](README.upstream.md) · [上游项目 AgriciDaniel/claude-seo](https://github.com/AgriciDaniel/claude-seo)(MIT)

## 这是什么

[claude-seo](https://github.com/AgriciDaniel/claude-seo) 是一个给 Claude Code / ZCode 用的 SEO 审计插件:给它任意网站,它派 19 个并行子代理跑完整 SEO 审计(技术/内容/Schema/性能/外链/GEO),输出评分与行动计划。

本仓库在上游 **v2.5.0** 基础上做了三项增强:

| # | 增强 | 说明 |
|---|---|---|
| 1 | **`seo-similarweb` 扩展** | 新增 `/seo similarweb` 命令族(27 端点):流量估算、渠道/地理分布、互动指标、**关键词真实搜索量/难度/CPC/意图/趋势**、**URL 级外链(锚文本+DomainScore+DoFollow/状态)**、相似站、排名、出入站流量——作为 DataForSEO/Ahrefs 等付费 API 缺席时的**免费数据源** |
| 2 | **五个审计代理接入该数据源** | seo-backlinks(URL 级外链补 Common Crawl 域名级缺口)/ seo-cluster(真实量级做聚类权重)/ seo-sxo(意图校准)/ seo-content(竞品基线)/ seo-technical(趋势佐证)——无数据时自动回退原免费路径,不阻塞审计 |
| 3 | **ZCode 安装器** | 新增 `install-zcode.sh`,支持 ZCode(~/.zcode)与 Claude Code(~/.claude)双平台 |

## SimilarWeb 扩展的工作方式(重要)

本仓库**不含任何真实 API 端点**——SimilarWeb 代理 API 属于自托管基础设施,地址由使用者自己在安装时注入:

```bash
# 1. 先装主插件(见下文安装节)
# 2. 注入你的代理地址并装扩展
SW_API_BASE="https://你的代理地址" bash extensions/similarweb/install.sh
```

- 安装器会把技能内的 `__SW_API_BASE__` 占位符替换为你的地址(未设置则以占位态安装并警告)
- 代理需兼容 SimilarWeb 官方 widget/api 路径(27 端点,GET 无 body;POST 需 `Content-Type: application/json` 且 body 固定 `[]`)
- 若你有代理的完整文档,放置于安装后技能目录的 `references/llms-full.txt` 即可被代理查阅(可选,仓库不收录)

## 安装

依赖:git、Python 3.11–3.14。无需任何 API key(基础审计开箱即用)。

**Claude Code(macOS / Linux)**:

```bash
git clone https://github.com/dake2482/claude-seo-cn.git
cd claude-seo-cn
bash install.sh          # 装到 ~/.claude/skills + ~/.claude/agents,并创建隔离 Python 运行时
SW_API_BASE="https://你的代理地址" bash extensions/similarweb/install.sh   # 可选:装 SimilarWeb 扩展
```

**ZCode**:

```bash
bash install-zcode.sh    # 装到 ~/.zcode/skills + ~/.zcode/agents
SW_API_BASE="https://你的代理地址" bash extensions/similarweb/install.sh   # 可选(自动探测 ~/.zcode)
```

**卸载**:`bash uninstall.sh`(ZCode 用户手动删除 `~/.zcode/skills/seo*` 与 `~/.zcode/agents/seo-*.md`)。

## 使用

```
新开会话 →
/seo audit https://example.com            # 全站审计(19 代理并行)
/seo similarweb keywords openrouter alternative   # 关键词真实量/难度/CPC/趋势
/seo similarweb backlinks example.com     # URL 级外链(锚文本/DomainScore/状态)
/seo similarweb overview example.com      # 一页画像:访问/排名/渠道/互动
/seo doctor                               # 运行环境自检
```

完整命令表见 [skills/seo/SKILL.md](skills/seo/SKILL.md) 的 Quick Reference(约 30 个命令:audit/page/technical/content/schema/sitemap/geo/agentic/cluster/backlinks/local/hreflang/drift 等)。

### SimilarWeb 数据口径

- SimilarWeb 为**估算值**;月访问 <5K 的小站/新站数据不可靠,报告中会标注
- 错误三态:`UPSTREAM_RATE_LIMITED` / `NO_AVAILABLE_ACCOUNT` 为上游账号池暂态错误(退避 30–60s 重试);`NOT_FOUND` 为该站/词无数据(永久,如实报告)
- 并发纪律:连续查询间隔 5–10s,避免触发限流

## 与上游的差异明细

```
extensions/similarweb/            # 新增:SimilarWeb 扩展(skill + agent + install.sh,占位符发行)
skills/seo/SKILL.md               # Quick Reference 与 Subagents 各加 seo-similarweb 一行
agents/seo-{backlinks,cluster,sxo,content,technical}.md   # 追加"免费数据源"提示节
install-zcode.sh                  # 新增:ZCode 安装器
README.upstream.md                # 上游原 README(英文,存档)
```

上游其余内容(26 个子技能、19 个代理、runtime、hooks、测试)保持 v2.5.0 原样。后续如需跟进上游版本,以本仓 fork 基线做增量合并即可。

## 隐私声明

- 本仓库**不包含**任何私有 API 端点、密钥、内网地址或个人路径;SimilarWeb 代理地址通过安装时环境变量注入,不进入版本库
- 扩展调用纪律(只读 GET / 固定 body POST)写在技能内;抓取响应按不可信外部数据处理

## License

MIT(继承上游)。上游著作权与许可见 [LICENSE](LICENSE);本仓库新增部分同样以 MIT 发布。

## 致谢

- [AgriciDaniel/claude-seo](https://github.com/AgriciDaniel/claude-seo) —— 上游项目与全部核心能力
