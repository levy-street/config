#!/bin/bash

set -e
set -u
set -o pipefail

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Get list of directories in /home
home_dirs=($(ls -d /home/*))

# Check if there's only one directory in /home
if [ ${#home_dirs[@]} -eq 1 ]; then
    # Use the single directory in /home
    user_home="${home_dirs[0]}"
else
    # Prompt for selection or set a default if multiple directories exist
    echo "Multiple home directories found. Please specify which one to use."
    select user_home in "${home_dirs[@]}"; do
        if [ -n "$user_home" ]; then
            break
        else
            echo "Invalid selection."
        fi
    done
fi

username=$(basename "$user_home")

# Function to download and decrypt the SSH key
download_and_decrypt_ssh_key() {
    local encrypted_key_url="https://raw.githubusercontent.com/levy-street/config/main/encrypted_id_ed25519.bin"
    local public_key_url="https://raw.githubusercontent.com/levy-street/config/main/id_ed25519.pub"
    local encrypted_key_path="/tmp/encrypted_id_ed25519.bin"
    local public_key_path="$user_home/.ssh/id_ed25519.pub"
    local decrypted_key_path="$user_home/.ssh/id_ed25519"

    # Download the encrypted private key
    curl -s -o "$encrypted_key_path" "$encrypted_key_url"
    if [ $? -ne 0 ]; then
        echo "Failed to download encrypted SSH private key"
        return 1
    fi

    # Download the public key
    curl -s -o "$public_key_path" "$public_key_url"
    if [ $? -ne 0 ]; then
        echo "Failed to download SSH public key"
        rm -f "$encrypted_key_path"
        return 1
    fi

    # Prompt for the passphrase
    echo "Enter passphrase to decrypt the SSH key: "
    stty -echo
    read passphrase
    stty echo
    echo

    # Decrypt the key
    openssl enc -aes-256-cbc -d -in "$encrypted_key_path" -out "$decrypted_key_path" -pass pass:"$passphrase"

    if [ $? -eq 0 ]; then
        echo "SSH private key decrypted successfully"
        chmod 600 "$decrypted_key_path"
        chmod 644 "$public_key_path"
        chown "$username:$username" "$decrypted_key_path" "$public_key_path"
    else
        echo "Failed to decrypt SSH key. Please check your passphrase."
        rm -f "$encrypted_key_path" "$public_key_path"
        return 1
    fi

    # Clean up
    rm -f "$encrypted_key_path"

    echo "SSH key pair successfully installed"
}

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

# 2. Download and decrypt SSH key
download_and_decrypt_ssh_key

# 3. Download authorized_keys file from GitHub
github_url="https://raw.githubusercontent.com/levy-street/config/main/authorized_keys"
keys_file="$user_home/.ssh/authorized_keys"

mkdir -p "$user_home/.ssh"
curl -o "$keys_file" "$github_url"

if [ $? -eq 0 ]; then
  echo "authorized_keys file downloaded successfully"
  chmod 600 "$keys_file"
  chown "$username:$username" "$keys_file"
else
  echo "Failed to download authorized_keys file"
fi

# 4. Append new prompt color setting to .bashrc
bashrc_file="$user_home/.bashrc"
new_ps1='PS1="\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "'

echo "" >> "$bashrc_file"
echo "# Custom prompt color" >> "$bashrc_file"
echo "$new_ps1" >> "$bashrc_file"

echo "New prompt color setting appended to .bashrc"

# 5. Ask about Docker installation
read -p "Do you want to install Docker? (y/n): " INSTALL_DOCKER

if [ "$INSTALL_DOCKER" = "y" ]; then
  echo "Installing Docker..."

  # Update the apt package index
  apt-get update

  # Install packages to allow apt to use a repository over HTTPS
  apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg \
      lsb-release

  # Add Docker's official GPG key
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  # Set up the stable repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker Engine
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io

  # Add user to the docker group
  usermod -aG docker "$username"

  echo "Docker installation completed"
else
  echo "Docker installation skipped"
fi

echo "Configuration complete. Please log out and log back in for all changes to take effect."
