pretty_echo() {
  local msg="$1"
  local width=60
  local border="============================================"
  printf "\n\033[1;36m%s\033[0m\n" "${border:0:$width}"
  printf "\033[1;36m  %s\033[0m\n" "$msg"
  printf "\033[1;36m%s\033[0m\n\n" "${border:0:$width}"
}

#!/usr/bin/env bash
set -euo pipefail

pretty_echo "Creating EKS cluster"
eksctl create cluster -f cluster.yaml

pretty_echo "Installing Flux Operator via Helm"
helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --namespace flux-system \
  --create-namespace

pretty_echo "Creating a Flux Instance using: kubectl apply -f fluxinstance.yaml"
