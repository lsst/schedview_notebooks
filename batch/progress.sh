#!/usr/bin/env bash
#SBATCH --account=rubin:developers      # Account name
#SBATCH --job-name=lsstcam_nightsum_daily   # Job name
#SBATCH --output=/sdf/data/rubin/shared/scheduler/schedview/sbatch/scheduler_nightsum_%A_%a.out # Output file (stdout)
#SBATCH --error=/sdf/data/rubin/shared/scheduler/schedview/sbatch/scheduler_nightsum_%A_%a.out  # Error file (stderr)
#SBATCH --partition=milano              # Partition (queue) names
#SBATCH --nodes=1                       # Number of nodes
#SBATCH --ntasks=1                      # Number of tasks run in parallel
#SBATCH --cpus-per-task=1               # Number of CPUs per task
#SBATCH --mem=12G                       # Requested memory
#SBATCH --time=1:00:00                 # Wall time (hh:mm:ss)

echo "******** START of scheduler_nightsum.sh **********"

if [ -z $(command -v prenight_inventory ) ] ; then
  # If prenight_inventory is not already in our environment,
  # set up the standard prenight sim environment at the
  # USDF.

  # Source global definitions
  if [ -f /etc/bashrc ]; then
    . /etc/bashrc
  fi

  # SLAC S3DF - source all files under ~/.profile.d
  if [[ -e ~/.profile.d && -n "$(ls -A ~/.profile.d/)" ]]; then
    source <(cat $(find -L  ~/.profile.d -name '*.conf'))
  fi

  source /sdf/group/rubin/sw/w_latest/loadLSST.sh
  conda activate /sdf/data/rubin/shared/scheduler/envs/like_rsp_w2025_36
fi

# The gate files provide a mechanism that scheduler group members
# can use to stop this script from running, so if a cron job is
# running it it can still be stopped when the owner is not
# available.
# This is accomplished by deleting the gate file
# with the name of the owner of the cron job.
CRONGATE=/sdf/data/rubin/shared/scheduler/cron_gates/progress/${USER}
echo "Checking gatefile ${CRONGATE}"
if test ! -e ${CRONGATE} ; then
    echo "Aborting because ${CRONGATE} does not exist."
    echo "See /sdf/data/rubin/shared/scheduler/cron_gates/README.txt"
    exit 1
fi

set -o xtrace

echo "Setting parameters"

newgrp rubin_users
SCHEDULER_GROUP_USERS="lynnej neilsen yoachim"

export ACCESS_TOKEN_FILE=${HOME}/.lsst/usdf_access_token

date --iso=s
if [ -z ${SCHEDVIEW_DAY_OBS+xxx} ] ; then
    SCHEDVIEW_DAY_OBS=$(date -d yesterday '+%Y%m%d')
else
  if [[ ! ${SCHEDVIEW_DAY_OBS} =~ ^20[0-9]{6}$ ]]; then
    echo "SCHEDVIEW_DAY_OBS must by in YYYYMMDD format"
    exit 1
  fi
fi
DAYOBS_YY=$(echo $SCHEDVIEW_DAY_OBS | cut -c-4)
DAYOBS_MM=$(echo $SCHEDVIEW_DAY_OBS | cut -c5-6)
DAYOBS_DD=$(echo $SCHEDVIEW_DAY_OBS | cut -c7-8)
export SCHEDVIEW_DAY_OBS

export SCHEDVIEW_VISIT_ORIGIN=lsstcam
export EXTRAP_DAY_OBS='20261101'

echo "Preparing directory for this pre-progress report"
date --iso=s
# Make the directory in which to work and save the html file
PROGRESS_DIR="/sdf/data/rubin/shared/scheduler/reports/preprogress/lsstcam/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
mkdir -p ${PROGRESS_DIR}
chmod go+rx "/sdf/data/rubin/shared/scheduler/reports/preprogress/lsstcam/${DAYOBS_YY}"
chmod go+rx "/sdf/data/rubin/shared/scheduler/reports/preprogress/lsstcam/${DAYOBS_YY}/${DAYOBS_MM}"
chmod go+rx ${PROGRESS_DIR}

for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do 
  setfacl -m ${SCHEDULER_GROUP_USER}:rwX "/sdf/data/rubin/shared/scheduler/reports/preprogress/lsstcam/${DAYOBS_YY}"
  setfacl -m ${SCHEDULER_GROUP_USER}:rwX "/sdf/data/rubin/shared/scheduler/reports/preprogress/lsstcam/${DAYOBS_YY}/${DAYOBS_MM}"
  setfacl -m ${SCHEDULER_GROUP_USER}:rwX "${PROGRESS_DIR}"
done

cd ${PROGRESS_DIR}

PROGRESS_SOURCE="/sdf/data/rubin/shared/scheduler/packages/schedview_notebooks/progress/pre-progress.ipynb"
echo "Copying pre-progress.ipynb from ${PROGRESS_SOURCE}"
date --iso=s
# Get the notebook
PROGRESS_FNAME_BASE="pre-progress_${DAYOBS_YY}-${DAYOBS_MM}-${DAYOBS_DD}"
PROGRESS_FNAME=${PROGRESS_FNAME_BASE}.ipynb

cp ${PROGRESS_SOURCE} $PROGRESS_FNAME
for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do setfacl -m ${SCHEDULER_GROUP_USER}:rw ${PROGRESS_FNAME} ; done

echo "Executing the pre-progress notebook"
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
    ${PROGRESS_FNAME}

chmod go+r ${PROGRESS_FNAME_BASE}.html
for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do setfacl -m ${SCHEDULER_GROUP_USER}:rw ${PROGRESS_FNAME_BASE}.html ; done


echo "Rebuilding schedview report table of contents"
date --iso=s
cd /sdf/data/rubin/shared/scheduler/reports
SCHEDVIEW_TOC_SOURCE="/sdf/data/rubin/shared/scheduler/packages/schedview_notebooks/contents/pregenerated_toc.ipynb"
SCHEDVIEW_TOC_FNAME="/sdf/data/rubin/shared/scheduler/reports/report_toc.ipynb"
cp ${SCHEDVIEW_TOC_SOURCE} ${SCHEDVIEW_TOC_FNAME}
time jupyter nbconvert \
    --to html \
    --execute \
    --no-input \
    --ExecutePreprocessor.kernel_name=python3 \
    --ExecutePreprocessor.startup_timeout=3600 \
    --ExecutePreprocessor.timeout=3600 \
    ${SCHEDVIEW_TOC_FNAME}

chmod go+r /sdf/data/rubin/shared/scheduler/reports/report_toc.html
for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do setfacl -m ${SCHEDULER_GROUP_USER}:rw /sdf/data/rubin/shared/scheduler/reports/report_toc.html ; done

echo "Done."
date --iso=s

