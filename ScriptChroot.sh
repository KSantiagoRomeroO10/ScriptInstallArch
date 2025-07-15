
# 13. Instalar paquetes adicionales
pacman -Syyu --noconfirm grub efibootmgr cryptsetup lvm2 e2fsprogs git networkmanager nvidia nvidia-utils nvidia-settings iwd fastfetch

# 14. Mostrar el contenido de /etc/fstab
cat /etc/fstab

# 15. Editar HOOKS en mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block lvm2 filesystems fsck)/' /etc/mkinitcpio.conf

# 16. Regenerar initramfs
mkinitcpio -p linux

# 17. Instalar GRUB en modo EFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="ArchPingu" --recheck

# 18. Generar archivo de configuración de GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# 19. Establecer zona horaria
ln -sf /usr/share/zoneinfo/America/Bogota /etc/localtime
hwclock --systohc

# 20. Establecer el idioma y la región
sed -i '/^#es_CO.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen

# Layout de teclado de la Consola virtual 
echo "KEYMAP=dvorak-la" > /etc/vconsole.conf

# Host y Host name configuration
echo "ArchPingu" > /etc/hostname

cat > /etc/hosts <<EOF
127.0.0.1    localhost
::1          localhost
127.0.0.1    lh.santiagoromero.dev
127.0.0.1    ArchPingu.localdomain ArchPingu
EOF

echo "Configurando contraseña de root"
echo "root:161020" | chpasswd

# Crear usuario con home
useradd -m santiago

# Asignar contraseña
echo "santiago:161020" | chpasswd

# Mostrar /home
ls /home

# Agregar al grupo wheel
usermod -aG wheel santiago

# Ver grupos
groups santiago

# Habilitar sudo para wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

exit
