#!/bin/bash
# Create lambda function zip files for each subdirectory under "lambdas/".
# Loops through the subdirectories under "lambdas/" and create a ZIP file for each, 
# including the Python packages from "requirements.txt" in each subdirectory. 
# Each lambda function directory in "lambdas/" should have a "requirements.txt" file and
# a python script that will be used for the lambda function.

# Output: "deploy" directory will be created in the root directory, and the ZIP files will be placed there.

# Example directory structure:
# root/
#   lambdas/
#     lambda1/
#       lambda1.py
#       requirements.txt
#     lambda2/
#       lambda2.py
#       requirements.txt
#     lambda3/
#       lambda3.py
#       requirements.txt

# Base project directory
BASE_DIR=${1:-"/Users/anguswatters/Desktop/github/rainOrSnowTools"}

# Set the deploy directory
DEPLOY_DIR="$BASE_DIR/deploy"

# Set the app directory name (where the lambda functions are located, each lambda function in its own subdirectory)
APP_DIR="lambdas"

echo "Creating deploy directory if it doesn't exist"
echo "DEPLOY_DIR:\n --> $DEPLOY_DIR"

# Creating the deploy directory
mkdir -p "$DEPLOY_DIR"

# Iterate through each subdirectory under "lambda/"
for SUBDIR in "$BASE_DIR/$APP_DIR"/*; do
    if [ -d "$SUBDIR" ]; then
        # Extract the directory name
        DIR_NAME=$(basename "$SUBDIR")

        # Set the target directory and ZIP file for the current subdirectory
        PKG_DIR="$BASE_DIR/$APP_DIR/package"
        TARGET_DIR="$SUBDIR/package"
        ZIP_FILE="$DEPLOY_DIR/$DIR_NAME.zip"

        echo "------------------------------------------------"
        echo "---- Creating lambda package for $DIR_NAME  ----"
        echo "------------------------------------------------"

        echo "- SUBDIR: $SUBDIR"
        echo "- DIR_NAME: $DIR_NAME"
        echo "- PKG_DIR: $PKG_DIR"
        echo "- TARGET_DIR: $TARGET_DIR"
        echo "- ZIP_FILE: $ZIP_FILE"
        echo "------------------------------------------------"

        echo "Making temporary directory for Python packages"

        # # Ensure the "PKG_DIR" directory exists
        mkdir -p "$PKG_DIR"

        echo "Installing Python packages from 'requirements.txt to 'PKG_DIR'"

        pip install \
            --platform manylinux2014_x86_64 \
            --target "$PKG_DIR" \
            --implementation cp \
            --python-version 3.11 \
            --only-binary=:all: --upgrade \
            -r "$SUBDIR/requirements.txt"
        
        # Go into the PKG_DIR directory
        cd "$PKG_DIR" 

        echo "Zipping 'PKG_DIR' contents into 'ZIP_FILE'..."

        echo "PKG_DIR: $PKG_DIR\n---> ZIP_FILE:\n --> $ZIP_FILE"
        
        # Create the initial ZIP file with the Python packages
        zip -r9 "$ZIP_FILE" .

        # Go back to the original directory
        cd "$BASE_DIR/$APP_DIR/"

        echo "Updated $ZIP_FILE with $DIR_NAME contents"
        
        # Add the contents of the given lambdas/ subdirectory (DIR_NAME) to the ZIP file
        # zip -g "$ZIP_FILE" -r "$DIR_NAME"
        zip -g "$ZIP_FILE" -r "$DIR_NAME" -x "$DIR_NAME/config.py"

        echo "Removing $PKG_DIR"

        # remove the PKG_DIR directory
        rm -rf "$PKG_DIR"

        cd "$BASE_DIR"

        echo "====================================================="
        echo "====================================================="
    fi
done
