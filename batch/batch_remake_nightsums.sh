#!/usr/bin/env bash
set -Eeuo pipefail

# Usage: ./remake_nightsums.sh START_DAYOBS END_DAYOBS [SCHEDVIEW_NOTEBOOKS_DIR]
# Dates must be YYYYMMDD.
# Default SCHEDVIEW_NOTEBOOKS_DIR is the current directory.

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_CACHE_DIR="/sdf/group/rubin/web_data/sim-data/schedview/cache"
readonly DEFAULT_LOG_FILE="/sdf/data/rubin/shared/scheduler/schedview/scheduler_nightsum/scheduler_nightsum.out"
readonly SBATCH_BIN="/opt/slurm/slurm-curr/bin/sbatch"

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} START_DAYOBS END_DAYOBS [SCHEDVIEW_NOTEBOOKS_DIR]

Arguments:
  START_DAYOBS               Start date (inclusive), format YYYYMMDD
  END_DAYOBS                 End date (inclusive), format YYYYMMDD
  SCHEDVIEW_NOTEBOOKS_DIR  Optional; defaults to current directory

Environment variables (optional overrides):
  SCHEDVIEW_CACHE_DIR      Default: ${DEFAULT_CACHE_DIR}
  SCHEDVIEW_LOG_FILE       Default: ${DEFAULT_LOG_FILE}
  SBATCH_BIN               Default: ${SBATCH_BIN}
EOF
}

err() {
    echo "Error: $*" >&2
}

is_valid_dayobs() {
    local D="$1"
    [[ "$D" =~ ^[0-9]{8}$ ]] || return 1
    date -d "${D}" +%Y%m%d >/dev/null 2>&1 || return 1
}

# --- Argument count check ---
if [[ $# -lt 2 || $# -gt 3 ]]; then
    err "Expected 2 or 3 arguments."
    usage
    exit 1
fi

readonly START_DAYOBS="$1"
readonly END_DAYOBS="$2"
readonly SCHEDVIEW_NOTEBOOKS_DIR="${3:-.}"

# Optional overrides via environment
readonly SCHEDVIEW_CACHE_DIR="${SCHEDVIEW_CACHE_DIR:-$DEFAULT_CACHE_DIR}"
readonly SCHEDVIEW_LOG_FILE="${SCHEDVIEW_LOG_FILE:-$DEFAULT_LOG_FILE}"
readonly SBATCH="${SBATCH_BIN_OVERRIDE:-${SBATCH_BIN}}"

# --- Validate dates ---
if ! is_valid_dayobs "$START_DAYOBS"; then
    err "START_DAYOBS '$START_DAYOBS' is not a valid date in YYYYMMDD format."
    exit 1
fi

if ! is_valid_dayobs "$END_DAYOBS"; then
    err "END_DAYOBS '$END_DAYOBS' is not a valid date in YYYYMMDD format."
    exit 1
fi

# Compare canonicalized forms to avoid invalid lexical edge cases
START_DATE="$(date -d "$START_DAYOBS" +%s)"
END_DATE="$(date -d "$END_DAYOBS" +%s)"
if (( START_DATE > END_DATE )); then
    err "START_DAYOBS ($START_DAYOBS) must be <= END_DAYOBS ($END_DAYOBS)."
    exit 1
fi

# --- Validate paths/binaries ---
if ! command -v "$SBATCH" >/dev/null 2>&1; then
    err "sbatch binary not found/executable: $SBATCH"
    exit 1
fi

readonly JOB_SCRIPT="${SCHEDVIEW_NOTEBOOKS_DIR}/batch/scheduler_nightsum.sh"
if [[ ! -f "$JOB_SCRIPT" ]]; then
    err "Job script not found: $JOB_SCRIPT"
    exit 1
fi

if [[ ! -r "$JOB_SCRIPT" ]]; then
    err "Job script is not readable: $JOB_SCRIPT"
    exit 1
fi

LOG_DIR="$(dirname "$SCHEDVIEW_LOG_FILE")"
if [[ ! -d "$LOG_DIR" ]]; then
    err "Log directory does not exist: $LOG_DIR"
    exit 1
fi

CURRENT_DAYOBS="$END_DAYOBS"
SUBMITTED=0
FAILED=0

while [[ "$CURRENT_DAYOBS" -ge "$START_DAYOBS" ]]; do
    if "$SBATCH" \
        --export="SCHEDVIEW_DAY_OBS=${CURRENT_DAYOBS},SCHEDVIEW_CACHE_DIR=${SCHEDVIEW_CACHE_DIR}" \
        "$JOB_SCRIPT" >>"$SCHEDVIEW_LOG_FILE" 2>&1; then
        ((SUBMITTED += 1))
    else
        ((FAILED += 1))
        err "Failed to submit job for date ${CURRENT_DAYOBS}."
    fi

    CURRENT_DAYOBS="$(date -d "${CURRENT_DAYOBS} -1 day" +%Y%m%d)"
done

if (( FAILED > 0 )); then
    err "Completed with errors: submitted=${SUBMITTED}, failed=${FAILED}."
    exit 1
fi

echo "Done: submitted ${SUBMITTED} jobs for dates ${START_DAYOBS}..${END_DAYOBS} (descending)."
