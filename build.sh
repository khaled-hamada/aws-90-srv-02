#!/bin/bash

# Update packages
apt update

echo "🔧 Installing prerequisites"
apt install -y git unzip curl

# Create dotnet install dir
echo "💿 Installing .NET SDK 6 manually"
mkdir -p /home/ubuntu/dotnet
cd /home/ubuntu/dotnet

# Download SDK 6.0.420 for Linux x64
wget https://download.visualstudio.microsoft.com/download/pr/64022ae0-d1f7-49e3-8dc4-47c005ed8f9f/62648ac8fdc3c7cde3013487816f8a55/dotnet-sdk-6.0.420-linux-x64.tar.gz

# Extract SDK
tar -xzf dotnet-sdk-6.0.420-linux-x64.tar.gz

# Export dotnet to path
echo 'export DOTNET_ROOT=/home/ubuntu/dotnet' >> /home/ubuntu/.bashrc
echo 'export PATH=$PATH:/home/ubuntu/dotnet' >> /home/ubuntu/.bashrc
export DOTNET_ROOT=/home/ubuntu/dotnet
export PATH=$PATH:/home/ubuntu/dotnet

# Verify install
dotnet --version

# Clone your GitHub repo
cd /home/ubuntu
echo "📦 Cloning GitHub repository"
sudo -u ubuntu git clone https://github.com/khaled-hamada/aws-90-srv-02.git
cd aws-90-srv-02

# Build and publish
echo "🏗️ Building the .NET app"
dotnet publish -c Release --self-contained=false --runtime linux-x64

# Find the DLL name automatically (fallback to default name if not detected)
PUBLISHED_DLL=$(find bin/Release/net6.0/linux-x64 -type f -name "*.dll" | head -n 1)

# Create systemd service file
echo "⚙️ Creating systemd service"

cat >/etc/systemd/system/srv-02.service <<EOL
[Unit]
Description=Dotnet S3 info service

[Service]
ExecStart=/home/ubuntu/dotnet/dotnet $PUBLISHED_DLL
WorkingDirectory=/home/ubuntu/aws-90-srv-02
SyslogIdentifier=srv-02
Restart=always
User=ubuntu
Environment=DOTNET_CLI_HOME=/temp
Environment=DOTNET_ROOT=/home/ubuntu/dotnet
Environment=PATH=/home/ubuntu/dotnet:\$PATH

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and enable service
echo "🔁 Reloading and starting service"
systemctl daemon-reload
systemctl enable srv-02
systemctl start srv-02

# Show status
systemctl status srv-02 --no-pager
