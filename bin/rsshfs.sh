#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

show_help() {
    cat <<HELPEOF
Usage:
  $SCRIPT_NAME <user@host> [<remote_dir>] <local_mount>
  $SCRIPT_NAME -u <local_mount>
  $SCRIPT_NAME -h | --help

Description:
  Mount a remote directory locally via SSHFS, or unmount an existing mount.
  If <remote_dir> is omitted, it defaults to the remote user's home directory.

Arguments:
  <user@host>     Remote SSH target (e.g., user@server.com or SSH config host)
  <remote_dir>    Optional path on remote host to mount (defaults to remote home)
  <local_mount>   Local directory to mount into

Options:
  -u, --unmount   Unmount the specified local mount point
  -h, --help      Display this help message and exit

Examples:
  # Mount remote home directory (defaults to remote \$HOME):
  $SCRIPT_NAME user@remote-box ~/mnt/remote

  # Mount specific remote directory:
  $SCRIPT_NAME user@remote-box /var/www ~/mnt/webserver

  # Unmount directory:
  $SCRIPT_NAME -u ~/mnt/remote
HELPEOF
}

# Check prerequisites
if ! command -v sshfs >/dev/null 2>&1; then
    echo "Error: 'sshfs' is not installed or not in PATH." >&2
    exit 1
fi

unmount_dir() {
    local target="$1"

    if [ ! -d "$target" ]; then
        echo "Error: Directory '$target' does not exist." >&2
        exit 1
    fi

    if ! mountpoint -q "$target" 2>/dev/null; then
        echo "Notice: '$target' is not currently a mountpoint."
        exit 0
    fi

    echo "Unmounting $target..."
    if command -v fusermount3 >/dev/null 2>&1; then
        fusermount3 -u "$target"
    elif command -v fusermount >/dev/null 2>&1; then
        fusermount -u "$target"
    else
        umount "$target"
    fi
    echo "Successfully unmounted $target."
}

if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -u|--unmount)
        if [[ $# -lt 2 ]]; then
            echo "Error: Missing local mount directory to unmount." >&2
            echo "Run '$SCRIPT_NAME --help' for usage." >&2
            exit 1
        fi
        unmount_dir "$2"
        exit 0
        ;;
esac

if [[ $# -lt 2 ]]; then
    echo "Error: Missing required arguments." >&2
    echo "Run '$SCRIPT_NAME --help' for usage." >&2
    exit 1
fi

REMOTE_HOST="$1"
if [[ $# -eq 2 ]]; then
    REMOTE_DIR=""
    LOCAL_MOUNT="$2"
    REMOTE_SPEC="${REMOTE_HOST}:"
    DISPLAY_DIR="remote \$HOME"
else
    REMOTE_DIR="$2"
    LOCAL_MOUNT="$3"
    REMOTE_SPEC="${REMOTE_HOST}:${REMOTE_DIR}"
    DISPLAY_DIR="$REMOTE_DIR"
fi

SSHFS_OPTS=(
    -o reconnect
    -o ServerAliveInterval=15
    -o ServerAliveCountMax=3
    -o follow_symlinks
    -o idmap=user
    -o cache=yes
    -o kernel_cache
    -o compression=yes
)

mkdir -p "$LOCAL_MOUNT"

if mountpoint -q "$LOCAL_MOUNT" 2>/dev/null; then
    echo "Notice: '$LOCAL_MOUNT' is already mounted."
    exit 0
fi

echo "Mounting $REMOTE_HOST ($DISPLAY_DIR) to $LOCAL_MOUNT..."
sshfs "$REMOTE_SPEC" "$LOCAL_MOUNT" "${SSHFS_OPTS[@]}"

if mountpoint -q "$LOCAL_MOUNT" 2>/dev/null; then
    echo "Successfully mounted to $LOCAL_MOUNT"
else
    echo "Error: Failed to mount to $LOCAL_MOUNT" >&2
    exit 1
fi
