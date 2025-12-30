#!/bin/bash
#
# Claude Code Post-Edit Hook
# Runs quick tests after file edits to catch issues early
#

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Get the file that was edited from environment
FILE="${CLAUDE_TOOL_INPUT_file_path:-}"

# Skip if no file or not a Ruby/ERB file
if [ -z "$FILE" ]; then
    exit 0
fi

# Determine what tests to run based on file type
case "$FILE" in
    */models/*.rb)
        # Run related model specs
        MODEL_NAME=$(basename "$FILE" .rb)
        SPEC_FILE="spec/models/pwb/${MODEL_NAME}_spec.rb"
        if [ -f "$SPEC_FILE" ]; then
            echo "Running model tests for $MODEL_NAME..."
            bundle exec rspec "$SPEC_FILE" --fail-fast 2>&1 | tail -15
        fi
        ;;
    */helpers/*.rb)
        # Run helper specs
        HELPER_NAME=$(basename "$FILE" .rb)
        SPEC_FILE="spec/helpers/pwb/${HELPER_NAME}_spec.rb"
        if [ -f "$SPEC_FILE" ]; then
            echo "Running helper tests for $HELPER_NAME..."
            bundle exec rspec "$SPEC_FILE" --fail-fast 2>&1 | tail -15
        fi
        ;;
    */controllers/*.rb)
        # Run controller specs
        CONTROLLER_NAME=$(basename "$FILE" .rb)
        SPEC_FILE="spec/controllers/pwb/${CONTROLLER_NAME}_spec.rb"
        if [ -f "$SPEC_FILE" ]; then
            echo "Running controller tests for $CONTROLLER_NAME..."
            bundle exec rspec "$SPEC_FILE" --fail-fast 2>&1 | tail -15
        fi
        ;;
    */lib/tasks/*.rake)
        # Run rake task specs
        TASK_NAME=$(basename "$FILE" .rake)
        SPEC_FILE="spec/lib/tasks/${TASK_NAME}_spec.rb"
        if [ -f "$SPEC_FILE" ]; then
            echo "Running rake task tests for $TASK_NAME..."
            bundle exec rspec "$SPEC_FILE" --fail-fast 2>&1 | tail -15
        fi
        ;;
    *.rb)
        # For other Ruby files, just check syntax
        echo "Checking Ruby syntax..."
        ruby -c "$FILE" 2>&1
        ;;
    *.erb|*.liquid)
        # For templates, run a quick asset check
        echo "Template modified: $FILE"
        ;;
esac

exit 0
