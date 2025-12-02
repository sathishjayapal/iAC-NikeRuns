# AWS Load Balancer Controller - CLI Commands Reference

## Prerequisites Check

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Verify kubectl is configured
kubectl cluster-info

# Check current context
kubectl config current-context
```

## Terraform Deployment

```bash
# Navigate to EKS module directory
cd /Users/skminfotech/IdeaProjects/iAC-NikeRuns/aws-modules/eks

# Initialize Terraform (download new providers)
terraform init -upgrade

# Validate configuration
terraform validate

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# View outputs
terraform output
```

## Verification Commands

```bash
# Configure kubectl (if not already done)
aws eks update-kubeconfig --region <your-region> --name <cluster-name>

# Check if AWS Load Balancer Controller pods are running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check deployment status
kubectl get deployment -n kube-system aws-load-balancer-controller

# View controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50

# Follow logs in real-time
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# Verify service account
kubectl describe sa aws-load-balancer-controller -n kube-system

# Check IAM role annotation
kubectl get sa aws-load-balancer-controller -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

## Ingress Management

```bash
# Apply ingress configuration
kubectl apply -f sathish-config-server-ing.yaml

# Get all ingresses
kubectl get ingress

# Get specific ingress with details
kubectl get ingress sathish-config-server

# Describe ingress (shows events and ALB details)
kubectl describe ingress sathish-config-server

# Get ingress in YAML format
kubectl get ingress sathish-config-server -o yaml

# Watch ingress status (wait for ALB creation)
kubectl get ingress -w

# Get ALB DNS name
kubectl get ingress sathish-config-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Service Management

```bash
# Apply service configuration
kubectl apply -f sathish-config-server-svc.yaml

# Get services
kubectl get svc

# Describe service
kubectl describe svc sathish-config-server

# Get service endpoints
kubectl get endpoints sathish-config-server
```

## Pod Management

```bash
# Get pods
kubectl get pods

# Get pods with labels
kubectl get pods -l app=sathish-config-server

# Describe pod
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Follow pod logs
kubectl logs -f <pod-name>

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/sh

# Port forward to pod
kubectl port-forward svc/sathish-config-server 8888:8888
```

## Testing the Application

```bash
# Get ALB DNS name
ALB_DNS=$(kubectl get ingress sathish-config-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint (no auth required)
curl http://$ALB_DNS/actuator/health

# Test config endpoint (requires auth)
curl -u sathish:pass http://$ALB_DNS/gotoaws-sathish/default

# Test with verbose output
curl -v -u sathish:pass http://$ALB_DNS/gotoaws-sathish/default

# Test with custom Host header
curl -H "Host: sathishprojects.configserver.com" http://$ALB_DNS/actuator/health

# Save response to file
curl -u sathish:pass http://$ALB_DNS/gotoaws-sathish/default -o config-response.json
```

## AWS CLI Commands

```bash
# List EKS clusters
aws eks list-clusters --region us-east-1

# Describe cluster
aws eks describe-cluster --name <cluster-name> --region us-east-1

# List load balancers
aws elbv2 describe-load-balancers --region us-east-1

# List target groups
aws elbv2 describe-target-groups --region us-east-1

# Describe specific load balancer
aws elbv2 describe-load-balancers --names k8s-default-sathishc-515db38315 --region us-east-1

# Check target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn> --region us-east-1

# List IAM roles
aws iam list-roles | grep aws-load-balancer-controller

# Get IAM policy
aws iam get-policy --policy-arn <policy-arn>
```

## Troubleshooting Commands

```bash
# Check controller events
kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep aws-load-balancer-controller

# Check ingress events
kubectl get events --sort-by='.lastTimestamp' | grep ingress

# Verify OIDC provider
aws eks describe-cluster --name <cluster-name> --query "cluster.identity.oidc.issuer" --output text

# List OIDC providers
aws iam list-open-id-connect-providers

# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:elbv2.k8s.aws/cluster,Values=<cluster-name>"

# Check subnets
aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/cluster/<cluster-name>,Values=shared"

# Verify subnet tags
aws ec2 describe-subnets --subnet-ids <subnet-id> --query 'Subnets[0].Tags'
```

## Cleanup Commands

```bash
# Delete ingress (this will delete the ALB)
kubectl delete ingress sathish-config-server

# Delete service
kubectl delete svc sathish-config-server

# Delete deployment
kubectl delete deployment sathish-config-server

# Uninstall AWS Load Balancer Controller (via Terraform)
terraform destroy -target=helm_release.aws_load_balancer_controller

# Full cleanup
terraform destroy
```

## Monitoring Commands

```bash
# Watch pods continuously
kubectl get pods -w

# Watch ingress continuously
kubectl get ingress -w

# Get resource usage
kubectl top nodes
kubectl top pods

# Check controller metrics
kubectl port-forward -n kube-system svc/aws-load-balancer-webhook-service 8080:443
curl http://localhost:8080/metrics

# View all resources in namespace
kubectl get all -n kube-system | grep aws-load-balancer
```

## DNS Testing

```bash
# Check DNS resolution
nslookup k8s-default-sathishc-515db38315-274695219.us-east-1.elb.amazonaws.com

# Check custom domain
nslookup sathishprojects.configserver.com

# Test with dig
dig k8s-default-sathishc-515db38315-274695219.us-east-1.elb.amazonaws.com

# Get ALB IP addresses
dig k8s-default-sathishc-515db38315-274695219.us-east-1.elb.amazonaws.com +short
```

## Useful One-Liners

```bash
# Get all ingresses with their ALB DNS names
kubectl get ingress -o custom-columns=NAME:.metadata.name,HOSTS:.spec.rules[*].host,ADDRESS:.status.loadBalancer.ingress[*].hostname

# Get all services with their types
kubectl get svc -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[*].hostname

# Get pod IPs
kubectl get pods -o custom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName

# Check if controller is leader
kubectl get lease -n kube-system aws-load-balancer-controller-leader -o yaml

# Get all target group bindings
kubectl get targetgroupbindings -A
```

## Export Commands

```bash
# Export ingress configuration
kubectl get ingress sathish-config-server -o yaml > ingress-backup.yaml

# Export service configuration
kubectl get svc sathish-config-server -o yaml > service-backup.yaml

# Export all resources
kubectl get all -o yaml > all-resources-backup.yaml

# Export namespace resources
kubectl get all -n kube-system -o yaml > kube-system-backup.yaml
```

## Quick Reference

### Get ALB URL
```bash
kubectl get ingress sathish-config-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Test Application
```bash
curl -u sathish:pass http://$(kubectl get ingress sathish-config-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/gotoaws-sathish/default
```

### Check Controller Status
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -o wide
```

### View Recent Events
```bash
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

## Common Issues and Solutions

### Issue: Ingress not getting an address
```bash
# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Check ingress events
kubectl describe ingress sathish-config-server
```

### Issue: 503 Service Unavailable
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn <arn>

# Check pod status
kubectl get pods -l app=sathish-config-server

# Check service endpoints
kubectl get endpoints sathish-config-server
```

### Issue: Permission denied errors
```bash
# Verify IAM role
kubectl describe sa aws-load-balancer-controller -n kube-system

# Check IAM policy
aws iam get-role --role-name <cluster-name>-aws-load-balancer-controller
```

## Related Files

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `outputs.tf` - Output definitions
- `aws-load-balancer-controller-iam-policy.json` - IAM policy document
- `AWS_LOAD_BALANCER_CONTROLLER.md` - Comprehensive documentation
- `DEPLOYMENT_STEPS.md` - Step-by-step deployment guide
