resource "aws_spot_instance_request" "spot" {
  count                  = var.SPOT_INSTANCE_COUNT
  ami                    = data.aws_ami.ami.id
  instance_type          = var.INSTANCE_TYPE
  wait_for_fulfillment   = true
  vpc_security_group_ids = [aws_security_group.allow-app-component.id]
  subnet_id              = element(data.terraform_remote_state.vpc.outputs.PRIVATE_SUBNETS_IDS, count.index)

  tags = {
    Name = "${var.COMPONENT}-${var.ENV}"
  }
}

resource "aws_instance" "od" {
  count                  = var.OD_INSTANCE_COUNT
  ami                    = data.aws_ami.ami.id
  instance_type          = var.INSTANCE_TYPE
  vpc_security_group_ids = [aws_security_group.allow-app-component.id]
  subnet_id              = element(data.terraform_remote_state.vpc.outputs.PRIVATE_SUBNETS_IDS, count.index)
}

locals {
  SPOT_INSTANCE_IDS = aws_spot_instance_request.spot.*.spot_instance_id
  OD_INSTANCE_IDS   = aws_instance.od.*.id
  ALL_INSTANCE_IDS  = concat(local.SPOT_INSTANCE_IDS, local.OD_INSTANCE_IDS)

  SPOT_PRIVATE_IP = aws_spot_instance_request.spot.*.private_ip
  OD_PRIVATE_IP   = aws_instance.od.*.private_ip
  ALL_PRIVATE_IP  = concat(local.SPOT_PRIVATE_IP, local.OD_PRIVATE_IP)
}

resource "aws_ec2_tag" "name-tag" {
  count       = length(local.ALL_INSTANCE_IDS)
  resource_id = element(local.ALL_INSTANCE_IDS, count.index)
  key         = "Name"
  value       = "${var.COMPONENT}-${var.ENV}"
}

resource "null_resource" "ansible-apply" {
  count = length(local.ALL_PRIVATE_IP)
  provisioner "remote-exec" {
    connection {
      host     = element(local.ALL_PRIVATE_IP, count.index)
      user     = jsondecode(data.aws_secretsmanager_secret_version.latest.secret_string)["SSH_USER"]
      password = jsondecode(data.aws_secretsmanager_secret_version.latest.secret_string)["SSH_PASS"]
    }
    inline = [
      "ansible-pull -U https://github.com/roboshop-blue-green/ansible.git roboshop.yml -e COMPONENT=cart -e ENV=${var.ENV} -e APP_VERSION=${var.APP_VERSION}"
    ]
  }
}