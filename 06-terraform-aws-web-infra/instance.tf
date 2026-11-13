resource "aws_instance" "web" {
  ami                         = var.amiID[var.region]
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.dove-key.key_name
  vpc_security_group_ids      = [aws_security_group.dove-sg.id]
  availability_zone           = var.zone1
  associate_public_ip_address = true

  tags = {
    Name    = "terraform-web-server"
    Project = "terraform-web-infra"
  }

  provisioner "file" {
    source      = "web.sh"
    destination = "/tmp/web.sh"
  }

  connection {
    type        = "ssh"
    user        = var.webuser
    private_key = file("dove-key")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/web.sh",
      "sudo /tmp/web.sh"
    ]
  }

  provisioner "local-exec" {
    command = "echo ${self.private_ip} >> private_ip.txt"
  }
}

resource "aws_ec2_instance_state" "web_state" {
  instance_id = aws_instance.web.id
  state       = "running"
}