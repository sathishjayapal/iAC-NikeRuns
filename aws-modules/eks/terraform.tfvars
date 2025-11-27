# EKS Cluster Configuration
# Based on cluster.yaml eksctl configuration

region       = "us-east-1"
cluster_name = "sathish-eks-cluster-01"

# VPC and Subnets (replace with actual IDs)
vpc_id      = "vpc-0a1753e65db583cd6"
subnet_id_a = "subnet-0ce25994763da6aae"
subnet_id_b = "subnet-0725627f1a0851e25"
subnet_id_c = "subnet-01a73f2ece83afd8d"

# IAM Configuration
create_cluster_role = false
service_role_arn    = "arn:aws:iam::381636780001:role/sathisheksclusterservicerole"

# Node Group Configuration
node_group_name       = "sathisheks-ng-1-workers"
node_instance_type    = "t2.micro"
node_desired_capacity = 2
node_min_size         = 1
node_max_size         = 4

# SSH Configuration
ssh_key_name = "foreksworkloads"

# Node Labels
node_labels = {
  role = "workers"
}

# Tags
common_tags = {
  Environment = "development"
  ManagedBy   = "terraform"
}

node_group_tags = {
  "k8s.io/cluster-autoscaler/enabled"        = "true"
  "k8s.io/cluster-autoscaler/eks-cluster-01" = "owned"
}
