# ============================================================================
# Hub：集中放置接口型终端节点的「共享服务 VPC」
# 华为云 VPC + VPCEP + 私有 DNS 实现跨 VPC 透明访问
# ============================================================================

# --- Hub VPC 与子网（终端节点 ENI 由系统自动放置在该 VPC 内）---
resource "huaweicloud_vpc" "hub" {
  name = "${var.project_name}-hub-vpc"
  cidr = "10.0.0.0/16"
}

resource "huaweicloud_vpc_subnet" "hub" {
  name       = "${var.project_name}-hub-subnet"
  vpc_id     = huaweicloud_vpc.hub.id
  cidr       = "10.0.1.0/24"
  gateway_ip = "10.0.1.1"
}

# --- 查询各服务对应的「公共服务」ID ---
# 系统预置的云服务终端节点服务（接口型/网关型）按 region 不同而名称不同，
# 通过公共终端节点服务 data source 解析出 service_id。
data "huaweicloud_vpcep_public_services" "this" {
  for_each     = { for s in var.endpoint_services : s.short_name => s }
  service_name = each.value.public_service_name
}

# --- 在 Hub VPC 内为每个服务创建「接口型终端节点」---
# 华为云接口型终端节点（接口型 = ENI 形态 + 私网 IP，可被 DNS 记录指向）。
# enable_dns = false：关闭终端节点内置 DNS 解析，由本仓库自建的私有 DNS 区域接管。
# network_id = 终端节点网卡（ENI）所在子网；华为云把「子网 ID」在 SDK 中称为
#              network_id（对应 API 的 SubnetID）。该参数必填，缺失会报
#              EndPoint.0023 Invalid subnet_id。
resource "huaweicloud_vpcep_endpoint" "this" {
  for_each    = { for s in var.endpoint_services : s.short_name => s }
  vpc_id      = huaweicloud_vpc.hub.id
  network_id  = huaweicloud_vpc_subnet.hub.id
  service_id  = data.huaweicloud_vpcep_public_services.this[each.key].services[0].id
  enable_dns  = false
  description = "${var.project_name}-ep-${each.key}"
}

# --- 为每个服务创建私有 DNS 区域 ---
# 华为云私有 DNS 区域（zone_type = "private"），承载服务域名的内网解析。
# 华为云通过 zone 的 router 块一次性声明关联 VPC，无需自定义资源协助。
# 私有区域创建时必须至少关联一个 VPC（router 块），此处关联 Hub VPC 以激活内网解析；
# 其余 VPC（如 Spoke）通过 huaweicloud_dns_private_zone_associate 追加关联（见 spoke.tf）。
resource "huaweicloud_dns_zone" "this" {
  for_each  = { for s in var.endpoint_services : s.short_name => s }
  name      = each.value.zone_name
  zone_type = "private"
  ttl       = 300

  # 私有区域创建/更新时通过 router 块声明「所有」关联 VPC。
  # 注意：dns_zone 的 router 块是该区域 VPC 关联的权威来源，不能与独立的
  # huaweicloud_dns_private_zone_associate 资源混用（后者会被 router 块覆盖清除）。
  # 因此 Hub 与 Spoke 都在此处声明。
  router {
    router_id     = huaweicloud_vpc.hub.id
    router_region = var.region
  }

  router {
    router_id     = huaweicloud_vpc.spoke.id
    router_region = var.region
  }
}

# --- 在私有区域内写 A 记录，指向 Hub 终端节点的内网 IP ---
# A 记录值取自华为云终端节点的 ip_address 字段。
resource "huaweicloud_dns_recordset" "this" {
  for_each = { for s in var.endpoint_services : s.short_name => s }
  zone_id  = huaweicloud_dns_zone.this[each.key].id
  name     = each.value.zone_name
  type     = "A"
  records  = [huaweicloud_vpcep_endpoint.this[each.key].ip_address]
  ttl      = 300
}
