# 部署指导书（集中化 VPC 终端节点访问）

## 1. 前置条件

| 项 | 要求 |
|---|---|
| 账号 | 华为云账号，具备 VPC / VPCEP / DNS 创建权限 |
| 工具 | Terraform ≥ 1.5（本实践在 1.9.8 验证） |
| Provider | `huaweicloud/huaweicloud` ~> 1.70（已验证 1.96.1） |
| 区域 | 默认 `cn-north-4`；更换区域须同步核对 `public_service_name` 与 `zone_name` |
| 凭据 | 通过环境变量注入，禁止硬编码：<br/>`export HW_ACCESS_KEY="<HW_ACCESS_KEY>"`<br/>`export HW_SECRET_KEY="<HW_SECRET_KEY>"`<br/>（临时凭证可选 `export HW_SECURITY_TOKEN="<TOKEN>"`） |

> 凭据一律使用占位符 `<HW_ACCESS_KEY>` / `<HW_SECRET_KEY>` 表示，真实值不得写入任何文件或文档。

## 2. 快速开始

```bash
# 1. 进入 Terraform 目录
cd infra

# 2. 初始化（拉取 provider）
terraform init

# 3. 预览变更（不会真正创建资源）
terraform plan

# 4. 确认部署清单
terraform apply
```

## 3. 关键参数

在 `infra/variables.tf` 的 `endpoint_services` 中维护服务列表，每项三要素：

- `short_name`：资源命名简称（如 `dns`）；
- `public_service_name`：VPCEP 控制台「公共终端节点服务」中查到的服务名（按 region 核实）；
- `zone_name`：要覆盖解析的私有 DNS 区域名（沿用真实服务域名可透明解析；测试期可改为合成域名）。

新增一个接口型服务，只需在列表中追加一项，Hub 终端节点、私有区域、A 记录、区域关联会随之自动生成。

## 4. 验证（部署成功后）

1. **终端节点就绪**：在 VPCEP 控制台确认终端节点状态为「可用」，记录其内网 IP。
2. **DNS 解析覆盖**：在 Spoke VPC 内创建一台临时 ECS，执行：
```bash
nslookup dns.cn-north-4.myhuaweicloud.com
# 预期返回 Hub 终端节点内网 IP（即私有区域 A 记录值）
```
3. **网络连通**：从 Spoke ECS 对终端节点 IP 的 443 端口做连通性测试（如 `curl -v https://<zone_name>`），确认经对等连接可达。
4. **跨 VPC 关联生效**：确认 Spoke VPC 已出现在该私有区域的「关联 VPC」列表中。

## 5. 清理资源

调试 / 验证完成后务必销毁全部资源：

```bash
cd infra
terraform destroy
```

`terraform destroy` 会移除本 state 内全部资源；执行后建议在控制台 API 直查 Hub/Spoke VPC、终端节点、私有区域确无残留（尤其终端节点 ENI 与私有区域关联）。
