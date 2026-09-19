resource "aws_instance" "devops_lab" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id = data.aws_subnet.devops_subnet.id

  vpc_security_group_ids = [
    data.aws_security_group.devops_sg.id
  ]

  key_name = "devops-lab-key"

  tags = {
    Name = "devops-lab-server"
  }
}