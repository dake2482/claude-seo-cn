#!/usr/bin/env bash
set -euo pipefail

# Claude SEO → ZCode installer (adapted from upstream install.sh v2.5.0)
# Installs skills into ~/.zcode/skills and agents into ~/.zcode/agents.

SRC="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="${HOME}/.zcode/skills"
SKILL_DIR="${SKILL_ROOT}/seo"
AGENT_DIR="${HOME}/.zcode/agents"

echo "→ Installing Claude SEO (v2.5.0) into ZCode..."

mkdir -p "${SKILL_DIR}" "${AGENT_DIR}"

# Main skill + shared assets
cp -R "${SRC}/skills/seo/"* "${SKILL_DIR}/"
for skill_dir in "${SRC}/skills"/*/; do
    skill_name=$(basename "${skill_dir}")
    target="${SKILL_ROOT}/${skill_name}"
    mkdir -p "${target}"
    cp -R "${skill_dir}"* "${target}/"
done

for extra in schema data pdf scripts hooks; do
    [ -d "${SRC}/${extra}" ] && cp -R "${SRC}/${extra}" "${SKILL_DIR}/${extra}"
done
cp "${SRC}/requirements.txt" "${SKILL_DIR}/requirements.txt" 2>/dev/null || true
cp "${SRC}/.claude-plugin/plugin.json" "${SKILL_DIR}/runtime-plugin.json"
# Keep plugin manifest shape so runtime.py uses ~/Library/Application Support/claude-seo
# as its data dir (venv + Chromium) instead of polluting ~/.zcode/skills.
mkdir -p "${SKILL_DIR}/.claude-plugin"
cp "${SRC}/.claude-plugin/plugin.json" "${SKILL_DIR}/.claude-plugin/plugin.json"

# Agents
cp "${SRC}/agents/"*.md "${AGENT_DIR}/"

# Extensions (optional add-ons)
for ext_dir in "${SRC}/extensions"/*/; do
    [ -d "${ext_dir}" ] || continue
    ext_name=$(basename "${ext_dir}")
    [ -d "${ext_dir}skills" ] && for ext_skill in "${ext_dir}skills"/*/; do
        [ -d "${ext_skill}" ] || continue
        target="${SKILL_ROOT}/$(basename "${ext_skill}")"
        mkdir -p "${target}"
        cp -R "${ext_skill}"* "${target}/"
    done
    [ -d "${ext_dir}agents" ] && cp "${ext_dir}agents/"*.md "${AGENT_DIR}/" 2>/dev/null || true
    [ -d "${ext_dir}references" ] && { mkdir -p "${SKILL_DIR}/extensions/${ext_name}/references"; cp -R "${ext_dir}references/"* "${SKILL_DIR}/extensions/${ext_name}/references/"; }
    [ -d "${ext_dir}scripts" ] && { mkdir -p "${SKILL_DIR}/extensions/${ext_name}/scripts"; cp -R "${ext_dir}scripts/"* "${SKILL_DIR}/extensions/${ext_name}/scripts/"; }
done

# Rewrite ${CLAUDE_PLUGIN_ROOT} tokens to absolute ~/.zcode paths
chmod +x "${SKILL_DIR}/scripts/claude-seo" 2>/dev/null || true
chmod +x "${SKILL_DIR}/hooks/"*.sh "${SKILL_DIR}/hooks/"*.py 2>/dev/null || true

skills_root_esc=$(printf '%s' "${SKILL_ROOT}/" | sed 's/[#&\\]/\\&/g')
launcher_esc="${SKILL_DIR}/scripts/claude-seo"
rewrite_doc() {
    local doc="$1" temp_doc="${1}.zcode-tmp"
    sed -e "s#\${CLAUDE_PLUGIN_ROOT}/skills/#${skills_root_esc}#g" \
        -e "s#\${CLAUDE_PLUGIN_ROOT}/scripts/claude-seo#${launcher_esc}#g" \
        "${doc}" > "${temp_doc}"
    mv "${temp_doc}" "${doc}"
}
for source_root in "${SRC}/skills"/* "${SRC}/extensions"/*/skills/*; do
    [ -d "${source_root}" ] || continue
    skill_name=$(basename "${source_root}")
    while IFS= read -r -d '' source_doc; do
        relative_doc=${source_doc#"${source_root}/"}
        doc="${SKILL_ROOT}/${skill_name}/${relative_doc}"
        [ -f "${doc}" ] && rewrite_doc "${doc}"
    done < <(find "${source_root}" -type f -name '*.md' -print0)
done
for source_root in "${SRC}/extensions"/*/references; do
    [ -d "${source_root}" ] || continue
    ext_name=$(basename "$(dirname "${source_root}")")
    while IFS= read -r -d '' source_doc; do
        relative_doc=${source_doc#"${source_root}/"}
        doc="${SKILL_DIR}/extensions/${ext_name}/references/${relative_doc}"
        [ -f "${doc}" ] && rewrite_doc "${doc}"
    done < <(find "${source_root}" -type f -name '*.md' -print0)
done
for source_doc in "${SRC}/agents/"*.md "${SRC}/extensions"/*/agents/*.md; do
    [ -f "${source_doc}" ] || continue
    rewrite_doc "${AGENT_DIR}/$(basename "${source_doc}")"
done

echo "→ Creating isolated Python runtime (venv + Chromium)..."
set +e
"${SKILL_DIR}/scripts/claude-seo" setup
status=$?
set -e
if [ "${status}" -ne 0 ] && [ "${status}" -ne 10 ]; then
    echo "✗ Python runtime setup failed (exit ${status})." >&2
    exit 1
elif [ "${status}" -eq 10 ]; then
    echo "⚠ Runtime installed, but Chromium setup incomplete." >&2
fi

echo ""
echo "✓ Claude SEO installed for ZCode."
echo "  Skills:  ${SKILL_ROOT}/seo*  ($(ls "${SKILL_ROOT}" | grep -c '^seo'))"
echo "  Agents:  ${AGENT_DIR} ($(ls "${AGENT_DIR}" | wc -l | tr -d ' ') files)"
