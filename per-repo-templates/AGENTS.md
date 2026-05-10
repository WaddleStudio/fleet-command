# AGENTS.md — Agent 操作規則（{專案名稱}）

> 本檔案定義 agent 操作本 repo 時的規則。  
> 完整全域規則見 [fleet-command/AGENTS.md](https://github.com/skywalker6666/fleet-command)  
> 完整規格書見 [fleet-command/spec-{project}.md](https://github.com/skywalker6666/fleet-command)

---

## 快速規則

- **Agent 帳號**: `{owner}-agent`
- **Commit 格式**: `[agent] {type}: {description}`
- **Branch 命名**: `agent/{task-description}`
- **只能 push feature branch，不可 push main**
- **變更必須走 PR，等主人 review**

## 本 Repo 專屬規則

### ✅ Agent 可以做

- {列出 agent 在本 repo 中允許的操作}
- 例：在 src/ 下新增或修改程式碼（走 PR）
- 例：更新 tests/
- 例：更新 README.md 和 docs/

### ❌ Agent 不可以做

- {列出 agent 在本 repo 中禁止的操作}
- 例：修改 .env 或 config 中的 API key / 密碼
- 例：修改 CI/CD 設定
- 例：修改 DB migration 檔案（需主人確認）
- 例：修改本檔案（AGENTS.md）

## 開發 Context

- **技術棧**: {語言 / 框架 / DB}
- **目前狀態**: {Sprint X / V1 完成 / 規劃中}
- **最高優先任務**: 見 GitHub Issues 中 P0 標籤

## 日誌

操作完成後，將日誌寫入 **fleet-command** 的 `agent-log/YYYY-MM-DD.md`，不是本 repo。

---

*全域規則以 fleet-command/AGENTS.md 為準。本檔案僅補充 repo 專屬規則。*

## CardSense Browser Checks

- On Windows/Codex, use installed Google Chrome directly for CardSense browser verification.
- Do not try bundled `gstack/browse/dist/browse` first for page checks.
- Use Chrome headless for screenshots, DOM/text inspection, console/runtime checks, and route comparisons.
- If Chrome itself is unavailable, report the fallback explicitly.
