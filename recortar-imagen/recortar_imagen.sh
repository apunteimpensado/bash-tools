#!/bin/bash
# 
# Image Crop Tool
# 
# This script crops the top and bottom 20% from all images in a directory,
# saving the results with numbered filenames (001.jpg, 002.png, etc.).
# 
# Usage:
#   ./crop_images.sh                    # Process current directory
#   ./crop_images.sh /path/to/images    # Process specific directory
#   ./crop_images.sh /path/to/images output_folder  # Custom output folder
# 
# Requirements:
#   ImageMagick (convert command)
#

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is not installed. Please install it first."
    echo "Ubuntu/Debian: sudo apt-get install imagemagick"
    echo "macOS: brew install imagemagick"
    exit 1
fi

# Use current directory as input folder if no argument provided
if [ $# -eq 0 ]; then
    input_folder="."
    output_folder="cropped_images"
elif [ $# -eq 1 ]; then
    input_folder="$1"
    output_folder="cropped_images"
else
    input_folder="$1"
    output_folder="$2"
fi

# Validate input directory
if [ ! -d "$input_folder" ]; then
    echo "Error: Input directory '$input_folder' does not exist."
    exit 1
fi

# Create output folder
mkdir -p "$output_folder"

# Get all image files and store them in an array
image_files=()
for file in "$input_folder"/*; do
    if [[ -f "$file" ]]; then
        case "${file,,}" in
            *.jpg|*.jpeg|*.png|*.bmp|*.tiff|*.webp)
                image_files+=("$file")
                ;;
        esac
    fi
done

# Check if any images were found
if [ ${#image_files[@]} -eq 0 ]; then
    echo "No image files found in $input_folder"
    exit 0
fi

echo "Found ${#image_files[@]} image(s) to process..."

# Process each image file
counter=1
for img in "${image_files[@]}"; do
    filename=$(basename "$img")
    extension="${filename##*.}"
    
    # Get image dimensions
    width=$(identify -format "%w" "$img")
    height=$(identify -format "%h" "$img")
    
    # Calculate crop values (20% from top and bottom = 40% total)
    top_crop=$((height * 20 / 100))
    height_crop=$((height * 60 / 100))  # Keep middle 60%
    
    # Check if image is large enough to crop
    if [ $((top_crop * 2)) -ge $height ]; then
        echo "Warning: Image $filename too small to crop 40%. Skipping."
        continue
    fi
    
    # Create output filename with preserved extension and 3-digit numbering
    output_file="${output_folder}/$(printf "%03d" $counter).$extension"
    
    # Add safety check for output file existence
    if [ -f "$output_file" ]; then
        echo "Warning: Output file $output_file already exists. Skipping."
        continue
    fi
    
    # Crop: -crop WxH+X+Y (width x height + x_offset + y_offset)
    convert "$img" -crop ${width}x${height_crop}+0+${top_crop} "$output_file"
    
    echo "Processed: $filename -> $(basename $output_file)"
    ((counter++))
done

echo "Processing complete! Cropped images saved to: $output_folder"