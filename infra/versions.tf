# ============================================================================
# 华为云 Provider 与 Terraform 版本约束
# 集中化 VPC 终端节点访问（Hub & Spoke）
# ============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }

  # 生产环境建议将状态落盘到 OBS，避免本地状态丢失
  # backend "s3" {
  #   endpoint = "https://obs.cn-north-4.myhuaweicloud.com"
  #   bucket   = "your-tfstate-bucket"
  #   key      = "centralized-endpoints/terraform.tfstate"
  #   region   = "cn-north-4"
  # }
  backend "local" {}
}

# ============================================================================
# Provider 配置
# 凭据通过环境变量注入，不要硬编码
#   export HW_ACCESS_KEY="<HW_ACCESS_KEY>"
#   export HW_SECRET_KEY="<HW_SECRET_KEY>"
#   # 临时凭证（可选）
#   export HW_SECURITY_TOKEN="<TOKEN>"
# ============================================================================

provider "huaweicloud" {
  region = var.region
}
