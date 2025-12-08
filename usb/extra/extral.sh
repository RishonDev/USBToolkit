#Build a script that installs drivers for all linux distros that installs btrfs, (ext1,2,3,4), swap,exfat, fat32, NTFS, APFS, and HFS+
#!/usr/bin/env bash
set -euo pipefail

###########################################
#  NON-INTERACTIVE FS DRIVER INSTALLER
#  For USB creation tools
###########################################

# APFS install mode: none, fuse, source, rw
APFS_INSTALL="${APFS_INSTALL:-none}"
# need_root() {
#   [[ $EUID -ne 0 ]] && { echo "Run as root."; exit 1; }
# }

detect_pm() {
  for pm in apt dnf yum pacman zypper apk; do
    command -v "$pm" >/dev/null 2>&1 && { echo "$pm"; return; }
  done
  echo "unknown"
}

enable_repos() {
  case "$1" in
    apt)
      add-apt-repository -y universe || true
      add-apt-repository -y multiverse || true
      sed -i 's/^# deb/deb/g' /etc/apt/sources.list || true
      apt update -y || true
      ;;
    dnf|yum)
      if ! rpm -qa | grep -qi epel-release; then
        $1 install -y epel-release || true
      fi
      ;;
  esac
}

install_pkgs() {
  pm="$1"; shift
  pkgs=("$@")

  case "$pm" in
    apt) apt install -y "${pkgs[@]}" ;;
    dnf) dnf install -y "${pkgs[@]}" ;;
    yum) yum install -y "${pkgs[@]}" ;;
    pacman) pacman -Sy --noconfirm "${pkgs[@]}" ;;
    zypper) zypper -n install "${pkgs[@]}" ;;
    apk) apk add "${pkgs[@]}" ;;
  esac
}

install_apfs() {
  case "$APFS_INSTALL" in
    none)
      return
      ;;
    fuse)
      echo "[+] Installing APFS FUSE (read-only)..."
      git clone --depth=1 https://github.com/sgan81/apfs-fuse /tmp/apfs-fuse
      cd /tmp/apfs-fuse
      make -j"$(nproc)"
      make install
      ;;
    source)
      echo "[+] Building libfsapfs + apfs-fuse..."
      apt install -y git build-essential pkg-config fuse3 libfuse3-dev || true
      git clone --recursive https://github.com/libyal/libfsapfs /tmp/libfsapfs
      cd /tmp/libfsapfs
      ./synclibs.sh
      ./autogen.sh
      ./configure
      make -j"$(nproc)"
      make install
      ldconfig
      ;;
    rw)
      echo "[!] Installing experimental APFS RW kernel module (unsafe)..."
      apt install -y git build-essential linux-headers-$(uname -r) || true
      git clone https://github.com/linux-apfs/linux-apfs-rw /tmp/apfs-rw
      cd /tmp/apfs-rw
      make -j"$(nproc)"
      make install
      depmod -a
      ;;
  esac
}

postcheck() {
  echo "--- Installed tools ---"
  for f in mkfs.btrfs mkfs.ext4 mkfs.exfat mkfs.vfat ntfs-3g mkswap mkfs.hfs mkfs.hfsplus; do
    command -v "$f" >/dev/null && echo "OK: $f" || echo "MISSING: $f"
  done
}

###############################################
#                 MAIN
###############################################

need_root

pm=$(detect_pm)
[[ "$pm" == "unknown" ]] && { echo "Unsupported distro."; exit 1; }

echo "[+] Package manager detected: $pm"
enable_repos "$pm"

# Map packages
case "$pm" in
  apt)
    pkgs=(btrfs-progs e2fsprogs util-linux exfatprogs dosfstools ntfs-3g hfsprogs)
    ;;
  dnf|yum)
    pkgs=(btrfs-progs e2fsprogs util-linux exfat-utils dosfstools ntfs-3g hfsplus-tools)
    ;;
  pacman)
    pkgs=(btrfs-progs e2fsprogs util-linux exfatprogs dosfstools ntfs-3g hfsprogs)
    ;;
  zypper)
    pkgs=(btrfsprogs e2fsprogs util-linux exfatprogs dosfstools ntfs-3g hfsprogs)
    ;;
  apk)
    pkgs=(btrfs-progs e2fsprogs util-linux exfat-utils dosfstools ntfs-3g hfsprogs)
    ;;
esac

echo "[+] Installing filesystem support packages..."
install_pkgs "$pm" "${pkgs[@]}"

echo "[+] Installing APFS mode: $APFS_INSTALL"
install_apfs

postcheck

echo "[✔] Filesystem driver installation complete."
