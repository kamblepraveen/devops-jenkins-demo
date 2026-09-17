resource "aws_instance" "devops_lab" {
  ami           = "ami-08188a5a4dfdbd573"
  instance_type = var.instance_type

  tags = {
    Name = "devops-lab-server"
  }
}