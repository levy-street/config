#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# 1. Change hostname
read -p "Enter new hostname: " new_hostname
hostnamectl set-hostname $new_hostname
echo "Hostname changed to $new_hostname"

# 2. Download authorized_keys file from GitHub
github_url="https://raw.githubusercontent.com/levy-street/config/main/authorized_keys"
keys_file="/home/ubuntu/.ssh/authorized_keys"

mkdir -p /home/ubuntu/.ssh
curl -o $keys_file $github_url

if [ $? -eq 0 ]; then
  echo "authorized_keys file downloaded successfully"
  chmod 600 $keys_file
else
  echo "Failed to download authorized_keys file"
fi

# 3. Change prompt color in .bashrc
bashrc_file="/home/ubuntu/.bashrc"
new_ps1='PS1='"'"'${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '"'"

if grep -q "PS1=" $bashrc_file; then
  sed -i '/PS1=/c\'"$new_ps1" $bashrc_file
else
  echo $new_ps1 >> $bashrc_file
fi

echo "Prompt color changed in .bashrc"

# 4. Ask if user wants to install Docker
read -p "Do you want to install Docker? (y/n): " install_docker

if [ "$install_docker" = "y" ]; then
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

  echo "Docker installation completed"
else
  echo "Docker installation skipped"
fi


echo "Configuration complete. Please log out and log back in for all changes to take effect."
