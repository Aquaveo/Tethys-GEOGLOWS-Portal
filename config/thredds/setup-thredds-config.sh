#!/bin/bash

# Check if the correct number of arguments are provided
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <S3_BUCKET_NAME> <S3_PREFIX> <LOCAL_BASE_DIR>"
    exit 1
fi

# Arguments
S3_BUCKET_NAME="$1"
S3_PREFIX="$2"
LOCAL_BASE_DIR="$3"

# Directories for configuration files
CONF_DIR="$LOCAL_BASE_DIR/conf"
PUBLIC_DATA_DIR="$LOCAL_BASE_DIR/data"
THREDDS_LOGS_DIR="$LOCAL_BASE_DIR/logs/thredds"
TOMCAT_LOGS_DIR="$LOCAL_BASE_DIR/logs/tomcat"

# Create necessary directories
echo "Creating directories..."
mkdir -p "$CONF_DIR"
mkdir -p "$PUBLIC_DATA_DIR"
mkdir -p "$THREDDS_LOGS_DIR"
mkdir -p "$TOMCAT_LOGS_DIR"

# Download configuration files from S3
echo "Downloading configuration files from S3..."
aws s3 cp "s3://$S3_BUCKET_NAME/$S3_PREFIX/tomcat-users.xml" "$CONF_DIR/tomcat-users.xml"
aws s3 cp "s3://$S3_BUCKET_NAME/$S3_PREFIX/catalog.xml" "$CONF_DIR/catalog.xml"
aws s3 cp "s3://$S3_BUCKET_NAME/$S3_PREFIX/threddsConfig.xml" "$CONF_DIR/threddsConfig.xml"

# Verify files were downloaded
if [[ -f "$CONF_DIR/tomcat-users.xml" && -f "$CONF_DIR/catalog.xml" && -f "$CONF_DIR/threddsConfig.xml" ]]; then
    echo "Configuration files downloaded successfully."
else
    echo "Error: One or more configuration files could not be downloaded."
    exit 1
fi

# Set permissions for ECS task
echo "Setting permissions..."
chmod -R 755 "$LOCAL_BASE_DIR"

echo "Setup complete. Config files are available at $LOCAL_BASE_DIR"
