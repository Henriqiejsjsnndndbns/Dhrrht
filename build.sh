#!/bin/bash
# ============================================================
# ISO Receiver - Build Script
# Cria uma imagem USB bootavel com o sistema ISO Receiver
# Baseado em Alpine Linux para manter o tamanho < 30MB
# ============================================================

set -e

# Configuration
ALPINE_VERSION="3.19"
ALPINE_ARCH="x86_64"
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"
ALPINE_MINIROOTFS_URL="${ALPINE_MIRROR}/v${ALPINE_VERSION}/releases/${ALPINE_ARCH}/alpine-minirootfs-${ALPINE_VERSION}.0-${ALPINE_ARCH}.tar.gz"

BUILD_DIR="$(pwd)/build"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
OUTPUT_DIR="$(pwd)/output"
IMG_FILE="${OUTPUT_DIR}/iso-receiver-usb.img"
IMG_SIZE_MB=28  # Under 30MB limit

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Este script precisa ser executado como root (sudo)."
        echo "  Uso: sudo bash build.sh"
        exit 1
    fi
}

check_deps() {
    log_step "Verificando dependencias..."
    local missing=""

    for cmd in wget tar dd mkfs.vfat parted losetup syslinux cpio gzip; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done

    if [ -n "$missing" ]; then
        log_warn "Dependencias faltando:$missing"
        log_info "Instalando dependencias..."

        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq
            apt-get install -y -qq wget tar syslinux syslinux-utils \
                parted dosfstools e2fsprogs kmod cpio gzip
        elif command -v apk >/dev/null 2>&1; then
            apk add wget tar syslinux parted dosfstools \
                e2fsprogs kmod cpio gzip
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y wget tar syslinux parted dosfstools \
                e2fsprogs kmod cpio gzip
        else
            log_error "Gerenciador de pacotes nao reconhecido. Instale manualmente: $missing"
            exit 1
        fi
    fi

    log_info "Dependencias OK."
}

prepare_dirs() {
    log_step "Preparando diretorios..."
    rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR" "$OUTPUT_DIR"
    mkdir -p "${ROOTFS_DIR}"/{bin,sbin,usr/bin,usr/sbin,usr/local/bin}
    mkdir -p "${ROOTFS_DIR}"/{etc/init.d,proc,sys,dev,tmp,run,mnt}
    mkdir -p "${ROOTFS_DIR}"/{boot,lib/modules}
}

download_alpine() {
    log_step "Baixando Alpine Linux minirootfs..."
    local tarball="${BUILD_DIR}/alpine-minirootfs.tar.gz"

    if [ ! -f "$tarball" ]; then
        wget -q --show-progress -O "$tarball" "$ALPINE_MINIROOTFS_URL"
    else
        log_info "Usando cache existente."
    fi

    log_info "Extraindo rootfs..."
    tar xzf "$tarball" -C "$ROOTFS_DIR"
}

install_packages() {
    log_step "Instalando pacotes no rootfs (MTP, FUSE, utils)..."

    # Set up Alpine repos inside chroot
    mkdir -p "${ROOTFS_DIR}/etc/apk"
    echo "${ALPINE_MIRROR}/v${ALPINE_VERSION}/main" > "${ROOTFS_DIR}/etc/apk/repositories"
    echo "${ALPINE_MIRROR}/v${ALPINE_VERSION}/community" >> "${ROOTFS_DIR}/etc/apk/repositories"

    # Copy resolv.conf for DNS
    cp /etc/resolv.conf "${ROOTFS_DIR}/etc/resolv.conf" 2>/dev/null || true

    # Install packages via chroot
    if command -v chroot >/dev/null 2>&1; then
        mount -t proc proc "${ROOTFS_DIR}/proc" 2>/dev/null || true
        mount -t sysfs sysfs "${ROOTFS_DIR}/sys" 2>/dev/null || true
        mount --bind /dev "${ROOTFS_DIR}/dev" 2>/dev/null || true

        chroot "$ROOTFS_DIR" /bin/sh -c "
            apk update --quiet
            apk add --quiet --no-cache \
                bash \
                busybox \
                busybox-extras \
                fuse \
                fuse-common \
                jmtpfs \
                util-linux \
                lsblk \
                usbutils \
                kexec-tools \
                dialog \
                ncurses \
                coreutils \
                findutils \
                grep \
                sed \
                gawk \
                wget \
                curl
        " 2>/dev/null || log_warn "Alguns pacotes podem nao ter sido instalados."

        umount "${ROOTFS_DIR}/proc" 2>/dev/null || true
        umount "${ROOTFS_DIR}/sys" 2>/dev/null || true
        umount "${ROOTFS_DIR}/dev" 2>/dev/null || true
    else
        log_warn "chroot nao disponivel. Rootfs tera funcionalidade limitada."
    fi
}

copy_custom_files() {
    log_step "Copiando arquivos customizados..."

    # Copy init script
    cp "rootfs/etc/init.d/rcS" "${ROOTFS_DIR}/etc/init.d/rcS"
    chmod +x "${ROOTFS_DIR}/etc/init.d/rcS"

    # Copy main application
    cp "rootfs/usr/local/bin/iso-receiver" "${ROOTFS_DIR}/usr/local/bin/iso-receiver"
    chmod +x "${ROOTFS_DIR}/usr/local/bin/iso-receiver"

    # Create /init symlink for initramfs
    cat > "${ROOTFS_DIR}/init" << 'INITEOF'
#!/bin/sh
exec /etc/init.d/rcS
INITEOF
    chmod +x "${ROOTFS_DIR}/init"

    # Set up inittab
    cat > "${ROOTFS_DIR}/etc/inittab" << 'EOF'
::sysinit:/etc/init.d/rcS
::respawn:/usr/local/bin/iso-receiver
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
EOF

    # Create /etc/fstab
    cat > "${ROOTFS_DIR}/etc/fstab" << 'EOF'
proc    /proc   proc    defaults    0   0
sysfs   /sys    sysfs   defaults    0   0
tmpfs   /tmp    tmpfs   defaults    0   0
tmpfs   /run    tmpfs   defaults    0   0
EOF

    # Set hostname
    echo "iso-receiver" > "${ROOTFS_DIR}/etc/hostname"

    # Create passwd/group for root
    echo "root:x:0:0:root:/root:/bin/sh" > "${ROOTFS_DIR}/etc/passwd"
    echo "root:x:0:" > "${ROOTFS_DIR}/etc/group"
}

copy_kernel() {
    log_step "Copiando kernel do sistema host..."

    local kernel_version=$(uname -r)
    local kernel_src="/boot/vmlinuz-${kernel_version}"

    if [ -f "$kernel_src" ]; then
        cp "$kernel_src" "${ROOTFS_DIR}/boot/vmlinuz"
        log_info "Kernel copiado: $kernel_version"
    elif [ -f "/boot/vmlinuz" ]; then
        cp "/boot/vmlinuz" "${ROOTFS_DIR}/boot/vmlinuz"
        log_info "Kernel copiado: vmlinuz"
    else
        log_warn "Kernel nao encontrado. Voce precisara adicionar manualmente."
        log_warn "Copie seu vmlinuz para output/boot/vmlinuz"
    fi

    # Copy modules if available
    if [ -d "/lib/modules/${kernel_version}" ]; then
        mkdir -p "${ROOTFS_DIR}/lib/modules/"
        cp -a "/lib/modules/${kernel_version}" "${ROOTFS_DIR}/lib/modules/" 2>/dev/null || true
        # Only copy essential modules to save space
        log_info "Modulos do kernel copiados."
    fi
}

create_initramfs() {
    log_step "Criando initramfs..."

    cd "$ROOTFS_DIR"
    find . | cpio -o -H newc 2>/dev/null | gzip -9 > "${BUILD_DIR}/initramfs.img"
    cd - >/dev/null

    cp "${BUILD_DIR}/initramfs.img" "${ROOTFS_DIR}/boot/initramfs.img"
    log_info "Initramfs criado: $(du -sh "${BUILD_DIR}/initramfs.img" | awk '{print $1}')"
}

create_usb_image() {
    log_step "Criando imagem USB bootavel (${IMG_SIZE_MB}MB)..."

    # Create empty image
    dd if=/dev/zero of="$IMG_FILE" bs=1M count=$IMG_SIZE_MB status=none

    # Create partition table and partition
    parted -s "$IMG_FILE" mklabel msdos
    parted -s "$IMG_FILE" mkpart primary fat32 1MiB 100%
    parted -s "$IMG_FILE" set 1 boot on

    # Set up loop device
    local loop_dev
    loop_dev=$(losetup --find --show --partscan "$IMG_FILE")
    local part_dev="${loop_dev}p1"

    # Trap to cleanup loop device and mount on failure
    local mnt_dir="${BUILD_DIR}/mnt"
    cleanup_usb_image() {
        umount "$mnt_dir" 2>/dev/null || true
        losetup -d "$loop_dev" 2>/dev/null || true
    }
    trap cleanup_usb_image EXIT ERR

    # Wait for partition device
    sleep 1
    if [ ! -b "$part_dev" ]; then
        partprobe "$loop_dev" 2>/dev/null || true
        sleep 1
    fi

    # Format partition as FAT32
    mkfs.vfat -F 32 "$part_dev"

    # Mount and copy files
    mkdir -p "$mnt_dir"
    mount "$part_dev" "$mnt_dir"

    # Install syslinux bootloader
    mkdir -p "${mnt_dir}/boot/syslinux"
    cp configs/syslinux.cfg "${mnt_dir}/boot/syslinux/syslinux.cfg"

    # Copy syslinux files
    local syslinux_dir=""
    for dir in /usr/lib/syslinux /usr/lib/syslinux/bios /usr/share/syslinux /usr/lib/SYSLINUX; do
        if [ -d "$dir" ]; then
            syslinux_dir="$dir"
            break
        fi
    done

    if [ -n "$syslinux_dir" ]; then
        cp "${syslinux_dir}/ldlinux.sys" "${mnt_dir}/boot/syslinux/" 2>/dev/null || true
        cp "${syslinux_dir}/ldlinux.c32" "${mnt_dir}/boot/syslinux/" 2>/dev/null || true
        cp "${syslinux_dir}/libutil.c32" "${mnt_dir}/boot/syslinux/" 2>/dev/null || true
        cp "${syslinux_dir}/menu.c32" "${mnt_dir}/boot/syslinux/" 2>/dev/null || true
        cp "${syslinux_dir}/libcom32.c32" "${mnt_dir}/boot/syslinux/" 2>/dev/null || true
    fi

    # Copy kernel and initramfs
    mkdir -p "${mnt_dir}/boot"
    if [ -f "${ROOTFS_DIR}/boot/vmlinuz" ]; then
        cp "${ROOTFS_DIR}/boot/vmlinuz" "${mnt_dir}/boot/"
    fi
    cp "${BUILD_DIR}/initramfs.img" "${mnt_dir}/boot/"

    # Install syslinux MBR
    if [ -n "$syslinux_dir" ] && [ -f "${syslinux_dir}/mbr.bin" ]; then
        dd if="${syslinux_dir}/mbr.bin" of="$loop_dev" bs=440 count=1 conv=notrunc status=none
    elif [ -f "/usr/lib/syslinux/mbr/mbr.bin" ]; then
        dd if="/usr/lib/syslinux/mbr/mbr.bin" of="$loop_dev" bs=440 count=1 conv=notrunc status=none
    fi

    # Install syslinux on partition
    syslinux --install --directory /boot/syslinux "$part_dev" 2>/dev/null || \
        syslinux -i -d /boot/syslinux "$part_dev" 2>/dev/null || \
        log_warn "Syslinux install pode ter falhado."

    # Show size info
    log_info "Conteudo do USB:"
    du -sh "${mnt_dir}"/* 2>/dev/null | while read -r line; do
        echo "  $line"
    done

    # Cleanup
    umount "$mnt_dir"
    losetup -d "$loop_dev"

    # Clear the trap after successful cleanup
    trap - EXIT ERR

    local final_size=$(du -sh "$IMG_FILE" | awk '{print $1}')
    log_info "Imagem criada: $IMG_FILE ($final_size)"
}

show_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        Build Concluido com Sucesso!                     ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Imagem gerada:${NC} $IMG_FILE"
    echo -e "${WHITE}Tamanho:${NC} $(du -sh "$IMG_FILE" | awk '{print $1}')"
    echo ""
    echo -e "${CYAN}Para gravar no pendrive:${NC}"
    echo ""
    echo -e "  ${WHITE}sudo dd if=$IMG_FILE of=/dev/sdX bs=4M status=progress${NC}"
    echo ""
    echo -e "  ${YELLOW}⚠  Substitua /dev/sdX pelo dispositivo correto do seu pendrive!${NC}"
    echo -e "  ${YELLOW}   Use 'lsblk' para identificar o dispositivo.${NC}"
    echo ""
    echo -e "${CYAN}Para usar:${NC}"
    echo -e "  1. Grave a imagem no pendrive com o comando acima"
    echo -e "  2. Inicie o notebook pelo pendrive (boot USB)"
    echo -e "  3. Conecte o celular via cabo USB"
    echo -e "  4. No celular, ative 'Transferencia de arquivos' (MTP)"
    echo -e "  5. Selecione a ISO desejada e aguarde a transferencia"
    echo ""
}

# ============================================================
# Main Build Process
# ============================================================

main() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  ISO Receiver - Build System                           ${NC}"
    echo -e "${WHITE}  Criando sistema bootavel para pendrive USB            ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo ""

    check_root
    check_deps
    prepare_dirs
    download_alpine
    install_packages
    copy_custom_files
    copy_kernel
    create_initramfs
    create_usb_image
    show_summary
}

main "$@"
