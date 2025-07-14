#!/usr/bin/env bash
set -euo pipefail

# 1. Mostrar lsblk
echo "Discos disponibles:"
lsblk

sleep 2

# 2. Listar discos excepto el medio de instalación
echo "Detectando discos..."
DISKS=($(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}' | grep -v "/dev/sr0"))

if [ ${#DISKS[@]} -eq 0 ]; then
  echo "No se encontraron discos."
  exit 1
fi

# 3. Formatear discos
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

# 4. Crear LVM sobre las particiones
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

# 5. Configurar lvm.conf
echo "Modificando /etc/lvm/lvm.conf"
sed -i 's/^.*\(allow_mixed_block_sizes\).*$/    allow_mixed_block_sizes = 1/' /etc/lvm/lvm.conf

# 6. Crear volúmenes lógicos con tamaños específicos
lvcreate -L 50G vg0 -n root
lvcreate -L 20G vg0 -n var
lvcreate -L 30G vg0 -n opt
lvcreate -L 32G vg0 -n swap
lvcreate -l 100%FREE vg0 -n home

# 7. Mostrar lista de volúmenes
echo "Volúmenes lógicos creados:"
lvs

sleep 2

# 8. Ejecutar comandos finales
modprobe dm_mod
vgscan
vgchange -ay

echo "Configuración de discos finalizada."

sleep 2
