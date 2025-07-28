#!/bin/bash

# Function to fetch and transform the Zig version
fetch_and_transform_zig_version() {
    local url="$1"
    
    # Fetch the JSON data with error handling
    response=$(curl -s "$url")
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo "Error: Failed to fetch version data from $url" >&2
        return 1
    fi
    
    # Extract the version using jq with error handling
    original_version=$(echo "$response" | jq -r '.master.version')
    if [ $? -ne 0 ] || [ -z "$original_version" ] || [ "$original_version" = "null" ]; then
        echo "Error: Failed to extract version from JSON response" >&2
        return 1
    fi
    
    # Transform the version string using robust pattern matching
    transformed_version=$(transform_version "$original_version")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to transform version '$original_version'" >&2
        return 1
    fi
    
    echo "$original_version" "$transformed_version"
}

# Robust version transformation function
# Handles current and future version patterns without breaking
transform_version() {
    local version="$1"
    
    # Validate input
    if [ -z "$version" ]; then
        echo "Error: Empty version string" >&2
        return 1
    fi
    
    # Handle simple release versions (e.g., 0.14.0, 1.0.0, 10.5.3)
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$version"
        return 0
    fi
    
    # Handle development versions with pattern: X.Y.Z-dev.N+hash
    # This regex is flexible enough to handle dev.829, dev.1254, etc.
    if [[ "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-(dev\.[0-9]+)\+([a-f0-9]+)$ ]]; then
        # Convert 0.14.0-dev.829+2e26cf83c to 0.14.0_dev.829.g2e26cf83c
        echo "${BASH_REMATCH[1]}_${BASH_REMATCH[2]}.g${BASH_REMATCH[3]}"
        return 0
    fi
    
    # Handle development versions with extended pattern: X.Y.Z-dev.N.M+hash
    if [[ "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-(dev\.[0-9]+\.[0-9]+)\+([a-f0-9]+)$ ]]; then
        # Convert 0.15.0-dev.1254.3+abc123def to 0.15.0_dev.1254.3.gabc123def
        echo "${BASH_REMATCH[1]}_${BASH_REMATCH[2]}.g${BASH_REMATCH[3]}"
        return 0
    fi
    
    # Handle release candidate versions: X.Y.Z-rc.N+hash
    if [[ "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-(rc\.[0-9]+)\+([a-f0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}_${BASH_REMATCH[2]}.g${BASH_REMATCH[3]}"
        return 0
    fi
    
    # Handle beta versions: X.Y.Z-beta.N+hash
    if [[ "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-(beta\.[0-9]+)\+([a-f0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}_${BASH_REMATCH[2]}.g${BASH_REMATCH[3]}"
        return 0
    fi
    
    # Handle alpha versions: X.Y.Z-alpha.N+hash
    if [[ "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-(alpha\.[0-9]+)\+([a-f0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}_${BASH_REMATCH[2]}.g${BASH_REMATCH[3]}"
        return 0
    fi
    
    # Generic fallback: sanitize any version format
    # This ensures the script won't break with completely new version formats
    # Apply the basic sanitization rules: '-' -> '_', '+' -> '.g'
    local sanitized_version
    sanitized_version=$(echo "$version" | sed 's/-/_/g' | sed 's/+/.g/g')
    
    if [ $? -eq 0 ] && [ -n "$sanitized_version" ]; then
        echo "$sanitized_version"
        return 0
    else
        echo "Error: Failed to sanitize version '$version'" >&2
        return 1
    fi
}

# Function to update the PKGBUILD file
update_pkgbuild() {
    local file_path="$1"
    local new_version="$2"
    
    # Check if PKGBUILD file exists
    if [ ! -f "$file_path" ]; then
        echo "Error: PKGBUILD file not found at '$file_path'" >&2
        return 1
    fi
    
    # Backup the original file
    cp "$file_path" "$file_path.backup" || {
        echo "Error: Failed to create backup of PKGBUILD" >&2
        return 1
    }
    
    # Use sed to find and replace the pkgver line
    sed -i "s/pkgver=.*/pkgver=$new_version/" "$file_path"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to update PKGBUILD" >&2
        # Restore backup
        mv "$file_path.backup" "$file_path"
        return 1
    fi
    
    # Verify the change was made
    if ! grep -q "pkgver=$new_version" "$file_path"; then
        echo "Error: Version update verification failed" >&2
        # Restore backup
        mv "$file_path.backup" "$file_path"
        return 1
    fi
    
    # Remove backup on success
    rm "$file_path.backup"
    return 0
}

# Main execution
main() {
    # URL of the JSON file
    url="https://ziglang.org/download/index.json"
    
    echo "Fetching Zig version information..."
    
    # Fetch and transform the version
    version_info=$(fetch_and_transform_zig_version "$url")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch and transform version" >&2
        exit 1
    fi
    
    read original_version transformed_version <<< "$version_info"
    
    # Validate that we got both versions
    if [ -z "$original_version" ] || [ -z "$transformed_version" ]; then
        echo "Error: Failed to parse version information" >&2
        exit 1
    fi
    
    echo "Original version: $original_version"
    echo "Transformed version: $transformed_version"
    
    # Update the PKGBUILD file
    pkgbuild_path="PKGBUILD"  # Assuming PKGBUILD is in the current directory
    
    echo "Updating PKGBUILD..."
    if update_pkgbuild "$pkgbuild_path" "$transformed_version"; then
        echo "Successfully updated PKGBUILD with new version: $transformed_version"
    else
        echo "Error: Failed to update PKGBUILD" >&2
        exit 1
    fi
}

# Run main function
main "$@"
