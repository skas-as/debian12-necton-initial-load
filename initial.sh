#!/bin/bash

LOG_FILE="/tmp/deploy-necton.log"
exec > >(tee -a "$LOG_FILE") 2>&1

GRUB_FILE="/etc/default/grub"
CERT_URL="https://raw.githubusercontent.com/skas-as/debian12-necton-inital-load/main/necton-WIN-CA01-RootCA-pem.crt"
CERT_NAME="necton-WIN-CA01-RootCA-pem.crt"
CERT_DEST="/usr/local/share/ca-certificates/$CERT_NAME"
AD_DOMAIN="necton.internal"
AD_ACCOUNT="goncalo.prata"
ADMIN_GROUP="linux-admins"
SSSD_FILE="/etc/sssd/sssd.conf"
SUDOERS_FILE="/etc/sudoers.d/$ADMIN_GROUP"

update_grub() {
  echo "### Updating GRUB..."
  # sanity backup
  cp "$GRUB_FILE" "$GRUB_FILE.bak"
  # replace line
  sed -i 's/^GRUB_CMDLINE_LINUX=".*"/GRUB_CMDLINE_LINUX="quiet console=tty0 console=ttyS0,115200"/' "$GRUB_FILE"
  update-grub
  echo "### GRUB_CMDLINE_LINUX updated successfully!"
}

install_cert() {
  echo "### Downloading certificate from $CERT_URL..."
  if wget -q -O "$CERT_DEST" "$CERT_URL"; then
    chmod 644 "$CERT_DEST"
    chown root:root "$CERT_DEST"
    echo "### Updating trusted certificates..."
    update-ca-certificates
    echo "### Certificate $CERT_NAME installed successfully."
  else
    echo "### ERROR: Failed to download certificate from $CERT_URL"
  fi
}

join_domain() {
  install_cert
  echo "### Joining domain..."
  # installing necessary packages
  apt install adcli packagekit samba-common-bin sudo -y
  apt install realmd -y
  # testing ad discovery
  realm -v discover "$AD_DOMAIN"
  # joining ad
  realm -v join "$AD_DOMAIN" -U "$AD_ACCOUNT"
  # sanity backup
  cp "$SSSD_FILE" "$SSSD_FILE.bak"
  # replace line
  sed -i 's/^fallback_homedir *=.*/override_homedir = \/home\/%u@%d/' "$SSSD_FILE"
  # add lines
  grep -q '^ad_access_filter *= ' "$SSSD_FILE" || echo "ad_access_filter = FOREST:NECTON.INTERNAL:(memberOf=CN=$ADMIN_GROUP,CN=Users,DC=necton,DC=internal)" >> "$SSSD_FILE"
  grep -q '^ad_gpo_access_control *= ' "$SSSD_FILE" || echo "ad_gpo_access_control = disabled" >> "$SSSD_FILE"
  systemctl restart sssd
  # enable auto home creation
  pam-auth-update
  # visudo
  if [[ -f "$SUDOERS_FILE" ]]; then
    echo "### Sudoers file $SUDOERS_FILE already exists. Skipping creation."
  else
    # insert after sudo group
    cat <<EOF > "$SUDOERS_FILE"
# Allow members of group $ADMIN_GROUP on domain $AD_DOMAIN
# to execute any command
%$ADMIN_GROUP@$AD_DOMAIN ALL=(ALL:ALL) ALL
EOF
    # change permissions
    chmod 440 "$SUDOERS_FILE"
    # check syntax
    if visudo -c -f "$SUDOERS_FILE"; then
      echo "### Valid sudoers file!"
    else
      echo "Syntax error on sudoers file! reverting..."
      rm "$SUDOERS_FILE"
    fi
  fi
}

execute_all() {
  echo "### Executing everything..."
  update_grub
  join_domain
}

###########################################################################################
echo "###########################"
echo "# Debian 12 Deploy Script #"
echo "###########################"
PS3="### Choose an option (or 0 to quit): "
options=("Update GRUB for xterm.js" "Join $AD_DOMAIN domain" "Execute all of the above" "Quit")

select opt in "${options[@]}"
do
  case $REPLY in
    1) update_grub ;;
    2) join_domain ;;
    3) execute_all ;;
    4|0) echo "Exiting..."; break ;;
    *) echo "Invalid option."; ;;
  esac
done
