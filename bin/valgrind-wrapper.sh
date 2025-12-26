#!/bin/bash
# valgrind-wrapper.sh

set -e

# Default values
LOG_DIR="valgrind_logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEFAULT_LOG="${LOG_DIR}/valgrind_${TIMESTAMP}.log"

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        -d|--log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

PROGRAM="$1"
shift
ARGS="$@"

# Set log file if not specified
if [[ -z "$LOG_FILE" ]]; then
    PROGRAM_BASENAME=$(basename "$PROGRAM")
    LOG_FILE="${LOG_DIR}/valgrind_${PROGRAM_BASENAME}_${TIMESTAMP}.log"
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

VALGRIND_OPTS="--leak-check=full \
               --show-leak-kinds=all \
               --track-origins=yes \
               --num-callers=30 \
               --error-exitcode=1 \
               --trace-children=yes \
               --log-file=$LOG_FILE"

# Add verbose mode if requested
if [[ "$VERBOSE_MODE" == true ]]; then
    VALGRIND_OPTS="$VALGRIND_OPTS --verbose"
fi

# Check if program exists
if [[ ! -x "$PROGRAM" ]]; then
    echo "Error: $PROGRAM not found or not executable"
    exit 1
fi

# Display information (unless quiet mode)
if [[ "$QUIET_MODE" != true ]]; then
    echo "=============================================="
    echo "Valgrind Memory Analysis"
    echo "=============================================="
    echo "Program:    $PROGRAM"
    echo "Arguments:  $ARGS"
    echo "Log file:   $LOG_FILE"
    echo "Timestamp:  $(date)"
    echo "=============================================="
    echo ""
fi

# Run valgrind
if [[ "$QUIET_MODE" == true ]]; then
    valgrind $VALGRIND_OPTS ./"$PROGRAM" $ARGS > /dev/null 2>&1
else
    echo "Running Valgrind..."
    valgrind $VALGRIND_OPTS ./"$PROGRAM" $ARGS
fi

# Check exit code
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
    if [[ "$QUIET_MODE" != true ]]; then
        echo "❌ Valgrind found errors (exit code: $EXIT_CODE)"
        echo "📄 Detailed report saved to: $LOG_FILE"
        
        # Show summary of errors from log file
        echo ""
        echo "Error Summary:"
        echo "--------------"
        grep -E "ERROR SUMMARY|definitely lost|indirectly lost|possibly lost" "$LOG_FILE" | head -4
    fi
    exit $EXIT_CODE
else
    if [[ "$QUIET_MODE" != true ]]; then
        echo "✅ Valgrind completed successfully"
        echo "📄 Report saved to: $LOG_FILE"
        
        # Show quick summary
        echo ""
        echo "Memory Summary:"
        echo "---------------"
        grep "ERROR SUMMARY" "$LOG_FILE"
    fi
fi
