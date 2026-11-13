data "aws_ami" "amiID" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

output "ami_id" {
  description = "Latest Ubuntu 22.04 LTS AMI ID"
  value       = data.aws_ami.amiID.id
}

output "WebPublicIP" {
  description = "Public IP address of the Ubuntu web instance"
  value       = aws_instance.web.public_ip
}

output "WebPrivateIP" {
  description = "Private IP address of the Ubuntu web instance"
  value       = aws_instance.web.private_ip
}