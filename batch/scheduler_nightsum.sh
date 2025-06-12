#!/usr/bin/env bash
#SBATCH --account=rubin:developers      # Account name
#SBATCH --job-name=lsstcam_nightsum_daily   # Job name
#SBATCH --output=/sdf/data/rubin/shared/scheduler/schedview/sbatch/scheduler_nightsum.out # Output file (stdout)
#SBATCH --error=/sdf/data/rubin/shared/scheduler/schedview/sbatch/scheduler_nightsum.err  # Error file (stderr)
#SBATCH --partition=milano              # Partition (queue) names
#SBATCH --nodes=1                       # Number of nodes
#SBATCH --ntasks=1                      # Number of tasks run in parallel
#SBATCH --cpus-per-task=1               # Number of CPUs per task
#SBATCH --mem=4G                       # Requested memory
#SBATCH --time=1:00:00                 # Wall time (hh:mm:ss)

echo "******** START of scheduler_nightsum.sh **********"

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# SLAC S3DF - source all files under ~/.profile.d
if [[ -e ~/.profile.d && -n "$(ls -A ~/.profile.d/)" ]]; then
  source <(cat $(find -L  ~/.profile.d -name '*.conf'))
fi

date --iso=s

source /sdf/group/rubin/sw/w_latest/loadLSST.sh
conda activate /sdf/data/rubin/user/neilsen/home/dot_conda/envs/ehn313
source ${HOME}/.auth_bashrc

set -o xtrace

echo "Setting parameters"
date --iso=s
export SCHEDVIEW_VISIT_ORIGIN='lsstcam'
DAYOBS_YY=$(date -d yesterday '+%Y')
DAYOBS_MM=$(date -d yesterday '+%m')
DAYOBS_DD=$(date -d yesterday '+%d')
export SCHEDVIEW_DAY_OBS="${DAYOBS_YY}${DAYOBS_MM}${DAYOBS_DD}"

echo "Preparing directory for this nightsum"
date --iso=s
# Make the directory in which to work and save the html file
NIGHTSUM_DIR="/sdf/data/rubin/shared/scheduler/reports/nightsum/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
mkdir -p ${NIGHTSUM_DIR}
cd ${NIGHTSUM_DIR}

SCHEDULER_NIGHTSUM_SOURCE="/sdf/data/rubin/user/neilsen/forcron/schedview_notebooks/nightly/scheduler-nightsum.ipynb"
echo "Copying scheduler_nightsum.ipynb from ${SCHEDULER_NIGHTSUM_SOURCE}"
date --iso=s
# Get the notebook
NIGHTSUM_FNAME_BASE="nightsum_${DAYOBS_YY}-${DAYOBS_MM}-${DAYOBS_DD}"
NIGHTSUM_FNAME=${NIGHTSUM_FNAME_BASE}.ipynb
# Do not just blindly check out of git, but copy from somewhere hand
# checked.
cp ${SCHEDULER_NIGHTSUM_SOURCE} $NIGHTSUM_FNAME

echo "Executing the nightsum notebook"
date --iso=s
# At the USDF, the timings can be very slow compared to running on a laptop,
# so set the timeouts really high.
# Setting the kernel_name to python3 uses the kernel from the activated
# conda environment.
time jupyter nbconvert \
    --to html \
    --execute \
    --no-input \
    --ExecutePreprocessor.kernel_name=python3 \
    --ExecutePreprocessor.startup_timeout=3600 \
    --ExecutePreprocessor.timeout=3600 \
    ${NIGHTSUM_FNAME}


echo "Preparing directory for this prenight comparison"
date --iso=s
# Make the directory in which to work and save the html file
COMPARE_NIGHT_DIR="/sdf/data/rubin/shared/scheduler/reports/compareprenight/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
mkdir -p ${COMPARE_NIGHT_DIR}
cd ${COMPARE_NIGHT_DIR}

COMPARE_NIGHT_SOURCE="/sdf/data/rubin/user/neilsen/forcron/schedview_notebooks/nightly/compareprenight.ipynb"
echo "Copying compareprenight.ipynb from ${COMPARE_NIGHT_SOURCE}"
date --iso=s
# Get the notebook
COMPARE_NIGHT_FNAME_BASE="comparenight_${DAYOBS_YY}-${DAYOBS_MM}-${DAYOBS_DD}"
COMPARE_NIGHT_FNAME=${COMPARE_NIGHT_FNAME_BASE}.ipynb
# Do not just blindly check out of git, but copy from somewhere hand
# checked.
cp ${COMPARE_NIGHT_SOURCE} $COMPARE_NIGHT_FNAME


echo "Executing the compare prenight notebook"
date --iso=s
# At the USDF, the timings can be very slow compared to running on a laptop,
# so set the timeouts really high.
# Setting the kernel_name to python3 uses the kernel from the activated
# conda environment.
time jupyter nbconvert \
    --to html \
    --execute \
    --no-input \
    --ExecutePreprocessor.kernel_name=python3 \
    --ExecutePreprocessor.startup_timeout=3600 \
    --ExecutePreprocessor.timeout=3600 \
    ${COMPARE_NIGHT_FNAME}


echo "Done."
date --iso=s
