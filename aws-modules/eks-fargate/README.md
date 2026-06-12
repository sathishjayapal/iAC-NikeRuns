# eks-fargate (A Cloud Guru sandbox starting point)

Minimal EKS cluster with Fargate-only compute. Designed for the A Cloud Guru
AWS sandbox: **uses the sandbox-provided VPC and the subnets you point it at
via data sources** and (optionally) adds the minimum extra networking that
Fargate strictly requires.

## What it creates

Always:
- 1 EKS cluster (Kubernetes 1.30) with public + private API endpoints
- 1 OIDC provider (cheap, future-proofs IRSA)
- 1 Fargate pod execution IAM role
- 2 Fargate profiles: `fp-system` (kube-system), `fp-microservices` (microservices)

Only when `create_private_subnets = true` (see below):
- 2 private subnets inside the existing sandbox VPC (one per AZ)
- 1 NAT gateway + 1 EIP in the first caller-supplied (public) subnet
- 1 route table sending 0.0.0.0/0 -> NAT GW, associated with both private subnets

## What it does NOT create

- No new VPC, no IGW, no public subnets (uses the sandbox's)
- No EC2 node groups, no Auto Scaling Groups
- No AWS Load Balancer Controller, no Helm releases
- No ECR repos (created via `aws ecr create-repository` in the deploy runbook)
- No Aurora / RDS / MSK

## Why the private-subnet toggle exists

EKS Fargate refuses to start pods in subnets whose route table sends
0.0.0.0/0 to an Internet Gateway. AWS rejects the `CreateFargateProfile`
call with `InvalidParameterException: Subnet ... is not a private subnet`.

A Cloud Guru sandbox VPCs are typically public-only. The toggle adds the
smallest possible private networking inside the existing VPC so Fargate
will accept the profiles, without recreating the VPC.

The NAT gateway costs ~$0.045/hr (~$1.08/day). `terraform destroy` removes
it at the end of the session.

## Prerequisites in the sandbox

```bash
aws sts get-caller-identity
aws ec2 describe-vpcs --query 'Vpcs[].{Id:VpcId,Tags:Tags}'
aws ec2 describe-subnets --filters Name=vpc-id,Values=<vpc-id> \
  --query 'Subnets[].{Id:SubnetId,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}'

# Check which subnets are PRIVATE (no 0.0.0.0/0 -> igw- route):
for sn in $(aws ec2 describe-subnets --filters Name=vpc-id,Values=<vpc-id> \
    --query 'Subnets[].SubnetId' --output text); do
  rt=$(aws ec2 describe-route-tables --filters Name=association.subnet-id,Values=$sn \
       --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId' --output text)
  echo "$sn -> default route: ${rt:-NONE (private)}"
done
```

If the loop prints `NONE (private)` or a `nat-...` for some subnets, you
already have private subnets - put those IDs in `subnet_ids` and leave
`create_private_subnets = false`.

If every subnet has a `igw-...` default route, set
`create_private_subnets = true`.

Either way you need >=2 subnet IDs in different availability zones.

## Apply

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set vpc_id, subnet_ids, create_private_subnets
terraform init
terraform apply

aws eks update-kubeconfig --region us-east-1 \
  --name $(terraform output -raw cluster_name)
```

> **Always re-run `aws eks update-kubeconfig` after any `terraform apply`
> that recreates the cluster (or after a fresh sandbox session).** EKS
> assigns a new API endpoint hostname each time, and a stale kubeconfig
> shows up as `dial tcp: lookup ...eks.amazonaws.com: no such host` on
> every kubectl command. See troubleshooting below.

## Post-apply: patch CoreDNS to run on Fargate

CoreDNS ships annotated for EC2 nodes. With no node group it stays Pending
until you remove the annotation.

```bash
kubectl patch deployment coredns -n kube-system --type=json \
  -p='[{"op":"remove","path":"/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
kubectl rollout restart deployment coredns -n kube-system
kubectl get pods -n kube-system -w
```

**Expect 2-4 minutes** before both CoreDNS pods reach `1/1 Running`.
Fargate pods are slower to start than EC2 pods because each pod gets its
own micro-VM (image pull happens after the VM boots). Pending for the
first ~90 seconds is normal, not stuck.

Success looks like:

```
NAME                       READY   STATUS    RESTARTS   AGE
coredns-xxxxxxxxxx-aaaaa   1/1     Running   0          2m
coredns-xxxxxxxxxx-bbbbb   1/1     Running   0          2m
```

Quick DNS sanity check (one-off pod, auto-deletes; takes ~60-90s to start):

```bash
kubectl run -it --rm dnstest --image=busybox:1.36 --restart=Never -- \
  nslookup kubernetes.default
```

You should get an answer with the cluster IP. If yes, cluster networking
is fully functional and you can proceed to `../k8s/README.md` for the
application deploy steps.

## Teardown

```bash
kubectl delete namespace microservices --ignore-not-found
terraform destroy
```

The NAT gateway, EIP, private subnets, route table, OIDC provider, IAM
roles, Fargate profiles, and EKS cluster are all torn down. Nothing is
left running in the sandbox.

## Troubleshooting

- **`InvalidParameterException: Subnet ... is not a private subnet`** on
  `terraform apply`: set `create_private_subnets = true` in tfvars and
  re-apply.

- **`InvalidParameterException: CIDR ... overlaps with another subnet`** on
  `terraform apply`: your VPC already uses the default CIDRs. Override
  `private_subnet_cidrs` with two non-overlapping /24 ranges inside the
  VPC CIDR.

- **CoreDNS Pending forever after apply**: run the patch above. If still
  Pending after ~5 min, check `kubectl describe pod -n kube-system -l
  k8s-app=kube-dns` for selector mismatches against the `fp-system`
  Fargate profile (namespace must be `kube-system`).

- **`dial tcp: lookup <hash>.gr7.<region>.eks.amazonaws.com: no such host`**
  on every kubectl command: kubeconfig is stale (cluster was destroyed
  and recreated, or you switched sandboxes). Triage with:
  ```bash
  aws eks describe-cluster --region us-east-1 --name nikeruns-sandbox \
    >/dev/null 2>&1 \
    && aws eks update-kubeconfig --region us-east-1 --name nikeruns-sandbox \
    && kubectl cluster-info \
    || echo "cluster does NOT exist - run terraform apply"
  ```
  If the cluster exists, the `update-kubeconfig` call rewrites your kube
  context with the current endpoint and kubectl works again.

- **`Warning  LoggingDisabled ... aws-logging configmap was not found`**
  on every Fargate pod: harmless. It just means you haven't opted in to
  shipping Fargate stdout/stderr to CloudWatch via the optional
  `aws-logging` ConfigMap in `aws-observability` namespace. Pods run
  fine without it. Add the ConfigMap later if/when you want the logs.

- **`endpoint ... no such host` only from your laptop, but from another
  machine it works**: check that you didn't tighten `public_access_cidrs`
  to a stale IP. `aws eks describe-cluster --query
  'cluster.resourcesVpcConfig.publicAccessCidrs'` shows the current
  allow-list.
