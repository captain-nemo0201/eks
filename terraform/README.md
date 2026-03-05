# Terraform POC: EKS + Karpenter (Spot + Graviton)

This repo spins up a **dedicated VPC**, an **EKS cluster**, and installs **Karpenter** so workloads can scale on demand using:
- **arm64 (AWS Graviton) Spot** capacity
- **amd64 (x86_64) Spot** capacity

Developers can choose where a workload runs using `nodeSelector: kubernetes.io/arch: arm64|amd64`.

---

## Layout

- `main.tf` – only calls the module
- `providers.tf` – AWS provider (Kubernetes/Helm providers are configured inside the module)
- `modules/eks_karpenter_poc/` – VPC, EKS, Karpenter, NodePools

```
terraform/
  main.tf
  providers.tf
  variables.tf
  outputs.tf
  versions.tf
  modules/
    eks_karpenter_poc/
      vpc.tf
      eks.tf
      karpenter.tf
      ...
```

---

## Prereqs

- Terraform >= 1.6
- AWS CLI
- kubectl
- AWS credentials with permissions to create VPC/EKS/IAM (Admin is fine for a POC)

---

## Deploy

```bash
cd terraform
terraform init
terraform apply
```

Then configure kubectl (command is also printed as an output):

```bash
aws eks update-kubeconfig --region <REGION> --name <CLUSTER_NAME>
kubectl get nodes
```
---

## Notes on Karpenter compatibility

- This POC uses **Karpenter v1 APIs**:
  - `apiVersion: karpenter.sh/v1` (`NodePool`)
  - `apiVersion: karpenter.k8s.aws/v1` (`EC2NodeClass`)
- CRDs are installed explicitly via the `karpenter-crd` Helm chart **before** installing the main controller chart.
- If your cluster uses NetworkPolicies that block ingress to the `karpenter` namespace, you may need to allowlist webhook-related ports (see Karpenter upgrade notes).


> The cluster comes with a small **system** managed node group (ON_DEMAND, arm64) with the taint  
> `CriticalAddonsOnly=true:NoSchedule` so core add-ons + the Karpenter controller can always start.
> Application workloads should land on Karpenter-provisioned capacity.

---

## Run a workload on Graviton (arm64)

Create `demo-arm64.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-arm64
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-arm64
  template:
    metadata:
      labels:
        app: demo-arm64
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64
      containers:
        - name: app
          image: public.ecr.aws/docker/library/nginx:1.27
          ports:
            - containerPort: 80
```

Apply:

```bash
kubectl apply -f demo-arm64.yaml
kubectl get pods -o wide
```

Verify architecture:

```bash
kubectl get pod -l app=demo-arm64 -o wide
kubectl get node <node-name> -o jsonpath='{.status.nodeInfo.architecture}{"\n"}'
```

---

## Run a workload on x86 (amd64)

Create `demo-amd64.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-amd64
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-amd64
  template:
    metadata:
      labels:
        app: demo-amd64
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64
      containers:
        - name: app
          image: public.ecr.aws/docker/library/nginx:1.27
          ports:
            - containerPort: 80
```

```bash
kubectl apply -f demo-amd64.yaml
kubectl get pods -o wide
```

---

## Useful commands

```bash
kubectl get nodepools
kubectl get ec2nodeclasses
kubectl -n karpenter get deploy
kubectl -n karpenter logs deploy/karpenter -f
```

---

## Destroy

```bash
cd terraform
terraform destroy
```

---

## Recommendations (what to improve before production)

### 1) Add an On-Demand fallback pool
Spot is great, but it can be temporarily unavailable per AZ/instance family. Without fallback, pods can remain Pending.
Typical pattern:
- `*-spot` NodePools for cost efficiency
- `*-ondemand` NodePools with lower priority / smaller limits as a safety net

### 2) Tighten instance selection
For a POC, instance families are broad. For prod:
- constrain sizes (`instance-size`) and/or vCPU/memory bounds
- exclude burstable for latency-sensitive services
- consider `minValues` (Karpenter) to avoid over-fragmentation

### 3) Use disruption budgets & topology
- set `disruption.budgets` so consolidation doesn’t evict too aggressively
- add `topologySpreadConstraints` in workloads to avoid single-AZ concentration

### 4) Observability & cost controls
- install kube-state-metrics / Prometheus / Grafana (or managed alternatives)
- enable CloudWatch Container Insights if you already use CloudWatch
- add cost allocation tags + budgets/alerts

### 5) Security baseline
- private endpoint (or restricted CIDR) for the EKS API in prod
- enforce Pod Security Standards / OPA Gatekeeper / Kyverno
- consider IRSA/Pod Identity for app workloads; lock down node IAM role policies

---
