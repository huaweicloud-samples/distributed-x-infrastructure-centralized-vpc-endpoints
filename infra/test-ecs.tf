# ============================================================================
# 业务逻辑验证用测试 ECS（临时）
# ----------------------------------------------------------------------------
# 用途：在 Spoke VPC 内起一台最小规格 ECS，验证「Spoke 内部能解析集中化
#       私有域名 dns.cn-north-4.myhuaweicloud.com -> Hub 终端节点 IP」。
# 约束：纯内网，无 EIP、无公网 NAT（符合部署硬约束）。
# 销毁：验证完用 `terraform destroy -target=...`（见文件末尾说明）精准销毁，
#       不影响主架构资源。
# 规格说明：s6.small.1 + 系统盘。
# ============================================================================

# 可用的 x86 公共镜像。
# 坑（已踩）：cn-north-4 的 "Huawei Cloud EulerOS 2.0 64bit" 全是 ARM/Ascend/GPU 变体，
#      连 "with NO Driver" 通用版内部也被标记为 ARM，配 x86 规格必报 Ecs.0005。
#      改用确定是 x86 通用的 CentOS 7.9 64bit（经典 x86 公共镜像），并排除名字含 Arm 的变体。
data "huaweicloud_images_images" "euler" {
  name_regex = "CentOS 7.9 64bit"
  visibility = "public"
}

locals {
  x86_image_id = [
    for i in data.huaweicloud_images_images.euler.images :
    i.id if !can(regex("Arm", i.name))
  ][0]
}

# 可用区
data "huaweicloud_availability_zones" "this" {
  state = "available"
}

# 测试用安全组：华为新建安全组默认已带「放通全部出方向」规则，
# 因此不再显式添加 egress（否则会 conflict）。入方向仅放 Spoke 网段 ICMP/SSH 便于排障。
resource "huaweicloud_networking_secgroup" "test_ecs" {
  name = "${var.project_name}-test-ecs-sg"
}

resource "huaweicloud_networking_secgroup_rule" "ingress_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = huaweicloud_vpc_subnet.spoke.cidr
  security_group_id = huaweicloud_networking_secgroup.test_ecs.id
}

resource "huaweicloud_networking_secgroup_rule" "ingress_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = huaweicloud_vpc_subnet.spoke.cidr
  security_group_id = huaweicloud_networking_secgroup.test_ecs.id
}

# 测试 ECS（落在 Spoke 子网，纯内网）
resource "huaweicloud_compute_instance" "test_ecs" {
  name               = "${var.project_name}-test-ecs"
  flavor_name        = "s6.small.1"
  image_id           = local.x86_image_id
  availability_zone  = data.huaweicloud_availability_zones.this.names[0]
  security_group_ids = [huaweicloud_networking_secgroup.test_ecs.id]
  admin_pass         = "HwVerify@2026Ecs"

  network {
    uuid = huaweicloud_vpc_subnet.spoke.id
  }

  # 首次启动即自动执行 DNS 解析验证：域名应解析为 Hub 终端节点 IP 10.0.1.236
  user_data = <<-EOT
    #!/bin/bash
    DOMAIN="dns.cn-north-4.myhuaweicloud.com"
    EXPECTED="10.0.1.236"
    IP=$(getent hosts "$DOMAIN" | awk '{print $1}' | head -1)
    {
      echo "===== 集中化终端节点 DNS 解析验证 ====="
      echo "时间: $(date)"
      echo "域名: $DOMAIN"
      echo "解析结果 IP: $${IP:-<未解析>}"
      if [ "$IP" = "$EXPECTED" ]; then
        echo "结果: PASS（Spoke 内网成功解析到 Hub 终端节点 $EXPECTED）"
      else
        echo "结果: FAIL（期望 $EXPECTED，实际 $${IP:-空}）"
      fi
      echo "---- 对终端节点 IP 的可达性探测（受 Hub 侧 ENI 安全组影响，非必过）----"
      ping -c 3 -W 2 "$EXPECTED" || echo "（ping 不通属正常：终端节点 ENI 入方向未开放 ICMP）"
    } | tee /root/verify_result.txt
  EOT
}

# ============================================================================
# 验证完销毁（不影响主架构）：
#   terraform destroy \
#     -target=huaweicloud_compute_instance.test_ecs \
#     -target=huaweicloud_networking_secgroup_rule.ingress_ssh \
#     -target=huaweicloud_networking_secgroup_rule.ingress_icmp \
#     -target=huaweicloud_networking_secgroup.test_ecs
# ============================================================================
