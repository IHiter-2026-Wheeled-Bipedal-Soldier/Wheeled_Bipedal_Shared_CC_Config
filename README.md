# Workflow Summary

推荐工作流程写在 Resources/AI 开发工作流系统设计框架.md 里面。

整个工作流采用解耦方式构建，不强制按照整个工作流执行，可以单独使用工作流中的各项技能。
默认启用 git 自动管理：会话首个 prompt 前自动 CPST 提交，会话结束自动 CPED 提交（仅在有变更时提交）。
若当前目录未 git init，则仅在本 session 询问一次是否初始化 git；用户可选择本 session 跳过。
采用自迭代记忆逻辑构建，会自动记忆处理过程中遇见的错误，防止下次犯同样的错误。

借鉴自：

- [Claude Code Overview](https://code.claude.com/docs/zh-CN/overview)
- [anthropics/claude-code](https://github.com/anthropics/claude-code)
- [obra/superpowers](https://github.com/obra/superpowers)
- [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code/tree/main/skills/continuous-learning-v2)
