# cctap — 设计文档

**状态：** 草稿
**日期：** 2026-06-02
**作者：** jcong830

## 1. 问题

并发跑多个 Claude Code（CC）会话时，很容易错过某个会话**干完一轮**、**等你输入**或**意外退出**的时刻。需要手动来回切窗口才能发现哪个停了。目前没有内建机制把"注意力"推回给用户。

## 2. 目标

做一个 macOS 专用小工具 **cctap**，在 CC 会话需要关注时立刻弹出原生通知横幅，并支持点击横幅一键切回那个 Warp tab。

具体目标：

1. CC 完成一轮回答（Stop hook）时通知。
2. CC 需要用户输入（Notification hook：权限弹窗、idle 等待）时通知。
3. CC 异常退出（SessionEnd hook，非正常 reason）时通知。
4. 通知里能一眼看出是**哪个会话**——用工作目录 + 最近一条用户消息摘要标识。
5. 如果你当前焦点已经在那个 Warp tab 上，**不再通知**。
6. 点击横幅能把对应的 Warp tab 切到前台。
7. 通过 Homebrew tap 分发，安装命令一行：`brew install jcong830/tap/cctap`。

## 3. 非目标

- 不支持其他终端（iTerm2、Apple Terminal、VSCode 内嵌终端等）。MVP 只支持 Warp，tab 切换逻辑也是 Warp 专属的。
- 不支持其他系统（Linux、Windows）。
- 不做手机推送 / Slack / IM。本地 macOS 横幅即可。
- 不做按事件区分的声音。所有通知**静默**。
- 不替代或冲突现有 hook（`dcc`、`pii-detector` 等）。cctap 只**追加**到用户的 hooks 数组里，绝不覆盖。

## 4. 已锁定的关键决策

| 决策项 | 选择 |
|---|---|
| 通知方式 | macOS 原生通知，底层用 `terminal-notifier` |
| 触发事件 | `Stop` + `Notification` + `SessionEnd`（仅异常 reason） |
| 通知内容 | 项目目录名 + 事件类型 + 最近一条用户消息摘要 |
| 点击行为 | 切回匹配的 Warp tab |
| 声音 | 静默（仅横幅） |
| 焦点已对上时跳过 | 是——当前 Warp tab 的工作目录与事件 cwd 匹配时不发通知 |
| 分发方式 | Homebrew tap (`jcong830/homebrew-tap`) |

## 5. 架构

入口 `bin/cctap`（bash），根据第一个参数分派：

- `stop` / `notification` / `session-end` —— hook 处理器（被 CC 调用）
- `install` / `uninstall` —— 修改 settings.json
- `doctor` —— 环境自检
- `test-notify` —— 发一条合成通知，做手动 smoke

辅助模块放 `lib/`，每个文件保持小且可独立 source，方便用 bats 做单测。

### 5.1 仓库布局

```
cctap/
├── bin/
│   └── cctap                  # 入口，~150 LoC bash
├── lib/
│   ├── focus_check.sh         # osascript：当前 Warp tab 的 cwd 是否 == 事件 cwd？
│   ├── focus_warp.sh          # osascript：把工作目录匹配 <cwd> 的 Warp tab 切到前台
│   ├── transcript.sh          # jq 流水线：从 transcript JSONL 抽出最后一条 user message
│   └── notify.sh              # terminal-notifier 的封装
├── share/
│   └── install/
│       ├── hooks-snippet.json # 要 merge 进 ~/.claude/settings.json 的三段 hook
│       └── merge_hooks.sh     # 基于 jq 的幂等 merge
├── test/
│   ├── unit/                  # lib/ 的 bats 单测
│   ├── integration/           # 用 fixture + $PATH 注入的假 terminal-notifier 做分派链路测试
│   └── fixtures/              # 各类 hook payload 样本（stop / notification / session-end）
├── Formula/cctap.rb           # 同步到 homebrew-tap 仓库
└── README.md
```

Homebrew tap 仓库（`homebrew-tap`）放正式的 `cctap.rb`；in-tree 的 `Formula/cctap.rb` 用于开发期方便测试和 CI。

### 5.2 数据流（以 Stop 事件为例）

```
CC hook 触发，stdin 给到 JSON：{session_id, transcript_path, cwd, ...}
    │
    ▼
bin/cctap stop
    │
    ├─ 解析 payload (jq) → cwd, transcript_path, session_id
    ├─ focus_check.sh "$cwd"   → 若 Warp 当前 tab 匹配，静默 exit 0
    ├─ transcript.sh "$transcript_path" → 取最后一条 user message，截断到 ~60 字
    ├─ 组装：
    │     title    = "$(basename $cwd) · 已完成"
    │     subtitle = "$user_msg_summary"
    │     message  = "Claude 已结束本轮"
    └─ notify.sh:
          terminal-notifier
            -title $title -subtitle $subtitle -message $message
            -group "cctap:$cwd"      # 同一会话的通知替换而非堆叠
            -sender com.warp.Warp    # 通知图标归属 Warp
            -execute "lib/focus_warp.sh '$cwd'"
```

### 5.3 三种事件的差异

| 事件 | 标题后缀 | subtitle 数据源 | message |
|---|---|---|---|
| `stop` | `· 已完成` | transcript 里最后一条 user message | `Claude 已结束本轮` |
| `notification` | `· 待确认` | hook payload 自带的 `message` 字段（如 "Claude needs your permission to use Bash"） | （空——subtitle 已经说明了原因） |
| `session-end`（异常） | `· 异常退出` | transcript 里最后一条 user message | `原因: $reason` |

`session-end` 要做过滤：`reason ∈ {clear, logout}` 时跳过（这是用户主动结束）；`prompt_input_exit`、`other` 以及其他未知值都视为值得通知。

### 5.4 Warp 切焦点的实现

`focus_check.sh "$cwd"`：

```applescript
tell application "Warp"
    if not frontmost then return "no"
    set wd to working directory of selected tab of front window
    if wd starts with "$cwd" then return "yes" else return "no"
end tell
```

退出码 0 = "命中，跳过通知"。

`focus_warp.sh "$cwd"`：

```applescript
tell application "Warp"
    activate
    repeat with w in windows
        repeat with t in tabs of w
            if (working directory of t) starts with "$cwd" then
                set index of w to 1
                set selected of t to true
                return
            end if
        end repeat
    end repeat
end tell
```

找不到匹配 tab 时的兜底：仅 `activate Warp`。README 里要明确说"tab 级切焦点是 best-effort"——Warp 的 AppleScript 字典随版本会变，不保证每个版本都能做到 tab 级精确切换。

## 6. 可靠性

cctap 跑在 CC 的主循环里。契约：

- **所有 hook 路径 exit 0**，哪怕内部出错。CC 绝不能因为通知挂了而出问题。
- **所有 hook 路径 ≤ 1s 返回。** 重活（如 transcript 解析）有硬超时；超时则降级为只发标题。
- **不写 stdout**，只写 stderr，避免污染 hook 协议。

| 失败场景 | 行为 |
|---|---|
| `terminal-notifier` 未安装 | stderr 警告，exit 0。`doctor` 标为致命错误。Brew formula 已声明为 runtime 依赖，正常装下来不会出现。 |
| `jq` 未安装 | 同上。 |
| `transcript_path` 不存在 / 解析失败 | subtitle 降级为空，通知照发。 |
| Warp AppleScript 失败（权限缺失 / 版本不兼容） | `focus_check` 视为"未命中"，正常发通知；`focus_warp` 降级为仅 `activate Warp`。 |
| Hook payload JSON 损坏 | exit 0，stderr 记错误。 |
| 任何其他异常 | `trap` 兜底，exit 0。 |

日志写到 `~/.cache/cctap/cctap.log`，带简单的按大小轮转（每次运行时若 > 1 MB 则截断保留最后 1000 行）。`cctap doctor` 会 tail 最近几行帮排查。

## 7. 安装 / 卸载

`brew install jcong830/tap/cctap` 把 `cctap` 装到 PATH 上，同时拉依赖（`terminal-notifier`、`jq`）。

`cctap install`：

1. 把 `~/.claude/settings.json` 备份到 `~/.claude/backups/settings.<timestamp>.json`。
2. 用 jq 把 `share/install/hooks-snippet.json` 里的三条 hook（Stop、Notification、SessionEnd）**追加**到现有 `hooks` 对象的对应 matcher 数组里，保留所有现有 hook（`dcc`、`pii-detector` 等）原样不动。
3. 幂等：检测到 cctap 的 hook 已存在则跳过。
4. 打印一份权限清单：系统设置 → 隐私与安全性 → 自动化 → Terminal/Warp → 允许控制 Warp 和系统事件。
5. 自动跑一次 `cctap doctor` 确认环境就绪。

`cctap uninstall`：

1. 同样备份 settings.json。
2. 只移除 cctap 的 entry（通过 command 字符串包含 `cctap` 匹配），其余 hook 原样保留。
3. 打印下一步 `brew uninstall cctap`。

## 8. 测试策略

| 层 | 工具 | 覆盖范围 |
|---|---|---|
| 单元 | bats-core | transcript 解析、cwd 前缀匹配、字符串截断、settings.json merge 的 jq 表达式 |
| 集成 | bats + `$PATH` 注入的假 `terminal-notifier`（记录被调用的 argv） | `cctap stop < payload.json` 的端到端分派：标题/副标题/正文/group/execute 正确；无 stdout；exit 0 |
| 手动 smoke | `cctap doctor`、`cctap test-notify` | 通知真能弹出来；点击真能切 Warp；各事件类型标题对得上 |
| CI | GitHub Actions（`macos-latest`）：跑 bats + `brew test cctap` | 运行时正确性 + formula 健康 |

所有集成 fixture 放 `test/fixtures/`，内容是从真实 CC 会话里抓出来、脱敏后的 payload JSON。

## 9. 推迟到实现阶段的开放项

- settings.json 幂等 merge 的精确 jq 表达式——用单测驱动写。
- `doctor` 输出要不要上色 / 格式化——纯外观，实现时再定。
- 日志轮转细节——先用"文件 > 1 MB 时截断到最后 N 行"，跑一阵再看是否需要调整。

这些都是战术层面的，不会影响上面任何契约。

## 10. 未来工作（v1 之外）

- 其他终端支持（iTerm2、Apple Terminal）。需要把 `focus_*` 做成可插拔后端，按 `$TERM_PROGRAM` 等环境变量分派。
- 手机推送 fallback（Bark / IM webhook 等）——笔记本空闲时把通知推到手机。
- "把项目 X 的通知静默 30 分钟" 这种 CLI 子命令。
- 按事件严重性分声音（v1 用户已明确不要）。
