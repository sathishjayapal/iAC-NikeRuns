#! /bin/bash

# Extract the public IP from Terraform output
public_ip=$(terraform output -raw public_ip)

# Use the public IP in your script
echo "The public IP is: $public_ip"

sudo yum update -y
sudo yum install -y httpd.x86_64
sudo systemctl start httpd.service
sudo systemctl enable httpd.service
sudo yum install java-21-amazon-corretto-headless -y
sudo export username="sathish"
sudo export pass="pass"

#!/bin/bash
# Example usage: SCP command
