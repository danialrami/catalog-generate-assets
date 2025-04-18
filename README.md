# Audio Assets Generator

Generate album artwork and Spotify Canvas animations from your audio files. This tool automatically creates:

1. Album artwork based on spectrograms and unique identicons
2. Spotify Canvas animations with glitch effects
3. A catalog ID system for tracking your audio files

## Features

- **Album Artwork Generator**: Creates unique album artwork by combining a spectrogram of your audio with a procedurally generated identicon
- **Spotify Canvas Generator**: Produces animated visuals in the correct dimensions for Spotify Canvas (9:16 ratio)
- **Catalog Number System**: Generates a unique identifier for each audio file for cataloging purposes
- **Organized Asset Directory**: Creates a clean directory structure for all generated assets
- **Comprehensive Logging**: Maintains detailed logs of the generation process

## Requirements

- Python 3.8+
- FFmpeg (required for MP4 conversion)
- Node.js (for jdenticon generation)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/audio-assets-generator.git
   cd audio-assets-generator
   ```

2. Make the scripts executable:
   ```bash
   chmod +x generate-assets.sh
   chmod +x v2_generate-assets.sh
   ```

3. Run the script (either version):
   ```bash
   # Basic version
   ./generate-assets.sh path/to/your/audio/file.wav
   
   # Enhanced version with improved UI
   ./v2_generate-assets.sh path/to/your/audio/file.wav
   ```

The script will automatically:
- Create a Python virtual environment
- Install all required dependencies
- Generate the assets
- Clean up temporary files

## Output Structure

For an input file `song.wav`, the script creates:

```
song_assets/
├── artwork/
│   └── song.png
├── canvas/
│   ├── song_canvas_static.png
│   ├── song_canvas.gif
│   └── song_canvas.mp4
├── components/
│   ├── identicon.png
│   ├── spectrogram.png
│   └── rectangle_spectrogram.png
├── catalog_info.txt
└── generation_log.txt
```

## Customization

You can customize the spectrogram saturation when prompted:
- `0.0`: Grayscale spectrogram
- `1.0`: Normal color saturation
- Values above 1.0 (up to 2.0): Enhanced saturation

## How It Works

1. **Audio Analysis**: The script analyzes your audio file to create a spectrogram and unique hash
2. **Identicon Generation**: A unique geometric pattern is created based on the audio hash
3. **Artwork Creation**: The spectrogram and identicon are combined to create album artwork
4. **Canvas Animation**: The artwork is transformed into an animated Spotify Canvas with glitch effects
5. **Catalog System**: A catalog ID is generated based on the audio file's hash

## Contributing

Contributions are welcome -- Please feel free to submit a Pull Request.