# eks-fargate (A Cloud Guru sandbox starting point)

Minimal EKS cluster with Fargate-only compute. Designed for the A Cloud Guru
AWS sandbox: **uses the sandbox-provided VPC and subnets via data sources**
and creates nothing networking-related.

## What it creates

- 1 EKS cluster (Kubernetes 1.30) with public + private API endpoints
- 1 OIDC provider (cheap, future-proofs IRSA)
- 1 Fargate pod execution IAM role
- 2 Fargate profiles: `fp-system` (kube-system), `fp-microservices` (microservices)

## What it does NOT create

- No VPC, subnets, NAT gateways, IGWs, route tables — the sandbox provides these
- No EC2 node groups
- No AWS Load Balancer Controller, no Helm releases
- No ECR repos (created via `aws ecr create-repository` in the deploy runbook)
- No Aurora / RDS / MSK

## Prerequisites in the sandbox

```bash
aws sts get-caller-identity
aws ec2 describe-vpcs --query 'Vpcs[].{Id:VpcId,Tags:Tags}'
aws ec2 describe-subnets --filters Name=vpc-id,Values=<vpc-id> \
  --query 'Subnets[].{Id:SubnetId,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}'
```

You need **>=2 subnet IDs in different availability zones**. EKS will refuse to
create the cluster otherwise.

## Apply

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with the discovered VPC + subnet IDs
terraform init
terraform apply

aws eks update-kubeconfig --region $(terraform output -raw region 2>/dev/null || echo us-east-1) \
  --name $(terraform output -raw cluster_name)
```

## Post-apply: patch CoreDNS to run on Fargate

CoreDNS ships annotated for EC2 nodes. With no node group, it stays Pending
until you remove the annotation.

```bash
kubectl patch deployment coredns -n kube-system --type=json \
  -p='[{"op":"remove","path":"/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
kubectl rollout restart deployment coredns -n kube-system
kubectl get pods -n kube-system -w
```

Then proceed to `../k8s/README.md` for the application deploy steps.

## Teardown

```bash
kubectl delete namespace microservices --ignore-not-found
terraform destroy
```
