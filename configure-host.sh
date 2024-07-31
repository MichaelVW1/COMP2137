#!/bin/bash

# Ignore TERM, HUP, and INT signals
trap '' TERM HUP INT

verbose=false
hostname_set=false
ip_set=false
hostentry_set=false
remove_entry=false

# Function to log and optionally print messages
log_message() {
    local message="$1"
    if [ "$verbose" = true ]; then
        echo "$message"
    fi
    logger "$message"
}

# Function to update hostname
update_hostname() {
    local desiredName="$1"
    local currentName
    currentName=$(hostname)

    if [ "$currentName" != "$desiredName" ]; then
        echo "$desiredName" > /etc/hostname
        hostname "$desiredName"
        sed -i "s/127\.0\.1\.1.*/127.0.1.1 $desiredName/" /etc/hosts
        log_message "Hostname changed from $currentName to $desiredName"
    else
        [ "$verbose" = true ] && echo "Hostname is already set to $desiredName"
    fi
}

# Function to update IP address
update_ip() {
    local desiredIPAddress="$1"
    local currentIPAddress
    currentIPAddress=$(hostname -I | awk '{print $1}')

    if [ "$currentIPAddress" != "$desiredIPAddress" ]; then
        sed -i "s/$currentIPAddress/$desiredIPAddress/" /etc/netplan/10-lxc.yaml
        netplan apply
        log_message "IP address changed from $currentIPAddress to $desiredIPAddress"
    else
        [ "$verbose" = true ] && echo "IP address is already set to $desiredIPAddress"
    fi
}

# Function to update host entry in /etc/hosts
update_hostentry() {
    local desiredName="$1"
    local desiredIPAddress="$2"

    if ! grep -q "$desiredIPAddress $desiredName" /etc/hosts; then
        echo "$desiredIPAddress $desiredName" >> /etc/hosts
        log_message "Added $desiredIPAddress $desiredName to /etc/hosts"
    else
        [ "$verbose" = true ] && echo "Entry $desiredIPAddress $desiredName is already in /etc/hosts"
    fi
}

# Function to remove exact host entry from /etc/hosts
remove_hostentry() {
    local entry="$1"

    # Backup the /etc/hosts file before making changes
    cp /etc/hosts /etc/hosts.bak

    # Remove the exact line containing the entry
    sed -i "/$entry/d" /etc/hosts

    log_message "Removed entry '$entry' from /etc/hosts"
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -verbose)
            verbose=true
            ;;
        -name)
            hostname_set=true
            desiredName="$2"
            shift
            ;;
        -ip)
            ip_set=true
            desiredIPAddress="$2"
            shift
            ;;
        -hostentry)
            hostentry_set=true
            entryName="$2"
            entryIPAddress="$3"
            shift 2
            ;;
        -remove)
            remove_entry=true
            entry="$2"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# Perform the necessary updates
if [ "$hostname_set" = true ]; then
    update_hostname "$desiredName"
fi
if [ "$ip_set" = true ]; then
    update_ip "$desiredIPAddress"
fi

if [ "$hostentry_set" = true ]; then
    update_hostentry "$entryName" "$entryIPAddress"
fi

if [ "$remove_entry" = true ]; then
    remove_hostentry "$entry"
fi
