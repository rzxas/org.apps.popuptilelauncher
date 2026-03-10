#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------
#  Popup Tile Launcher — Installer / Uninstaller
#  Auto-download, build, install, DBus/systemd integration
# ---------------------------------------------------------
#  Colors
# ---------------------------------------------------------
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; RESET="\e[0m"
ok()    { echo -e "${GREEN}[ OK ]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err()   { echo -e "${RED}[ERR ]${RESET} $1"; exit 1; }
info()  { echo -e "${BLUE}[INFO]${RESET} $1"; }

clear
# ---------------------------------------------------------
#  Detect distro (single unified block)
# ---------------------------------------------------------
detect_distro() {
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
}

# ---------------------------------------------------------
# Path, Check Dependencies
# ---------------------------------------------------------
paths_dependencies(){
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
}

check_dependencies(){
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
}
# ---------------------------------------------------------
#  Build and install helper & launcher
# ---------------------------------------------------------
install_helper(){
    echo -e "${YELLOW}===========================================================${RESET}"
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
    echo -e "${YELLOW}===========================================================${RESET}"

    # ---------- Paths to built files ----------
    HELPER_BIN="helper/build/plasma_helper"
    LAUNCHER_BIN="launcher/build/launcher"
    PLUGIN_SO="launcher/build/liborg.apps.launcher.so"
    PLUGIN_QMLDIR="launcher/imports/org/apps/launcher/qmldir"
    PLASMOID_DIR="$SRC_DIR"

    [[ -f "$HELPER_BIN" ]] || err "Helper binary missing"
    [[ -f "$LAUNCHER_BIN" ]] || err "Launcher binary missing"
    [[ -f "$PLUGIN_SO" ]] || err "QML plugin missing"

    # ---------- Install ----------
    info "Installing..."
    info "need priv for install module."
    mkdir -p "$INSTALL_BIN" "$INSTALL_DBUS" "$INSTALL_XHR"
    sudo mkdir -p "$INSTALL_QML"

    run_su "install -m 755 \"$HELPER_BIN\" \"$INSTALL_BIN/plasma_helper\""
    run_su "install -m 755 \"$LAUNCHER_BIN\" \"$INSTALL_BIN/launcher\""
    sudo install -m 755 "$PLUGIN_SO" "$INSTALL_QML/liborg.apps.launcher.so"
    sudo install -m 644 "$PLUGIN_QMLDIR" "$INSTALL_QML/qmldir"
}

# ---------------------------------------------------------
#  Paths
# ---------------------------------------------------------
WIDGET_ID="org.apps.popuptilelauncher"
USER_WIDGET="$HOME/.local/share/plasma/plasmoids/$WIDGET_ID"
SYSTEM_WIDGET="/usr/share/plasma/plasmoids/$WIDGET_ID"

# ---------------------------------------------------------
#  Detect existing installation
# ---------------------------------------------------------

detect_existing_widget() {
    if [[ -d "$USER_WIDGET" ]]; then
        INSTALLED_PATH="$USER_WIDGET"
    elif [[ -d "$SYSTEM_WIDGET" ]]; then
        INSTALLED_PATH="$SYSTEM_WIDGET"
    else
        INSTALLED_PATH=""
    fi
}

# ---------------------------------------------------------
#  Install widget (user or system)
# ---------------------------------------------------------

set_install_paths() {
    if [[ "$INSTALL_MODE" == "system" ]]; then
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
}

# ---------------------------------------------------------
#  installation type
# ---------------------------------------------------------
installation_type(){
    echo "--------------------------------------------"
    echo "Select installation type:"
    echo "  1) System installation (/usr/local) (for all user)"
    echo "  2) User installation (~/.local) (only for you)"
    echo "-----------------------"
    read -rp "Your choice [1/2]: " INSTALL_MODE
    echo "--------------------------------------------"

    if [[ "$INSTALL_MODE" == "1" ]]; then
        INSTALL_MODE="system"
    else
        INSTALL_MODE="user"
    fi
}

# ---------------------------------------------------------
#  Privilege
# ---------------------------------------------------------
run_su() {
    local cmd="$1"

    if [[ "$INSTALL_MODE" == "system" ]]; then
        sudo bash -c "$cmd"
    else
        bash -c "$cmd"
    fi
}

# ---------------------------------------------------------
#  Detect or download source
# ---------------------------------------------------------
local_src(){
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
}

# ---------------------------------------------------------
#  Plasmoid version check/install
# ---------------------------------------------------------
get_version() {
    grep -E '"Version":' "$1" | sed -E 's/.*"Version": *"([^"]+)".*/\1/'
}

version_lt() {
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" != "$2" ]
}

# ---------------------------------------------------------
#  DBus or systemd service install & Enable XHR
# ---------------------------------------------------------
service_install(){
        # ---------- DBus service ----------
        if [[ "$SERVICE_MODE" == "1" ]]; then
        run_su "cat > \"$INSTALL_DBUS/org.apps.PlasmaHelper.service\"" <<EOF
[D-BUS Service]
Name=org.apps.PlasmaHelper
Exec=$INSTALL_BIN/plasma_helper
EOF
            run_su "chmod 644 \"$INSTALL_DBUS/org.apps.PlasmaHelper.service\""
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
}

# ---------------------------------------------------------
#  Remove
# ---------------------------------------------------------

remove_file() {
    local path="$1"

    if [[ -e "$path" ]]; then
        run_su "rm -rf \"$path\""
        ok "Removed $(basename "$path")"
    else
        warn "$(basename "$path") not found"
    fi
}

# ---------------------------------------------------------
#  Main menu
# ---------------------------------------------------------
echo "--------------------------------------------"
echo " PopupTileLauncher Installer"
echo "--------------------------------------------"
echo "1) Install full widget (plasmoid + helper)"
echo "2) Uninstall"
echo "3) Install only helper/launcher (if the widget is installed earlier)"
echo "4) Exit"
echo "-----------------------"
read -rp "Choose option: " CHOICE
echo "--------------------------------------------"

case "$CHOICE" in
    1)
        # ---------- Detect distro ----------
        detect_distro
        paths_dependencies
        detect_existing_widget

        if [[ -n "$INSTALLED_PATH" ]]; then
            warn "Widget already installed at: $INSTALLED_PATH"
            read -rp "Overwrite? (y/n): " OW
            [[ "$OW" != "y" ]] && exit 0

            installation_type
        else
        installation_type
        fi

        set_install_paths

        # ---------- Ask service mode ----------
        echo "Select helper startup method:"
        echo "  1) DBus activation (recommended)"
        echo "  2) systemd user service"
        echo "-----------------------"
        read -rp "Your choice [1/2]: " SERVICE_MODE
        echo "--------------------------------------------"

        # ---------- Detect or Download local source ----------
        local_src
        # ---------- Check dependencies ----------
        check_dependencies
        # ---------- Build & install helper ----------
        install_helper
        # ---------- Plasmoid version check/install ----------

        INSTALLED_META="$INSTALL_PLASMOID/$WIDGET_ID/metadata.json"
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

        if [[ "$NEED_INSTALL" == "1" ]]; then
            run_su "mkdir -p \"$INSTALL_PLASMOID/$WIDGET_ID\""

            run_su "cp -r \
                \"$PLASMOID_DIR/contents\" \
                \"$PLASMOID_DIR/LICENSE\" \
                \"$PLASMOID_DIR/metadata.json\" \
                \"$PLASMOID_DIR/README.md\" \
                \"$INSTALL_PLASMOID/$WIDGET_ID\""

            ok "Plasmoid installed/updated"

            # ---------- Permissions for system installation ----------
            if [[ "$NEED_SUDO" == "1" ]]; then
                sudo find "$INSTALL_PLASMOID/$WIDGET_ID" -type d -exec chmod 755 {} \;
                sudo find "$INSTALL_PLASMOID/$WIDGET_ID" -type f -exec chmod 644 {} \;
                ok "Permissions set for system plasmoid"
            fi

        else
            ok "Plasmoid installation skipped"
        fi

        service_install
        echo -e "${YELLOW}===========================================================${RESET}"
        ok "Installation complete!"
        ok "Restart Plasma session to apply environment changes."
        echo -e "${YELLOW}===========================================================${RESET}"
        ;;

    2)
        installation_type
        detect_distro

        # ---------- Set paths & dependencies ----------
        paths_dependencies
        set_install_paths

        echo
        info "Uninstalling Popup Tile Launcher..."

        if [[ -e "$INSTALL_QML" ]]; then
            info "need priv for remove module."
            sudo rm -rf "$INSTALL_QML"
            ok "Removed QML module"
        else
            warn "QML module not found"
        fi
        remove_file "$INSTALL_BIN/plasma_helper"
        remove_file "$INSTALL_BIN/launcher"
        remove_file "$INSTALL_DBUS/org.apps.PlasmaHelper.service"
        remove_file "$INSTALL_XHR/enable_qml_xhr.sh"
        remove_file "$INSTALL_PLASMOID/$WIDGET_ID"
        remove_file "$REAL_HOME/.local/share/plasma_helper"
        remove_file "$REAL_HOME/.config/kde.org/plasmashell.conf"

        systemctl --user disable --now plasmahelper.service 2>/dev/null && ok "Disabled systemd user service" || true
        remove_file "$REAL_HOME/.config/systemd/user/plasmahelper.service"
        echo
        ok "Uninstall complete!"
        exit 0
        ;;

    3)
        info "Installing helper only..."
        installation_type
        detect_distro
        paths_dependencies
        set_install_paths
        # ---------- Detect or Download local source ----------
        local_src
        # ---------- Check dependencies ----------
        check_dependencies
        # ---------- Build & install helper ----------
        install_helper
        ok "helper, launcher and module install success."
        # ---------- Ask service mode ----------
        echo "--------------------------------------------"
        echo "Select helper startup method:"
        echo "  1) DBus activation (recommended)"
        echo "  2) systemd user service"
        echo "  3) Skip / Exit"
        echo "-----------------------"
        read -rp "Your choice [1/2/3]: " SERVICE_MODE
        echo "--------------------------------------------"

        if [[ "$SERVICE_MODE" == "3" ]]; then
            info "Skipping service installation."
            exit 0
        fi
        service_install
        ;;

    4)
        exit 0
        ;;

    *)
        error "Invalid choice."
        exit 1
        ;;
esac
