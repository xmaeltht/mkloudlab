#!/usr/bin/env bash
#
# Interactive local deployment for Mkloudlab
# Guides you through: Vagrant cluster → Prerequisites → Flux → Apps
#
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()     { echo -e "${RED}[ERROR]${NC} $1"; }
heading() { echo -e "\n${BOLD}${CYAN}═══ $1 ═══${NC}\n"; }
pause()   { echo -e "\n${CYAN}Press Enter to continue (or Ctrl+C to stop)...${NC}"; read -r; }

check_prereqs() {
  heading "Checking prerequisites"
  local missing=()
  command -v vagrant   &>/dev/null || missing+=(vagrant)
  command -v VBoxManage &>/dev/null || missing+=(VirtualBox)
  command -v task      &>/dev/null || missing+=(task)
  command -v kubectl   &>/dev/null || missing+=(kubectl)

  if [ ${#missing[@]} -gt 0 ]; then
    err "Missing: ${missing[*]}"
    echo ""
    echo "Install with:"
    echo "  Vagrant + VirtualBox: https://www.vagrantup.com/docs/installation"
    echo "  Task: brew install go-task/tap/go-task"
    echo "  Kubectl: https://kubernetes.io/docs/tasks/tools/"
    echo "  Flux (optional, will install if missing): curl -s https://fluxcd.io/install.sh | sudo bash"
    return 1
  fi
  info "Vagrant, VirtualBox, Task, and kubectl are available."
  if ! command -v flux &>/dev/null; then
    warn "Flux CLI not found. It will be installed when you run 'install:flux'."
  else
    info "Flux CLI is available."
  fi
  return 0
}

step_infrastructure() {
  heading "Step 1: Infrastructure (Vagrant cluster)"
  cd "$REPO_ROOT"
  if kubectl cluster-info &>/dev/null 2>&1; then
    warn "kubectl already has a cluster. Use it or destroy existing VMs first (task vagrant:destroy)."
    read -p "Skip Vagrant and use current cluster? (y/N) " skip
    if [[ "$skip" =~ ^[Yy]$ ]]; then
      info "Skipping Vagrant. Using current cluster."
      return 0
    fi
  fi

  read -p "Number of worker nodes [2]: " workers
  workers=${workers:-2}
  export WORKER_COUNT=$workers
  info "Starting cluster with 1 controller + $WORKER_COUNT worker(s)..."
  task vagrant:up
  pause
}

step_fix_dns() {
  heading "Step 1b: Fix cluster DNS (so pods can resolve github.com)"
  cd "$REPO_ROOT"
  task fix:dns
  pause
}

step_prerequisites() {
  heading "Step 2: Cluster prerequisites (Gateway API, storage, cert-manager)"
  cd "$REPO_ROOT"
  task install:prerequisites
  pause
}

step_cloudflare() {
  heading "Step 2b: Cloudflare API token (optional, for TLS)"
  if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    info "CLOUDFLARE_API_TOKEN is already set. Configuring in cluster..."
    task certificates:configure-token
  else
    echo "To get TLS certificates via DNS-01, set CLOUDFLARE_API_TOKEN."
    read -p "Set token now? (y/N) " set_token
    if [[ "$set_token" =~ ^[Yy]$ ]]; then
      read -sp "Paste your Cloudflare API token: " CLOUDFLARE_API_TOKEN
      export CLOUDFLARE_API_TOKEN
      echo ""
      [ -n "$CLOUDFLARE_API_TOKEN" ] && task certificates:configure-token
    else
      info "Skipping. You can run later: export CLOUDFLARE_API_TOKEN=... && task certificates:configure-token"
    fi
  fi
  pause
}

step_flux() {
  heading "Step 3: Install Flux (GitOps)"
  cd "$REPO_ROOT"
  task install:flux
  pause
}

step_flux_configure() {
  heading "Step 4: Configure Flux GitRepository"
  cd "$REPO_ROOT"
  task flux:configure-repo
  pause
}

step_apps() {
  heading "Step 5: Deploy applications (Flux apps)"
  cd "$REPO_ROOT"
  task install:apps
  info "Flux will reconcile automatically. Check with: task flux:status"
  pause
}

step_certificates() {
  heading "Step 5b: Certificates (optional)"
  cd "$REPO_ROOT"
  task install:certificates
  pause
}

step_status() {
  heading "Status"
  cd "$REPO_ROOT"
  task status
}

run_full() {
  check_prereqs || exit 1
  pause
  step_infrastructure
  step_fix_dns
  step_prerequisites
  step_cloudflare
  step_flux
  step_flux_configure
  step_apps
  step_certificates
  step_status
  heading "Done"
  info "Next: task flux:status, task access, or see README.md for URLs (Grafana, Keycloak, etc.)."
}

run_step_by_step() {
  check_prereqs || exit 1
  while true; do
    heading "What do you want to do?"
    echo "  1) Infrastructure (Vagrant cluster)"
    echo "  1b) Fix cluster DNS (if Flux can't clone github.com)"
    echo "  2) Prerequisites (Gateway API, storage, cert-manager)"
    echo "  3) Cloudflare token (TLS)"
    echo "  4) Install Flux"
    echo "  5) Configure Flux GitRepository"
    echo "  6) Deploy apps (Flux)"
    echo "  7) Certificates"
    echo "  8) Show status"
    echo "  q) Quit"
    echo ""
    read -p "Choice [1, 1b, 2-8, q]: " choice
    case "$choice" in
      1) step_infrastructure ;;
      1b) step_fix_dns ;;
      2) step_prerequisites ;;
      3) step_cloudflare ;;
      4) step_flux ;;
      5) step_flux_configure ;;
      6) step_apps ;;
      7) step_certificates ;;
      8) step_status ;;
      q|Q) info "Bye."; exit 0 ;;
      *) warn "Invalid option." ;;
    esac
  done
}

usage() {
  echo "Usage: $0 [full|menu]"
  echo ""
  echo "  full   – Run full deployment interactively (default)"
  echo "  menu   – Show step-by-step menu to run individual steps"
  echo ""
  echo "From repo root you can also run: task deploy:local"
}

main() {
  local mode="${1:-full}"
  case "$mode" in
    full)  run_full ;;
    menu)  run_step_by_step ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
