#!/usr/bin/env bash

# --- Configuration ---
# Directory to store packed packages and version data
IPACKS_DIR="$HOME/.ipacks"
# File storing alias and version information
DATA_FILE="$IPACKS_DIR/data.json"

# --- Helper Functions ---
function print_usage {
  echo "Usage:"
  echo "  ipack pack <alias> [directory]  - Builds, packs, versions, and stores the package."
  echo "                                      If [directory] is provided, 'npm pack' runs inside it."
  echo "                                      Replaces '/' with '-' in the saved .tgz filename."
  echo "                                      Removes the previous .tgz for this alias."
  echo "  ipack i|install <alias>         - Installs the latest version of the package associated with <alias>."
  echo "  ipack help                      - Shows this help message."
}

function ensure_jq {
  # Check if jq command is available
  if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' command not found. Please install jq (e.g., 'brew install jq')."
    exit 1
  fi
}

function ensure_ipacks_setup {
  # Ensure the main storage directory exists
  mkdir -p "$IPACKS_DIR"
  # Initialize the data file if it doesn't exist
  if [ ! -f "$DATA_FILE" ]; then
    echo "{}" > "$DATA_FILE"
    echo "Initialized data file at $DATA_FILE"
  fi
}

function read_data {
  # Read the entire data file content
  jq '.' "$DATA_FILE"
}

function write_data {
  # Safely write JSON content to the data file using a temporary file
  local json_content="$1"
  local tmp_file
  tmp_file=$(mktemp)
  # Validate JSON before writing
  if echo "$json_content" | jq '.' > "$tmp_file"; then
    mv "$tmp_file" "$DATA_FILE"
  else
    echo "Error: Failed to write updated data to $DATA_FILE. Invalid JSON generated."
    rm "$tmp_file" # Clean up temp file
    exit 1
  fi
}

function get_alias_info {
  # Get the JSON object for a specific alias
  local alias="$1"
  jq -r --arg alias "$alias" '.[$alias]' "$DATA_FILE"
}

function update_alias_info {
  # Update or set the info (package name, version) for an alias
  # NOTE: Stores the ORIGINAL package name in the JSON
  local alias="$1"
  local original_package_name="$2" # Keep original name here
  local new_version="$3"

  local current_data
  current_data=$(read_data)

  local updated_data
  # Use jq to update the specific alias key
  updated_data=$(echo "$current_data" | jq \
    --arg alias "$alias" \
    --arg pkgName "$original_package_name" \
    --argjson version "$new_version" \
    '.[$alias] = {"packageName": $pkgName, "version": $version}')

  write_data "$updated_data"
}

# --- Main Script Logic ---

# Check dependencies
ensure_jq
ensure_ipacks_setup

# Parse arguments
COMMAND=$1
ALIAS=$2
ARG3=$3 # Could be the directory for 'pack'

case "$COMMAND" in
  pack)
    # --- 'pack' command logic ---
    if [ -z "$ALIAS" ]; then
      echo "Error: Alias is required for 'pack' command."
      print_usage
      exit 1
    fi

    # Check for package.json in the current directory
    if [ ! -f "package.json" ]; then
      echo "Error: 'package.json' not found in the current directory ($(pwd))."
      exit 1
    fi

    # Read ORIGINAL package name from package.json
    ORIGINAL_PACKAGE_NAME=$(jq -r '.name' package.json)
    if [ -z "$ORIGINAL_PACKAGE_NAME" ] || [ "$ORIGINAL_PACKAGE_NAME" == "null" ]; then
        echo "Error: Could not read package name from package.json."
        exit 1
    fi
    # Create a filesystem-safe version of the package name
    SAFE_PACKAGE_NAME=${ALIAS//\//-} # Replace all '/' with '-'
    echo "--- Original package name: $ORIGINAL_PACKAGE_NAME ---"
    echo "--- Filesystem-safe name: $SAFE_PACKAGE_NAME ---"


    # Build the package
    echo "--- Running 'npm run build'... ---"
    if ! npm run build; then
      echo "Error: 'npm run build' failed."
      exit 1
    fi
    echo "--- Build successful ---"

    ORIGINAL_PWD=$(pwd)
    PACK_DIR="." # Default pack location is current directory
    PACK_IN_SUBDIR=false

    # Check if a target directory for 'npm pack' was provided
    if [ -n "$ARG3" ]; then
      if [ -d "$ARG3" ]; then
        PACK_DIR="$ARG3"
        echo "--- Changing directory to '$PACK_DIR' for packing... ---"
        if ! cd "$PACK_DIR"; then
            echo "Error: Failed to change directory to '$PACK_DIR'."
            exit 1
        fi
        PACK_IN_SUBDIR=true
      else
        echo "Error: Provided directory '$ARG3' does not exist."
        cd "$ORIGINAL_PWD" || exit 1 # Go back if cd failed before exiting
        exit 1
      fi
    fi

    # Pack the package and capture the filename (last line of npm pack output)
    echo "--- Running 'npm pack' in '$PWD'... ---"
    # Note: npm pack might create a filename based on ORIGINAL_PACKAGE_NAME
    PACKED_FILENAME_RELATIVE=$(npm pack | tail -n 1)
    NPM_PACK_EXIT_CODE=$?

    # Store the absolute path to the packed file *before* potentially changing back
    PACKED_FILE_ABS_PATH="$PWD/$PACKED_FILENAME_RELATIVE"

    # Return to the original directory if we changed into a subdirectory
    if $PACK_IN_SUBDIR; then
      echo "--- Returning to original directory '$ORIGINAL_PWD'... ---"
      if ! cd "$ORIGINAL_PWD"; then
          echo "Error: Failed to return to the original directory '$ORIGINAL_PWD'."
          # Try to continue anyway, as the file is already packed
      fi
    fi

    # Check the result of npm pack
    if [ $NPM_PACK_EXIT_CODE -ne 0 ] || [ -z "$PACKED_FILENAME_RELATIVE" ] || [ ! -f "$PACKED_FILE_ABS_PATH" ]; then
      echo "Error: 'npm pack' failed or did not produce a file."
      echo "Expected file at: $PACKED_FILE_ABS_PATH"
      ls -la "$(dirname "$PACKED_FILE_ABS_PATH")" # List directory contents for debugging if pack failed
      exit 1
    fi
    # Check if the generated file name actually matches the expected safe name convention from npm>=7
    # Example: npm pack might generate '@org-pkg-1.0.0.tgz' or 'org-pkg-1.0.0.tgz'
    # We will rename it consistently using our SAFE_PACKAGE_NAME later.

    # Read the current version for the alias, defaulting to 0 if not found
    CURRENT_VERSION=$(jq -r --arg alias "$ALIAS" '.[$alias].version // 0' "$DATA_FILE")
    NEW_VERSION=$((CURRENT_VERSION + 1))
    echo "--- Versioning: '$ALIAS' -> $NEW_VERSION ---"

    # --- Clean up previous version ---
    if [ "$CURRENT_VERSION" -gt 0 ]; then
        # Construct the filename of the previous version using the SAFE name
        PREVIOUS_TGZ_FILENAME="${SAFE_PACKAGE_NAME}-${CURRENT_VERSION}.tgz"
        PREVIOUS_TGZ_PATH="$IPACKS_DIR/$PREVIOUS_TGZ_FILENAME"
        # Check if the previous version file exists and remove it
        if [ -f "$PREVIOUS_TGZ_PATH" ]; then
            echo "--- Removing previous version: $PREVIOUS_TGZ_PATH ---"
            if ! rm "$PREVIOUS_TGZ_PATH"; then
                # Log a warning but continue, as cleanup failure isn't critical
                echo "Warning: Failed to remove previous version at $PREVIOUS_TGZ_PATH."
            fi
        else
            # Inform user if no previous file was found
            echo "--- No previous version file found for $ALIAS (safe name $SAFE_PACKAGE_NAME) version $CURRENT_VERSION to remove. ---"
        fi
    else
         # Inform user this is the first tracked version for the alias
        echo "--- This is the first tracked version ($NEW_VERSION), no previous version to remove. ---"
    fi

    # --- Move and rename the newly packed file ---
    # Construct the NEW filename using the SAFE name
    NEW_TGZ_FILENAME="${SAFE_PACKAGE_NAME}-${NEW_VERSION}.tgz"
    TARGET_TGZ_PATH="$IPACKS_DIR/$NEW_TGZ_FILENAME"

    echo "--- Moving '$PACKED_FILE_ABS_PATH' to '$TARGET_TGZ_PATH'... ---"
    # The move command now uses the TARGET_TGZ_PATH which has the safe filename
    if ! mv "$PACKED_FILE_ABS_PATH" "$TARGET_TGZ_PATH"; then
      echo "Error: Failed to move the packed file."
      # Add more debugging info if move fails
      echo "Source: $PACKED_FILE_ABS_PATH"
      echo "Target: $TARGET_TGZ_PATH"
      echo "Source exists? $(ls -l "$PACKED_FILE_ABS_PATH")"
      echo "Target directory exists? $(ls -ld "$IPACKS_DIR")"
      exit 1
    fi

    # --- Update the data file with the new version info ---
    # IMPORTANT: Store the ORIGINAL package name in the JSON data
    echo "--- Updating alias info in '$DATA_FILE' (using original name '$ORIGINAL_PACKAGE_NAME')... ---"
    if update_alias_info "$ALIAS" "$ORIGINAL_PACKAGE_NAME" "$NEW_VERSION"; then
        echo "--- Successfully packed and stored '$ORIGINAL_PACKAGE_NAME' as '$ALIAS' version $NEW_VERSION ---"
        echo "--- Saved to: $TARGET_TGZ_PATH (using safe name $SAFE_PACKAGE_NAME) ---"
    else
        echo "Error: Failed to update $DATA_FILE."
        # Optional: Consider attempting to revert the move if the JSON update fails
        exit 1
    fi
    ;;

  i|install)
    # --- 'install' command logic ---
    if [ -z "$ALIAS" ]; then
      echo "Error: Alias is required for 'install' command."
      print_usage
      exit 1
    fi

    # Read the alias information from the data file
    ALIAS_INFO=$(get_alias_info "$ALIAS")

    # Check if alias exists in the data
    if [ "$ALIAS_INFO" == "null" ] || [ -z "$ALIAS_INFO" ]; then
      echo "Error: Alias '$ALIAS' not found in $DATA_FILE."
      exit 1
    fi

    # Extract ORIGINAL package name and latest version from the alias info
    ORIGINAL_PACKAGE_NAME=$(echo "$ALIAS_INFO" | jq -r '.packageName')
    LATEST_VERSION=$(echo "$ALIAS_INFO" | jq -r '.version')

    # Validate the extracted data
    if [ -z "$ORIGINAL_PACKAGE_NAME" ] || [ "$ORIGINAL_PACKAGE_NAME" == "null" ] || [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" == "null" ]; then
       echo "Error: Incomplete data found for alias '$ALIAS' in $DATA_FILE."
       exit 1
    fi

    # Create the filesystem-safe version of the package name for filename lookup
    SAFE_PACKAGE_NAME=${ALIAS//\//-}

    # Construct the full path to the package .tgz file using the SAFE name
    PACKAGE_FILENAME="${SAFE_PACKAGE_NAME}-${LATEST_VERSION}.tgz"
    PACKAGE_PATH="$IPACKS_DIR/$PACKAGE_FILENAME"

    # Check if the target package file exists
    if [ ! -f "$PACKAGE_PATH" ]; then
      echo "Error: Package file for '$ALIAS' (version $LATEST_VERSION) not found."
      echo "       Original name: $ORIGINAL_PACKAGE_NAME"
      echo "       Expected safe filename: $PACKAGE_FILENAME"
      echo "       Expected path: $PACKAGE_PATH"
      exit 1
    fi

    # Install the package using npm
    echo "--- Installing '$ORIGINAL_PACKAGE_NAME' version $LATEST_VERSION from '$PACKAGE_PATH'... ---"
    if ! npm install "$PACKAGE_PATH"; then
      echo "Error: 'npm install $PACKAGE_PATH' failed."
      exit 1
    fi
    echo "--- Successfully installed $ALIAS (package '$ORIGINAL_PACKAGE_NAME' version $LATEST_VERSION) ---"
    ;;

  help|--help|-h)
    # Display help message
    print_usage
    ;;

  *)
    # Handle unknown commands
    echo "Error: Unknown command '$COMMAND'."
    print_usage
    exit 1
    ;;
esac

exit 0