#!/bin/bash

# Set your target directory for packages and the destination ZIP file
BASE_DIR=${1:-"/Users/anguswatters/Desktop/github/mros_private"}
DEPLOY_DIR="$BASE_DIR/deploy"
ZIP_FILE="$BASE_DIR/lambda_function.zip"
TARGET_DIR="$BASE_DIR/package"
ZIP_NAME="lambda_function.zip"
APP_DIR="app"

# Install Python packages
pip install \
  --platform manylinux2014_x86_64 \
  --target "$TARGET_DIR" \
  --implementation cp \
  --python-version 3.11 \
  --only-binary=:all: --upgrade \
  python-dotenv==1.0.0 requests==2.31.0 pandas==2.0.3 boto3==1.28.42 s3fs==2023.10.0

echo "Installed packages to: $TARGET_DIR"

# Go into the target directory
cd "$TARGET_DIR"

# Create the initial ZIP file with the Python packages
zip -r9 "$ZIP_FILE" .

echo "Zipped $TARGET_DIR contents into $ZIP_FILE"

# Go back to the original directory
cd "$BASE_DIR"

# Add the contents of the "app" directory to the ZIP file
zip -g "./$ZIP_NAME" -r "$APP_DIR"

echo "Updating $ZIP_FILE with $APP_DIR contents"

# Create the "deploy" directory and move the ZIP file
DEPLOY_DIR="$BASE_DIR/deploy"
mkdir -p "$DEPLOY_DIR"
mv "$ZIP_NAME" "$DEPLOY_DIR"

echo "Created 'deploy' directory and moved $ZIP_NAME into it"

# Delete the "package" directory
rm -rf "$TARGET_DIR"
echo "Deleted 'package' directory"
