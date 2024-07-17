#!/bin/bash

# Function to display user-friendly output
function print_message {
    echo "---------------------------------------------"
    echo "$1"
    echo "---------------------------------------------"
}

# Function to update netplan configuration
function update_netplan {
    local new_ip_address="192.168.16.21/24"
    local netplan_file="/etc/netplan/10-lxc.yaml"

    # Check if netplan file exists
    if [ ! -f "$netplan_file" ]; then
        print_message "Netplan configuration file not found: $netplan_file"
        exit 1
    fi

    # Backup netplan file
    cp "$netplan_file" "$netplan_file.bak"

    # Update netplan configuration for eth0 using sed
    sed -i '/eth0:/,/addresses:/ s|\(^\s*addresses:\s*\)\[.*\]|\1['"$new_ip_address"']|g' "$netplan_file"

    # Apply netplan configuration
    sudo netplan apply > /dev/null 2>&1  # Suppress output

    if [ $? -eq 0 ]; then
        print_message "Netplan configuration updated successfully."
    else
        print_message "Failed to update netplan configuration."
        exit 1
    fi

    # Update /etc/hosts file
    update_hosts_file "$new_ip_address"
}

# Function to update /etc/hosts file
function update_hosts_file {
    local new_ip_address="$1"
    local hostname="server1"
    local hosts_file="/etc/hosts"

    # Check if the entry already exists in /etc/hosts
    if grep -q "$new_ip_address\s*$hostname" "$hosts_file"; then
        print_message "Entry already exists in /etc/hosts"
    else
        # Add the new entry to /etc/hosts using sudo
        echo "$new_ip_address $hostname" | sudo tee -a "$hosts_file" > /dev/null
        print_message "Added $new_ip_address $hostname to /etc/hosts"
    fi
}

# Function to install Apache2
function install_apache2 {
    sudo apt update > /dev/null 2>&1  # Suppress output
    print_message "Installing Apache2 web server..."
    sudo apt install -y apache2 > /dev/null 2>&1  # Suppress output

    # Check if Apache2 is installed and running
    if systemctl is-active --quiet apache2; then
        print_message "Apache2 installed successfully."
    else
        print_message "Failed to install Apache2."
        exit 1
    fi
}

# Function to install Squid proxy
function install_squid {
    sudo apt update > /dev/null 2>&1  # Suppress output
    print_message "Installing Squid web proxy..."
    sudo apt install -y squid > /dev/null 2>&1  # Suppress output
    # Check if Squid is installed and running
    if systemctl is-active --quiet squid; then
        print_message "Squid installed successfully."
    else
        print_message "Failed to install Squid."
        exit 1
    fi
}

# Function to install ufw
function install_ufw {
    print_message "Installing ufw firewall..."
    sudo apt update > /dev/null 2>&1  # Suppress output
    sudo apt install -y ufw > /dev/null 2>&1  # Suppress output

    # Check if ufw is installed
    if [ -x "$(command -v ufw)" ]; then
        print_message "ufw installed successfully."
    else
        print_message "Failed to install ufw."
        exit 1
    fi
}

# Function to create user accounts and configure SSH keys
function create_users {
    local users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

    for user in "${users[@]}"; do
        # Create user with home directory in /home and bash as default shell
        sudo mkdir -p "/home/$user/.ssh"
        sudo useradd -m -s /bin/bash "$user"

        # Generate RSA key (without passphrase), automatically answering "yes" to overwrite prompt
        echo -e "y\n" | sudo ssh-keygen -t rsa -f "/home/$user/.ssh/id_rsa" -N "" > /dev/null 2>&1

        # Generate Ed25519 key (without passphrase), automatically answering "yes" to overwrite prompt
        if [ "$user" == "dennis" ]; then
            # Use provided Ed25519 key for Dennis
            echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" > "/home/$user/.ssh/id_ed25519.pub"
        else
            echo -e "y\n" | sudo ssh-keygen -t ed25519 -f "/home/$user/.ssh/id_ed25519" -N "" > /dev/null 2>&1
        fi

        # Add user to sudo group if user is 'dennis'
        if [ "$user" == "dennis" ]; then
            sudo usermod -aG sudo "$user"
        fi

        # Create authorized_keys file and add SSH keys
        sudo cp "/home/$user/.ssh/id_rsa.pub" "/home/$user/.ssh/authorized_keys"
        sudo cat "/home/$user/.ssh/id_ed25519.pub" >> "/home/$user/.ssh/authorized_keys"

        # Set ownership and permissions for .ssh directory and authorized_keys file
        sudo chown -R "$user:$user" "/home/$user/.ssh"
        sudo chmod 700 "/home/$user/.ssh"
        sudo chmod 600 "/home/$user/.ssh/authorized_keys"

        print_message "User $user created with home directory /home/$user and SSH keys configured."
    done
}

# Function to configure ufw firewall
function configure_ufw {
    print_message "Configuring ufw firewall..."

    # Enable ufw and allow SSH on port 22 only on mgmt network
    sudo ufw --force enable > /dev/null 2>&1  # Enable ufw and suppress output
    sudo ufw default deny incoming > /dev/null 2>&1  # Deny all incoming traffic by default

    # Allow SSH on port 22 only on management network interface (replace eth1 with actual mgmt network interface)
    sudo ufw allow in on eth1 to any port 22 > /dev/null 2>&1

    # Allow HTTP on both interfaces (port 80)
    sudo ufw allow in on eth0 to any port 80 > /dev/null 2>&1
    sudo ufw allow in on eth1 to any port 80 > /dev/null 2>&1

    # Allow Squid web proxy on both interfaces (port 3128)
    sudo ufw allow in on eth0 to any port 3128 > /dev/null 2>&1
    sudo ufw allow in on eth1 to any port 3128 > /dev/null 2>&1

    # Reload ufw to apply changes
    sudo ufw reload > /dev/null 2>&1

    print_message "ufw firewall configured successfully."
}

# Main script
print_message "Starting network configuration, software installation, user accounts setup, and firewall setup..."

# Install ufw
install_ufw

# Update netplan configuration and /etc/hosts file
update_netplan

# Install Apache2 and Squid
install_apache2
install_squid

# Create user accounts and configure SSH keys
create_users

# Configure ufw firewall
configure_ufw

# Check for errors
if [ $? -eq 0 ]; then
    print_message "Setup completed successfully."
else
    print_message "Setup encountered errors. Please check logs for details."
fi
