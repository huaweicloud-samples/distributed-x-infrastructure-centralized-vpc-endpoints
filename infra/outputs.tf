# ============================================================================
# 输出
# ============================================================================

output "hub_vpc_id" {
  description = "Hub（共享服务）VPC ID"
  value       = huaweicloud_vpc.hub.id
}

output "spoke_vpc_id" {
  description = "Spoke（业务）VPC ID"
  value       = huaweicloud_vpc.spoke.id
}

output "peering_id" {
  description = "Hub ↔ Spoke 对等连接 ID"
  value       = huaweicloud_vpc_peering_connection.hub_spoke.id
}

output "endpoint_ips" {
  description = "各服务终端节点的内网 IP（A 记录指向值）"
  value       = { for k, ep in huaweicloud_vpcep_endpoint.this : k => ep.ip_address }
}

output "private_zone_ids" {
  description = "各服务私有 DNS 区域 ID（供其他 Spoke 关联复用）"
  value       = { for k, z in huaweicloud_dns_zone.this : k => z.id }
}

output "private_zone_names" {
  description = "各服务私有 DNS 区域/记录名"
  value       = { for k, z in huaweicloud_dns_zone.this : k => z.name }
}
