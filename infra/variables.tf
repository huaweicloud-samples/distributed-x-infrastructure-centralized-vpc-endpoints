# ============================================================================
# 变量定义
# ============================================================================

variable "region" {
  description = "华为云区域（与公共服务名、私有 DNS 区域名保持一致）"
  type        = string
  default     = "cn-north-4"
}

variable "project_name" {
  description = "资源命名前缀，用于统一标识本套集中化终端节点实践"
  type        = string
  default     = "centralized-endpoints"
}

# ============================================================================
# 要集中化的「接口型」终端节点服务列表
# ----------------------------------------------------------------------------
# 每个服务需要三要素：
#   short_name          —— 资源命名用的简称（如 dns），需满足 DNS 标签规则
#   public_service_name —— 在 VPCEP 控制台「公共终端节点服务」中查到的服务名，
#                          按 region 核实（如 cn-north-4 的云解析接口服务名为 "dns"）。
#                          该值用于 data source 查询系统预置服务的 service_id。
#   zone_name           —— 要覆盖解析的私有 DNS 区域/记录名。使用真实服务域名
#                          （如 dns.<region>.myhuaweicloud.com），使存量客户端 SDK
#                          透明解析到集中化终端节点；测试期若不想覆盖真实域名，
#                          可改为合成域名（如 svc.<region>.example-internal.com）。
#
# 注意：OBS 等「网关型」终端节点服务不走此接口型 + 私有 DNS 模式，
#       请见 docs/architecture.md 的「OBS 网关型差异」章节。
# ============================================================================
variable "endpoint_services" {
  description = "集中化的接口型终端节点服务列表"
  type = list(object({
    short_name          = string
    public_service_name = string
    zone_name           = string
  }))
  default = [
    {
      short_name          = "dns"
      public_service_name = "dns"
      zone_name           = "dns.cn-north-4.myhuaweicloud.com"
    }
  ]

  validation {
    condition     = length(var.endpoint_services) > 0
    error_message = "endpoint_services 至少需包含一个服务。"
  }
}
