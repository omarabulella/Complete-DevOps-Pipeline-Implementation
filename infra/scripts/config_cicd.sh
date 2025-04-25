#!/bin/bash

# Get EC2 IP from environment variable
PUBLIC_IP="${TF_VAR_cicd_public_ip}"
USER="ubuntu"
PRIVATE_KEY="${TF_VAR_ssh_key_path:-~/.ssh/my-key.pem}"

# Create local inventory file (not on remote server)
INVENTORY_FILE="/tmp/inventory.$$.ini"
echo "[cicd]" > "$INVENTORY_FILE"
echo "${PUBLIC_IP} ansible_user=${USER} ansible_ssh_private_key_file=${PRIVATE_KEY}" >> "$INVENTORY_FILE"

check_vm_ssh() {
  echo "Checking SSH access to ${PUBLIC_IP}..."
  until ssh -i "${PRIVATE_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${USER}@${PUBLIC_IP}" true 2>/dev/null; do
    echo "VM not ready yet. Retrying in 5 seconds..."
    sleep 5
  done
  echo "VM is ready for configuration."
}

# Run the status check
check_vm_ssh

echo "Running Ansible playbook..."
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
  -i "$INVENTORY_FILE" \
  -e "ansible_python_interpreter=/usr/bin/python3" \
  "$HOME/Complete-DevOps-Pipeline/infra/ansible/playbook.yml"

# Clean up
rm -f "$INVENTORY_FILE"