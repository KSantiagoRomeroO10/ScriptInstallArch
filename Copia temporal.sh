
# 9. Insertar mirrors activos al principio del mirrorlist
echo "Insertando mirrors en /etc/pacman.d/mirrorlist"

sed -i '/^Server/ i\
Server = https://mirrors.atlas.net.co/archlinux/$repo/os/$arch\nServer = https://edgeuno-bog2.mm.fcix.net/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist

# 10. Instalar sistema base
pacstrap /mnt base base-devel linux linux-firmware

# 11. Generar fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 12. Chroot al sistema instalado
arch-chroot /mnt

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
