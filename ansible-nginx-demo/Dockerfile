# Dockerfile for the "target server" containers used in this Ansible demo.
# We use plain Ubuntu 22.04 + openssh-server instead of systemd, because
# Ansible manages remote machines over SSH - it does not need systemd.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y openssh-server sudo python3 python3-apt curl && \
    mkdir -p /var/run/sshd && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user that Ansible will log in as, with passwordless sudo
RUN useradd -m -s /bin/bash devops && \
    echo "devops ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/devops/.ssh && \
    chmod 700 /home/devops/.ssh && \
    chown -R devops:devops /home/devops/.ssh

# Allow SSH login with key only (no password needed since we inject a public key at build/run time)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    echo "StrictModes no" >> /etc/ssh/sshd_config

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
