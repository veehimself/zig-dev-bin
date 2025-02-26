#!/bin/bash

# Function to fetch and transform the Zig version
fetch_and_transform_zig_version() {
    local url="$1"
    
    # Fetch the JSON data
    response=$(curl -s "$url")
    
    # Extract the version using jq
    original_version=$(echo "$response" | jq -r '.master.version')
    
    # Transform the version string
    transformed_version=$(echo "$original_version" | sed 's/-/_/g' | sed 's/+/.g/g')
    
    echo "$original_version" "$transformed_version"
}

# Function to update the PKGBUILD file
update_pkgbuild() {
    local file_path="$1"
    local new_version="$2"
    
    # Use sed to find and replace the pkgver line
    sed -i "s/pkgver=.*/pkgver=$new_version/" "$file_path"
}

# URL of the JSON file
url="https://ziglang.org/download/index.json"

# Fetch and transform the version
read original_version transformed_version <<< $(fetch_and_transform_zig_version "$url")

echo "Original version: $original_version"
echo "Transformed version: $transformed_version"

# Update the PKGBUILD file
pkgbuild_path="PKGBUILD"  # Assuming PKGBUILD is in the current directory
update_pkgbuild "$pkgbuild_path" "$transformed_version"

echo "Updated PKGBUILD with new version: $transformed_version"
