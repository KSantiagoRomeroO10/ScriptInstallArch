#!/usr/bin/env bash
set -euo pipefail

# 1. Mostrar lsblk
echo "Discos disponibles:"
lsblk

# 2. Listar discos excepto el medio de instalación
echo "Detectando discos..."
DISKS=($(lsblk -bndo NAME,TYPE,SIZE | awk '$2=="disk" && $3 > 200*1024*1024*1024 {print "/dev/"$1}' | grep -v "/dev/sr0"))

if [ ${#DISKS[@]} -eq 0 ]; then
  echo "No se encontraron discos."
  exit 1
fi

# Mostrar discos que se van a formatear y pedir confirmación
echo "Se formatearán los siguientes discos: ${DISKS[*]}"
read -p "¿Seguro que quieres continuar? s/N] " -r
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
  echo "Operación cancelada."
  exit 0
fi

# Formatear discos
for i in "${!DISKS[@]}"; do
  DISK="${DISKS[$i]}"
  echo "Procesando disco: $DISK"
  sgdisk --zap-all "$DISK"
  parted -s "$DISK" mklabel gpt

  if [ "$i" -eq 0 ]; then
    parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
    parted -s "$DISK" set 1 boot on
    parted -s "$DISK" mkpart primary 513MiB 100%
  else
    parted -s "$DISK" mkpart primary 1MiB 100%
  fi
done

# Configurar lvm.conf
echo "Modificando /etc/lvm/lvm.conf"
if ! sed -n '/^devices {/,/^}/p' /etc/lvm/lvm.conf | grep -q 'allow_mixed_block_sizes'; then
  sed -i '/^devices {/,/^}/ s/^}/    allow_mixed_block_sizes = 1\n}/' /etc/lvm/lvm.conf
fi

# Crear LVM sobre las particiones
PARTITIONS=()
for i in "${!DISKS[@]}"; do
  DISK="${DISKS[$i]}"
  if [ "$i" -eq 0 ]; then
    PART="${DISK}2"
  else
    PART="${DISK}1"
  fi
  PARTITIONS+=("$PART")
done

for p in "${PARTITIONS[@]}"; do
  echo "Creando volumen físico en $p"
  pvcreate "$p"
done

vgcreate vg0 "${PARTITIONS[@]}"

# 6. Crear volúmenes lógicos con tamaños específicos
lvcreate -L 50G vg0 -n root
lvcreate -L 20G vg0 -n var
lvcreate -L 30G vg0 -n opt
lvcreate -L 32G vg0 -n swap
lvcreate -l 100%FREE vg0 -n home

# 7. Mostrar lista de volúmenes
echo "Volúmenes lógicos creados:"
lvs

# 8. Ejecutar comandos finales
modprobe dm_mod
vgscan
vgchange -ay

# Formatear volúmenes
mkfs.ext4 /dev/vg0/root
mkfs.ext4 /dev/vg0/var
mkfs.ext4 /dev/vg0/opt
mkfs.ext4 /dev/vg0/home
mkswap /dev/vg0/swap

# Formatear EFI
mkfs.fat -F32 "${DISKS[0]}1"

# Montar puntos
mount /dev/vg0/root /mnt
mkdir /mnt/{boot,boot/efi,var,opt,home}
mount "${DISKS[0]}1" /mnt/boot/efi
mount /dev/vg0/var /mnt/var
mount /dev/vg0/opt /mnt/opt
mount /dev/vg0/home /mnt/home
swapon /dev/vg0/swap

echo "Configuración de discos finalizada."

# 9. Insertar mirrors activos al principio del mirrorlist
echo "Insertando mirrors en /etc/pacman.d/mirrorlist"

sed -i '/^Server/ i\
Server = https://mirrors.atlas.net.co/archlinux/$repo/os/$arch\nServer = https://edgeuno-bog2.mm.fcix.net/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist

cat /etc/pacman.d/mirrorlist

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

# Desmontar todos los sistemas de archivos
umount -R /mnt

# Desactivar swap
swapoff /dev/vg0/swap

# Reiniciar
reboot now
