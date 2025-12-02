# AWS Load Balancer Controller Setup

## Overview

The AWS Load Balancer Controller has been added to the EKS cluster configuration. This controller automatically provisions AWS Application Load Balancers (ALB) and Network Load Balancers (NLB) when you create Kubernetes Ingress or Service resources.

## What Was Added

### 1. IAM Policy
- **File**: `aws-load-balancer-controller-iam-policy.json`
- **Purpose**: Contains all necessary permissions for the controller to manage AWS load balancers
- **Permissions Include**:
  - EC2 operations (describe instances, security groups, subnets, etc.)
  - ELB operations (create, modify, delete load balancers and target groups)
  - Security group management
  - WAF and Shield integration
  - ACM certificate management

### 2. IAM Role with IRSA
- **Resource**: `aws_iam_role.aws_load_balancer_controller`
- **Purpose**: IAM role that uses IRSA (IAM Roles for Service Accounts) to provide AWS permissions to the controller pod
- **Trust Policy**: Configured to allow the Kubernetes service account to assume the role

### 3. Kubernetes Service Account
- **Name**: `aws-load-balancer-controller`
- **Namespace**: `kube-system`
- **Annotation**: Links to the IAM role via `eks.amazonaws.com/role-arn`

### 4. Helm Chart Deployment
- **Chart**: `aws-load-balancer-controller` from AWS EKS charts repository
- **Version**: 1.6.2 (configurable via variable)
- **Configuration**:
  - Cluster name
  - VPC ID
  - AWS region
  - Service account (pre-created)

## Configuration Variables

Add these to your `terraform.tfvars` or module call:

```hcl
# Enable/disable the controller (default: true)
enable_aws_load_balancer_controller = true

# Specify Helm chart version (default: "1.6.2")
aws_load_balancer_controller_version = "1.6.2"
```

## Deployment Steps

1. **Initialize Terraform** (if not already done):
   ```bash
   terraform init
   ```

2. **Plan the changes**:
   ```bash
   terraform plan
   ```

3. **Apply the configuration**:
   ```bash
   terraform apply
   ```

4. **Verify the deployment**:
   ```bash
   # Configure kubectl
   aws eks update-kubeconfig --region <your-region> --name <cluster-name>
   
   # Check controller pods
   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   
   # Check controller logs
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

## Usage Examples

### Example 1: Application Load Balancer (ALB) with Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  ingressClassName: alb
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

### Example 2: Network Load Balancer (NLB) with Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-nlb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

### Example 3: Internal ALB

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: internal-app-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internal
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
                name: internal-service
                port:
                  number: 80
```

## Important Annotations

### ALB Ingress Annotations
- `alb.ingress.kubernetes.io/scheme`: `internet-facing` or `internal`
- `alb.ingress.kubernetes.io/target-type`: `ip` or `instance`
- `alb.ingress.kubernetes.io/listen-ports`: JSON array of ports
- `alb.ingress.kubernetes.io/certificate-arn`: ACM certificate ARN for HTTPS
- `alb.ingress.kubernetes.io/ssl-redirect`: Enable HTTP to HTTPS redirect
- `alb.ingress.kubernetes.io/healthcheck-path`: Custom health check path

### NLB Service Annotations
- `service.beta.kubernetes.io/aws-load-balancer-type`: `external` or `nlb-ip`
- `service.beta.kubernetes.io/aws-load-balancer-nlb-target-type`: `ip` or `instance`
- `service.beta.kubernetes.io/aws-load-balancer-scheme`: `internet-facing` or `internal`
- `service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled`: `true` or `false`

## Troubleshooting

### Check Controller Status
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl describe deployment -n kube-system aws-load-balancer-controller
```

### View Controller Logs
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100
```

### Verify IAM Role
```bash
kubectl describe sa aws-load-balancer-controller -n kube-system
```

### Check Ingress Status
```bash
kubectl describe ingress <ingress-name>
kubectl get ingress <ingress-name> -o yaml
```

### Common Issues

1. **Controller pods not starting**: Check IAM role and OIDC provider configuration
2. **Load balancer not created**: Verify subnet tags (see below)
3. **Target registration fails**: Check security groups and network connectivity

## Required Subnet Tags

For the controller to discover subnets, ensure your subnets have these tags:

**Public subnets** (for internet-facing load balancers):
```
kubernetes.io/role/elb = 1
kubernetes.io/cluster/<cluster-name> = shared
```

**Private subnets** (for internal load balancers):
```
kubernetes.io/role/internal-elb = 1
kubernetes.io/cluster/<cluster-name> = shared
```

## Outputs

After deployment, Terraform provides these outputs:

- `aws_load_balancer_controller_role_arn`: IAM role ARN
- `aws_load_balancer_controller_policy_arn`: IAM policy ARN
- `aws_load_balancer_controller_status`: Deployment status

## References

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [AWS Load Balancer Controller GitHub](https://github.com/kubernetes-sigs/aws-load-balancer-controller)
- [Ingress Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/ingress/annotations/)
- [Service Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/service/annotations/)
