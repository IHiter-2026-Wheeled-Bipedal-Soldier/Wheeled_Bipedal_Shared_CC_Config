# Claude 配置管理与跨项目记忆 · 实施方案 v2

## 目标概述

1. **Rules 整合**：将分散在 hooks/、skills/ 的规范文档集中到 `rules/`
2. **清理废弃文件**：删除 [auto-commit.py](file:///e:/CODE_project/IHiter-2026-Wheeled-Bipedal-Soldier/Wheeled_Bipedal_Shared_CC_Config/hooks/auto-commit.py)、[auto-commit-push-pr.py](file:///e:/CODE_project/IHiter-2026-Wheeled-Bipedal-Soldier/Wheeled_Bipedal_Shared_CC_Config/hooks/auto-commit-push-pr.py)、`__pycache__/`（已被 skills 替代）
3. **Git 工作流 Skills 套件**：基于现有技能，设计完整、最小化的一键协作开发套件
4. **跨项目记忆模块**：初始化 `Wheeled_Bipedal_Shared_CC_Memory` 内部结构

---

## Proposed Changes

### 一、CC_Config 仓库：Rules 目录整合

将以下文件**迁移**（移动，不是复制）到 `rules/`，并修正所有引用路径：

| 原位置 | 迁移目标 |
|--------|----------|
| [hooks/workflow-guide.md](file:///e:/CODE_project/IHiter-2026-Wheeled-Bipedal-Soldier/Wheeled_Bipedal_Shared_CC_Config/hooks/workflow-guide.md) | `rules/workflow-guide.md` |
| [hooks/git-harness-agent-policy.md](file:///e:/CODE_project/IHiter-2026-Wheeled-Bipedal-Soldier/Wheeled_Bipedal_Shared_CC_Config/hooks/git-harness-agent-policy.md) | `rules/git-harness-agent-policy.md` |
| [skills/code-review/naming-rules.md](file:///e:/CODE_project/IHiter-2026-Wheeled-Bipedal-Soldier/Wheeled_Bipedal_Shared_CC_Config/skills/code-review/naming-rules.md) | `rules/naming-rules.md` |
| [skills/code-review/developing-styles.md](file:///e:/CODE_project/IHiter-2026-Wheeled-Bipedal-Soldier/Wheeled_Bipedal_Shared_CC_Config/skills/code-review/developing-styles.md) | `rules/developing-styles.md` |

**影响的引用路径检查**：
- `skills/code-review/SKILL.md` 中若引用上述文件，改为 `../../rules/` 相对路径
- `hooks/hook_*.sh` 若引用 workflow-guide / git-harness-agent-policy，改为 `../rules/` 相对路径

---

### 二、CC_Config 仓库：清理废弃文件

#### [DELETE] [hooks/auto-commit.py](file:///e:/CODE_project/IHiter-2026-Wheeled-Bipedal-Soldier/Wheeled_Bipedal_Shared_CC_Config/hooks/auto-commit.py)
#### [DELETE] [hooks/auto-commit-push-pr.py](file:///e:/CODE_project/IHiter-2026-Wheeled-Bipedal-Soldier/Wheeled_Bipedal_Shared_CC_Config/hooks/auto-commit-push-pr.py)  
#### [DELETE] `hooks/__pycache__/`

这些 Python 脚本已被 skills/ 套件取代，不再需要。

---

### 三、Git 工作流 Skills 套件（完整设计）

**设计原则**：skills 数量最少、每个技能专注单一职责、善用 AskUserQuestion 交互确认

#### 技能全景与触发词

| Skill | 触发词 | 核心功能 |
|-------|--------|----------|
| `commit` *(已有，保留)* | `/commit` | 智能 commit，conventional commits |
| `sync-submodules` *(新建)* | `/sync-submodules` | 一键更新所有子模块到最新远端版本 |
| `push-pr` *(重写 commit-push-pr)* | `/push-pr` | 推送当前分支 + 创建/更新 PR，可交互选择目标分支 |
| `sync-latest` *(新建)* | `/sync-latest` | 拉取主分支最新代码 + 变基/合并 + 更新子模块 |
| `clean-gone` *(已有，保留)* | `/clean-gone` | 清理已删除远端的本地 [gone] 分支 |
| `merge-work-branch` *(已有，保留)* | `/merge-work-branch` | 引导式合并工作分支，仅给出建议不自动执行 |

**完整协作开发流程**（6 个 skill 覆盖全生命周期）：

```
写代码
  └─ /commit           → 智能暂存 + Conventional Commit
  └─ /push-pr          → 推送 + 创建 PR（交互选目标分支）
审核通过后
  └─ /sync-latest      → 拉取主 + 更新子模块（pull + submodule sync）
  └─ /merge-work-branch→ 合并引导（建议命令，用户执行）
维护清理
  └─ /clean-gone       → 清理 [gone] 分支
  └─ /sync-submodules  → 单独同步子模块（如 .claude/memory 更新后）
```

#### [MODIFY] `skills/commit-push-pr/` → 重命名/重写为 `skills/push-pr/`

现有 `commit-push-pr` 职责不清晰（混合了 commit 和 push）。重写为纯 push + PR 技能：
- 先用 AskUserQuestion 确认目标分支（默认 main）
- 检测当前分支是否已 push，否则询问是否创建
- 执行 `git push` + `gh pr create` 或更新已有 PR

#### [NEW] `skills/sync-submodules/SKILL.md`
一键同步所有子模块（`.claude/` 和 `.claude/memory/`）到远端最新版本：
```bash
git submodule update --init --recursive --remote
```
先 AskUserQuestion 确认是否要拉取远端最新（--remote），还是仅初始化本地（--init）。

#### [NEW] `skills/sync-latest/SKILL.md`
一键与主分支同步：
1. AskUserQuestion：当前有未提交改动？建议先 `/commit`
2. `git fetch origin`
3. AskUserQuestion：选择变基（rebase）还是合并（merge）
4. `git pull origin main`（或 rebase）
5. `git submodule update --init --recursive`

---

### 四、跨项目记忆模块（CC_Memory 仓库）

#### [NEW] `MEMORY.md`（每次会话加载，控制在 200 行内）

```markdown
# 轮足机器人·跨项目记忆索引

## 通用已知 Bug
参考 @common-bugs.md

## 工作流偏好摘要
- 构建工具：Keil MDK（通过 keil-build skill 触发）
- Git 主分支：main，工作分支命名：work/<功能名>
- 提交语言：Conventional Commits，描述用中文
```

#### [NEW] `common-bugs.md`（替代现有空的 common-bugs.json）

按轮足机器人通用问题分类记录，Claude 按需读取。

---

## User Review Required

> [!IMPORTANT]
> **remote URL 待提供**：`.gitmodules` 需要两个仓库的远端 URL（GitHub/Gitee）。主仓库 Git 子模块挂载步骤将在你提供 URL 后由用户手动或另行执行。

> [!WARNING]
> **`commit-push-pr` 重命名为 `push-pr`**：若 CLAUDE.md 或其他配置中引用了旧技能名，需同步更新。

---

## Verification Plan

```bash
# 验证 rules/ 文件已迁移
ls .claude/rules/

# 验证 hooks/ 废弃文件已删除
ls .claude/hooks/ | grep auto-commit  # 应无输出

# 验证子模块技能描述准确
cat .claude/skills/sync-submodules/SKILL.md
```

手动验证：在 Claude Code 中输入 `/sync-submodules`，Claude 应触发对应技能并 AskUserQuestion。
