import subprocess
import hashlib
import os
import time
import numpy as np
from PIL import Image, ImageEnhance
import librosa
import librosa.display
import matplotlib.pyplot as plt
import io

def print_normal(message):
    """Print a message normally."""
    print(message)

def print_typewriter(message, delay=0.03):
    """Print a message with a typewriter effect."""
    for char in message:
        print(char, end='', flush=True)
        time.sleep(delay)
    print()

def hash_audio_file(file_path):
    """Generate a hash from an audio file."""
    print_normal("🔍 Analyzing your audio's unique fingerprint...")
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        while True:
            data = f.read(65536)
            if not data:
                break
            sha256.update(data)
    hash_value = sha256.hexdigest()
    print_normal(f"✓ Got it! Your audio hash is: {hash_value[:8]}...{hash_value[-8:]}")
    return hash_value

def create_identicon(hash_value, output_dir):
    """Create an identicon from a hash value."""
    print_normal("🎨 Generating your unique identicon...")
    identicon_path = os.path.join(output_dir, 'identicon.png')
    subprocess.run([
        'npx', 'jdenticon', hash_value, '--size', '5000', '--output', identicon_path
    ], check=True)
    print_normal("✓ Identicon created!")
    return Image.open(identicon_path).convert('RGBA')

def create_improved_spectrogram(audio_file_path, saturation_level=1.0):
    """Create a spectrogram with better proportions and select the middle section."""
    print_normal("🔊 Analyzing your audio frequencies with scaling...")
    
    # Load the audio file
    y, sr = librosa.load(audio_file_path)
    duration = len(y) / sr  # Duration in seconds
    
    # Calculate dimensions based on audio duration
    height = 10  # Fixed height in inches
    width = min(max(duration / 4, 10), 40)  # Scale width based on duration (10-40 inches)
    print_normal(f"Creating spectrogram with dimensions: {width}x{height} inches")
    
    # Compute the mel-scaled spectrogram
    S = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=128, fmax=8000)
    S_dB = librosa.power_to_db(S, ref=np.max)
    
    # Create a proportional rectangular figure with explicit DPI
    dpi = 100  # Set explicit DPI for consistent sizing
    plt.figure(figsize=(width, height), dpi=dpi)
    
    # Display the spectrogram
    librosa.display.specshow(S_dB, x_axis='time', y_axis='mel', sr=sr, fmax=8000)
    plt.axis('off')
    plt.tight_layout(pad=0)
    
    # Save to a BytesIO object with explicit bbox_inches
    buf = io.BytesIO()
    plt.savefig(buf, format='png', bbox_inches='tight', pad_inches=0, dpi=dpi)
    buf.seek(0)
    plt.close()
    
    # Open as PIL Image
    spec_img = Image.open(buf).convert('RGBA')
    print_normal(f"Raw spectrogram dimensions: {spec_img.size[0]}x{spec_img.size[1]} pixels")
    
    # Check if we got a properly rectangular image
    if spec_img.size[0] < spec_img.size[1] * 1.5:
        print_normal("Warning: Spectrogram not sufficiently rectangular. Forcing aspect ratio...")
        # Create a new image with forced aspect ratio
        target_width = int(spec_img.size[1] * 3)  # Make it 3 times as wide as it is tall
        new_img = Image.new('RGBA', (target_width, spec_img.size[1]), (0, 0, 0, 0))
        new_img.paste(spec_img.resize((min(spec_img.size[0], target_width), spec_img.size[1])), (0, 0))
        spec_img = new_img
        print_normal(f"Adjusted spectrogram dimensions: {spec_img.size[0]}x{spec_img.size[1]} pixels")
    
    # Adjust saturation if needed
    if saturation_level != 1.0:
        enhancer = ImageEnhance.Color(spec_img)
        spec_img = enhancer.enhance(saturation_level)
    
    # Find the most interesting segment
    width, height = spec_img.size
    square_size = height  # Our square will be the height of the spectrogram
    
    # Save the full rectangular spectrogram for reference
    rectangle_filename = "rectangle_spectrogram.png"
    full_rect_path = os.path.join(os.path.dirname(audio_file_path), rectangle_filename)
    spec_img.save(full_rect_path)
    print_normal(f"Saved full rectangular spectrogram to: {full_rect_path}")
    
    # The number of possible square segments we can extract
    num_segments = max(1, width - square_size + 1)
    
    if num_segments <= 1:
        # If the image is already square or smaller than square_size
        left = 0
        right = min(square_size, width)
    else:
        # Instead of finding the most interesting segment, 
        # just take the middle section
        left = (width - square_size) // 2
        right = left + square_size
    
    # Crop the selected square
    spec_img = spec_img.crop((left, 0, right, height))
    
    # Display the time position this corresponds to in the audio
    time_position = (left / width) * duration
    time_end = (right / width) * duration
    print_normal(f"✓ Enhanced spectrogram created! Selected middle segment covers audio from {time_position:.2f}s to {time_end:.2f}s")
    return spec_img, full_rect_path, rectangle_filename

def set_image_alpha(image, alpha_value):
    """Set the alpha channel for the entire image."""
    if image.mode != 'RGBA':
        image = image.convert('RGBA')
    r, g, b, a = image.split()
    new_alpha = Image.new('L', image.size, color=alpha_value)
    image.putalpha(new_alpha)
    return image

def resize_identicon(identicon, scale=0.4):
    """Resize the identicon by a scale factor."""
    width, height = identicon.size
    new_size = (int(width * scale), int(height * scale))
    return identicon.resize(new_size)

def create_album_artwork_v7(audio_file_path, saturation_level=1.0):
    """Create album artwork using v7 logic with added print statements."""
    # Get base name and extension
    base_name = os.path.splitext(os.path.basename(audio_file_path))[0]
    file_ext = os.path.splitext(audio_file_path)[1].lower()
    
    # Include saturation level in the output directory name
    output_dir = os.path.join(
        os.path.dirname(audio_file_path),
        f"id_{base_name}_{file_ext[1:]}_v7_sat{saturation_level}"
    )
    
    print_normal(f"📁 Creating output directory: {output_dir}")
    os.makedirs(output_dir, exist_ok=True)
    
    # Start using typewriter effect from here
    print_typewriter("🚀 Starting the v7 Album Artwork Generator")
    hash_value = hash_audio_file(audio_file_path)
    
    # Create identicon and spectrogram
    identicon = create_identicon(hash_value, output_dir)
    # Use the improved spectrogram function instead of the original
    spectrogram, rect_path, rect_filename = create_improved_spectrogram(audio_file_path, saturation_level)
    
    # Save the rectangle spectrogram to output directory
    os.rename(rect_path, os.path.join(output_dir, rect_filename))
    
    # Save the square spectrogram for reference
    spectrogram.save(os.path.join(output_dir, 'spectrogram.png'))
    
    # Resize spectrogram to match identicon size
    print_typewriter("📏 Resizing spectrogram to match identicon...")
    spectrogram = spectrogram.resize(identicon.size)
    
    # Make spectrogram semi-transparent
    print_typewriter("🔍 Adjusting spectrogram transparency...")
    spectrogram = set_image_alpha(spectrogram, 127)  # 127/255 = 50% transparency
    
    # Resize identicon and ensure full opacity
    print_typewriter("✂️ Resizing identicon...")
    identicon = resize_identicon(identicon)
    identicon.putalpha(255)  # Full opacity
    
    # Create final composite image with pure black background
    print_typewriter("⬛ Creating a sleek black background...")
    final_image = Image.new('RGBA', spectrogram.size, (0, 0, 0, 255))
    
    # Composite spectrogram first (background)
    print_typewriter("🔄 Applying the spectrogram to the background...")
    final_image.alpha_composite(spectrogram)
    
    # Center the identicon (foreground)
    print_typewriter("🎯 Centering the identicon...")
    position = (
        (spectrogram.size[0] - identicon.size[0]) // 2,
        (spectrogram.size[1] - identicon.size[1]) // 2
    )
    final_image.alpha_composite(identicon, position)
    
    # Convert final image to RGB before saving
    final_image_rgb = final_image.convert('RGB')
    
    # Save all outputs with the audio filename (without extension) for the final image
    output_path = os.path.join(output_dir, f'{base_name}.png')
    final_image_rgb.save(output_path)
    identicon.save(os.path.join(output_dir, 'identicon.png'))
    
    print_typewriter("✅ Album artwork v7 generated successfully!")
    print_typewriter(f"📍 Find your masterpiece at: {output_path}")
    print_typewriter("🎵 Now go make some more music worthy of this awesome cover!")
    
    return output_dir, output_path

def main():
    print_normal("🎧 Welcome to the Album Artwork Generator v7! 🎧")
    print_normal("🔥 Where your audio gets the visual treatment it deserves! 🔥")
    
    # Prompt user for audio file path
    audio_file_path = input("🎵 Enter the path to your audio file: ").strip("'")
    
    # Prompt user for saturation level
    saturation_input = input("🎨 Enter spectrogram saturation level (0.0 for grayscale, 1.0 for normal, default=1.0): ").strip()
    try:
        saturation_level = float(saturation_input) if saturation_input else 1.0
        # Ensure saturation is within reasonable bounds
        saturation_level = max(0.0, min(2.0, saturation_level))
    except ValueError:
        print_normal("⚠️ Invalid saturation value, using default (1.0)")
        saturation_level = 1.0
    
    # Run the script
    create_album_artwork_v7(audio_file_path, saturation_level)

if __name__ == "__main__":
    main()