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
TOMCAT_CONF_DIR="$LOCAL_BASE_DIR/conf"
CATALOG_DIR="$LOCAL_BASE_DIR/content/thredds"
PUBLIC_DATA_DIR="$LOCAL_BASE_DIR/content/thredds/public/thredds_data"
LOGS_DIR="$LOCAL_BASE_DIR/logs"

# Create necessary directories
echo "Creating directories..."
mkdir -p "$TOMCAT_CONF_DIR"
mkdir -p "$CATALOG_DIR"
mkdir -p "$PUBLIC_DATA_DIR"
mkdir -p "$LOGS_DIR"

# Download configuration files from S3
echo "Downloading configuration files from S3..."
aws s3 cp "s3://$S3_BUCKET_NAME/$S3_PREFIX/tomcat-users.xml" "$TOMCAT_CONF_DIR/tomcat-users.xml"
aws s3 cp "s3://$S3_BUCKET_NAME/$S3_PREFIX/catalog.xml" "$CATALOG_DIR/catalog.xml"
aws s3 cp "s3://$S3_BUCKET_NAME/$S3_PREFIX/threddsConfig.xml" "$CATALOG_DIR/threddsConfig.xml"

# Verify files were downloaded
if [[ -f "$TOMCAT_CONF_DIR/tomcat-users.xml" && -f "$CATALOG_DIR/catalog.xml" && -f "$CATALOG_DIR/threddsConfig.xml" ]]; then
    echo "Configuration files downloaded successfully."
else
    echo "Error: One or more configuration files could not be downloaded."
    exit 1
fi

# Set permissions for ECS task
echo "Setting permissions..."
chmod -R 755 "$LOCAL_BASE_DIR"

echo "Setup complete. Config files are available at $LOCAL_BASE_DIR"
