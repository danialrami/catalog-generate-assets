#!/bin/bash

# Get the absolute path to the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create a temporary script that will run in the new terminal
TEMP_SCRIPT=$(mktemp /tmp/asset_generator.command)
chmod +x "$TEMP_SCRIPT"

# Get absolute paths to Python scripts
ALBUM_ARTWORK_PY="$SCRIPT_DIR/v7_album_artwork.py"
CANVAS_GENERATOR_PY="$SCRIPT_DIR/canvas_generator.py"
# Add additional scripts here when needed
# ADDITIONAL_SCRIPT_PY="$SCRIPT_DIR/your_additional_script.py"

# Get command line arguments if any
AUDIO_FILE_ARG=""
if [ $# -gt 0 ]; then
    AUDIO_FILE_ARG="$1"
fi

# Write the actual script to the temporary file - using 'EOF' without quotes 
# to allow variable expansion for the script paths
cat > "$TEMP_SCRIPT" << EOF
#!/bin/bash

# Add common binary locations to PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory - use the original script directory
SCRIPT_DIR="$SCRIPT_DIR"

# Function to show notification
show_notification() {
    osascript -e "display notification \"\$1\" with title \"Asset Generator\""
}

# Virtual environment name and path
VENV_NAME="audio_assets_env"
VENV_PATH="\$SCRIPT_DIR/\$VENV_NAME"

# Path to Python scripts
ALBUM_ARTWORK_PY="$ALBUM_ARTWORK_PY"
CANVAS_GENERATOR_PY="$CANVAS_GENERATOR_PY"

# Function to check if a command exists
command_exists() {
    command -v "\$1" >/dev/null 2>&1
}

# Function to display error and exit
error_exit() {
    echo -e "\${RED}ERROR: \$1\${NC}" >&2
    show_notification "ERROR: \$1"
    read -p "Press Enter to exit..." 
    exit 1
}

# Function to remove quotes from a string
remove_quotes() {
    # Remove both single and double quotes from the beginning and end of the string
    echo "\$1" | sed -e "s/^[\\"']//g" -e "s/[\\"']\$//g"
}

# Create a function to capture and filter output
run_with_filtered_output() {
    local OUTPUT_FILE=\$(mktemp)
    local DISPLAY_PROGRESS=true
    
    # Run the command and tee to a temporary file
    "\$@" 2>&1 | tee "\$OUTPUT_FILE" | while read -r line; do
        # Only show progress messages to the user, log everything
        if [[ "\$line" == *"Converting to MP4"* ]] || [[ "\$line" == *"canvas generated at:"* ]]; then
            echo -e "\${GREEN}\$line\${NC}"
        elif [[ "\$line" == *"Opening and processing"* ]] || [[ "\$line" == *"Resizing image"* ]] || 
             [[ "\$line" == *"Generating glitch effects"* ]] || [[ "\$line" == *"Applying crossfade"* ]] || 
             [[ "\$line" == *"Saving output files"* ]]; then
            echo -e "\${GREEN}\$line\${NC}"
        elif [[ "\$line" == *"ffmpeg version"* ]] && \$DISPLAY_PROGRESS; then
            echo -e "\${GREEN}FFmpeg processing video... (details in log)\${NC}"
            DISPLAY_PROGRESS=false
        elif [[ "\$line" == *"Welcome to the Album Artwork Generator"* ]] || 
             [[ "\$line" == *"Analyzing your audio"* ]] || 
             [[ "\$line" == *"Got it! Your audio hash"* ]] || 
             [[ "\$line" == *"Generating your unique identicon"* ]] || 
             [[ "\$line" == *"Album artwork v7 generated successfully"* ]] ||
             [[ "\$line" == *"Saved full rectangular spectrogram"* ]]; then
            echo -e "\${GREEN}\$line\${NC}"
        fi
    done
    
    # Append the full output to the log file
    if [ -f "\$FULL_LOG_FILE" ]; then
        cat "\$OUTPUT_FILE" >> "\$FULL_LOG_FILE"
    fi
    
    # Clean up
    rm -f "\$OUTPUT_FILE"
    
    # Return the exit code of the original command
    return \${PIPESTATUS[0]}
}

# Function for installing packages with minimal output
pip_install_quiet() {
    # Run pip install, capture output to variable
    OUTPUT=\$(pip install "\$@" 2>&1)
    
    # Check if there was an error
    if [ \$? -ne 0 ]; then
        echo -e "\${RED}Failed to install \$*\${NC}"
        # Show a condensed error
        echo "\$OUTPUT" | grep -E "ERROR:|Error:" 
        return 1
    fi
    
    # Check if already installed
    if echo "\$OUTPUT" | grep -q "Requirement already satisfied"; then
        echo -e "\${GREEN}✓ Package(s) already installed: \$*\${NC}"
    else
        echo -e "\${GREEN}✓ Successfully installed: \$*\${NC}"
    fi
    
    # Copy to log file if it exists
    if [ -f "\$FULL_LOG_FILE" ]; then
        echo "\$OUTPUT" >> "\$FULL_LOG_FILE"
    fi
    
    return 0
}

# Function to add a new script to the process
run_additional_script() {
    echo -e "\${GREEN}Running additional processing script...\${NC}"
    local SCRIPT_PATH="\$1"
    local INPUT_FILE="\$2"
    
    # Check if the script exists
    if [ ! -f "\$SCRIPT_PATH" ]; then
        echo -e "\${YELLOW}Warning: Additional script not found at \$SCRIPT_PATH. Skipping.\${NC}"
        return 1
    fi
    
    # Run the script with filtered output
    run_with_filtered_output python3 "\$SCRIPT_PATH" << PYEOF
\$INPUT_FILE
PYEOF
    
    return \$?
}

# Set up logging
setup_logging() {
    # Create full log file
    FULL_LOG_FILE="\$ASSETS_DIR/generation_log.txt"
    touch "\$FULL_LOG_FILE"
    
    # Log the start of the process with timestamp
    echo "===== Asset Generation Started at \$(date) =====" >> "\$FULL_LOG_FILE"
    echo "Audio File: \$AUDIO_FILE" >> "\$FULL_LOG_FILE"
    echo "Assets Directory: \$ASSETS_DIR" >> "\$FULL_LOG_FILE"
    echo "=========================================" >> "\$FULL_LOG_FILE"
    
    # Log system information
    echo "System Information:" >> "\$FULL_LOG_FILE"
    echo "- Operating System: \$(uname -s)" >> "\$FULL_LOG_FILE"
    echo "- Python Version: \$(python3 --version 2>&1)" >> "\$FULL_LOG_FILE"
    if command_exists ffmpeg; then
        echo "- FFmpeg Version: \$(ffmpeg -version | head -n1)" >> "\$FULL_LOG_FILE"
    else
        echo "- FFmpeg: Not installed" >> "\$FULL_LOG_FILE"
    fi
    echo "- NumPy Version: \$(pip show numpy | grep Version 2>&1)" >> "\$FULL_LOG_FILE"
    echo "=========================================" >> "\$FULL_LOG_FILE"
}

# Check if Python 3 is installed
if ! command_exists python3; then
    error_exit "Python 3 is not installed. Please install Python 3 and try again."
fi

# Check if ffmpeg is installed
if ! command_exists ffmpeg; then
    echo -e "\${YELLOW}WARNING: FFmpeg is not installed. It's required for MP4 conversion.\${NC}"
    read -p "Do you want to continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
        exit 1
    fi
fi

echo -e "\${GREEN}Setting up virtual environment...\${NC}"

# Check if virtualenv is installed
if ! command_exists python3 -m venv; then
    echo -e "\${YELLOW}Installing virtualenv...\${NC}"
    pip3 install virtualenv || error_exit "Failed to install virtualenv"
fi

# Create virtual environment if it doesn't exist
if [ ! -d "\$VENV_PATH" ]; then
    echo -e "\${GREEN}Creating virtual environment at \$VENV_PATH...\${NC}"
    python3 -m venv "\$VENV_PATH" || error_exit "Failed to create virtual environment"
fi

# Activate virtual environment
echo -e "\${GREEN}Activating virtual environment...\${NC}"
source "\$VENV_PATH/bin/activate" || error_exit "Failed to activate virtual environment"

# Get audio file path - handle command line args if present
if [ ! -z "$AUDIO_FILE_ARG" ]; then
    AUDIO_FILE="$AUDIO_FILE_ARG"
else
    # No argument provided, prompt user
    echo -n "Enter the path to your audio file: "
    read AUDIO_FILE_INPUT
    AUDIO_FILE=\$(remove_quotes "\$AUDIO_FILE_INPUT")
fi

# Check if file exists
if [ ! -f "\$AUDIO_FILE" ]; then
    error_exit "Audio file not found: \$AUDIO_FILE"
fi

# Get audio file information
AUDIO_DIR=\$(dirname "\$AUDIO_FILE")
AUDIO_FILENAME=\$(basename "\$AUDIO_FILE")
AUDIO_NAME="\${AUDIO_FILENAME%.*}"

# Create a cleaner assets directory structure
ASSETS_DIR="\$AUDIO_DIR/\${AUDIO_NAME}_assets"
ARTWORK_DIR="\$ASSETS_DIR/artwork"
CANVAS_DIR="\$ASSETS_DIR/canvas"
COMPONENTS_DIR="\$ASSETS_DIR/components"

# Create the directory structure
mkdir -p "\$ARTWORK_DIR" "\$CANVAS_DIR" "\$COMPONENTS_DIR" || error_exit "Failed to create assets directories"

echo -e "\${GREEN}Created assets directory structure at: \$ASSETS_DIR\${NC}"

# Set up logging after directories are created
setup_logging

# Install dependencies with minimal output
echo -e "\${GREEN}Installing dependencies...\${NC}"
pip_install_quiet numpy==1.26.4 || error_exit "Failed to install numpy"
pip_install_quiet librosa matplotlib pillow glitch_this || error_exit "Failed to install dependencies"

# Ask for saturation level
echo -n "Enter spectrogram saturation level (0.0 for grayscale, 1.0 for normal, default=1.0): "
read SATURATION_INPUT
SATURATION=\${SATURATION_INPUT:-1.0}

# Log the saturation level
echo "Selected Saturation Level: \$SATURATION" >> "\$FULL_LOG_FILE"

# Apply the same output filtering to the album artwork generation
echo -e "\${GREEN}Generating album artwork...\${NC}"

# Run the python script with filtered output
run_with_filtered_output python3 "\$ALBUM_ARTWORK_PY" << PYEOF
\$AUDIO_FILE
\$SATURATION
PYEOF

# Get the output directory from the album artwork generator output
ORIG_ARTWORK_DIR="\$AUDIO_DIR/id_\${AUDIO_NAME}_wav_v7_sat\${SATURATION}"
ORIG_ARTWORK_PATH="\$ORIG_ARTWORK_DIR/\${AUDIO_NAME}.png"

# Check if artwork was generated
if [ ! -f "\$ORIG_ARTWORK_PATH" ]; then
    error_exit "Failed to generate album artwork or couldn't find the output file: \$ORIG_ARTWORK_PATH"
fi

# Copy the main artwork to the artwork directory
cp "\$ORIG_ARTWORK_PATH" "\$ARTWORK_DIR/" || error_exit "Failed to copy main artwork"

# Copy component files to the components directory
if [ -f "\$ORIG_ARTWORK_DIR/identicon.png" ]; then
    cp "\$ORIG_ARTWORK_DIR/identicon.png" "\$COMPONENTS_DIR/" || error_exit "Failed to copy identicon"
fi

if [ -f "\$ORIG_ARTWORK_DIR/spectrogram.png" ]; then
    cp "\$ORIG_ARTWORK_DIR/spectrogram.png" "\$COMPONENTS_DIR/" || error_exit "Failed to copy spectrogram"
fi

# Copy the rectangle spectrogram if it exists
if [ -f "\$ORIG_ARTWORK_DIR/rectangle_spectrogram.png" ]; then
    cp "\$ORIG_ARTWORK_DIR/rectangle_spectrogram.png" "\$COMPONENTS_DIR/" || error_exit "Failed to copy rectangle spectrogram"
fi

echo -e "\${GREEN}Album artwork generated at: \$ARTWORK_DIR/\$(basename "\$ORIG_ARTWORK_PATH")\${NC}"

# Run the canvas generator with the artwork from the artwork directory
echo -e "\${GREEN}Generating Spotify Canvas...\${NC}"
ARTWORK_FOR_CANVAS="\$ARTWORK_DIR/\$(basename "\$ORIG_ARTWORK_PATH")"

# Run the canvas generator with filtered output
run_with_filtered_output python3 "\$CANVAS_GENERATOR_PY" << PYEOF
\$ARTWORK_FOR_CANVAS
PYEOF

# Find and move canvas files to the canvas directory
ORIG_CANVAS_DIR="\$ARTWORK_DIR/\${AUDIO_NAME}_canvas"
if [ -d "\$ORIG_CANVAS_DIR" ]; then
    # Move files from the original canvas directory to our organized canvas directory
    find "\$ORIG_CANVAS_DIR" -type f -exec cp {} "\$CANVAS_DIR/" \;
    echo -e "\${GREEN}Canvas files copied to: \$CANVAS_DIR\${NC}"
else
    # Check if canvas files were created elsewhere
    ALT_CANVAS_DIR="\$ORIG_ARTWORK_DIR/\${AUDIO_NAME}_canvas"
    if [ -d "\$ALT_CANVAS_DIR" ]; then
        find "\$ALT_CANVAS_DIR" -type f -exec cp {} "\$CANVAS_DIR/" \;
        echo -e "\${GREEN}Canvas files copied to: \$CANVAS_DIR\${NC}"
    else
        echo -e "\${YELLOW}Warning: Could not find canvas files\${NC}"
    fi
fi

# Clean up original output directories
echo -e "\${GREEN}Cleaning up temporary files...\${NC}"
if [ -d "\$ORIG_ARTWORK_DIR" ]; then
    rm -rf "\$ORIG_ARTWORK_DIR"
    echo -e "\${GREEN}Removed original artwork directory\${NC}"
fi

if [ -d "\$ORIG_CANVAS_DIR" ]; then
    rm -rf "\$ORIG_CANVAS_DIR"
    echo -e "\${GREEN}Removed original canvas directory\${NC}"
fi

if [ -d "\$ALT_CANVAS_DIR" ]; then
    rm -rf "\$ALT_CANVAS_DIR"
    echo -e "\${GREEN}Removed alternative canvas directory\${NC}"
fi

# Also clean up the full rectangular spectrogram file in the audio directory
if [ -f "\$AUDIO_DIR/full_rect_spectrogram.png" ]; then
    rm -f "\$AUDIO_DIR/full_rect_spectrogram.png"
    echo -e "\${GREEN}Removed temporary full rectangular spectrogram\${NC}"
fi

# Deactivate virtual environment
deactivate

# Log completion time
echo "===== Asset Generation Completed at \$(date) =====" >> "\$FULL_LOG_FILE"
echo "Final Assets:" >> "\$FULL_LOG_FILE"
echo "- Album Artwork: \$ARTWORK_DIR/\$(basename "\$ORIG_ARTWORK_PATH")" >> "\$FULL_LOG_FILE"
echo "- Spotify Canvas: \$CANVAS_DIR" >> "\$FULL_LOG_FILE"
echo "- Component Files: \$COMPONENTS_DIR" >> "\$FULL_LOG_FILE"
echo "- Log File: \$FULL_LOG_FILE" >> "\$FULL_LOG_FILE"
echo "=========================================" >> "\$FULL_LOG_FILE"

# Run catalog number generator after all assets are created
echo -e "\${GREEN}Generating catalog number...\${NC}"

# Create a temporary Python script for catalog generation
TEMP_CATALOG_SCRIPT=\$(mktemp)
cat > "\$TEMP_CATALOG_SCRIPT" << 'PYTHONSCRIPT'
#!/usr/bin/env python3

import os
import sys
import hashlib
import time

def generate_catalog_number(audio_file_path):
    """Generate a catalog number for an audio file based on its hash."""
    print("🔢 Generating catalog number...")
    
    # Generate a hash from the audio file
    sha256 = hashlib.sha256()
    with open(audio_file_path, 'rb') as f:
        while True:
            data = f.read(65536)
            if not data:
                break
            sha256.update(data)
    hash_value = sha256.hexdigest()
    
    # Create the catalog number
    catalog_number = f"lufs-{hash_value[:8]}"
    
    print(f"✓ Created catalog number: {catalog_number}")
    return catalog_number, hash_value

def save_catalog_info(catalog_number, hash_value, audio_file_path):
    """Save catalog information to a file in the assets directory."""
    # Get the base name of the audio file
    base_name = os.path.splitext(os.path.basename(audio_file_path))[0]
    
    # Get the assets directory path
    audio_dir = os.path.dirname(audio_file_path)
    assets_dir = os.path.join(audio_dir, f"{base_name}_assets")
    
    # Create the catalog info file
    catalog_file_path = os.path.join(assets_dir, "catalog_info.txt")
    
    # Prepare the content
    content = f"""CATALOG INFORMATION
==================
Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}
Audio File: {os.path.basename(audio_file_path)}

Catalog Number: {catalog_number}
Full Hash: {hash_value}
"""
    
    # Write the file
    with open(catalog_file_path, 'w') as f:
        f.write(content)
    
    print(f"✓ Catalog information saved to: {catalog_file_path}")
    return catalog_file_path

def main():
    # Check if an audio file path was provided as an argument
    if len(sys.argv) > 1:
        audio_file_path = sys.argv[1]
    else:
        # Otherwise read from stdin
        audio_file_path = input("Enter the path to your audio file: ").strip()
    
    # Check if the file exists
    if not os.path.isfile(audio_file_path):
        print(f"Error: File not found: {audio_file_path}")
        return
    
    # Generate the catalog number
    catalog_number, hash_value = generate_catalog_number(audio_file_path)
    
    # Save the catalog information
    catalog_file_path = save_catalog_info(catalog_number, hash_value, audio_file_path)
    
    print("\n📋 Your catalog information is ready for distribution!")

if __name__ == "__main__":
    main()
PYTHONSCRIPT

# Make the script executable
chmod +x "\$TEMP_CATALOG_SCRIPT"

# Run the temporary catalog script
run_with_filtered_output python3 "\$TEMP_CATALOG_SCRIPT" "\$AUDIO_FILE"

# Add catalog number to output summary
if [ -f "\$ASSETS_DIR/catalog_info.txt" ]; then
    CATALOG_NUMBER=\$(grep "Catalog Number:" "\$ASSETS_DIR/catalog_info.txt" | cut -d':' -f2 | xargs)
    echo -e "\${GREEN}✓ Created catalog number: \$CATALOG_NUMBER\${NC}"
else
    echo -e "\${YELLOW}Warning: Catalog info file not created.\${NC}"
fi

# Clean up the temporary script
rm -f "\$TEMP_CATALOG_SCRIPT"

# At the end, add a short pause and success notification
show_notification "✅ All assets generated successfully!"
echo -e "\${GREEN}All assets generated successfully!\${NC}"
echo -e "\${GREEN}You can find your assets in the following locations:\${NC}"
echo -e "\${GREEN}Assets Directory: \$ASSETS_DIR\${NC}"
echo -e "\${GREEN}Album Artwork: \$ARTWORK_DIR/\$(basename "\$ORIG_ARTWORK_PATH")\${NC}"
echo -e "\${GREEN}Spotify Canvas: \$CANVAS_DIR\${NC}"
echo -e "\${GREEN}Component Files: \$COMPONENTS_DIR\${NC}"
if [ -f "\$ASSETS_DIR/catalog_info.txt" ]; then
    echo -e "\${GREEN}Catalog Info: \$ASSETS_DIR/catalog_info.txt\${NC}"
fi
echo -e "\${GREEN}Log File: \$FULL_LOG_FILE\${NC}"

# Short pause at the end
sleep 2
EOF

# Open the temporary script in Ghostty
open -a Ghostty "$TEMP_SCRIPT"

# Clean up the temp script after a delay
(sleep 10 && rm -f "$TEMP_SCRIPT") &