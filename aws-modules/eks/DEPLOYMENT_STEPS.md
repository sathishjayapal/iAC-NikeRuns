# AWS Load Balancer Controller - Deployment Steps

## Summary of Changes

The following files have been added/modified to enable AWS Load Balancer Controller:

### New Files
1. **aws-load-balancer-controller-iam-policy.json** - Complete IAM policy with all required permissions
2. **AWS_LOAD_BALANCER_CONTROLLER.md** - Comprehensive documentation and usage examples

### Modified Files
1. **main.tf** - Added:
   - Helm and Kubernetes provider configurations
   - IAM policy resource
   - IAM role with IRSA (IAM Roles for Service Accounts)
   - Kubernetes service account
   - Helm chart deployment

2. **variables.tf** - Added:
   - `enable_aws_load_balancer_controller` (default: true)
   - `aws_load_balancer_controller_version` (default: "1.6.2")

3. **outputs.tf** - Added:
   - `aws_load_balancer_controller_role_arn`
   - `aws_load_balancer_controller_policy_arn`
   - `aws_load_balancer_controller_status`

## Prerequisites

Before deploying, ensure:

1. ✅ OIDC provider is enabled (`enable_oidc = true` in your configuration)
2. ✅ EKS cluster is already deployed
3. ✅ kubectl is configured to access the cluster
4. ✅ Subnets have proper tags (see below)

## Required Subnet Tags

Your VPC subnets must have these tags for the controller to work:

**Public Subnets** (for internet-facing load balancers):
```
kubernetes.io/role/elb = 1
kubernetes.io/cluster/<your-cluster-name> = shared
```

**Private Subnets** (for internal load balancers):
```
kubernetes.io/role/internal-elb = 1
kubernetes.io/cluster/<your-cluster-name> = shared
```

## Deployment Commands

### Step 1: Initialize Terraform (if needed)
```bash
cd /Users/skminfotech/IdeaProjects/iAC-NikeRuns/aws-modules/eks
terraform init -upgrade
```

### Step 2: Review the Plan
```bash
terraform plan
```

Expected new resources:
- `aws_iam_policy.aws_load_balancer_controller[0]`
- `aws_iam_role.aws_load_balancer_controller[0]`
- `aws_iam_role_policy_attachment.aws_load_balancer_controller[0]`
- `kubernetes_service_account.aws_load_balancer_controller[0]`
- `helm_release.aws_load_balancer_controller[0]`

### Step 3: Apply the Configuration
```bash
terraform apply
```

### Step 4: Verify Deployment
```bash
# Configure kubectl (if not already done)
aws eks update-kubeconfig --region <your-region> --name <cluster-name>

# Check if controller pods are running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Expected output:
# NAME                                            READY   STATUS    RESTARTS   AGE
# aws-load-balancer-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# aws-load-balancer-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50

# Verify service account
kubectl describe sa aws-load-balancer-controller -n kube-system
```

## Configuration Options

### Default Configuration
The controller is enabled by default with these settings:
```hcl
enable_aws_load_balancer_controller = true
aws_load_balancer_controller_version = "1.6.2"
```

### To Disable (if needed)
Add to your `terraform.tfvars`:
```hcl
enable_aws_load_balancer_controller = false
```

### To Use Different Version
Add to your `terraform.tfvars`:
```hcl
aws_load_balancer_controller_version = "1.7.0"  # or any other version
```

## Testing the Controller

### Create a Test Application
```bash
# Create a simple nginx deployment
kubectl create deployment nginx --image=nginx:latest
kubectl expose deployment nginx --port=80 --target-port=80

# Create an ingress to test ALB creation
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx
                port:
                  number: 80
EOF

# Check ingress status
kubectl get ingress nginx-ingress
kubectl describe ingress nginx-ingress

# Wait for ALB to be provisioned (takes 2-3 minutes)
# The ADDRESS field will show the ALB DNS name when ready
```

### Cleanup Test Resources
```bash
kubectl delete ingress nginx-ingress
kubectl delete service nginx
kubectl delete deployment nginx
```

## Troubleshooting

### Issue: Controller pods not starting
**Solution**: Check IAM role and OIDC provider
```bash
kubectl describe sa aws-load-balancer-controller -n kube-system
kubectl describe pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Issue: Load balancer not created
**Solution**: Check subnet tags and controller logs
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100
```

### Issue: Terraform provider errors
**Solution**: Ensure AWS credentials are configured
```bash
aws sts get-caller-identity
```

## Next Steps

1. Deploy the configuration using the commands above
2. Verify the controller is running
3. Test with a sample application
4. Review the comprehensive documentation in `AWS_LOAD_BALANCER_CONTROLLER.md`
5. Start deploying your applications with Ingress or LoadBalancer services

## Important Notes

- The controller requires OIDC provider to be enabled (already configured in your setup)
- Helm and Kubernetes providers are now part of the configuration
- The IAM policy follows AWS best practices and includes all necessary permissions
- The controller uses IRSA (IAM Roles for Service Accounts) for secure AWS API access
- Two controller replicas are deployed by default for high availability

## Support

For detailed usage examples and advanced configurations, refer to:
- `AWS_LOAD_BALANCER_CONTROLLER.md` - Complete documentation
- [Official AWS Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
