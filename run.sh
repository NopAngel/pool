#!/bin/bash


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color


FILES_CLEANED=0
COMMANDS_EXECUTED=0
START_TIME=$(date +%s)

detect_distro() {
    echo -e "${BLUE}🔍 Detect your distro...${NC}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$NAME
        VERSION=$VERSION_ID
        ID=$ID

    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=$DISTRIB_ID
        VERSION=$DISTRIB_RELEASE
        ID=${DISTRIB_ID,,}

    elif [ -f /etc/debian_version ]; then
        DISTRO="Debian"
        VERSION=$(cat /etc/debian_version)
        ID="debian"

    elif [ -f /etc/redhat-release ]; then
        DISTRO=$(cat /etc/redhat-release | awk '{print $1}')
        VERSION=$(cat /etc/redhat-release | awk '{print $3}')
        ID="rhel"

    elif [ -f /etc/arch-release ]; then
        DISTRO="Arch Linux"
        VERSION="rolling"
        ID="arch"

    else
        DISTRO="Unknown"
        VERSION="?"
        ID="unknown"
    fi

    echo -e "${GREEN}✅ Distribution: $DISTRO $VERSION ($ID)${NC}"


    detect_package_manager
}

detect_package_manager() {
    if command -v apt &> /dev/null; then
        GESTOR="apt"
        echo -e "${GREEN}📦 Package manager: APT (Debian/Ubuntu)${NC}"

    elif command -v dnf &> /dev/null; then
        GESTOR="dnf"
        echo -e "${GREEN}📦 Package manager: DNF (Fedora/RHEL)${NC}"

    elif command -v yum &> /dev/null; then
        GESTOR="yum"
        echo -e "${GREEN}📦 Package manager: YUM (RHEL/CentOS)${NC}"

    elif command -v pacman &> /dev/null; then
        GESTOR="pacman"
        echo -e "${GREEN}📦 Package manager: Pacman (Arch)${NC}"

    elif command -v zypper &> /dev/null; then
        GESTOR="zypper"
        echo -e "${GREEN}📦 Package manager: Zypper (openSUSE)${NC}"

    else
        GESTOR="desconocido"
        echo -e "${RED}⚠️  Package Manager not found.${NC}"
    fi
}

optimize_debian() {
    echo -e "${BLUE}🔄 Optimizing Debian-based systems...${NC}"

    ((COMMANDS_EXECUTED++))
    sudo apt update

    ((COMMANDS_EXECUTED++))
    sudo apt upgrade -y

    ((COMMANDS_EXECUTED++))
    sudo apt autoremove --purge -y

    ((COMMANDS_EXECUTED++))
    sudo apt clean

    ((COMMANDS_EXECUTED++))
    sudo apt autoclean

    if command -v purge-old-kernels &> /dev/null; then
        ((COMMANDS_EXECUTED++))
        sudo purge-old-kernels
    fi


    CACHE_COUNT=$(find /var/cache/apt -type f 2>/dev/null | wc -l)
    ((FILES_CLEANED+=CACHE_COUNT))
}

optimize_fedora() {
    echo -e "${BLUE}🔄 Optimizing Fedora/RHEL-based systems...${NC}"

    if [ "$GESTOR" = "dnf" ]; then
        ((COMMANDS_EXECUTED++))
        sudo dnf upgrade --refresh -y

        ((COMMANDS_EXECUTED++))
        sudo dnf autoremove -y

        ((COMMANDS_EXECUTED++))
        sudo dnf clean all

        CACHE_COUNT=$(find /var/cache/dnf -type f 2>/dev/null | wc -l)
        ((FILES_CLEANED+=CACHE_COUNT))
    else
        ((COMMANDS_EXECUTED++))
        sudo yum update -y

        ((COMMANDS_EXECUTED++))
        sudo yum autoremove -y

        ((COMMANDS_EXECUTED++))
        sudo yum clean all
    fi
}

optimize_arch() {
    echo -e "${BLUE}🔄 Optimizing Arch Linux...${NC}"

    ((COMMANDS_EXECUTED++))
    sudo pacman -Syu --noconfirm

    ((COMMANDS_EXECUTED++))
    sudo pacman -Sc --noconfirm

    ((COMMANDS_EXECUTED++))
    sudo pacman -Qtdq | sudo pacman -Rns - --noconfirm 2>/dev/null || true

    if command -v paccache &> /dev/null; then
        ((COMMANDS_EXECUTED++))
        sudo paccache -rk 3

        CACHE_COUNT=$(sudo paccache -ruk0 2>/dev/null | grep -c "removed")
        ((FILES_CLEANED+=CACHE_COUNT))
    fi
}

optimize_opensuse() {
    echo -e "${BLUE}🔄 Optimizing openSUSE...${NC}"

    ((COMMANDS_EXECUTED++))
    sudo zypper refresh

    ((COMMANDS_EXECUTED++))
    sudo zypper update -y

    ((COMMANDS_EXECUTED++))
    sudo zypper clean -a
}

generic_clean() {
    echo -e "${BLUE}🧹 Performing generic cleanup...${NC}"


    if [ -d ~/.cache ]; then
        CACHE_COUNT=$(find ~/.cache -type f | wc -l)
        ((FILES_CLEANED+=CACHE_COUNT))
        ((COMMANDS_EXECUTED++))
        rm -rf ~/.cache/* 2>/dev/null
    fi

    if [ -d ~/.thumbnails ]; then
        THUMB_COUNT=$(find ~/.thumbnails -type f | wc -l)
        ((FILES_CLEANED+=THUMB_COUNT))
        ((COMMANDS_EXECUTED++))
        rm -rf ~/.thumbnails/* 2>/dev/null
    fi

    if command -v journalctl &> /dev/null; then
        ((COMMANDS_EXECUTED++))
        sudo journalctl --vacuum-time=3d
    fi

    LOG_COUNT=$(find /var/log -name "*.log" -type f 2>/dev/null | wc -l)
    ((FILES_CLEANED+=LOG_COUNT))
    ((COMMANDS_EXECUTED++))
    sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null
}

optimize_distro() {
    case $ID in
        ubuntu|debian|linuxmint|pop)
            optimize_debian
            generic_clean
            ;;
        fedora|rhel|centos|almalinux|rocky)
            optimize_fedora
            generic_clean
            ;;
        arch|manjaro|endeavouros)
            optimize_arch
            generic_clean
            ;;
        opensuse*|suse)
            optimize_opensuse
            generic_clean
            ;;
        *)
            echo -e "${YELLOW}⚠️ Distro not specifically supported, using generic cleanup${NC}"
            generic_clean
            ;;
    esac
}

show_summary() {
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo -e "\n${PURPLE}========== CLEAN UP SUMMARY ==========${NC}"
    echo -e "${CYAN}Files cleaned:${NC} ${GREEN}$FILES_CLEANED${NC}"
    echo -e "${CYAN}Commands executed:${NC} ${GREEN}$COMMANDS_EXECUTED${NC}"
    echo -e "${CYAN}Time elapsed:${NC} ${GREEN}${DURATION}s${NC}"
    echo -e "${CYAN}Distribution:${NC} ${GREEN}$DISTRO $VERSION${NC}"
    echo -e "${CYAN}Package manager:${NC} ${GREEN}$GESTOR${NC}"
    echo -e "${PURPLE}=======================================${NC}\n"


    if command -v df &> /dev/null; then
        echo -e "${YELLOW}💾 Disk space overview:${NC}"
        df -h / | tail -1
    fi
}

main() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
     ____   ____   ____ __
    |  _ \ / __ \ / __ \| |
    | |_) | |  | | |  | | |
    |  __/| |__| | |__| | |__
    |_|    \____/ \____/ |___|

      Linux Optimizer v1.0
EOF
    echo -e "${NC}"

    detect_distro

    echo -e "\n${YELLOW}Do you want to proceed with the optimization? (y/n)${NC}"
    read -r res

    if [[ "$res" =~ ^[SsYy]$ ]]; then
        optimize_distro
        show_summary
        echo -e "\n${GREEN}✅ Optimization completed successfully!${NC}"

    else
        echo -e "\n${RED}❌ Operation cancelled${NC}"
    fi
}

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    main
fi
