#!/bin/bash

# test_repo.sh: A script to diagnose the health and list all contents of the local DNF repository.

set -e

# --- Configuration ---
DNF_REPO_DIR="/home/user/marquee-magic_repo"
TEMP_XML_FILE="/tmp/primary.xml"

# --- Helper Functions ---
print_success() {
    echo "✅ SUCCESS: $1"
}

print_error() {
    echo "❌ ERROR: $1" >&2
    exit 1
}

print_info() {
    echo "ℹ️  INFO: $1"
}

# --- Main Script ---
echo "--- Starting Local DNF Repository Test ---"

# 1. Check if the repository directory exists
if [ ! -d "$DNF_REPO_DIR" ]; then
    print_error "Repository directory not found at ${DNF_REPO_DIR}"
fi
print_success "Repository directory found."

# 2. Check if the repodata directory exists
REPODATA_DIR="${DNF_REPO_DIR}/repodata"
if [ ! -d "$REPODATA_DIR" ]; then
    print_error "Metadata directory 'repodata' not found. Please run your build script to generate it."
fi
print_success "Metadata directory 'repodata' found."

# 3. Check if repomd.xml exists and is not empty
REPOMD_FILE="${REPODATA_DIR}/repomd.xml"
if [ ! -s "$REPOMD_FILE" ]; then
    print_error "Metadata index file 'repomd.xml' is missing or empty."
fi
print_success "Metadata index file 'repomd.xml' is valid."

# 4. Decompress the primary metadata file
print_info "--- Decompressing Primary Metadata ---"
PRIMARY_XML_PATH=$(awk '/type="primary"/,/<\/data>/ {if(/href=/) {gsub(/.*href="|"\/>/,""); print}}' "$REPOMD_FILE")
if [ -z "$PRIMARY_XML_PATH" ]; then
    print_error "Could not find the path to the primary XML file inside repomd.xml."
fi

FULL_ZST_PATH="${DNF_REPO_DIR}/${PRIMARY_XML_PATH}"

if [ ! -f "$FULL_ZST_PATH" ]; then
    print_error "Compressed primary metadata file not found at ${FULL_ZST_PATH}"
fi

# Use -f to force overwrite of the temp file without prompting
unzstd -f "$FULL_ZST_PATH" -o "$TEMP_XML_FILE"
print_success "Decompressed primary metadata to ${TEMP_XML_FILE}"

# 5. Analyze the contents for all packages
print_info "--- Analyzing Repository Contents ---"

# Use awk to find every package block and print its location href line.
PACKAGE_LIST=$(awk '
/<package type="rpm"/ { in_pkg=1 }
/location href/ && in_pkg { gsub(/.*href="aarch64\/|"\/>/,""); print }
/<\/package>/ { in_pkg=0 }
' "$TEMP_XML_FILE")

if [ -z "$PACKAGE_LIST" ]; then
    print_error "No packages were found in the repository metadata."
fi

PACKAGE_COUNT=$(echo "$PACKAGE_LIST" | wc -l)
print_success "Found ${PACKAGE_COUNT} total package(s) in the repository."
print_info "Listing all advertised packages:"
echo "----------------------------------------"
echo "$PACKAGE_LIST"
echo "----------------------------------------"
echo "--- Test Complete ---"

# Clean up
rm -f "$TEMP_XML_FILE"

