# k8s — deploy runbook (iteration 1)

End-to-end steps to deploy **rabbitmq + config-server + eventstracker** (with
an in-cluster postgres for eventstracker's DB) to the Fargate-only EKS cluster
created by `../eks-fargate`.

Success criterion: `kubectl get pods -n microservices` shows 4 pods all `1/1
Running`, and `/actuator/health` for both Spring services returns `{"status":"UP"}`.

> **NetworkPolicy on Fargate:** AWS EKS Fargate's built-in CNI does **not**
> enforce NetworkPolicy. The policies in `05-networkpolicy.yaml` are checked-in
> intent and document the expected wiring; they are not enforced until you
> install a Calico-style policy add-on (deferred to iteration 2). Defense in
> depth still comes from `pod-security.kubernetes.io/enforce: restricted` on
> the namespace, ClusterIP-only Services, non-root containers, dropped caps,
> and read-only root filesystems.

## 0. Prereqs

- The `eks-fargate` Terraform module has been applied
- `kubectl` is configured (`aws eks update-kubeconfig ...`)
- CoreDNS has been patched to run on Fargate (see `../eks-fargate/README.md`)
- Docker is logged in to ECR
- Both app repos are buildable (`./mvnw clean package -DskipTests` succeeds)

## 1. Create ECR repos and push images

```bash
export AWS_REGION=us-east-1
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export ECR_HOST=$ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com
export TAG=$(git rev-parse --short HEAD)   # immutable; never use :latest

# Idempotent ECR setup
for r in configserver eventstracker; do
  aws ecr create-repository --repository-name $r \
    --image-tag-mutability IMMUTABLE \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=KMS 2>/dev/null || true
done

aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin $ECR_HOST

# In sathishproject-config-server checkout:
./mvnw clean package -DskipTests
docker build --platform linux/amd64 \
  --build-arg APP_PORT=8888 \
  -t configserver:$TAG .
docker tag configserver:$TAG $ECR_HOST/configserver:$TAG
docker push $ECR_HOST/configserver:$TAG

# In eventstracker checkout:
./mvnw clean package -DskipTests
docker build --platform linux/amd64 -t eventstracker:$TAG .
docker tag eventstracker:$TAG $ECR_HOST/eventstracker:$TAG
docker push $ECR_HOST/eventstracker:$TAG
```

## 2. Patch the manifest image references

Replace the placeholder `image:` lines in two files:

```bash
sed -i.bak "s|REPLACE_WITH_ECR_URL/configserver:REPLACE_WITH_TAG|$ECR_HOST/configserver:$TAG|" 30-configserver.yaml
sed -i.bak "s|REPLACE_WITH_ECR_URL/eventstracker:REPLACE_WITH_TAG|$ECR_HOST/eventstracker:$TAG|" 40-eventstracker.yaml
```

(On macOS use `sed -i ''` — adjust the `.bak` accordingly.)

## 3. Apply namespace + (intent) network policies

```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f 05-networkpolicy.yaml
```

## 4. Generate random passwords + create Secrets

```bash
PG_PW=$(openssl rand -base64 24)
RMQ_PW=$(openssl rand -base64 24)
CS_USER=admin
CS_PW=$(openssl rand -base64 24)
ENCRYPT_KEY=$(openssl rand -base64 32)

# Save these to a local secrets.env (gitignored) so you can recreate them later
cat > secrets.env <<EOF
PG_PW=$PG_PW
RMQ_PW=$RMQ_PW
CS_USER=$CS_USER
CS_PW=$CS_PW
ENCRYPT_KEY=$ENCRYPT_KEY
EOF
chmod 600 secrets.env

kubectl -n microservices create secret generic postgres-secret \
  --from-literal=POSTGRES_DB=eventstracker \
  --from-literal=POSTGRES_USER=eventstracker \
  --from-literal=POSTGRES_PASSWORD=$PG_PW

kubectl -n microservices create secret generic rabbitmq-secret \
  --from-literal=RABBITMQ_DEFAULT_USER=eventstracker \
  --from-literal=RABBITMQ_DEFAULT_PASS=$RMQ_PW

kubectl -n microservices create secret generic configserver-secret \
  --from-literal=GIT_URI=https://github.com/sathishjayapal/jubilant-memory \
  --from-literal=encrypt_key=$ENCRYPT_KEY \
  --from-literal=username=$CS_USER \
  --from-literal=pass=$CS_PW

kubectl -n microservices create secret generic eventstracker-secret \
  --from-literal=SPRING_CLOUD_CONFIG_USERNAME=$CS_USER \
  --from-literal=SPRING_CLOUD_CONFIG_PASSWORD=$CS_PW \
  --from-literal=EVENTS_TRACKER_DB_URL=jdbc:postgresql://postgres:5432/eventstracker \
  --from-literal=EVENTS_TRACKER_DB_USER=eventstracker \
  --from-literal=EVENTS_TRACKER_DB_PASSWORD=$PG_PW \
  --from-literal=RABBITMQ_HOST=rabbitmq \
  --from-literal=RABBITMQ_USERNAME=eventstracker \
  --from-literal=RABBITMQ_PASSWORD=$RMQ_PW
```

## 5. Apply the workloads (in order)

```bash
kubectl apply -f 10-postgres.yaml
kubectl rollout status deployment/postgres -n microservices --timeout=5m

kubectl apply -f 20-rabbitmq.yaml
kubectl rollout status deployment/rabbitmq -n microservices --timeout=5m

kubectl apply -f 30-configserver.yaml
kubectl rollout status deployment/config-server -n microservices --timeout=10m

kubectl apply -f 40-eventstracker.yaml
kubectl rollout status deployment/eventstracker -n microservices --timeout=10m
```

## 6. Verify success

```bash
kubectl get pods -n microservices
# Expect 4 pods, all 1/1 Running:
#   postgres-...
#   rabbitmq-...
#   config-server-...
#   eventstracker-...

kubectl logs -n microservices deploy/config-server | grep -i started
kubectl logs -n microservices deploy/eventstracker | grep -iE 'started|flyway'

# config-server health (auth required)
kubectl port-forward -n microservices svc/config-server 8888:8888 &
PF_CS=$!
source secrets.env
curl -s -u "$CS_USER:$CS_PW" http://localhost:8888/actuator/health
kill $PF_CS

# eventstracker health
kubectl port-forward -n microservices svc/eventstracker 9081:9081 &
PF_ET=$!
curl -s http://localhost:9081/actuator/health
kill $PF_ET

kubectl exec -n microservices deploy/rabbitmq -- rabbitmq-diagnostics ping
```

Both health endpoints should return `{"status":"UP"}` and `rabbitmq-diagnostics`
should report `Ping succeeded`.

## 7. Teardown

```bash
kubectl delete namespace microservices
for r in configserver eventstracker; do
  aws ecr delete-repository --repository-name $r --force
done
# Then `terraform destroy` from ../eks-fargate
```

## Troubleshooting

- **`ImagePullBackOff`** on Fargate: the pod's subnets can't reach ECR. Confirm
  the subnets you passed to `eks-fargate` route 0.0.0.0/0 to either an IGW
  (with public IPs auto-assigned) or a NAT gateway.
- **CoreDNS Pending forever**: you forgot the post-apply patch in
  `../eks-fargate/README.md`.
- **`config-server` CrashLoopBackOff** with `Could not resolve placeholder`:
  the `configserver-secret` is missing one of `GIT_URI`, `username`, `pass`,
  `encrypt_key`. Inspect with `kubectl get secret configserver-secret -n microservices -o yaml`.
- **`eventstracker` initContainer never finishes**: `config-server` isn't
  serving `/actuator/health` as `UP`. Check its logs first.
- **`eventstracker` healthy but DB issues**: the `eventstracker` database/user
  is created on first run by the `postgres:16-alpine` container (env
  `POSTGRES_DB`/`POSTGRES_USER`); if you reused an existing PVC with different
  creds, drop the postgres pod or the PVC.
