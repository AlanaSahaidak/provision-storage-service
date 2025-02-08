output "vpc_id" {
  value = aws_vpc.nebo_vpc.id
}

output "private_subnet_id" {
  value = aws_subnet.nebo_private_subnet.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "linux_private_ip" {
  value = aws_instance.linux.private_ip
}