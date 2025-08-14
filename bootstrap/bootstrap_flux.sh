#!/usr/bin/env bash
set -Eeuo pipefail

# ========== Styling ==========
COLOR_INFO="\033[1;36m" # cyan bold
COLOR_OK="\033[1;32m"   # green bold
COLOR_WARN="\033[1;33m" # yellow bold
COLOR_ERR="\033[1;31m"  # red bold
COLOR_DIM="\033[2m"
COLOR_RESET="\033[0m"

border() {
  local width="${1:-60}"
  local bar="================================================================================================================================"
  printf "${COLOR_INFO}%s${COLOR_RESET}\n" "${bar:0:$width}"
}

pretty_echo() {
  local msg="$1"
  local width="${2:-60}"
  border "$width"
  printf "${COLOR_INFO}  %s${COLOR_RESET}\n" "$msg"
  border "$width"
}

ok_echo() { printf "${COLOR_OK}✔ %s${COLOR_RESET}\n" "$*"; }
warn_echo() { printf "${COLOR_WARN}⚠ %s${COLOR_RESET}\n" "$*"; }
err_echo() { printf "${COLOR_ERR}✖ %s${COLOR_RESET}\n" "$*"; }
dim_echo() { printf "${COLOR_DIM}%s${COLOR_RESET}\n" "$*"; }

# ========== Error & cleanup handling ==========
on_err() {
  local exit_code=$?
  err_echo "Script failed (exit code ${exit_code}). See message(s) above."
  exit "$exit_code"
}
trap on_err ERR

# ========== Helpers ==========
require_cmd() {
  local c
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      err_echo "Required command not found: ${c}"
      exit 127
    fi
  done
}

require_file() {
  local f
  for f in "$@"; do
    if [[ ! -f "$f" ]]; then
      err_echo "Required file not found: ${f}"
      exit 2
    fi
  done
}

run_step() {
  # Usage: run_step "Description" cmd arg1 arg2 ...
  local desc="$1"
  shift
  pretty_echo "$desc"
  dim_echo "\$ $*"
  local start end
  start=$(date +%s)
  if "$@"; then
    end=$(date +%s)
    ok_echo "${desc} (took $((end - start))s)"
  else
    end=$(date +%s)
    err_echo "${desc} FAILED (after $((end - start))s)"
    return 1
  fi
}

# ========== Preflight ==========
require_cmd eksctl helm kubectl flux
require_file cluster.yaml fluxinstance.yaml

# Optional context info
dim_echo "kubectl context: $(kubectl config current-context || echo '(none)')"
dim_echo "eksctl: $(eksctl version | head -n1)"
dim_echo "helm: $(helm version --short || true)"

# ========== Steps ==========
run_step "Creating EKS cluster" \
  eksctl create cluster -f cluster.yaml

run_step "Installing Flux Operator via Helm" \
  helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --namespace flux-system \
  --create-namespace

run_step "Creating flux SSH secret for Rhys' Github" \
  flux create secret git git-ssh-auth --namespace flux-system --url=ssh://git@github.com/BillyUdders/flux-operator-playground.git --private-key-file=/home/rhys/.ssh/id_ed25519

run_step "Creating a Flux Instance (kubectl apply -f fluxinstance.yaml)" \
  kubectl apply -f fluxinstance.yaml

pretty_echo "All done! 🎉"
ok_echo "Cluster created, Flux Operator installed, and FluxInstance applied."
