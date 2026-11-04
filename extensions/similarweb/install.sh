#!/usr/bin/env bash
set -euo pipefail

# seo-similarweb 扩展安装器(脱敏发行版,幂等)
#
# 用法:
#   SW_API_BASE="https://你的代理地址" bash extensions/similarweb/install.sh
#
# 功能:
#   1) 将 seo-similarweb 技能/代理装入 claude-seo 所在的 skills/agents 目录
#      (自动探测 ~/.claude 与 ~/.zcode;可用 CLAUDE_SEO_SKILLS 显式指定)
#   2) SW_API_BASE 设置时,把 SKILL.md 中的 __SW_API_BASE__ 占位符替换为真实地址;
#      未设置则保留占位并警告(技能结构可用但不可调用)
#   3) patch seo hub 命令表与代理清单(幂等)
#   4) 向 seo-backlinks/cluster/sxo/content/technical 代理注入数据源提示(幂等)
#
# 本仓库不含任何真实 API 端点;地址由使用者在安装时注入。

SRC="$(cd "$(dirname "$0")" && pwd)"
SW="${SW_API_BASE:-}"

# 探测目标目录
if [ -n "${CLAUDE_SEO_SKILLS:-}" ]; then
  SKILLS="${CLAUDE_SEO_SKILLS}"
elif [ -d "${HOME}/.claude/skills/seo" ]; then
  SKILLS="${HOME}/.claude/skills"
elif [ -d "${HOME}/.zcode/skills/seo" ]; then
  SKILLS="${HOME}/.zcode/skills"
else
  echo "✗ 未找到已安装的 claude-seo(查找 ~/.claude/skills/seo 与 ~/.zcode/skills/seo)。" >&2
  echo "  先运行仓库根目录的 install.sh,或用 CLAUDE_SEO_SKILLS=<skills目录> 指定。" >&2
  exit 1
fi
AGENTS="$(dirname "${SKILLS}")/agents"
MARK="SIMILARWEB-DATASOURCE"

echo "→ 目标:${SKILLS}"
[ -z "${SW}" ] && echo "⚠ 未设置 SW_API_BASE:将以占位符安装(技能不可实际调用);设置后重跑本脚本即可激活"

echo "→ [1/4] 安装技能与代理..."
mkdir -p "${SKILLS}/seo-similarweb/references"
sed "s#__SW_API_BASE__#${SW:-__SW_API_BASE__}#g" \
  "${SRC}/skills/seo-similarweb/SKILL.md" > "${SKILLS}/seo-similarweb/SKILL.md"
[ -f "${SRC}/references/llms-full.txt" ] && cp "${SRC}/references/llms-full.txt" "${SKILLS}/seo-similarweb/references/"
cp "${SRC}/agents/seo-similarweb.md" "${AGENTS}/seo-similarweb.md"

echo "→ [2/4] patch seo hub..."
HUB="${SKILLS}/seo/SKILL.md"
if [ -f "${HUB}" ] && ! grep -q "seo similarweb" "${HUB}"; then
  sed -i '' '/| `\/seo dataforseo \[command\]`/a\
| `/seo similarweb [command] [domain\|keyword]` | 免费 SimilarWeb 数据(自托管代理,无需 key):流量/渠道/地理/关键词量难度CPC/URL级外链/相似站/排名。详见 seo-similarweb 扩展 |
' "${HUB}" 2>/dev/null || sed -i '/| `\/seo dataforseo \[command\]`/a\
| `/seo similarweb [command] [domain\|keyword]` | 免费 SimilarWeb 数据(自托管代理,无需 key):流量/渠道/地理/关键词量难度CPC/URL级外链/相似站/排名。详见 seo-similarweb 扩展 |
' "${HUB}"
fi

echo "→ [3/4] 注入代理数据源提示..."
inject() {
  local f="${AGENTS}/$1.md" role="$2"
  [ -f "$f" ] || { echo "  ⚠ 缺 $f"; return; }
  grep -q "${MARK}" "$f" && { echo "  ✓ $1 已注入"; return; }
  cat >> "$f" <<EOF

## 免费数据源(${MARK},优先于推测)

自托管 SimilarWeb 代理 API(零鉴权)。调用纪律与 27 端点速查:**先读 seo-similarweb 技能的 SKILL.md**(GET 无 body;POST 需 Content-Type: application/json 且 body 固定 [];参数 URL query 区分大小写;90s 超时;UPSTREAM_RATE_LIMITED/NO_AVAILABLE_ACCOUNT 退避 30-60s 重试,NOT_FOUND 为无数据)。
角色用法:${role}
数据是估算值,报告须带口径;无数据时回退原免费路径,不阻塞任务。
EOF
  echo "  ✓ $1 已注入"
}
inject seo-backlinks "用 #2 backlinks 端点补 URL 级外链(UrlFrom/UrlTo/Anchor/DomainScore/DoFollow/IsNew/IsLost),替代仅 Common Crawl 域名级的 Tier 0 缺口;锚文本分布与竞品外链对比同用 #2。"
inject seo-cluster "用 #1 keyword suggestions 的真实 windowVolume/difficulty/cpc/primaryIntent 作为聚类与优先级权重(替代推测);#4 rankers 验证每个簇由谁承接。"
inject seo-sxo "用 #1 的 primaryIntent/secondaryIntent + volume 校准意图匹配;#9 kw-overview 查目标站现有词与排名位置。"
inject seo-content "内容评估需要市场基线时,用 #3 topkeywords(竞品非品牌词)与 #11 engagement 对标同类站内容表现。"
inject seo-technical "竞品对标场景可用 #8 devices / #22-25 月度趋势佐证流量健康度;一般技术审计无需调用。"

echo "→ [4/4] 完成。"
[ -z "${SW}" ] && echo "⚠ 再次提醒:SW_API_BASE 未设置,技能当前为占位状态。激活方式:" && echo "  SW_API_BASE=https://你的代理 bash extensions/similarweb/install.sh"
echo "  /seo similarweb keywords <kw> | backlinks <domain> | overview <domain> ..."
