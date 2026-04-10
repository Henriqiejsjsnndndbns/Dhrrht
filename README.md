# ISO Receiver - Sistema de Transferencia de ISO via Celular

Sistema bootavel para pendrive USB que permite receber arquivos ISO do celular via cabo USB e instalar no notebook.

## Como Funciona

1. **Boot pelo Pendrive**: O notebook inicia pelo pendrive com um sistema Linux minimo (~28MB)
2. **Conexao do Celular**: O sistema detecta automaticamente o celular conectado via cabo USB
3. **Transferencia**: Voce seleciona a ISO no celular e o sistema transfere para o notebook
4. **Instalacao**: Apos a transferencia, voce pode instalar a ISO no disco do notebook ou iniciar diretamente

## Requisitos

### Para Construir a Imagem
- Linux (Ubuntu, Debian, Fedora, Alpine)
- Acesso root (sudo)
- ~100MB de espaco livre para o build
- Conexao com a internet (para baixar o Alpine Linux)

### Dependencias (instaladas automaticamente)
- `wget`, `tar`, `dd`
- `syslinux` (bootloader)
- `squashfs-tools`
- `dosfstools` (mkfs.vfat)
- `e2fsprogs`
- `cpio`, `gzip`

### Para Usar
- Pendrive USB (minimo 32MB)
- Cabo USB para conectar o celular ao notebook
- Celular com a ISO desejada no armazenamento

## Inicio Rapido

### 1. Construir a Imagem

```bash
git clone https://github.com/Henriqiejsjsnndndbns/Dhrrht.git
cd Dhrrht
sudo bash build.sh
```

Ou usando Make:

```bash
make build
```

A imagem sera gerada em `output/iso-receiver-usb.img` (menos de 30MB).

### 2. Gravar no Pendrive

**Opcao A - Script automatico:**
```bash
sudo bash scripts/write-to-usb.sh
```

**Opcao B - Manualmente com dd:**
```bash
# Identifique o pendrive (ex: /dev/sdb)
lsblk

# Grave a imagem (CUIDADO: substitua /dev/sdX pelo dispositivo correto!)
sudo dd if=output/iso-receiver-usb.img of=/dev/sdX bs=4M status=progress
sync
```

### 3. Usar no Notebook

1. Insira o pendrive no notebook
2. Ligue o notebook e entre no menu de boot (geralmente F12, F2, ou DEL)
3. Selecione o pendrive USB como dispositivo de boot
4. O sistema **ISO Receiver** vai iniciar automaticamente
5. Conecte o celular ao notebook com o cabo USB
6. No celular, selecione **"Transferencia de arquivos"** (MTP)
7. O sistema vai detectar o celular e mostrar os arquivos ISO disponiveis
8. Selecione a ISO desejada
9. Aguarde a transferencia (barra de progresso e tempo estimado serao mostrados)
10. Escolha o que fazer com a ISO (instalar, iniciar, explorar)

## Estrutura do Projeto

```
iso-receiver/
├── build.sh                    # Script principal de build
├── Makefile                    # Atalhos de comandos
├── README.md                   # Este arquivo
├── configs/
│   ├── syslinux.cfg           # Configuracao do bootloader BIOS
│   └── grub.cfg               # Configuracao do bootloader UEFI
├── rootfs/
│   ├── etc/
│   │   └── init.d/
│   │       └── rcS            # Script de inicializacao do sistema
│   └── usr/
│       └── local/
│           └── bin/
│               └── iso-receiver  # Aplicativo principal
├── scripts/
│   ├── write-to-usb.sh        # Script para gravar no pendrive
│   └── test-app.sh            # Script para testar sem boot USB
└── output/                     # (gerado) Imagem USB final
    └── iso-receiver-usb.img
```

## Funcionalidades

### Interface do Sistema

- **Deteccao automatica do celular** via USB (MTP/PTP)
- **Barra de progresso** com porcentagem, velocidade e tempo estimado
- **Listagem de ISOs** encontradas no celular com tamanho
- **Menu interativo** com opcoes claras em portugues

### Opcoes Apos Transferencia

1. **Instalar no disco** - Grava a ISO diretamente no HD/SSD do notebook (com confirmacao de seguranca)
2. **Iniciar sistema** - Usa kexec para iniciar o sistema da ISO sem reiniciar
3. **Explorar ISO** - Monta a ISO e mostra seu conteudo
4. **Transferir outra ISO** - Volta ao inicio para receber outro arquivo

## Teste sem Boot USB

Voce pode testar o aplicativo diretamente no seu sistema:

```bash
# Instale jmtpfs se nao tiver
sudo apt install jmtpfs

# Execute o teste
bash scripts/test-app.sh

# Ou com sudo para funcionalidade completa
sudo bash scripts/test-app.sh
```

## Protocolo MTP (Media Transfer Protocol)

O sistema usa MTP para se comunicar com o celular. Para que funcione:

1. **Android**: Ao conectar o cabo USB, deslize a notificacao e selecione "Transferencia de arquivos (MTP)"
2. **iOS**: iPhones nao suportam MTP nativamente. Use um app de gerenciamento de arquivos que exporte via USB

### Ferramentas MTP Suportadas
- `jmtpfs` (recomendado)
- `simple-mtpfs`
- `gvfs-mtp`

## Solucao de Problemas

### Celular nao detectado
- Verifique se o cabo USB suporta transferencia de dados (nao apenas carregamento)
- No celular, selecione "Transferencia de arquivos" na notificacao USB
- Tente desconectar e reconectar o cabo

### ISO nao encontrada
- Certifique-se de que o arquivo .iso esta na memoria interna ou cartao SD do celular
- O arquivo deve ter a extensao `.iso`

### Erro ao gravar no disco
- Verifique se o disco de destino esta correto
- O disco nao pode estar em uso pelo sistema

## Tamanho do Sistema

O sistema completo no pendrive ocupa menos de **30MB**, incluindo:
- Kernel Linux (~5-8MB comprimido)
- Sistema Alpine Linux minimo (~5MB)
- Ferramentas MTP e utilitarios (~5-8MB)
- Aplicativo ISO Receiver (<1MB)
- Bootloader Syslinux (<1MB)

## Licenca

Este projeto e de uso livre. Use por sua conta e risco.

## Aviso

**CUIDADO**: A opcao "Instalar no disco" apaga TODOS os dados do disco selecionado. Use com cuidado e certifique-se de selecionar o disco correto. Sempre faca backup dos seus dados antes.
