#!/usr/bin/env bash
set -euo pipefail

############################################################
# ZERO-INTERACTION SUDO SYSTEM
############################################################
PASSWORD="${PASSWORD:-}"
if [[ -z "$PASSWORD" ]]; then
    echo "ERROR: PASSWORD variable not set."
    echo "Usage: PASSWORD=\"yourpass\" ./format.sh ..."
    exit 1
fi

sudo_exec() {
    echo "$PASSWORD" | sudo -S "$@"
}
mount_fs() {
    local fs="$1"
    local dev="$2"
    local mp="$3"

    # numeric UID/GID captured at script start
    local uid_val="$INVOKER_UID"
    local gid_val="$INVOKER_GID"

    # ensure mountpoint exists (run as root)
    sudo_exec mkdir -p "$mp"

    case "${fs,,}" in
        swap)
            sudo_exec swapon "$dev"
            echo "Swap enabled on $dev"
            return
            ;;

        apfs)
            if ! command -v apfs-fuse >/dev/null 2>&1; then
                echo "ERROR: apfs-fuse missing."
                exit 1
            fi
            sudo_exec apfs-fuse "$dev" "$mp"
            # try to fix ownership (may be limited by FUSE)
            sudo_exec chown "$uid_val":"$gid_val" "$mp" 2>/dev/null || true
            echo "APFS mounted via FUSE at $mp"
            ;;

        hfs+|hfsplus)
            sudo_exec mount -t hfsplus "$dev" "$mp"
            sudo_exec chown "$uid_val":"$gid_val" "$mp" || true
            sudo_exec chmod 775 "$mp" || true
            echo "HFS+ mounted at $mp (ownership set)"
            ;;

        ntfs)
            if command -v ntfs-3g >/dev/null 2>&1; then
                sudo_exec umount "$mp" 2>/dev/null || true
                sudo_exec ntfs-3g -o uid="$uid_val",gid="$gid_val",umask=0022 "$dev" "$mp"
            else
                sudo_exec mount -t ntfs "$dev" "$mp" 2>/dev/null || sudo_exec mount "$dev" "$mp"
                sudo_exec chown "$uid_val":"$gid_val" "$mp" 2>/dev/null || true
            fi
            echo "NTFS mounted at $mp"
            ;;

        exfat|fat32|vfat|fat)
            sudo_exec umount "$mp" 2>/dev/null || true
            # use numeric uid/gid for vfat/exfat so files are owned by invoking user
            sudo_exec mount -o uid="$uid_val",gid="$gid_val",umask=0022 "$dev" "$mp"
            echo "FAT/exFAT mounted at $mp (uid=$uid_val gid=$gid_val)"
            ;;

        btrfs|ext4|ext3)
            sudo_exec mount "$dev" "$mp"
            # change ownership of the root of the FS to allow the user to write
            sudo_exec chown "$uid_val":"$gid_val" "$mp" || true
            sudo_exec chmod 775 "$mp" || true
            echo "$fs mounted at $mp (owned by invoking user)"
            ;;

        *)
            sudo_exec mount "$dev" "$mp" 2>/dev/null || true
            sudo_exec chown "$uid_val":"$gid_val" "$mp" 2>/dev/null || true
            echo "$dev mounted at $mp"
            ;;
    esac
}
mkfs_with_label() {
    local fs="$1"
    local target="$2"

    case "${fs,,}" in
        ext4) sudo_exec mkfs.ext4 -F -L "$LABEL" "$target" ;;
        ext3) sudo_exec mkfs.ext3 -F -L "$LABEL" "$target" ;;
        btrfs) sudo_exec mkfs.btrfs -f -L "$LABEL" "$target" ;;
        swap) sudo_exec mkswap -L "$LABEL" "$target" ;;

        exfat|exfat*)
            if command -v mkfs.exfat >/dev/null 2>&1; then
                sudo_exec mkfs.exfat -n "$LABEL" "$target"
            else
                sudo_exec mkfs.exfat.py -n "$LABEL" "$target"
            fi
            ;;

        fat32|vfat|fat)
            sudo_exec mkfs.vfat -F32 -n "$LABEL" "$target"
            ;;

        ntfs)
            sudo_exec mkfs.ntfs -F -L "$LABEL" "$target"
            ;;

        apfs)
            if ! command -v mkfs.apfs >/dev/null 2>&1; then
                echo "ERROR: mkfs.apfs not found (install apfsprogs)."
                exit 1
            fi
            sudo_exec mkfs.apfs -v "$LABEL" "$target"
            ;;

        hfs+|hfsplus)
            if ! command -v mkfs.hfsplus >/dev/null 2>&1; then
                echo "ERROR: mkfs.hfsplus not found (install hfsprogs)."
                exit 1
            fi
            sudo_exec mkfs.hfsplus -v "$LABEL" "$target"
            ;;

        *)
            echo "ERROR: Unsupported filesystem: $fs"
            exit 1
            ;;
    esac
}

disk_with_efi() {
    DISK=$(resolve_device "$DISK")
    DISK=$(get_parent_disk "$DISK")
    unmount_device "$DISK"

    sudo_exec wipefs -a "$DISK"
    sudo_exec parted -s "$DISK" mklabel gpt

    # EFI 100MiB
    sudo_exec parted -s "$DISK" mkpart ESP fat32 1MiB 101MiB
    sudo_exec parted -s "$DISK" set 1 esp on
    # main partition rest
    sudo_exec parted -s "$DISK" mkpart primary 101MiB 100%
    sleep 1

    # determine partition device names reliably
    local before after new1 new2
    before=$(lsblk -ln -o NAME "$DISK")
    after=$(lsblk -ln -o NAME "$DISK")
    # normally result is disk then sda1 sda2 — use parent + "1"/"2" if detection fails:
    local efi_part main_part
    # try common pattern: parent + "1" / "2"
    if [[ -b "${DISK}1" && -b "${DISK}2" ]]; then
        efi_part="${DISK}1"
        main_part="${DISK}2"
    else
        # fallback: find new partitions by listing (robust diff)
        new1=$(comm -13 <(echo "$before") <(echo "$after") | sed -n '1p' || true)
        new2=$(comm -13 <(echo "$before") <(echo "$after") | sed -n '2p' || true)
        if [[ -n "$new1" ]]; then efi_part="/dev/$new1"; fi
        if [[ -n "$new2" ]]; then main_part="/dev/$new2"; fi
        # final fallback mapping
        if [[ -z "$efi_part" ]]; then efi_part="${DISK}1"; fi
        if [[ -z "$main_part" ]]; then main_part="${DISK}2"; fi
    fi

    # Format and mount using label-only for mount_fs
    local old_label="$LABEL"
    LABEL="EFI"
    mkfs_with_label fat32 "$efi_part"
    mount_fs fat32 "$efi_part" "EFI"

    LABEL="$old_label"
    mkfs_with_label "$FS_TYPE_DISK" "$main_part"
    mount_fs "$FS_TYPE_DISK" "$main_part" "$LABEL"

    echo "Created EFI partition at $efi_part and main partition at $main_part"
}

unmount_device() {
    local dev="$1"
    # unmount partitions reported by lsblk
    local parts
    parts=$(lsblk -ln -o NAME "$dev" | tail -n +2 2>/dev/null || true)
    for p in $parts; do
        local part="/dev/$p"
        local mp
        mp=$(lsblk -no MOUNTPOINT "$part" 2>/dev/null || true)
        if [[ -n "$mp" ]]; then
            sudo_exec umount "$mp" 2>/dev/null || true
        fi
    done

    # also try unmounting anything under /media or /run/media for the user
    for base in "/media/$INVOKER_USER" "/run/media/$INVOKER_USER"; do
        if [[ -d "$base" ]]; then
            for m in $(find "$base" -maxdepth 2 -type d 2>/dev/null || true); do
                if mountpoint -q "$m"; then
                    sudo_exec umount "$m" 2>/dev/null || true
                fi
            done
        fi
    done
}

resolve_device() {
    local input="$1"

    # If already a block device
    if [[ -b "$input" ]]; then
        echo "$input"
        return 0
    fi

    # If it's a directory (mountpoint), resolve to source device
    if [[ -d "$input" ]]; then
        local src
        src=$(findmnt -n -o SOURCE --target "$input" 2>/dev/null || true)
        if [[ -n "$src" && -b "$src" ]]; then
            echo "$src"
            return 0
        fi
    fi

    # df fallback
    if df --output=source "$input" >/dev/null 2>&1; then
        local s
        s=$(df --output=source "$input" | tail -1)
        if [[ -n "$s" && -b "$s" ]]; then
            echo "$s"
            return 0
        fi
    fi

    echo "ERROR: Unable to resolve device for: $input" >&2
    exit 1
}

get_disk_from_partition() {
    part="$1"
    lsblk -no PKNAME "$part" | xargs -I{} echo "/dev/{}"
}

############################################################
# HELP MENU
############################################################
usage() {
    cat <<EOF
USB Toolkit — Zero Interaction Mode

Operations:
  --eraseDisk <disk> <fs>      Full wipe + new partition + mkfs + mount
  --erase, -e <part> <fs>      Format a single partition
  --zero <disk> <fs>           Full dd wipe → GPT/MBR → mkfs → mount
  --addPartition, -a <disk> <size> <fs> <name>
                               Add a new partition of <size>
  --name, -n <label>           Set filesystem label
  --mbr                        Use MBR partition scheme (default GPT)
  --help, -h                   Show help

Filesystem support:
  ext4, ext3, btrfs, swap, fat32, exfat, ntfs, apfs, hfs+

Example:
  PASSWORD="pass" ./format.sh --eraseDisk /dev/sdb ext4 -n MYUSB
EOF
    exit 1
}

############################################################
# FLAG STORAGE
############################################################
ERASE_DISK=false
ERASE_PART=false
ZERO_DISK=false
ADDPART=false
USE_MBR=false
DISK_WITH_EFI=false
DISK=""
PART=""
FS_TYPE_DISK=""
FS_TYPE_PART=""
ZERO_TARGET=""
ZERO_FS=""
ADDPART_DISK=""
ADDPART_SIZE_RAW=""
ADDPART_FS=""
ADDPART_NAME=""
LABEL="USB"
INVOKER_UID=$(id -u)
INVOKER_GID=$(id -g)
INVOKER_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER" || whoami 2>/dev/null)}"

############################################################
# DEVICE RESOLUTION: /media/... → /dev/...
############################################################
resolve_device() {
    local input="$1"

    # Already a block device?
    if [[ -b "$input" ]]; then
        echo "$input"
        return 0
    fi

    # Mountpoint resolution
    if [[ -d "$input" ]]; then
        local src
        src=$(findmnt -n -o SOURCE --target "$input" 2>/dev/null || true)
        if [[ -b "$src" ]]; then
            echo "$src"
            return 0
        fi
    fi

    # df fallback
    if df --output=source "$input" >/dev/null 2>&1; then
        local s
        s=$(df --output=source "$input" | tail -1)
        if [[ -b "$s" ]]; then
            echo "$s"
            return 0
        fi
    fi

    echo "ERROR: Unable to resolve device for: $input"
    exit 1
}

get_parent_disk() {
    local dev="$1"

    # If already a whole disk, return unchanged
    if lsblk -dn -o TYPE "$dev" 2>/dev/null | grep -q "^disk$"; then
        echo "$dev"
        return 0
    fi

    # Otherwise return parent block device name
    local parent
    parent=$(lsblk -no PKNAME "$dev" 2>/dev/null || true)
    if [[ -n "$parent" ]]; then
        echo "/dev/$parent"
        return 0
    fi

    # fallback
    echo "$dev"
}

############################################################
# ARGUMENT PARSING
############################################################
while [[ $# -gt 0 ]]; do
    case "$1" in
        --eraseDisk)
            ERASE_DISK=true
            DISK=$(resolve_device "$2")
            DISK=$(get_parent_disk "$DISK")
            FS_TYPE_DISK="$3"
            shift 3
            ;;

        --erase|-e)
            ERASE_PART=true
            PART=$(resolve_device "$2")
            FS_TYPE_PART="$3"
            shift 3
            ;;
        --diskWithEFI|-dwe)
            DISK=$(resolve_device "$2")
            DISK=$(get_parent_disk "$DISK")
            FS_TYPE_DISK="$3"
            disk_with_efi
            shift 3
            ;;

        --zero)
            ZERO_DISK=true
            ZERO_TARGET=$(resolve_device "$2")
            ZERO_TARGET=$(get_parent_disk "$ZERO_TARGET")
            ZERO_FS="$3"
            shift 3
            ;;

    #     --addPartition)
        
    #   dev=$(resolve_device "$2")
    #   disk=$(get_disk_from_partition "$dev")
    #   echo $disk
    #   unmount_device "$disk"

# sudo fdisk "$disk" <<EOF
# d
# n
# p


# w
# EOF

#       partprobe "$dev"
#       shift
#       shift
#       ;;

        --name|-n)
            LABEL="$2"
            shift 2
            ;;

        --mbr)
            USE_MBR=true
            shift
            ;;

        --help|-h)
            usage
            ;;

        *)
            echo "Unknown flag: $1"
            usage
            ;;
    esac
done

if ! $ERASE_DISK && ! $ERASE_PART && ! $ZERO_DISK && ! $ADDPART; then
    echo "ERROR: No operation specified."
    usage
fi

############################################################
# FILESYSTEM CREATION
############################################################

############################################################
# MOUNTING HANDLER
############################################################
# Then replace mount_fs() with:


############################################################
# ERASE PARTITION
############################################################
erase_partition() {
    sudo_exec umount "$PART" 2>/dev/null || true
    mkfs_with_label "$FS_TYPE_PART" "$PART"
    mount_fs "$FS_TYPE_PART" "$PART" "/mnt/$(basename "$PART")"
}

############################################################
# ERASE DISK
############################################################
erase_disk() {
    for p in $(lsblk -ln -o NAME "$DISK" | tail -n +2); do
        sudo_exec umount "/dev/$p" 2>/dev/null || true
    done

    sudo_exec wipefs -a "$DISK"

    if $USE_MBR; then
        sudo_exec parted -s "$DISK" mklabel msdos
        sudo_exec parted -s "$DISK" mkpart primary 1MiB 100%
    else
        sudo_exec parted -s "$DISK" mklabel gpt
        sudo_exec parted -s "$DISK" mkpart primary 0% 100%
    fi

    sleep 1
    local part="${DISK}1"
    mkfs_with_label "$FS_TYPE_DISK" "$part"
    mount_fs "$FS_TYPE_DISK" "$part" "/mnt/$(basename "$part")"
}

############################################################
# ZERO DISK
############################################################
zero_disk() {
    for p in $(lsblk -ln -o NAME "$ZERO_TARGET" | tail -n +2); do
        sudo_exec umount "/dev/$p" 2>/dev/null || true
    done

    sudo_exec dd if=/dev/zero of="$ZERO_TARGET" bs=1M status=progress

    if $USE_MBR; then
        sudo_exec parted -s "$ZERO_TARGET" mklabel msdos
        sudo_exec parted -s "$ZERO_TARGET" mkpart primary 1MiB 100%
    else
        sudo_exec parted -s "$ZERO_TARGET" mklabel gpt
        sudo_exec parted -s "$ZERO_TARGET" mkpart primary 0% 100%
    fi

    sleep 1
    local part="${ZERO_TARGET}1"
    mkfs_with_label "$ZERO_FS" "$part"
    mount_fs "$ZERO_FS" "$part" "/mnt/$(basename "$part")"
}

############################################################
# ADD PARTITION
############################################################
add_partition() {
    ADDPART_DISK=$(resolve_device "$ADDPART_DISK")
    ADDPART_DISK=$(get_parent_disk "$ADDPART_DISK")
    unmount_device "$ADDPART_DISK"

    local devbase sectors disk_mib
    devbase=$(basename "$ADDPART_DISK")
    sectors=$(cat "/sys/block/$devbase/size" 2>/dev/null || echo 0)
    disk_mib=$(( (sectors * 512) / 1024 / 1024 ))

    # parse size
    parse_size() {
        local s="$1"
        if [[ $s =~ ^([0-9]+)G$ ]]; then echo $(( ${BASH_REMATCH[1]} * 1024 ))
        elif [[ $s =~ ^([0-9]+)M$ ]]; then echo "${BASH_REMATCH[1]}"
        elif [[ $s =~ ^([0-9]+)%$ ]]; then echo $(( disk_mib * ${BASH_REMATCH[1]} / 100 ))
        else echo "ERROR: Bad size format: $s" >&2; exit 1; fi
    }
    local size_mib
    size_mib=$(parse_size "$ADDPART_SIZE_RAW")

    # get free ranges
    local free_ranges
    free_ranges=$(sudo_exec parted -m -s "$ADDPART_DISK" unit MiB print free 2>/dev/null | awk -F: '/free/ {s=$2; e=$3; gsub("MiB","",s); gsub("MiB","",e); print s, e}' || true)
    if [[ -z "$free_ranges" ]]; then
        echo "ERROR: No free ranges detected on $ADDPART_DISK" >&2
        exit 1
    fi

    # choose largest region
    local best_start=0 best_size=-1
    while read -r s e; do
        [[ -z "$s" || -z "$e" ]] && continue
        # accept decimals safely
        s=$(printf "%.0f" "$s")
        e=$(printf "%.0f" "$e")
        local region_size=$(( e - s ))
        if (( region_size > best_size )); then
            best_size=$region_size
            best_start=$s
            best_end=$e
        fi
    done <<< "$free_ranges"

    if (( best_size < size_mib )); then
        echo "ERROR: Not enough free space." >&2
        exit 1
    fi

    local start_mib=$best_start
    local end_mib=$(( start_mib + size_mib ))

    # capture existing parts before change
    local before after newpart
    before=$(lsblk -ln -o NAME "$ADDPART_DISK")
    sudo_exec parted -s "$ADDPART_DISK" mkpart primary "$ADDPART_FS" "${start_mib}MiB" "${end_mib}MiB"
    sleep 1
    after=$(lsblk -ln -o NAME "$ADDPART_DISK")
    newpart=$(comm -13 <(echo "$before") <(echo "$after") | head -n 1)
    if [[ -z "$newpart" ]]; then
        # fallback guess
        newpart=$(lsblk -ln -o NAME "$ADDPART_DISK" | tail -n 1)
    fi
    newpart="/dev/$newpart"

    local old_label="$LABEL"
    LABEL="$ADDPART_NAME"
    mkfs_with_label "$ADDPART_FS" "$newpart"
    LABEL="$old_label"

    mount_fs "$ADDPART_FS" "$newpart" "$ADDPART_NAME"
    echo "Added partition: $newpart   Mounted at: /media/$INVOKER_USER/$ADDPART_NAME"
}

if $ERASE_PART; then erase_partition; fi
if $ERASE_DISK; then erase_disk; fi
if $ZERO_DISK; then zero_disk; fi
if $ADDPART; then add_partition; fi
if $DISK_WITH_EFI; then disk_with_efi; fi