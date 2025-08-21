#!/bin/bash

# test_repo.sh: A script to diagnose the health and contents of the local DNF repository.

set -e

# --- Configuration ---
DNF_REPO_DIR="/home/user/marquee-magic_repo"
PACKAGE_NAME="marquee-server"
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
echo "--- Decompressing Primary Metadata ---"
PRIMARY_XML_PATH=$(awk '/type="primary"/,/<\/data>/ {if(/href=/) {gsub(/.*href="|"\/>/,""); print}}' "$REPOMD_FILE")
if [ -z "$PRIMARY_XML_PATH" ]; then
    print_error "Could not find the path to the primary XML file inside repomd.xml."
fi

# Ensure the path is relative to the repo dir for unzstd
FULL_ZST_PATH="${DNF_REPO_DIR}/${PRIMARY_XML_PATH}"

if [ ! -f "$FULL_ZST_PATH" ]; then
    print_error "Compressed primary metadata file not found at ${FULL_ZST_PATH}"
fi

unzstd "$FULL_ZST_PATH" -o "$TEMP_XML_FILE"
print_success "Decompressed primary metadata to ${TEMP_XML_FILE}"

# 5. Analyze the contents for the specified package
echo "--- Analyzing Repository Contents for '${PACKAGE_NAME}' ---"
PACKAGE_COUNT=$(grep -c "<name>${PACKAGE_NAME}</name>" "$TEMP_XML_FILE")

if [ "$PACKAGE_COUNT" -eq 0 ]; then
    print_error "Package '${PACKAGE_NAME}' was not found in the repository metadata."
fi

print_info "Found ${PACKAGE_COUNT} entr(y/ies) for '${PACKAGE_NAME}'."

# List all found versions
print_info "Listing all advertised versions:"
grep -A 2 "<name>${PACKAGE_NAME}</name>" "$TEMP_XML_FILE" | grep 'location href'

if [ "$PACKAGE_COUNT" -gt 1 ]; then
    print_error "Multiple versions of '${PACKAGE_NAME}' found in the metadata. This is the source of the DNF issue. Please run the build script that cleans the 'repodata' directory."
fi

LATEST_VERSION=$(grep -A 2 "<name>${PACKAGE_NAME}</name>" "$TEMP_XML_FILE" | grep 'location href' | sed -n 's/.*href="aarch64\/\(.*\).rpm".*/\1/p')

print_success "Repository is pristine. The only advertised version is: ${LATEST_VERSION}"
echo "--- Test Complete ---"

# Clean up
rm -f "$TEMP_XML_FILE"

