# Assignment 8 - Part B: Automated Installation and Configuration of Nginx Using Ansible

## Aim
To use Ansible to automatically install the Nginx web server and deploy a
custom web page on multiple servers, without logging into each server
manually, and to demonstrate that running the same automation twice does
not break or repeat the work (idempotency).

## Architecture

```
          +------------------+
          |   Control Node   |
          |  (this laptop,   |
          |  runs Ansible)   |
          +------------------+
             |    |    |
             | SSH| SSH| SSH
             v    v    v
      +--------+ +--------+ +--------+
      |Server-1| |Server-2| |Server-3|
      |(docker)| |(docker)| |(docker)|
      |:2201/22| |:2202/22| |:2203/22|
      | nginx  | | nginx  | | nginx  |
      |:8081/80| |:8082/80| |:8083/80|
      +--------+ +--------+ +--------+
```

Server-1/2/3 are 3 separate Docker containers (Ubuntu 22.04 + SSH server),
standing in for 3 real machines. The control node (your laptop) connects to
each one over SSH using a key pair, exactly like it would with real servers
in the cloud.

## Files
- `Dockerfile` - builds the "target server" image (Ubuntu + SSH + sudo user).
- `docker-compose.yml` - starts 3 containers of that image, mapping SSH to
  ports 2201/2202/2203 and HTTP to 8081/8082/8083 on the host.
- `inventory.ini` - tells Ansible about the 3 servers (group `webservers`).
- `ansible.cfg` - project settings (disables SSH host-key checking for this lab).
- `install-nginx.yml` - the playbook that installs and configures nginx.
- `run.sh` - runs the entire demo end to end and saves output to `outputs/`.

## How to run
```bash
cd ansible-nginx-demo
./run.sh
```
This single command will:
1. Check Docker is available (falls back to a local-only demo if not).
2. Install Ansible via pip if it isn't already installed.
3. Generate an SSH key and build/start the 3 containers.
4. Run `ansible ... -m ping` to confirm connectivity.
5. Run the playbook once (installs nginx, writes the page).
6. Run the playbook again (to prove idempotency - nothing should change).
7. `curl` each server's web page to confirm it is live.

All terminal output is also saved as text files in `outputs/` so it can be
pasted into the lab report as evidence.

## Step-by-step commands
If you prefer to run each step manually instead of `./run.sh`, here is the
full sequence:

```bash
cd ansible-nginx-demo

# 0. Check Docker is installed and running
docker info

# 1. Check/install Ansible
ansible --version

# 2. Generate an SSH keypair for Ansible to use on the containers
ssh-keygen -t rsa -b 2048 -f ssh-key/id_rsa_ansible -N "" -q
chmod 600 ssh-key/id_rsa_ansible

# 3. Build and start the 3 "server" containers
docker compose down -v
docker compose up -d --build

# 4. Confirm Ansible can reach all 3 servers over SSH
ansible all -i inventory.ini -m ping

# 5. Run the playbook (1st time - installs nginx, writes the page)
ansible-playbook -i inventory.ini install-nginx.yml

# 6. Run the playbook again (2nd time - idempotency check, expect changed=0)
ansible-playbook -i inventory.ini install-nginx.yml

# 7. Verify each server is serving the page
curl -s http://localhost:8081/
curl -s http://localhost:8082/
curl -s http://localhost:8083/
```

## Expected output
- Ping step: `pong` from all 3 hosts.
- 1st playbook run: `PLAY RECAP` shows `changed` tasks (installing nginx,
  starting it, writing the page).
- 2nd playbook run: `PLAY RECAP` shows `changed=0` for all hosts - proof
  that Ansible only does work when something actually needs to change.
- curl output: `<h1>Web Server Configured Using Ansible</h1>` from each
  of the 3 ports (8081, 8082, 8083).

## Benefits demonstrated by this assignment
- **Agentless**: no special software needs to be pre-installed on the
  servers, only SSH + Python (which almost every Linux server already has).
- **Idempotent**: running the playbook many times gives the same end
  result and does not repeat work that is already done (proven by the
  2nd run showing `changed=0`).
- **Repeatable**: the exact same playbook can be pointed at 3 servers or
  300 servers by just editing the inventory file.
- **Infrastructure as Code**: the server setup (nginx + web page) is
  written down as a YAML file in version control, instead of being "tribal
  knowledge" in someone's head or a wiki page.
- **Centralized management**: one playbook run from one control node
  configures every server in the `webservers` group at once.
- **Reduced human error**: no manual typing of commands on each server one
  by one, so no chance of a typo on server 2 but not server 1 or server 3.

## How this fits into the full DevOps workflow
This assignment is one stage of a bigger CI/CD pipeline that is usually
taught across multiple assignments:

```
GitHub (source code)
   -> Jenkins (build & test automatically on every push)
      -> Containerized App (packaged into a Docker image)
         -> Kubernetes (runs/orchestrates the containers in a cluster)
            -> Helm (packages the Kubernetes YAML as a reusable chart)
               -> Ansible (configures the underlying servers/VMs - e.g.
                  installing nginx, dependencies, OS-level settings -
                  that Kubernetes itself runs on top of)
```

In short: GitHub stores the code, Jenkins builds and tests it, the app is
containerized with Docker, Kubernetes + Helm run and manage those
containers at scale, and Ansible is what configures and prepares the
actual servers/VMs underneath all of that (or configures standalone
servers, like the nginx server in this assignment, that sit outside the
Kubernetes cluster). Ansible is the "configure the machine" layer, while
Kubernetes/Helm are the "run the containers" layer.
