# ICC 2023 Amazon EKS Demo

## Prerequisites

- AWS credentials with IAM policies meeting requirements for eksctl usage
- Helm client for K8s package management
- kubectl / kustomize for K8s interactions

> [!NOTE]
> Some of the commands below are newline-delimited with a backslash (`\`) character for use with macOS/Linux shells.
> If you're using Windows and Powershell, replace these with a backtick (\`) character, if using Command Prompt, replace with caret (`^`) character.

## Commands

Create the cluster and test kubectl configuration:

```bash
# Create an EKS cluster with eksctl
eksctl create cluster -f cluster.yml
# Test the updated config
kubectl get nodes
```

Setup Cert-Manager:

```bash
# Add jetstack repo for cert-manager
helm repo add jetstack https://charts.jetstack.io
# Update from chart repositories
helm repo update
# Install cert-manager into its own namespace along with CRDs
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

Install AWS Load Balancer Controller

```bash
# Add the Helm repository for EKS
helm repo add eks https://aws.github.io/eks-charts
# Read in the latest charts from the Helm repo
helm repo update
# Install AWS Load Balancer Controller into our EKS cluster
helm install \
    aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system --set clusterName=icc2023-demo \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller
```

Create a namespace for our demo:

```bash
# Create the namespace
kubectl create namespace icc2023
# Set as default namespace for our current cluster target
kubectl config set-context --current --namespace=icc2023
```

Deploy a self-signed ClusterIssuer for bootstrapping our GAN Certificate Authority:

```bash
kubectl apply -f ../selfsigned-issuer.yml
```

If you want to preview what will be deployed in the final step, use `kustomize build`:

```bash
mkdir out
kustomize build -o out
```

Deploy Ignition:

```bash
kubectl apply -k .
```

## Other Notes

To cleanup after the demo above, make sure that you first delete the namespace containing all of your resources.  This will help ensure that no resources are orphaned after cluster deletion:

```
kubectl delete namespace icc2023
```

Delete the cluster:

```bash
eksctl delete cluster --name icc2023-demo
```
