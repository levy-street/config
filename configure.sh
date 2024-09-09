#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# 1. Change hostname
read -p "Enter new hostname (leave blank to keep current hostname): " new_hostname
if [ -n "$new_hostname" ]; then
  # Set the hostname using hostnamectl
  hostnamectl set-hostname "$new_hostname"

  # Update /etc/hosts file
  sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts

  # Verify the change
  current_hostname=$(hostnamectl --static)
  if [ "$current_hostname" = "$new_hostname" ]; then
    echo "Hostname successfully changed to $new_hostname"
  else
    echo "Failed to change hostname. Current hostname is still $current_hostname"
  fi
else
  current_hostname=$(hostnamectl --static)
  echo "Keeping current hostname: $current_hostname"
fi

# 2. Download authorized_keys file from GitHub
github_url="https://raw.githubusercontent.com/levy-street/config/main/authorized_keys"
keys_file="/home/ubuntu/.ssh/authorized_keys"

mkdir -p /home/ubuntu/.ssh
curl -o $keys_file $github_url

if [ $? -eq 0 ]; then
  echo "authorized_keys file downloaded successfully"
  chmod 600 $keys_file
  chown ubuntu:ubuntu $keys_file
else
  echo "Failed to download authorized_keys file"
fi

# 3. Append new prompt color setting to .bashrc
bashrc_file="/home/ubuntu/.bashrc"
new_ps1='PS1="\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "'

echo "" >> $bashrc_file
echo "# Custom prompt color" >> $bashrc_file
echo $new_ps1 >> $bashrc_file

echo "New prompt color setting appended to .bashrc"

# 4. Ask about Docker installation
if [ -z "$INSTALL_DOCKER" ]; then
  read -p "Do you want to install Docker? (y/n): " INSTALL_DOCKER
fi

if [ "$INSTALL_DOCKER" = "y" ]; then
  echo "Installing Docker..."

  # Update the apt package index
  apt-get update -y

  # Install packages to allow apt to use a repository over HTTPS
  apt-get install -y ca-certificates curl

  # Add Docker's official GPG key
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Update the apt package index again
  apt-get update -y

  # Install Docker Engine, containerd, and Docker Compose
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Create the docker group if it doesn't exist
  groupadd -f docker

  # Add ubuntu user to the docker group
  usermod -aG docker ubuntu

  echo "Docker installation completed"
else
  echo "Docker installation skipped"
fi

echo "Configuration complete. Please log out and log back in for all changes to take effect."
