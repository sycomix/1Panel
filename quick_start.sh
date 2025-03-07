#!/bin/bash

# Function to check and install dependencies
check_and_install_deps() {
    # Check package manager and set installation commands
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        PKG_UPDATE="apt-get update"
        PKG_INSTALL="apt-get install -y"
        CURL_INSTALL="apt-get install -y curl"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum update -y"
        PKG_INSTALL="yum install -y"
        CURL_INSTALL="yum install -y curl"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf update -y"
        PKG_INSTALL="dnf install -y"
        CURL_INSTALL="dnf install -y curl"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
        PKG_UPDATE="zypper refresh"
        PKG_INSTALL="zypper install -y"
        CURL_INSTALL="zypper install -y curl"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        PKG_UPDATE="pacman -Sy"
        PKG_INSTALL="pacman -S --noconfirm"
        CURL_INSTALL="pacman -S --noconfirm curl"
    else
        echo "No supported package manager found (apt, yum, dnf, zypper, or pacman)"
        echo "Please install the following dependencies manually:"
        echo "- Go (version 1.16 or higher)"
        echo "- Node.js (version 16 or higher)"
        echo "- npm (latest version)"
        exit 1
    fi

    # Ensure curl is installed
    if ! command -v curl &> /dev/null; then
        echo "Installing curl..."
        sudo $CURL_INSTALL
    fi

    # Update package lists
    echo "Updating package lists..."
    sudo $PKG_UPDATE

    # Install Go
    install_golang() {
        echo "Installing Go..."
        # Download and install latest Go version
        GO_VERSION="1.21.6"  # Latest stable version as of 2024
        GOLANG_URL="https://go.dev/dl/go${GO_VERSION}.linux-${architecture}.tar.gz"
        
        # Remove any existing Go installation
        sudo rm -rf /usr/local/go
        
        # Download and extract Go
        curl -LO $GOLANG_URL
        sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-${architecture}.tar.gz
        rm go${GO_VERSION}.linux-${architecture}.tar.gz
        
        # Set up Go environment
        echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
        source /etc/profile.d/go.sh
    }

    # Check Go version and install if needed
    if ! command -v go &> /dev/null; then
        echo "Go not found. Installing..."
        install_golang
    else
        GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        if [[ "$(echo -e "1.16\n$GO_VERSION" | sort -V | head -n1)" == "1.16" ]]; then
            echo "✓ Go version $GO_VERSION is sufficient"
        else
            echo "Go version $GO_VERSION is too old. Installing newer version..."
            install_golang
        fi
    fi

    # Install Node.js and npm
    install_nodejs() {
        echo "Installing Node.js and npm..."
        if [[ "$PKG_MANAGER" == "apt-get" ]]; then
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo $PKG_INSTALL nodejs
        elif [[ "$PKG_MANAGER" == "yum" || "$PKG_MANAGER" == "dnf" ]]; then
            curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
            sudo $PKG_INSTALL nodejs
        elif [[ "$PKG_MANAGER" == "zypper" ]]; then
            sudo zypper addrepo https://download.opensuse.org/repositories/devel:/languages:/nodejs/15.4/devel:languages:nodejs.repo
            sudo zypper refresh
            sudo $PKG_INSTALL nodejs18
        elif [[ "$PKG_MANAGER" == "pacman" ]]; then
            sudo $PKG_INSTALL nodejs npm
        fi
    }

    # Check Node.js and npm versions
    if ! command -v node &> /dev/null; then
        echo "Node.js not found. Installing..."
        install_nodejs
    else
        NODE_VERSION=$(node -v | sed 's/v//')
        if [[ "$(echo -e "16.0.0\n$NODE_VERSION" | sort -V | head -n1)" == "16.0.0" ]]; then
            echo "✓ Node.js version $NODE_VERSION is sufficient"
        else
            echo "Node.js version $NODE_VERSION is too old. Installing newer version..."
            install_nodejs
        fi
    fi

    # Verify installations and versions
    echo "Verifying installations..."
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version)
        echo "✓ Go: $GO_VERSION"
    else
        echo "✗ Go installation failed"
        exit 1
    fi

    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v)
        echo "✓ Node.js: $NODE_VERSION"
    else
        echo "✗ Node.js installation failed"
        exit 1
    fi

    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm -v)
        echo "✓ npm: $NPM_VERSION"
    else
        echo "✗ npm installation failed"
        exit 1
    fi

    echo "All dependencies installed successfully!"
}

osCheck=$(uname -a)
if [[ $osCheck =~ 'x86_64' ]]; then
    architecture="amd64"
elif [[ $osCheck =~ 'arm64' ]] || [[ $osCheck =~ 'aarch64' ]]; then
    architecture="arm64"
elif [[ $osCheck =~ 'armv7l' ]]; then
    architecture="armv7"
elif [[ $osCheck =~ 'ppc64le' ]]; then
    architecture="ppc64le"
elif [[ $osCheck =~ 's390x' ]]; then
    architecture="s390x"
else
    echo "The system architecture is not currently supported. Please refer to the official documentation to select a supported system."
    exit 1
fi

# Check and install dependencies
echo "Checking and installing dependencies..."
check_and_install_deps

# Use local project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
CORE_NAME="1panel-core"
AGENT_NAME="1panel-agent"

# Clean and create build directory
echo "Preparing build environment..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build frontend
echo "Building frontend..."
cd "${SCRIPT_DIR}/frontend" || exit 1
if ! npm install; then
    echo "Failed to install frontend dependencies"
    exit 1
fi
if ! npm run build:pro; then
    echo "Failed to build frontend"
    exit 1
fi

# Build core
echo "Building core component..."
cd "${SCRIPT_DIR}/core" || exit 1
if ! GOOS=linux GOARCH=${architecture} go build -trimpath -ldflags '-s -w' -o "${BUILD_DIR}/${CORE_NAME}" cmd/server/main.go; then
    echo "Failed to build core component"
    exit 1
fi

# Build agent
echo "Building agent component..."
cd "${SCRIPT_DIR}/agent" || exit 1
if ! GOOS=linux GOARCH=${architecture} go build -trimpath -ldflags '-s -w' -o "${BUILD_DIR}/${AGENT_NAME}" cmd/server/main.go; then
    echo "Failed to build agent component"
    exit 1
fi

# Copy necessary files
echo "Preparing installation files..."
if ! cp -r "${SCRIPT_DIR}/frontend/dist" "${BUILD_DIR}/web"; then
    echo "Failed to copy frontend dist files"
    exit 1
fi
if ! cp -r "${SCRIPT_DIR}/core/scripts" "${BUILD_DIR}/scripts"; then
    echo "Failed to copy core scripts"
    exit 1
fi

# Generate install script
cat > "${BUILD_DIR}/install.sh" << 'EOF'
#!/bin/bash

# Installation directories
INSTALL_DIR="/usr/local/1panel"
DATA_DIR="/usr/local/1panel/data"
SYSTEMD_DIR="/etc/systemd/system"

# Create installation directories
if ! mkdir -p "${INSTALL_DIR}"; then
    echo "Failed to create installation directory"
    exit 1
fi
if ! mkdir -p "${DATA_DIR}"; then
    echo "Failed to create data directory"
    exit 1
fi

# Copy files
if ! cp -r ./* "${INSTALL_DIR}/"; then
    echo "Failed to copy installation files"
    exit 1
fi

# Create systemd service files
cat > "${SYSTEMD_DIR}/1panel.service" << 'EOFS'
[Unit]
Description=1Panel Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/1panel/1panel-core
WorkingDirectory=/usr/local/1panel
Restart=always

[Install]
WantedBy=multi-user.target
EOFS

cat > "${SYSTEMD_DIR}/1panel-agent.service" << 'EOFS'
[Unit]
Description=1Panel Agent Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/1panel/1panel-agent
WorkingDirectory=/usr/local/1panel
Restart=always

[Install]
WantedBy=multi-user.target
EOFS

# Set permissions
if ! chmod +x "${INSTALL_DIR}/1panel-core"; then
    echo "Failed to set permissions for core"
    exit 1
fi
if ! chmod +x "${INSTALL_DIR}/1panel-agent"; then
    echo "Failed to set permissions for agent"
    exit 1
fi

# Enable and start services
if ! sudo systemctl daemon-reload; then
    echo "Error: Failed to reload systemd daemon. Please check your permissions."
    exit 1
fi

if ! sudo systemctl enable 1panel.service; then
    echo "Error: Failed to enable 1panel service. Please check your permissions."
    exit 1
fi

if ! sudo systemctl enable 1panel-agent.service; then
    echo "Error: Failed to enable 1panel-agent service. Please check your permissions."
    exit 1
fi

if ! sudo systemctl start 1panel.service; then
    echo "Error: Failed to start 1panel service. Please check your permissions."
    echo "You can try running: sudo systemctl start 1panel.service"
    exit 1
fi

if ! sudo systemctl start 1panel-agent.service; then
    echo "Error: Failed to start 1panel-agent service. Please check your permissions."
    echo "You can try running: sudo systemctl start 1panel-agent service"
    exit 1
fi

echo "1Panel installation completed successfully!"
echo "You can access the panel through your browser"
EOF

# Make install script executable
chmod +x "${BUILD_DIR}/install.sh"

# Run installation
echo "Starting installation..."
cd "${BUILD_DIR}" || exit 1
if ! /bin/bash install.sh; then
    echo "Installation failed. Please check the error messages above."
    exit 1
fi
