#!/usr/bin/env bash
# run.sh - one-shot script for Assignment 8 Part B demo
# Builds 3 Docker containers (fake servers), installs nginx on them with
# Ansible, runs it twice to prove idempotency, and verifies with curl.
# All output is also saved into ./outputs/*.txt for the lab report.

set -uo pipefail
cd "$(dirname "$0")"

OUT=./outputs
mkdir -p "$OUT"
SSH_DIR=./ssh-key
mkdir -p "$SSH_DIR"

step() { echo; echo "==================================================="; echo "STEP: $1"; echo "==================================================="; }

# ---------------------------------------------------------------------------
step "0. Check Docker"
# ---------------------------------------------------------------------------
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  DOCKER_AVAILABLE=1
  echo "Docker is installed and running. Will use 3 Docker containers as Server-1/2/3."
else
  DOCKER_AVAILABLE=0
  echo "Docker is NOT available on this machine."
  echo "Falling back to a LOCAL-ONLY demo: Ansible will run against 'localhost'"
  echo "using ansible_connection=local (no SSH, no containers). Install/enable"
  echo "Docker Desktop and re-run this script to get the full 3-server demo."
fi

# ---------------------------------------------------------------------------
step "1. Ensure Ansible is installed"
# ---------------------------------------------------------------------------
if ! command -v ansible >/dev/null 2>&1; then
  echo "ansible not found, installing via pip3..."
  pip3 install --user ansible | tee "$OUT/00-ansible-install.txt"
  export PATH="$HOME/Library/Python/3.11/bin:$HOME/.local/bin:$PATH"
else
  echo "ansible already installed: $(ansible --version | head -1)"
fi
ansible --version | tee "$OUT/00-ansible-version.txt"

if [ "$DOCKER_AVAILABLE" -eq 0 ]; then
  echo "[all_local]" > inventory.ini
  echo "localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3" >> inventory.ini
  sed -i.bak 's/hosts: webservers/hosts: all_local/' install-nginx.yml
  echo "Rewrote inventory.ini and install-nginx.yml for local-only fallback mode."
  echo "Run this script again later on a machine with Docker for the real multi-server demo."
  # Still continue below so the playbook actually runs against localhost.
fi

# ---------------------------------------------------------------------------
if [ "$DOCKER_AVAILABLE" -eq 1 ]; then
step "2. Generate SSH keypair for Ansible -> containers"
  if [ ! -f "$SSH_DIR/id_rsa_ansible" ]; then
    ssh-keygen -t rsa -b 2048 -f "$SSH_DIR/id_rsa_ansible" -N "" -q
    echo "Generated new keypair in $SSH_DIR/"
  else
    echo "Keypair already exists in $SSH_DIR/, reusing it."
  fi
  chmod 600 "$SSH_DIR/id_rsa_ansible"

step "3. Build and start the 3 'server' containers"
  docker compose down -v >/dev/null 2>&1
  docker compose up -d --build 2>&1 | tee "$OUT/01-docker-up.txt"

  echo "Waiting for SSH to come up on all 3 containers..."
  for port in 2201 2202 2203; do
    for i in $(seq 1 30); do
      if nc -z 127.0.0.1 "$port" 2>/dev/null; then
        echo "Port $port is up."
        break
      fi
      sleep 1
    done
  done
  sleep 3
fi

# ---------------------------------------------------------------------------
step "4. Ansible ping test"
# ---------------------------------------------------------------------------
ansible all -i inventory.ini -m ping 2>&1 | tee "$OUT/02-ping.txt"

# ---------------------------------------------------------------------------
step "5. Run the playbook (1st time - installs nginx)"
# ---------------------------------------------------------------------------
ansible-playbook -i inventory.ini install-nginx.yml 2>&1 | tee "$OUT/03-playbook-run1.txt"

# ---------------------------------------------------------------------------
step "6. Run the playbook again (2nd time - idempotency check, expect changed=0)"
# ---------------------------------------------------------------------------
ansible-playbook -i inventory.ini install-nginx.yml 2>&1 | tee "$OUT/04-playbook-run2.txt"

# ---------------------------------------------------------------------------
step "7. Verify with curl"
# ---------------------------------------------------------------------------
{
  if [ "$DOCKER_AVAILABLE" -eq 1 ]; then
    for p in 8081 8082 8083; do
      echo "--- curl http://localhost:$p/ ---"
      curl -s "http://localhost:$p/"
      echo
    done
  else
    echo "--- curl http://localhost/ (local fallback) ---"
    curl -s "http://localhost/"
    echo
  fi
} | tee "$OUT/05-curl-verify.txt"

step "DONE"
echo "All captured output is in $OUT/"
