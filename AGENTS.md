# AGENTS.md — Agent 操作規則（全域）

> 本文件定義所有 AI agent 操作 fleet-command 及其子專案時的規則。  
> 適用於：OpenClaw、Claude Code CLI、Copilot、Antigravity 及任何未來的 agent。

---

## Agent 身份

- **Agent GitHub 帳號**: `{owner}-agent`（非主人帳號）
- **所有 agent 產生的 commit 必須使用 agent 帳號**，不可冒用主人帳號
- Agent 的 commit message 格式：`[agent] {type}: {description}`
  - 例：`[agent] feat: 更新 CardSense API spec 中的 endpoint 定義`
  - 例：`[agent] docs: 整理 RTA v1 架構決策記錄`

---

## 權限邊界

### ✅ 允許

- Push 到 feature branches（命名：`agent/{task-description}`）
- 開 Pull Request，附上變更摘要
- 建立、更新、關閉 Issues
- 更新 README.md、docs/ 目錄下的文件
- 寫入 agent-log/ 目錄
- 讀取所有 spec-*.md、arch-*.md、ref-*.md

### ❌ 禁止

- Push 到 `main` branch（必須走 PR → 主人 review → merge）
- Merge 任何 PR（僅主人可 merge）
- 刪除 branch、tag、release
- 修改 GitHub Actions / CI/CD 設定
- 修改 repo Settings（collaborators, branch protection 等）
- 修改本文件（AGENTS.md）或安全相關設定
- 存取、複製、引用公司程式碼或內部文件
- 接觸主人的個人 credentials（SSH keys, 個人 PAT 等）

---

## 各專案操作範圍

| Repo | Agent 可做的事 | Agent 不可做的事 |
|------|---------------|-----------------|
| fleet-command | 更新 agent-log/、建議 spec 修改（走 PR） | 直接修改 spec-*.md 的 main branch |
| cardsense-* | Feature branch 開發、寫測試、更新文件 | 修改 DB migration、CI config |
| review-trust-analyzer | 同上 | 修改 model training config |
| seedcraft | 同上 | 修改 LINE channel 設定 |
| techtrend | 同上 | 修改 Stripe 付款設定 |
| smartchoice | 同上 | 修改 Google Maps API key 設定 |
| fridgemanager | 同上 | 修改 push notification 設定 |

---

## 工作流程

### 標準任務流程

```
1. 讀取 fleet-command 中的相關 spec-*.md，了解專案全貌
2. 讀取目標 repo 的 CLAUDE.md，了解技術棧和開發規範
3. 建立 feature branch: agent/{任務描述}
4. 執行任務（寫 code / 更新文件 / 其他）
5. 寫入操作日誌到 fleet-command/agent-log/YYYY-MM-DD.md
6. 開 PR，附上：
   - 變更摘要（做了什麼、為什麼）
   - 影響範圍（哪些檔案、哪些功能）
   - 待主人確認的事項（如果有）
7. 等待主人 review → merge 或要求修改
```

### 跨專案任務

涉及多個 repo 的任務（例如跨專案整合）：

```
1. 先在 fleet-command 開 Issue 描述任務全貌
2. 各 repo 分別開 feature branch
3. 各 repo 分別開 PR，互相引用
4. 主人統一 review 後依序 merge
```

---

## Branch 類型字典

- `feat`: 新功能或可見能力增加
- `fix`: bug 修正或回歸修正
- `chore`: 文件、設定、生成檔、流程、維護，或不改行為的重構
- `wip`: 探索中、尚未可合併、需要保留中間態

Branch 命名格式：

```text
{type}/{slug}
```

規則：

- branch type 必須依工作內容選擇，不要一律使用同一種前綴
- 若同一批工作跨多個 repo，所有 repo 使用相同的 `slug`
- 同一批工作可在不同 repo 使用不同 type，但預設應盡量收斂成同一 type
- 若工作內容已明確可歸類，不要使用 `wip`

### 完成開發後流程

每次完成一輪開發後，agent 應依序執行：

```text
1. 跑對應驗證
2. 判斷是否需要更新 fleet-command
3. 若 workspace.manifest.json、WORKSPACE_CONTEXT.generated.md、.rgignore 相關內容變更，執行 renderer
4. 檢查各 repo git status
5. 按 repo + branch type + shared slug 整理 branch
6. 依 repo 分開 batch commit
7. 依 repo 分開 batch push
```

補充規則：

- Python 相關套件管理與命令執行一律使用 `uv`
- 若變更影響 workflow、架構、agent 規範、workspace 規則、shared skill、source-of-truth 文件，優先更新 `fleet-command`
- renderer 指的是：
  - `python fleet-command/scripts/render_workspace_assets.py`
- batch commit 的單位是「每個 repo 各自提交」，不要把多個 repo 的變更混成同一個 commit
- batch push 的單位也是「每個 repo 各自 push 到對應 branch」

## 日誌規範

每次 agent 操作結束後，寫入 `agent-log/YYYY-MM-DD.md`：

```markdown
## HH:MM — {任務標題}

- **Agent**: OpenClaw / Claude Code / Copilot
- **Repo**: {目標 repo 名稱}
- **任務**: {簡述做了什麼}
- **結果**: {成功/部分完成/失敗}
- **PR**: #{PR 編號}（如有）
- **備註**: {遇到的問題或需要主人注意的事}
```

---

## 安全規則

1. **絕不在 commit 中包含任何 credentials**（token, password, API key）
2. **絕不修改 .gitignore 來取消忽略敏感檔案**
3. **發現疑似安全問題時，立即停止操作並在 Discord 回報**
4. **不主動安裝未經主人核准的第三方 dependency**
5. **不執行 `rm -rf`、`DROP TABLE` 等破壞性操作，除非 PR 中明確說明**

---

## 與主人的溝通

- **日常回報**: 透過 agent-log/ 和 PR description
- **需要核准**: 透過 Discord #approvals 頻道
- **緊急問題**: 透過 Discord #general 頻道直接通知
- **不確定的事**: 寧可問，不要猜。開 Issue 或 Discord 詢問。

---

*本文件由主人維護，agent 不可自行修改。*
## CardSense Workspace Completion

Before ending any CardSense workspace task, run the global `cardsense-workspace-completion` skill. If that global skill is unavailable, use the local dashboard rules in `fleet-command/skills/fleet-dashboard-closeout/SKILL.md`.

This is part of the default completion flow, not an optional follow-up. Use it to decide verification, dashboard/status updates, tool choices, branch hygiene, commit, push, and PR status.

Minimum closeout:

1. Inspect the task result and diff.
2. Classify the dashboard impact as `no_dashboard_change`, `status_update`, `release_evidence`, `open_queue_update`, or `workspace_rule_update`.
3. Update the smallest necessary set of files: `CardSense-Status.md`, `dashboard/data/*.json`, `agent-log/YYYY-MM-DD.md`, `workspace/workspace.manifest.json`, or generated contexts.
4. Run `uv run python -m unittest tests.test_dashboard_data`.
5. If dashboard files changed, serve `fleet-command/dashboard` over HTTP with `uv run python -m http.server 5177` and smoke it with Chrome via gstack/browser.
6. Confirm the task branch before committing. Do not finish implementation work on `main` or `master` unless the user explicitly asked for that.
7. Commit verified changes by repo, push the task branch, and create or update the PR when remote access is available.
8. Report the classification, files changed, verification result, branch, commit, push, PR status, and any remaining drift.

Keep the dashboard focused:

- Current repo health and open work belong in `dashboard/data/checks.json`.
- Completed repair or release evidence belongs in `dashboard/data/releases.json`.
- Roadmap state belongs in `dashboard/data/roadmap.json`.
- Project stage, focus, commands, and links belong in `dashboard/data/projects.json`.

Tool defaults:

- Python commands use `uv run python`.
- Browser checks use installed Google Chrome through gstack/browser. If Chrome/gstack is unavailable, report the fallback explicitly.

## Development CLI Checks

During development, use `fleet-command/skills/cardsense-dev-checks/SKILL.md` for frequent CLI/API verification: targeted repo tests, local/prod API smoke with `curl`, Chrome/gstack browser smoke, GitHub PR/CI inspection with `gh`, and Vercel read-only inspection when available.

Use `cardsense-dev-checks` while building or debugging. Use `cardsense-workspace-completion` before ending the task.
