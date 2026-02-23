---
name: setup-statusline
description: 設定 Claude Code 自訂狀態列，顯示 Context Window 剩餘量、API 額度、模型名稱、Git 分支
disable-model-invocation: true
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
---

# Setup Statusline Skill

當使用者執行 `/setup-statusline` 時，自動設定 Claude Code 的自訂狀態列。

## 執行步驟

### 1. 偵測作業系統

透過平台資訊判斷目前是 Windows 還是 macOS/Linux。

### 2. 複製腳本檔案

腳本來源位於此 Skill 目錄內：
- Windows: `~/.claude/skills/setup-statusline/scripts/statusline.ps1`
- macOS/Linux: `~/.claude/skills/setup-statusline/scripts/statusline.sh`

將對應腳本複製到 `~/.claude/` 目錄下：

**Windows:**
```
複製 ~/.claude/skills/setup-statusline/scripts/statusline.ps1 → ~/.claude/statusline.ps1
```

**macOS/Linux:**
```
複製 ~/.claude/skills/setup-statusline/scripts/statusline.sh → ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

### 3. 更新 settings.json

讀取 `~/.claude/settings.json`（若不存在則建立），加入或更新 `statusLine` 區段：

**Windows:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -ExecutionPolicy Bypass -File ~/.claude/statusline.ps1"
  }
}
```

注意：`~/.claude/statusline.ps1` 路徑需替換為完整絕對路徑（如 `C:/Users/<使用者名稱>/.claude/statusline.ps1`）。

**macOS/Linux:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

注意：`~/.claude/statusline.sh` 路徑需替換為完整絕對路徑（如 `/Users/<使用者名稱>/.claude/statusline.sh`）。

**重要**：保留 settings.json 中的所有其他既有設定，只新增或更新 `statusLine` 區段。

### 4. 驗證

完成後進行驗證：
1. 確認腳本檔案已複製到 `~/.claude/` 目錄
2. 確認 `settings.json` 的 `statusLine` 設定正確
3. 告知使用者重新啟動 Claude Code 即可看到新狀態列

### 狀態列顯示格式

```
Remaining: 85% | 5h:70%(3h45m) 7d:55%(5d2h) | Opus 4.6 | ProjectDir git:(branch)
```

- **Remaining: XX%** — Context Window 剩餘百分比
- **5h:XX%(Xh Xm) 7d:XX%(Xd Xh)** — API 速率限制額度（從 Anthropic OAuth Usage API 取得，15 秒快取）
- **模型名稱** — 簡化顯示（如 Opus 4.6、Sonnet 4.5）
- **目錄名稱 git:(分支)** — 目前工作目錄與 Git 分支
