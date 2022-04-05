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
}
