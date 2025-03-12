output "ec2-mongodb_privateIP" {
    value = aws_instance.ec2-mongodb.private_ip
    description = "Private IP address of the EC2 instance"
}

output "ec2-mongodb_publicIP" {
    value = aws_instance.ec2-mongodb.public_ip
    description = "Public IP address of the EC2 instance"
}