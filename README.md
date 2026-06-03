# cctap

Claude Code 到 macOS 通知的桥接小工具。

## 它做什么

多个 Claude Code 会话并发跑时，你常常分不清哪个会话已经停下、哪个还在等你确认。cctap 在会话**完成一轮**、**等待确认**或**异常退出**时弹出一条原生 macOS 通知横幅，点击横幅会尝试把对应的 Warp tab 切到前台。

仅支持 macOS。v1 仅支持 Warp 作为目标终端。

## 安装

```bash
brew install lilwind7/tap/cctap
cctap install
```

`cctap install` 会做这几件事：

- 把 `~/.claude/settings.json` 备份到 `~/.claude/backups/`
- 幂等地追加 cctap 的三个 hook（Stop / Notification / SessionEnd）到 settings.json
- 运行 `cctap doctor` 自检

第一次使用前需要在系统里授权一次：

**系统设置 → 隐私与安全性 → 自动化** → 允许 Terminal / Warp 控制 **Warp** 和 **System Events**。

## 用法

装完即用，无需额外配置。Claude Code 会话触发对应 hook 时自动弹通知。下列子命令供日常使用：

| 命令 | 作用 |
|---|---|
| `cctap install` | 注入 hooks 到 `~/.claude/settings.json`（幂等，可重复运行） |
| `cctap uninstall` | 仅移除 cctap 自己的 hooks，不影响其他 hook |
| `cctap doctor` | 检查依赖、权限和最近日志 |
| `cctap test-notify` | 立刻发一条测试横幅，确认通知通路正常 |
| `cctap stop` | Stop hook 处理器（由 Claude Code 调用，不要手动执行） |
| `cctap notification` | Notification hook 处理器（由 Claude Code 调用） |
| `cctap session-end` | SessionEnd hook 处理器（由 Claude Code 调用） |

## 设计要点

- **静默通知**：所有横幅都不带声音，避免并发会话连环响。
- **替换不堆叠**：同一会话的连续通知用相同 group id 投递，新的覆盖旧的，不在通知中心积压。
- **聚焦时跳过**：若当前 Warp tab 已经对准会话的 cwd，cctap 判定你已经在看了，直接不弹。
- **永远 exit 0**：所有 hook 路径承诺 ≤1s 返回、`exit 0`、不写 stdout，绝不阻塞 Claude Code。
- **切 tab 是 best-effort**：点击横幅尝试通过 AppleScript 激活匹配的 Warp tab，但 Warp 的脚本字典随版本变化，失败也不影响通知本身。

## 排错

第一步永远是：

```bash
cctap doctor
```

`doctor` 会检查 `terminal-notifier`、`jq`、`osascript` 是否就位，Warp 是否在跑，并把最近 10 条日志贴出来。

日志文件：

```
~/.cache/cctap/cctap.log
```

常见问题：

- **没看到横幅**：先 `cctap test-notify`。如果连测试横幅都没有，多半是 macOS 通知权限没给 `terminal-notifier`，去**系统设置 → 通知**里找 `terminal-notifier` 打开。
- **点横幅没切 tab**：检查**自动化**权限是否授予；Warp 没在跑时无法切换；Warp 大版本更新后 AppleScript 字典可能变化，此时切 tab 会失败但通知仍正常。
- **install 报错 / settings.json 被改坏**：原文件已备份到 `~/.claude/backups/settings.<timestamp>.json`，可手动还原。

## 卸载

```bash
cctap uninstall      # 从 settings.json 移除 cctap 的 hooks
brew uninstall cctap # 移除二进制
```

`uninstall` 不删 `~/.cache/cctap/` 和 `~/.claude/backups/`，需要的话自己清理。

## 给贡献者

仓库布局：

```
bin/cctap              主入口，子命令分发
lib/transcript.sh      解析 Claude Code transcript（jsonl）
lib/notify.sh          terminal-notifier 封装
lib/focus_check.sh     判断 Warp 当前是否对准某个 cwd
lib/focus_warp.sh      点击横幅后激活匹配的 Warp tab
share/install/         hooks 片段 + 幂等 jq merge 脚本
test/unit/             bats 单元测试
test/integration/      bats 集成测试
test/fixtures/         transcript / payload 示例
test/helpers/          bats 公共 helpers
docs/superpowers/plans/2026-06-02-cctap.md    设计与实施计划
```

跑测试需要 bats-core 以及 `bats-assert` / `bats-support`。后两个**不在 homebrew/core**，住在 `kaos/shell` tap 里：

```bash
brew tap kaos/shell
brew install bats-core kaos/shell/bats-assert kaos/shell/bats-support
```

跑全部测试：

```bash
bats test/unit test/integration
```

设计与逐步实施的细节都在 `docs/superpowers/plans/2026-06-02-cctap.md`，改动前建议先读一遍。
