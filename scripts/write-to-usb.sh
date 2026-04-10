#!/bin/bash
# ============================================================
# Write ISO Receiver image to USB drive
# Script auxiliar para gravar a imagem no pendrive
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

IMG_FILE="output/iso-receiver-usb.img"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Execute como root: sudo bash $0${NC}"
    exit 1
fi

if [ ! -f "$IMG_FILE" ]; then
    echo -e "${RED}Imagem nao encontrada: $IMG_FILE${NC}"
    echo -e "${YELLOW}Execute primeiro: sudo bash build.sh${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${WHITE}  ISO Receiver - Gravacao no Pendrive            ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""

# List available USB devices
echo -e "${WHITE}Dispositivos USB disponiveis:${NC}"
echo ""

lsblk -d -n -o NAME,SIZE,MODEL,TRAN 2>/dev/null | grep "usb" | while read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    model=$(echo "$line" | awk '{$1=""; $2=""; $NF=""; print $0}' | sed 's/^ *//' | sed 's/ *$//')
    echo -e "  ${CYAN}/dev/$name${NC} - ${WHITE}$size${NC} $model"
done

echo ""

# If no USB found, show all removable
if ! lsblk -d -n -o TRAN 2>/dev/null | grep -q "usb"; then
    echo -e "${YELLOW}Nenhum dispositivo USB detectado. Mostrando todos os discos:${NC}"
    echo ""
    lsblk -d -n -o NAME,SIZE,MODEL 2>/dev/null | grep -v "loop\|sr\|ram" | while read -r line; do
        echo -e "  ${WHITE}$line${NC}"
    done
    echo ""
fi

echo -e "${WHITE}Digite o dispositivo do pendrive (ex: /dev/sdb): ${NC}"
read -r USB_DEV

if [ -z "$USB_DEV" ]; then
    echo -e "${RED}Nenhum dispositivo informado.${NC}"
    exit 1
fi

if [ ! -b "$USB_DEV" ]; then
    echo -e "${RED}Dispositivo invalido: $USB_DEV${NC}"
    exit 1
fi

# Safety check - don't write to system disk
SYSTEM_DISK=$(mount | grep ' / ' | awk '{print $1}' | sed 's/p\?[0-9]*$//')
if [ "$USB_DEV" = "$SYSTEM_DISK" ]; then
    echo -e "${RED}ERRO: Este e o disco do sistema! Operacao cancelada.${NC}"
    exit 1
fi

# Show device info
echo ""
echo -e "${WHITE}Dispositivo selecionado:${NC}"
lsblk "$USB_DEV" 2>/dev/null
echo ""

echo -e "${RED}ATENCAO: Todos os dados em $USB_DEV serao APAGADOS!${NC}"
echo -e "${WHITE}Digite 'SIM' para confirmar: ${NC}"
read -r confirm

if [ "$confirm" != "SIM" ]; then
    echo -e "${YELLOW}Operacao cancelada.${NC}"
    exit 0
fi

# Unmount any mounted partitions
umount "${USB_DEV}"* 2>/dev/null || true

echo ""
echo -e "${YELLOW}Gravando imagem no pendrive...${NC}"
echo ""

# Write image with progress
dd if="$IMG_FILE" of="$USB_DEV" bs=4M status=progress conv=fsync

echo ""
sync

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Gravacao concluida com sucesso!             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${WHITE}Agora voce pode:${NC}"
echo -e "  1. Remover o pendrive com seguranca"
echo -e "  2. Conectar no notebook"
echo -e "  3. Configurar o BIOS para boot via USB"
echo -e "  4. Iniciar o notebook pelo pendrive"
echo ""
