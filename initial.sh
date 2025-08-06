#!/bin/bash

GRUB_FILE="/etc/default/grub"

# Backup de segurança
cp "$GRUB_FILE" "$GRUB_FILE.bak"
# Substituição da linha
sed -i 's/^GRUB_CMDLINE_LINUX=".*"/GRUB_CMDLINE_LINUX="quiet console=tty0 console=ttyS0,115200"/' "$GRUB_FILE"
update-grub
# Confirmar alteração
echo "GRUB_CMDLINE_LINUX updated successfully!"
