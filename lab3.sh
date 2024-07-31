#!/bin/bash
# This script runs the configure-host.sh script from the current directory to modify 2 servers and update the local /etc/hosts file

verbose=false

# Function to log and optionally print messages
log_message() {
    local message="$1"
    if [ "$verbose" = true ]; then
        echo "$message"
    fi
    logger "$message"
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -verbose)
            verbose=true
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# SCP and SSH commands with error checking
transfer_and_execute() {
    local server="$1"
    local name="$2"
    local ip="$3"
    local hostentry_name="$4"
    local hostentry_ip="$5"
    local verbose_option=""

    if [ "$verbose" = true ]; then
        verbose_option="-verbose"
    fi

    echo "Transferring configure-host.sh to $server" >&2
    scp configure-host.sh remoteadmin@"$server":/root
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to transfer configure-host.sh to $server"
        exit 1
    fi

    echo "Executing configure-host.sh on $server with -name $name -ip $ip -hostentry $hostentry_name $hostentry_ip $verbose_option" >&2
    ssh remoteadmin@"$server" "/root/configure-host.sh -name \"$name\" -ip \"$ip\" -hostentry \"$hostentry_name\" \"$hostentry_ip\" $verbose_option"
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to execute configure-host.sh on $server"
        exit 1
    fi
}

# Update server1 with two host entries
transfer_and_execute "server1-mgmt" "loghost" "192.168.16.3" "webhost" "192.168.16.4"
# Add the additional host entry for server1
ssh remoteadmin@"server1-mgmt" "/root/configure-host.sh -hostentry loghost 192.168.16.3 $([ "$verbose" = true ] && echo "-verbose")"
if [ $? -ne 0 ]; then
    log_message "Error: Failed to add additional host entry to server1"
    exit 1
fi
ssh remoteadmin@"server1-mgmt" "/root/configure-host.sh -remove '192.168.16.200 server1' $([ "$verbose" = true ] && echo "-verbose")"

# Update server2
transfer_and_execute "server2-mgmt" "webhost" "192.168.16.4" "loghost" "192.168.16.3"

ssh remoteadmin@"server2-mgmt" "/root/configure-host.sh -hostentry webhost 192.168.16.4 $([ "$verbose" = true ] && echo "-verbose")"
if [ $? -ne 0 ]; then
    log_message "Error: Failed to add additional host entry to server2"
    exit 1
fi

ssh remoteadmin@"server2-mgmt" "/root/configure-host.sh -remove '192.168.16.201 server2' $([ "$verbose" = true ] && echo "-verbose")"

# Update the local machine's /etc/hosts file
./configure-host.sh -hostentry "loghost" "192.168.16.3" $([ "$verbose" = true ] && echo "-verbose")
if [ $? -ne 0 ]; then
    log_message "Error: Failed to update local /etc/hosts with loghost entry"
    exit 1
fi

./configure-host.sh -hostentry "webhost" "192.168.16.4" $([ "$verbose" = true ] && echo "-verbose")
if [ $? -ne 0 ]; then
    log_message "Error: Failed to update local /etc/hosts with webhost entry"
    exit 1
fi
