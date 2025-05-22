#!/bin/bash
set -e

# ──────────────────────────────────────────────────────────────────────────────
# CONFIG
DOTNET_DIR=/home/ubuntu/dotnet
REPO_URL=https://github.com/khaled-hamada/aws-90-srv-02.git
APP_DIR=/home/ubuntu/aws-90-srv-02
SERVICE_NAME=srv-02
# ──────────────────────────────────────────────────────────────────────────────

echo "Installing system prerequisites…"
sudo apt-get update
sudo apt-get install -y git unzip curl

echo "Installing .NET SDK 6.0 manually…"
# wipe any old install
sudo rm -rf $DOTNET_DIR
mkdir -p $DOTNET_DIR
cd $DOTNET_DIR

# correct SDK tarball URL for 6.0.420
wget https://builds.dotnet.microsoft.com/dotnet/Sdk/6.0.420/dotnet-sdk-6.0.420-linux-x64.tar.gz -O dotnet-sdk.tar.gz
tar -xzf dotnet-sdk.tar.gz
rm dotnet-sdk.tar.gz

echo "Verifying .NET install:"
$DOTNET_DIR/dotnet --version

echo "Cloning your GitHub repo…"
cd /home/ubuntu
# clone as ubuntu user
sudo -u ubuntu git clone $REPO_URL
cd $APP_DIR

echo "Publishing the .NET app…"
# ensure CLI first-use can write
export DOTNET_CLI_HOME=/tmp
# always call dotnet via full path
$DOTNET_DIR/dotnet publish -c Release --self-contained=false --runtime linux-x64

echo "Locating the published DLL…"
PUBLISH_DIR=$(find bin/Release -type d -name publish | head -n1)
if [ -z "$PUBLISH_DIR" ]; then
  echo "❌ No publish directory!" >&2
  exit 1
fi
PUBLISHED_DLL=$(find "$PUBLISH_DIR" -maxdepth 1 -type f -name "*.dll" | head -n1)
if [ -z "$PUBLISHED_DLL" ]; then
  echo "❌ No .dll in $PUBLISH_DIR!" >&2
  exit 1
fi
echo "Found: $PUBLISHED_DLL"

echo "Writing systemd unit…"
# tee under sudo so the file is created with root perms
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=Dotnet S3 info service

[Service]
ExecStart=$DOTNET_DIR/dotnet $APP_DIR/$PUBLISHED_DLL
WorkingDirectory=$APP_DIR
SyslogIdentifier=$SERVICE_NAME
Restart=always
User=ubuntu

Environment=DOTNET_CLI_HOME=/tmp
Environment=DOTNET_ROOT=$DOTNET_DIR
Environment=PATH=$DOTNET_DIR:\$PATH

[Install]
WantedBy=multi-user.target
EOF

echo "Enabling & starting service…"
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME

echo "Final status:"
sudo systemctl status $SERVICE_NAME --no-pager
