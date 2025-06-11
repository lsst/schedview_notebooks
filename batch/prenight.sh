#!/usr/bin/env bash
#SBATCH --account=rubin:developers      # Account name
#SBATCH --job-name=lsstcam_prenight_daily   # Job name
#SBATCH --output=/sdf/data/rubin/shared/scheduler/schedview/sbatch/prenight.out # Output file (stdout)
#SBATCH --error=/sdf/data/rubin/shared/scheduler/schedview/sbatch/prenight.err  # Error file (stderr)
#SBATCH --partition=milano              # Partition (queue) names
#SBATCH --nodes=1                       # Number of nodes
#SBATCH --ntasks=1                      # Number of tasks run in parallel
#SBATCH --cpus-per-task=1               # Number of CPUs per task
#SBATCH --mem=8G                       # Requested memory
#SBATCH --time=1:00:00                 # Wall time (hh:mm:ss)

echo "******** START of PRENIGHT.sh **********"

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
conda activate /sdf/data/rubin/shared/scheduler/envs/prenight
source ${HOME}/.auth_bashrc

set -o xtrace

echo "Setting parameters"
date --iso=s
export SCHEDVIEW_INSTRUMENT='lsstcam'
export SCHEDVIEW_TELESCOPE="simonyi"
DAYOBS_YY=$(date '+%Y')
DAYOBS_MM=$(date '+%m')
DAYOBS_DD=$(date '+%d')
export SCHEDVIEW_DAY_OBS="${DAYOBS_YY}${DAYOBS_MM}${DAYOBS_DD}"
export SCHEDVIEW_SIM_DATE="${DAYOBS_YY}-${DAYOBS_MM}-${DAYOBS_DD}"
export SCHEDVIEW_SIM_INDEX="1"

echo "Preparing prenight directory for this prenight"
date --iso=s
# Make the directory in which to work and save the html file
PRENIGHT_DIR="/sdf/data/rubin/shared/scheduler/reports/prenight/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
mkdir -p ${PRENIGHT_DIR}
cd ${PRENIGHT_DIR}

PRENIGHT_SOURCE="/sdf/data/rubin/user/neilsen/forcron/schedview_notebooks/prenight/prenight.ipynb"
echo "Copying prenight.ipynb from ${PRENIGHT_SOURCE}"
date --iso=s
# Get the notebook
PRENIGHT_FNAME_BASE="prenight_${DAYOBS_YY}-${DAYOBS_MM}-${DAYOBS_DD}"
PRENIGHT_FNAME=${PRENIGHT_FNAME_BASE}.ipynb
# Do not just blindly check out of git, but copy from somewhere hand
# checked.
cp ${PRENIGHT_SOURCE} $PRENIGHT_FNAME

echo "Executing the prenight notebook"
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
    ${PRENIGHT_FNAME}


echo "Preparing multiprenight directory for this dayobs"
date --iso=s
# Make the directory in which to work and save the html file
MULTIPRENIGHT_DIR="/sdf/data/rubin/shared/scheduler/reports/multiprenight/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
mkdir -p ${MULTIPRENIGHT_DIR}
cd ${MULTIPRENIGHT_DIR}

MULTIPRENIGHT_SOURCE="/sdf/data/rubin/user/neilsen/forcron/schedview_notebooks/prenight/multiprenight.ipynb"
echo "Copying multiprenight.ipynb from ${MULTIPRENIGHT_SOURCE}"
date --iso=s
# Get the notebook
MULTIPRENIGHT_FNAME_BASE="multiprenight_${DAYOBS_YY}-${DAYOBS_MM}-${DAYOBS_DD}"
MULTIPRENIGHT_FNAME=${MULTIPRENIGHT_FNAME_BASE}.ipynb
# Do not just blindly check out of git, but copy from somewhere hand
# checked.
cp ${MULTIPRENIGHT_SOURCE} $MULTIPRENIGHT_FNAME

echo "Executing the multiprenight notebook"
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
    ${MULTIPRENIGHT_FNAME}

echo "Done."
date --iso=s


echo "Done."
date --iso=s
