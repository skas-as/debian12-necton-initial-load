#!/bin/bash

GRUB_FILE="/etc/default/grub"
AD_DOMAIN="necton.internal"
AD_ACCOUNT="goncalo.prata"

update_grub() {
  echo "### Updating GRUB..."
  # sanity backup
  cp "$GRUB_FILE" "$GRUB_FILE.bak"
  # replace line
  sed -i 's/^GRUB_CMDLINE_LINUX=".*"/GRUB_CMDLINE_LINUX="quiet console=tty0 console=ttyS0,115200"/' "$GRUB_FILE"
  update-grub
  echo "### GRUB_CMDLINE_LINUX updated successfully!"
}

join_domain() {
  echo "### Joining domain..."
  # installing necessary packages
  apt install adcli packagekit samba-common-bin sudo -y
  apt install realmd -y
  # testing ad discovery
  realm -v discover $AD_DOMAIN
  # joining ad
  realm -v join $AD_DOMAIN -U $AD_ACCOUNT
  # TODO
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
