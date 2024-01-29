#!/bin/bash
# Sample string
my_string="appe_my_string"

# Check if the string starts with "mros"
if [[ $my_string != mros* ]]; then
    # If it doesn't start with "mros", append "mros" to the front
    my_string="mros_$my_string"
fi

echo "$my_string"
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

# # Base project directory
# BASE_DIR=${1:-"/Users/anguswatters/Desktop/github/rainOrSnowTools"}

# Check if the BASE_DIR is provided as a command-line argument, if so, use it, otherwise use the current directory
if [ -z "$1" ] || [ "$1" == "." ]; then
    BASE_DIR=$(pwd)  # Use the current directory if no argument is provided
    echo "BASE_DIR not provided, using current directory: $BASE_DIR"
    echo "pwd: $(pwd)"
else
    BASE_DIR=$1
fi

echo "BASE_DIR: $BASE_DIR"

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
        RELATIVE_ZIP_FILE="../deploy/$DIR_NAME.zip"  # Relative path to the ZIP file

        echo "--------------------------------------------------------------"
        echo "---- Creating lambda package: '$DIR_NAME' ----"
        echo "--------------------------------------------------------------"

        # echo "- SUBDIR: $SUBDIR"
        echo "- DIR_NAME: $DIR_NAME"
        # echo "- PKG_DIR: $PKG_DIR"
        # echo "- TARGET_DIR: $TARGET_DIR"
        echo "- ZIP_FILE: $ZIP_FILE"
        echo "- RELATIVE_ZIP_FILE: $RELATIVE_ZIP_FILE"
        echo "------------------------------------------------"

        # echo "Making temporary directory for Python packages"

        # # # # Ensure the "PKG_DIR" directory exists
        # # mkdir -p "$PKG_DIR"

        # echo "Installing Python packages from 'requirements.txt to 'PKG_DIR'"

        # # pip install \
        # #     --platform manylinux2014_x86_64 \
        # #     --target "$PKG_DIR" \
        # #     --implementation cp \
        # #     --python-version 3.11 \
        # #     --only-binary=:all: --upgrade \
        # #     -r "$SUBDIR/requirements.txt"


        # echo "Removing 'tests', 'examples', and '__pycache__' files from package directory"

        # # # # # Remove unwanted directories (tests/, docs/, examples/, __pycache__/)
        # # find "$PKG_DIR" -type d -name "tests" -exec rm -rf {} +
        # # # find "$PKG_DIR" -type d -name "docs" -exec rm -rf {} +
        # # find "$PKG_DIR" -type d -name "examples" -exec rm -rf {} +
        # # find "$PKG_DIR" -type d -name "__pycache__" -exec rm -rf {} +

        # # Go into the PKG_DIR directory
        # cd "$PKG_DIR" 

        # echo "------------------------------------------------"
        # echo "Zipping 'PKG_DIR' contents into 'ZIP_FILE'..."

        # # echo -e "PKG_DIR: $PKG_DIR\n---> ZIP_FILE:\n --> $ZIP_FILE"
        # echo "Sending PKG_DIR contents to ZIP_FILE:"
        # echo -e " PKG_DIR: '$PKG_DIR' \n   --------> \n ZIP_FILE: '$ZIP_FILE'"
        # echo "------------------------------------------------"

        # # # Create the initial ZIP file with the Python packages
        # # zip -r9 "$ZIP_FILE" .

        # # Go back to the original directory
        # cd "$BASE_DIR/$APP_DIR/"

        # echo "Updated ZIP_FILE with DIR_NAME contents"
        # # echo "Updated '$ZIP_FILE' with '$DIR_NAME' contents"

        # # For all directories except "app", add the contents of the given lambdas/ subdirectory (DIR_NAME) 
        # # to the ZIP file EXCLUDING the "config.py" file
        # echo -e "Adding '$DIR_NAME' contents to:\n '$ZIP_FILE'\n(EXCLUDING 'config.py' file)"
        # # Add the contents of the given lambdas/ subdirectory (DIR_NAME) to the ZIP file, (EXCLUDE the "config.py" file)
        # # zip -g "$ZIP_FILE" -r "$DIR_NAME" -x "$DIR_NAME/config.py"

        # ZIP_FILE_PATH="$DEPLOY_DIR/$DIR_NAME.zip"
        # echo "ZIP_FILE_PATH: $ZIP_FILE_PATH"
        # # create a variable by concatenating "TF_VAR_" and $DIR_NAME 
        # # (e.g. "TF_VAR_lambda1" for "lambda1" directory)
        # TF_VAR_DIR_NAME="TF_VAR_$DIR_NAME"

        # echo "TF_VAR_DIR_NAME: $TF_VAR_DIR_NAME"

        # echo "Removing $PKG_DIR"

        # remove the PKG_DIR directory
        # rm -rf "$PKG_DIR"
        # Replace ".zip" with "_zip" in the file name

        # TF_VAR_NAME="${DIR_NAME%.zip}_zip"
        # # Export the relative zip file path as an environment variable with TF_VAR_<DIR_NAME>
        # export "TF_VAR_$TF_VAR_NAME"="$RELATIVE_ZIP_FILE"

        # echo "Exported TF_VAR_$TF_VAR_NAME: $RELATIVE_ZIP_FILE"
        
        # Check if the string starts with "mros", if it doesn't, append "mros" to the front
        if [[ $DIR_NAME != mros* ]]; then
            # If it doesn't start with "mros", append "mros" to the front
            LAMBDA_FUNCTION_NAME="mros_$DIR_NAME"
            # Replace "_" with "-"
            LAMBDA_FUNCTION_NAME=${LAMBDA_FUNCTION_NAME//_/\-}
        else
            LAMBDA_FUNCTION_NAME="$DIR_NAME"
            # Replace "_" with "-"
            LAMBDA_FUNCTION_NAME=${LAMBDA_FUNCTION_NAME//_/\-}

        fi

        echo "LAMBDA_FUNCTION_NAME: $LAMBDA_FUNCTION_NAME"

        # ---- NAME TO USAE FOR THE LAMBDA FUNCTION ON AWS exported as: ----
        # ---- "TF_VAR_<DIR_NAME>_lambda_function_name" = "$LAMBDA_FUNCTION_NAME" ----
        
        # Create a TF variable name from the directory name
        TF_VAR_FUNCTION_NAME="${DIR_NAME}_lambda_function_name"

        echo "TF_VAR_FUNCTION_NAME: $TF_VAR_FUNCTION_NAME"

        export "TF_VAR_$TF_VAR_FUNCTION_NAME"="$LAMBDA_FUNCTION_NAME"

        echo "Exported TF_VAR_$TF_VAR_FUNCTION_NAME: $LAMBDA_FUNCTION_NAME"

        # ---- NAME OF THE ZIP FILE FOR THE LAMBDA FUNCTION exported as: ----
        # ---- "TF_VAR_<DIR_NAME>_lambda_zip_file_name" = "$DIR_NAME.zip" ----

        # Create a TF variable name from the directory name
        TF_VAR_FUNCTION_ZIP_FILENAME="${DIR_NAME}_lambda_zip_file_name"

        echo "TF_VAR_FUNCTION_ZIP_FILENAME: $TF_VAR_FUNCTION_ZIP_FILENAME"

        export "TF_VAR_$TF_VAR_FUNCTION_ZIP_FILENAME"="${DIR_NAME}.zip"

        echo "Exported TF_VAR_$TF_VAR_FUNCTION_ZIP_FILENAME: ${DIR_NAME}.zip"

        cd "$BASE_DIR"
        
        echo "====================================================="
        echo "====================================================="
    fi
done
