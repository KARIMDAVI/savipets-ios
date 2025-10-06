#!/usr/bin/env python3
"""
Script to fix app icon transparency issues for App Store submission.
This script removes alpha channels from PNG images to make them opaque.
"""

import os
import sys
from PIL import Image

def remove_transparency(image_path, output_path):
    """Remove transparency from PNG image and make it opaque with white background."""
    try:
        # Open the image
        img = Image.open(image_path)
        
        # Convert to RGBA if not already
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        # Create a white background
        background = Image.new('RGB', img.size, (255, 255, 255))
        
        # Paste the image onto the white background
        background.paste(img, mask=img.split()[-1])  # Use alpha channel as mask
        
        # Save as RGB (no alpha channel)
        background.save(output_path, 'PNG')
        print(f"✅ Fixed: {image_path} -> {output_path}")
        
    except Exception as e:
        print(f"❌ Error processing {image_path}: {e}")

def main():
    """Process all app icon files."""
    app_icon_dir = "SaviPets/Assets.xcassets/AppIcon.appiconset"
    
    if not os.path.exists(app_icon_dir):
        print(f"❌ App icon directory not found: {app_icon_dir}")
        return
    
    # List of icon files to process
    icon_files = [
        "SaviPets-iOS-Default-1024x1024@1x.png",
        "SaviPets-iOS-Dark-1024x1024@1x.png", 
        "SaviPets-iOS-TintedLight-1024x1024@1x.png"
    ]
    
    for icon_file in icon_files:
        input_path = os.path.join(app_icon_dir, icon_file)
        if os.path.exists(input_path):
            # Create backup
            backup_path = input_path + ".backup"
            os.rename(input_path, backup_path)
            
            # Process and save fixed version
            remove_transparency(backup_path, input_path)
        else:
            print(f"⚠️  Icon file not found: {icon_file}")
    
    print("\n🎉 App icon transparency fix complete!")
    print("📝 Next steps:")
    print("1. Clean and rebuild your project")
    print("2. Archive and upload to App Store Connect")

if __name__ == "__main__":
    main()



