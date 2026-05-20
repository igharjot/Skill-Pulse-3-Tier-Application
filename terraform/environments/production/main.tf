module "skillpulse_ec2" {
  source = "../../modules/ec2"

  project_name                  = "skillpulse"

  environment                   = "production"

  aws_region                    = var.aws_region

  instance_type                 = "t3.small"

  ami_id                        = "ami-0f58b397bc5c1f2e8"

  key_name                      = "skillpulse-key"

  allowed_ssh_ip                = "YOUR_PUBLIC_IP/32"

  root_volume_size              = 25

  enable_termination_protection = true
}