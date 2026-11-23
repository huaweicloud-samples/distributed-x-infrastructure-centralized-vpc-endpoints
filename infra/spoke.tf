# ============================================================================
# Spoke：业务 VPC，复用 Hub 集中化的终端节点
# 华为云原生「私有区域 ↔ VPC 关联」资源直接完成跨 VPC DNS 覆盖，无需函数。
# ============================================================================

# --- Spoke VPC 与子网 ---
resource "huaweicloud_vpc" "spoke" {
  name = "${var.project_name}-spoke-vpc"
  cidr = "10.1.0.0/16"
}

resource "huaweicloud_vpc_subnet" "spoke" {
  name       = "${var.project_name}-spoke-subnet"
  vpc_id     = huaweicloud_vpc.spoke.id
  cidr       = "10.1.1.0/24"
  gateway_ip = "10.1.1.1"
}

# --- Hub ↔ Spoke 对等连接，提供网络连通 ---
# 通过显式创建 VPC 对等连接以保证端到端可达。
# 同账号对等连接自动接受，无需 accepter 资源。
resource "huaweicloud_vpc_peering_connection" "hub_spoke" {
  name        = "${var.project_name}-hub-spoke-peer"
  vpc_id      = huaweicloud_vpc.hub.id
  peer_vpc_id = huaweicloud_vpc.spoke.id
}

# --- 双向路由：Spoke 到达 Hub 终端节点 IP，Hub 回到 Spoke ---
# type = "peering"，nexthop 指向对等连接 ID
resource "huaweicloud_vpc_route" "spoke_to_hub" {
  vpc_id      = huaweicloud_vpc.spoke.id
  destination = huaweicloud_vpc.hub.cidr
  type        = "peering"
  nexthop     = huaweicloud_vpc_peering_connection.hub_spoke.id
}

resource "huaweicloud_vpc_route" "hub_to_spoke" {
  vpc_id      = huaweicloud_vpc.hub.id
  destination = huaweicloud_vpc.spoke.cidr
  type        = "peering"
  nexthop     = huaweicloud_vpc_peering_connection.hub_spoke.id
}

# --- Spoke VPC 与私有 DNS 区域的关联已在 hub.tf 的 huaweicloud_dns_zone
#     router 块中声明（Hub + Spoke 同为该区域的关联 VPC）。
#     华为云用 zone 的 router 块原生完成跨 VPC 关联，无需函数代码介入。
#     关联后，Spoke VPC 的内部 DNS（100.125.x.x）会把 zone_name 解析为 Hub
#     终端节点 IP，存量客户端无需改代码即可透明访问集中化终端节点。
