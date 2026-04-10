# ISO Receiver - Makefile
# Sistema bootavel para receber ISOs do celular via USB

.PHONY: all build write test clean help

all: build

# Build the bootable USB image
build:
	@echo "Construindo imagem USB bootavel..."
	sudo bash build.sh

# Write image to USB drive
write:
	@echo "Gravando imagem no pendrive..."
	sudo bash scripts/write-to-usb.sh

# Test the application without booting
test:
	@bash scripts/test-app.sh

# Clean build artifacts
clean:
	@echo "Limpando arquivos de build..."
	rm -rf build/ output/
	@echo "Limpo!"

# Show help
help:
	@echo ""
	@echo "ISO Receiver - Sistema de Transferencia de ISO via Celular"
	@echo ""
	@echo "Comandos disponiveis:"
	@echo "  make build  - Constroi a imagem USB bootavel"
	@echo "  make write  - Grava a imagem no pendrive"
	@echo "  make test   - Testa o aplicativo sem boot USB"
	@echo "  make clean  - Limpa arquivos de build"
	@echo "  make help   - Mostra esta ajuda"
	@echo ""
