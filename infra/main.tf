# ============================================================================
# 集中化 VPC 终端节点访问（Hub & Spoke）— Terraform 入口
#
# 本文件仅作 IaC 入口标记。实际资源按职责拆分到：
#   - versions.tf  ：Terraform / Provider 版本约束
#   - variables.tf ：输入变量
#   - hub.tf       ：Hub VPC + 接口型终端节点 + 私有 DNS 区域 + A 记录
#   - spoke.tf     ：Spoke VPC + Hub ↔ Spoke 对等连接 + 双向路由
#   - test-ecs.tf  ：业务逻辑验证用临时 ECS（验证完用 -target 销毁）
#   - outputs.tf   ：输出（Hub VPC ID / Spoke VPC ID / 对等连接 ID / 终端节点 IP / 私有区域 ID 与名称）
#
# Terraform 会自动加载同目录全部 .tf，因此这里不写实际资源，只放注释与入口说明。
# ============================================================================
