#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------
#  Popup Tile Launcher — Installer / Uninstaller
#  Auto-download, build, install, DBus/systemd integration
# ---------------------------------------------------------

# ---------- Colors ----------
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; RESET="\e[0m"
ok()    { echo -e "${GREEN}[ OK ]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err()   { echo -e "${RED}[ERR ]${RESET} $1"; exit 1; }
info()  { echo -e "${BLUE}[INFO]${RESET} $1"; }

clear
echo
echo "Popup Tile Launcher"
echo "--------------------"
echo "1) Install"
echo "2) Uninstall"
read -rp "Your choice [1/2]: " MAIN_MODE

if [[ "$MAIN_MODE" == "2" ]]; then
    echo
    echo "Select uninstall mode:"
    echo "  1) System uninstall (/usr/local)"
    echo "  2) User uninstall (~/.local)"
    read -rp "Your choice [1/2]: " UN_MODE

    # ---------- Detect distro ----------
    source /etc/os-release

    if [[ "$ID" = "arch" || "${ID_LIKE-}" == *"arch"* ]]; then
        DISTRO="arch"
    elif [[ "$ID" = "debian" || "${ID_LIKE-}" == *"debian"* || "$ID" = "ubuntu" ]]; then
        DISTRO="debian"
    elif [[ "$ID" = "fedora" || "${ID_LIKE-}" == *"fedora"* ]]; then
        DISTRO="fedora"
    else
        DISTRO="unknown"
    fi

    info "Detected distro: $DISTRO"

    # ---------- Set paths & dependencies ----------
    case "$DISTRO" in
        arch)
            QML_PATH="/usr/lib/qt6/qml"
            ;;
        debian)
            QML_PATH="/usr/lib/x86_64-linux-gnu/qt6/qml"
            ;;
        fedora)
            QML_PATH="/usr/lib64/qt6/qml"
            ;;
        *)
            err "Unsupported distro. Install manually."
            ;;
    esac

    if [[ "$UN_MODE" == "1" ]]; then
        UN_BIN="/usr/local/bin"
        UN_QML="$QML_PATH/org/apps/launcher"
        UN_DBUS="/usr/share/dbus-1/services/org.apps.PlasmaHelper.service"
        UN_PLASMOID="/usr/share/plasma/plasmoids/org.apps.popuptilelauncher"
        # Determine real user
        if [[ -n "${SUDO_USER-}" ]]; then
            REAL_USER="$SUDO_USER"
        elif [[ -n "${PKEXEC_UID-}" ]]; then
            REAL_USER=$(id -un "$PKEXEC_UID")
        elif [[ -n "${LOGNAME-}" && "$LOGNAME" != "root" ]]; then
            REAL_USER="$LOGNAME"
        elif [[ -n "${USER-}" && "$USER" != "root" ]]; then
            REAL_USER="$USER"
        else
            # fallback: first logged-in non-root user
            REAL_USER=$(who | awk 'NR==1{print $1}')
        fi
        REAL_HOME=$(eval echo "~$REAL_USER")
        UN_XHR="$REAL_HOME/.config/plasma-workspace/env"
        NEED_SUDO=1
    else
        UN_BIN="$HOME/.local/bin"
        UN_QML="$QML_PATH/org/apps/launcher"
        UN_DBUS="$HOME/.local/share/dbus-1/services/org.apps.PlasmaHelper.service"
        UN_PLASMOID="$HOME/.local/share/plasma/plasmoids/org.apps.popuptilelauncher"
        UN_XHR="$HOME/.config/plasma-workspace/env"
        REAL_USER="$USER"
        REAL_HOME="$HOME"
        NEED_SUDO=0
    fi

    if [[ "$NEED_SUDO" == "1" && $EUID -ne 0 ]]; then
        info "Root required. Restarting with sudo..."
        exec sudo bash "$0"
    fi

    echo
    info "Uninstalling Popup Tile Launcher..."

    rm -f "$UN_BIN/plasma_helper" && ok "Removed plasma_helper" || warn "plasma_helper not found"
    rm -f "$UN_BIN/launcher" && ok "Removed launcher" || warn "launcher not found"
    sudo rm -rf "$UN_QML" && ok "Removed QML module" || warn "QML module not found"
    rm -f "$UN_DBUS" && ok "Removed DBus service" || warn "DBus service not found"
    rm -f "$UN_XHR/enable_qml_xhr.sh" && ok "Removed XHR" || warn "XHR not found"
    rm -rf "$UN_PLASMOID" && ok "Removed plasmoid" || warn "Plasmoid not found"
    rm -rf "$REAL_HOME/.local/share/plasma_helper" || warn "instances not found"
    rm -rf "$REAL_HOME/.config/kde.org/plasmashell.conf" || warn "shell instances not found"

    systemctl --user disable --now plasmahelper.service 2>/dev/null && ok "Disabled systemd user service" || true
    rm -f "$REAL_HOME/.config/systemd/user/plasmahelper.service" 2>/dev/null && ok "Removed systemd user service" || true

    echo
    ok "Uninstall complete!"
    exit 0
fi

# ---------- Detect distro ----------
source /etc/os-release

if [[ "$ID" = "arch" || "${ID_LIKE-}" == *"arch"* ]]; then
    DISTRO="arch"
elif [[ "$ID" = "debian" || "${ID_LIKE-}" == *"debian"* || "$ID" = "ubuntu" ]]; then
    DISTRO="debian"
elif [[ "$ID" = "fedora" || "${ID_LIKE-}" == *"fedora"* ]]; then
    DISTRO="fedora"
else
    DISTRO="unknown"
fi

info "Detected distro: $DISTRO"

# ---------- Set paths & dependencies ----------
case "$DISTRO" in
    arch)
        QML_PATH="/usr/lib/qt6/qml"
        PKGS_BUILD=(base-devel cmake qt6-base qt6-declarative qt6-tools qt6-svg)
        PKGS_KF6=(kio kservice kcoreaddons kpackage kwindowsystem)
        ;;
    debian)
        QML_PATH="/usr/lib/x86_64-linux-gnu/qt6/qml"
        PKGS_BUILD=(cmake make g++ qt6-base-dev qt6-declarative-dev qt6-tools-dev)
        PKGS_KF6=(libkf6coreaddons-dev libkf6service-dev libkf6kio-dev libkf6windowsystem-dev)
        ;;
    fedora)
        QML_PATH="/usr/lib64/qt6/qml"
        PKGS_BUILD=(cmake gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qttools-devel qt6-qtsvg-devel)
        PKGS_KF6=(kf6-kcoreaddons-devel kf6-kservice-devel kf6-kio-devel kf6-kpackage-devel kf6-kwindowsystem-devel)
        ;;
    *)
        err "Unsupported distro. Install manually."
        ;;
esac

# ---------- Ask install mode ----------
echo
echo "Select installation type:"
echo "  1) System installation (/usr/local)"
echo "  2) User installation (~/.local) (recommended)"
read -rp "Your choice [1/2]: " INSTALL_MODE

if [[ "$INSTALL_MODE" == "1" ]]; then
    INSTALL_BIN="/usr/local/bin"
    INSTALL_QML="$QML_PATH/org/apps/launcher"
    INSTALL_DBUS="/usr/share/dbus-1/services"
    INSTALL_PLASMOID="/usr/share/plasma/plasmoids"
    # Determine real user
    if [[ -n "${SUDO_USER-}" ]]; then
        REAL_USER="$SUDO_USER"
    elif [[ -n "${PKEXEC_UID-}" ]]; then
        REAL_USER=$(id -un "$PKEXEC_UID")
    elif [[ -n "${LOGNAME-}" && "$LOGNAME" != "root" ]]; then
        REAL_USER="$LOGNAME"
    elif [[ -n "${USER-}" && "$USER" != "root" ]]; then
        REAL_USER="$USER"
    else
        # fallback: first logged-in non-root user
        REAL_USER=$(who | awk 'NR==1{print $1}')
    fi
    REAL_HOME=$(eval echo "~$REAL_USER")
    INSTALL_XHR="$REAL_HOME/.config/plasma-workspace/env"
    NEED_SUDO=1
else
    INSTALL_BIN="$HOME/.local/bin"
    INSTALL_QML="$QML_PATH/org/apps/launcher"
    INSTALL_DBUS="$HOME/.local/share/dbus-1/services"
    INSTALL_PLASMOID="$HOME/.local/share/plasma/plasmoids"
    INSTALL_XHR="$HOME/.config/plasma-workspace/env"
    REAL_USER="$USER"
    REAL_HOME="$HOME"
    NEED_SUDO=0
fi

# ---------- Ask service mode ----------
echo
echo "Select helper startup method:"
echo "  1) DBus activation (recommended)"
echo "  2) systemd user service"
read -rp "Your choice [1/2]: " SERVICE_MODE

# ---------- sudo escalation ----------
if [[ "$NEED_SUDO" == "1" && $EUID -ne 0 ]]; then
    info "Root required. Restarting with sudo..."
    exec sudo bash "$0"
fi

# ---------- Detect local source ----------
if [[ -d "helper" && -d "launcher" && -d "contents" && -f "metadata.json" ]]; then
    info "Local source detected — using current directory."
    LOCAL_SOURCE=1
    SRC_DIR="$(pwd)"
else
    info "No local source found — downloading latest release from GitHub..."
    LOCAL_SOURCE=0
fi

# ---------- Download if needed ----------
if [[ "$LOCAL_SOURCE" == "0" ]]; then

    # Try to get real .tar.gz release asset
    if LATEST_URL=$(curl -s https://api.github.com/repos/rzxas/org.apps.popuptilelauncher/releases/latest \
        | grep "browser_download_url" \
        | grep "org.apps.popuptilelauncher.*.tar.gz" \
        | cut -d '"' -f 4); [[ -z "$LATEST_URL" ]]; then

        warn "Release .tar.gz not found — falling back to tarball_url"

        LATEST_URL=$(curl -s https://api.github.com/repos/rzxas/org.apps.popuptilelauncher/releases/latest \
            | grep "tarball_url" \
            | cut -d '"' -f 4)

        [[ -z "$LATEST_URL" ]] && err "Failed to detect any valid release URL."
    fi

    info "Using release asset: $LATEST_URL"
    curl -L "$LATEST_URL" -o source.tar.gz
    ok "Downloaded release"
# ---------- Extract ----------
    rm -rf src
    mkdir src
    tar -xzf source.tar.gz -C src --strip-components=1
    SRC_DIR="$(pwd)/src"
fi

# ---------- Enter source directory ----------
cd "$SRC_DIR"

# ---------- Check dependencies ----------
info "Checking dependencies..."

missing=()

case "$DISTRO" in
    arch)
        for pkg in "${PKGS_BUILD[@]}" "${PKGS_KF6[@]}"; do
            pacman -Qi "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
        done
        ;;
    debian)
        for pkg in "${PKGS_BUILD[@]}" "${PKGS_KF6[@]}"; do
            dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
        done
        ;;
    fedora)
        for pkg in "${PKGS_BUILD[@]}" "${PKGS_KF6[@]}"; do
            rpm -q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
        done
        ;;
esac

if (( ${#missing[@]} > 0 )); then
    warn "Missing packages:"
    printf '%s\n' "${missing[@]}"
    err "Install missing dependencies and rerun installer."
else
    ok "All dependencies found"
fi

# ---------- Build ----------
info "Building helper and launcher..."

rm -rf launcher/build helper/build
mkdir -p launcher/build helper/build

cd launcher/build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j"$(nproc)"

cd ../../helper/build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j"$(nproc)"
cd ../..
ok "Build complete"

# ---------- Paths to built files ----------
HELPER_BIN="helper/build/plasma_helper"
LAUNCHER_BIN="launcher/build/launcher"
PLUGIN_SO="launcher/build/liborg.apps.launcher.so"
PLUGIN_QMLDIR="launcher/imports/org/apps/launcher/qmldir"
# PLASMOID_DIR="../src"
PLASMOID_DIR="$SRC_DIR"

[[ -f "$HELPER_BIN" ]] || err "Helper binary missing"
[[ -f "$LAUNCHER_BIN" ]] || err "Launcher binary missing"
[[ -f "$PLUGIN_SO" ]] || err "QML plugin missing"

# ---------- Install ----------
info "Installing..."
info "need priv for install module."
mkdir -p "$INSTALL_BIN" "$INSTALL_DBUS" "$INSTALL_XHR"
sudo mkdir -p "$INSTALL_QML"

install -m 755 "$HELPER_BIN" "$INSTALL_BIN/plasma_helper"
install -m 755 "$LAUNCHER_BIN" "$INSTALL_BIN/launcher"
sudo install -m 755 "$PLUGIN_SO" "$INSTALL_QML/liborg.apps.launcher.so"
sudo install -m 644 "$PLUGIN_QMLDIR" "$INSTALL_QML/qmldir"

# ---------- Plasmoid version check/install ----------
get_version() {
    grep -E '"Version":' "$1" | sed -E 's/.*"Version": *"([^"]+)".*/\1/'
}

version_lt() {
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" != "$2" ]
}

INSTALLED_META="$INSTALL_PLASMOID/org.apps.popuptilelauncher/metadata.json"
NEW_META="$PLASMOID_DIR/metadata.json"

if [[ ! -f "$INSTALLED_META" ]]; then
    info "Plasmoid not installed yet — installing fresh copy."
    NEED_INSTALL=1
else
    NEW_VER=$(get_version "$NEW_META")
    OLD_VER=$(get_version "$INSTALLED_META")

    if version_lt "$OLD_VER" "$NEW_VER"; then
        info "Updating plasmoid: $OLD_VER → $NEW_VER"
        NEED_INSTALL=1
    else
        info "Installed version ($OLD_VER) is up to date. Skipping plasmoid copy."
        NEED_INSTALL=0
    fi
fi

# ---------- Plasmoid version check/install ----------
if [[ "$NEED_INSTALL" == "1" ]]; then
    mkdir -p "$INSTALL_PLASMOID/org.apps.popuptilelauncher"

    cp -r \
        "$PLASMOID_DIR/contents" \
        "$PLASMOID_DIR/LICENSE" \
        "$PLASMOID_DIR/metadata.json" \
        "$PLASMOID_DIR/README.md" \
        "$INSTALL_PLASMOID/org.apps.popuptilelauncher"

    ok "Plasmoid installed/updated"

    # ---------- Permissions for system installation ----------
    if [[ "$NEED_SUDO" == "1" ]]; then
        sudo find "$INSTALL_PLASMOID/org.apps.popuptilelauncher" -type d -exec chmod 755 {} \;
        sudo find "$INSTALL_PLASMOID/org.apps.popuptilelauncher" -type f -exec chmod 644 {} \;
        ok "Permissions set for system plasmoid"
    fi

else
    ok "Plasmoid installation skipped"
fi

# ---------- DBus service ----------
if [[ "$SERVICE_MODE" == "1" ]]; then
cat > "$INSTALL_DBUS/org.apps.PlasmaHelper.service" <<EOF
[D-BUS Service]
Name=org.apps.PlasmaHelper
Exec=$INSTALL_BIN/plasma_helper
EOF
    chmod 644 "$INSTALL_DBUS/org.apps.PlasmaHelper.service"
    ok "DBus service installed"
fi

# ---------- systemd user service ----------
if [[ "$SERVICE_MODE" == "2" ]]; then
mkdir -p "$REAL_HOME/.config/systemd/user"
cat > "$REAL_HOME/.config/systemd/user/plasmahelper.service" <<EOF
[Unit]
Description=Popup Tile Launcher helper

[Service]
ExecStartPre=/usr/bin/sleep 5
ExecStart=$INSTALL_BIN/plasma_helper
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now plasmahelper.service

ok "systemd user service installed"
fi

# ---------- Enable XHR for .desktop reading ----------
cat > "$INSTALL_XHR/enable_qml_xhr.sh" <<EOF
#!/bin/sh
export QML_XHR_ALLOW_FILE_READ=1
export QML_XHR_ALLOW_FILE_WRITE=1
EOF

chmod +x "$INSTALL_XHR/enable_qml_xhr.sh"
chown "$REAL_USER":"$REAL_USER" "$INSTALL_XHR/enable_qml_xhr.sh"

ok "Environment variables added for reading .desktop"
echo -e "${YELLOW}===========================================================${RESET}"
ok "Installation complete!"
ok "Restart Plasma session to apply environment changes."
echo -e "${YELLOW}===========================================================${RESET}"
