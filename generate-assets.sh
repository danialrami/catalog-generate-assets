#!/bin/bash

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Virtual environment name and path
VENV_NAME="audio_assets_env"
VENV_PATH="$SCRIPT_DIR/$VENV_NAME"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to display error and exit
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Function to remove quotes from a string
remove_quotes() {
    # Remove both single and double quotes from the beginning and end of the string
    echo "$1" | sed -e "s/^[\"']//g" -e "s/[\"']$//g"
}

# Check if Python 3 is installed
if ! command_exists python3; then
    error_exit "Python 3 is not installed. Please install Python 3 and try again."
fi

# Check if ffmpeg is installed
if ! command_exists ffmpeg; then
    echo -e "${YELLOW}WARNING: FFmpeg is not installed. It's required for MP4 conversion.${NC}"
    read -p "Do you want to continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}Setting up virtual environment...${NC}"

# Check if virtualenv is installed
if ! command_exists python3 -m venv; then
    echo -e "${YELLOW}Installing virtualenv...${NC}"
    pip3 install virtualenv || error_exit "Failed to install virtualenv"
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_PATH" ]; then
    echo -e "${GREEN}Creating virtual environment at $VENV_PATH...${NC}"
    python3 -m venv "$VENV_PATH" || error_exit "Failed to create virtual environment"
fi

# Activate virtual environment
echo -e "${GREEN}Activating virtual environment...${NC}"
source "$VENV_PATH/bin/activate" || error_exit "Failed to activate virtual environment"

# Install dependencies
echo -e "${GREEN}Installing dependencies...${NC}"
pip install numpy==1.26.4 || error_exit "Failed to install numpy"
pip install librosa matplotlib pillow glitch_this || error_exit "Failed to install dependencies"

# Check if audio file path is provided as argument
if [ $# -eq 0 ]; then
    read -p "Enter the path to your audio file: " QUOTED_AUDIO_FILE
    # Remove quotes if present
    AUDIO_FILE=$(remove_quotes "$QUOTED_AUDIO_FILE")
else
    # Remove quotes if present in command line argument
    AUDIO_FILE=$(remove_quotes "$1")
fi

# Check if file exists
if [ ! -f "$AUDIO_FILE" ]; then
    error_exit "Audio file not found: $AUDIO_FILE"
fi

# Get audio file information
AUDIO_DIR=$(dirname "$AUDIO_FILE")
AUDIO_FILENAME=$(basename "$AUDIO_FILE")
AUDIO_NAME="${AUDIO_FILENAME%.*}"

# Create a cleaner assets directory structure
ASSETS_DIR="$AUDIO_DIR/${AUDIO_NAME}_assets"
ARTWORK_DIR="$ASSETS_DIR/artwork"
CANVAS_DIR="$ASSETS_DIR/canvas"
COMPONENTS_DIR="$ASSETS_DIR/components"

# Create the directory structure
mkdir -p "$ARTWORK_DIR" "$CANVAS_DIR" "$COMPONENTS_DIR" || error_exit "Failed to create assets directories"

echo -e "${GREEN}Created assets directory structure at: $ASSETS_DIR${NC}"

# Ask for saturation level
read -p "Enter spectrogram saturation level (0.0 for grayscale, 1.0 for normal, default=1.0): " SATURATION
SATURATION=${SATURATION:-1.0}

# Run the album artwork generator with saturation parameter
echo -e "${GREEN}Generating album artwork...${NC}"
python3 "$SCRIPT_DIR/v7_album_artwork.py" <<EOF
$AUDIO_FILE
$SATURATION
EOF

# Get the output directory from the album artwork generator output
ORIG_ARTWORK_DIR="$AUDIO_DIR/id_${AUDIO_NAME}_wav_v7_sat${SATURATION}"
ORIG_ARTWORK_PATH="$ORIG_ARTWORK_DIR/${AUDIO_NAME}.png"

# Check if artwork was generated
if [ ! -f "$ORIG_ARTWORK_PATH" ]; then
    error_exit "Failed to generate album artwork or couldn't find the output file."
fi

# Copy the main artwork to the artwork directory
cp "$ORIG_ARTWORK_PATH" "$ARTWORK_DIR/" || error_exit "Failed to copy main artwork"

# Copy component files to the components directory
if [ -f "$ORIG_ARTWORK_DIR/identicon.png" ]; then
    cp "$ORIG_ARTWORK_DIR/identicon.png" "$COMPONENTS_DIR/" || error_exit "Failed to copy identicon"
fi

if [ -f "$ORIG_ARTWORK_DIR/spectrogram.png" ]; then
    cp "$ORIG_ARTWORK_DIR/spectrogram.png" "$COMPONENTS_DIR/" || error_exit "Failed to copy spectrogram"
fi

echo -e "${GREEN}Album artwork generated at: $ARTWORK_DIR/$(basename "$ORIG_ARTWORK_PATH")${NC}"

# Run the canvas generator with the artwork from the artwork directory
echo -e "${GREEN}Generating Spotify Canvas...${NC}"
ARTWORK_FOR_CANVAS="$ARTWORK_DIR/$(basename "$ORIG_ARTWORK_PATH")"
python3 "$SCRIPT_DIR/canvas_generator.py" <<EOF
$ARTWORK_FOR_CANVAS
EOF

# Find and move canvas files to the canvas directory
ORIG_CANVAS_DIR="$ARTWORK_DIR/${AUDIO_NAME}_canvas"
if [ -d "$ORIG_CANVAS_DIR" ]; then
    # Move files from the original canvas directory to our organized canvas directory
    find "$ORIG_CANVAS_DIR" -type f -exec cp {} "$CANVAS_DIR/" \;
    echo -e "${GREEN}Canvas files copied to: $CANVAS_DIR${NC}"
else
    # Check if canvas files were created elsewhere
    ALT_CANVAS_DIR="$ORIG_ARTWORK_DIR/${AUDIO_NAME}_canvas"
    if [ -d "$ALT_CANVAS_DIR" ]; then
        find "$ALT_CANVAS_DIR" -type f -exec cp {} "$CANVAS_DIR/" \;
        echo -e "${GREEN}Canvas files copied to: $CANVAS_DIR${NC}"
    else
        echo -e "${YELLOW}Warning: Could not find canvas files${NC}"
    fi
fi

# Clean up original output directories
echo -e "${GREEN}Cleaning up temporary files...${NC}"
if [ -d "$ORIG_ARTWORK_DIR" ]; then
    rm -rf "$ORIG_ARTWORK_DIR"
    echo -e "${GREEN}Removed original artwork directory${NC}"
fi

if [ -d "$ORIG_CANVAS_DIR" ]; then
    rm -rf "$ORIG_CANVAS_DIR"
    echo -e "${GREEN}Removed original canvas directory${NC}"
fi

if [ -d "$ALT_CANVAS_DIR" ]; then
    rm -rf "$ALT_CANVAS_DIR"
    echo -e "${GREEN}Removed alternative canvas directory${NC}"
fi

# Deactivate virtual environment
deactivate

echo -e "${GREEN}All assets generated successfully!${NC}"
echo -e "${GREEN}You can find your assets in the following locations:${NC}"
echo -e "${GREEN}Assets Directory: $ASSETS_DIR${NC}"
echo -e "${GREEN}Album Artwork: $ARTWORK_DIR/$(basename "$ORIG_ARTWORK_PATH")${NC}"
echo -e "${GREEN}Spotify Canvas: $CANVAS_DIR${NC}"
echo -e "${GREEN}Component Files: $COMPONENTS_DIR${NC}"
