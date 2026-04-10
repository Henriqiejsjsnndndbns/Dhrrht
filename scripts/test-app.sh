#!/bin/bash
# ============================================================
# Test the ISO Receiver application without booting from USB
# Testa o aplicativo ISO Receiver sem precisar dar boot pelo USB
# Useful for development and testing
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "============================================="
echo "  ISO Receiver - Modo de Teste"
echo "============================================="
echo ""
echo "Este script executa o aplicativo diretamente"
echo "no seu sistema para fins de teste."
echo ""
echo "NOTA: Algumas funcoes (como kexec e gravar"
echo "em disco) estao desabilitadas no modo teste."
echo ""

# Check if running as root (needed for MTP/mount operations)
if [ "$(id -u)" -ne 0 ]; then
    echo "AVISO: Sem privilegios root, algumas funcoes serao limitadas."
    echo "Para funcionalidade completa: sudo bash $0"
    echo ""
fi

# Check for MTP tools
if command -v jmtpfs >/dev/null 2>&1; then
    echo "[OK] jmtpfs disponivel"
elif command -v simple-mtpfs >/dev/null 2>&1; then
    echo "[OK] simple-mtpfs disponivel"
else
    echo "[!!] Nenhuma ferramenta MTP encontrada."
    echo "     Instale com: sudo apt install jmtpfs"
    echo "     Ou: sudo apt install simple-mtpfs"
fi

echo ""
echo "Pressione ENTER para iniciar..."
read -r

# Run the main application
exec bash "${APP_DIR}/rootfs/usr/local/bin/iso-receiver"
