#!/usr/bin/env bash
#SBATCH --account=rubin:developers      # Account name
#SBATCH --job-name=lsstcam_prenight_daily   # Job name
#SBATCH --output=/sdf/data/rubin/shared/scheduler/schedview/sbatch/prenight_%A_%a.out # Output file (stdout)
#SBATCH --error=/sdf/data/rubin/shared/scheduler/schedview/sbatch/prenight_%A_%a.out  # Error file (stderr)
#SBATCH --partition=milano              # Partition (queue) names
#SBATCH --nodes=1                       # Number of nodes
#SBATCH --ntasks=1                      # Number of tasks run in parallel
#SBATCH --cpus-per-task=1               # Number of CPUs per task
#SBATCH --mem=8G                       # Requested memory
#SBATCH --time=1:00:00                 # Wall time (hh:mm:ss)

echo "******** START of PRENIGHT.sh **********"


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
  conda activate /sdf/data/rubin/shared/scheduler/envs/prenight_like_rsp_w2025_36

  export PYTHONPATH=/sdf/data/rubin/shared/scheduler/packages/rubin_sim-2.4.1.dev140+g532ec2c46:${PYTHONPATH}
  export PYTHONPATH=/sdf/data/rubin/shared/scheduler/packages/schedview-0.19.2.dev11+g44bf8dd:${PYTHONPATH}
fi

set -o xtrace

# The gate files provide a mechanism that scheduler group members
# can use to stop this script from running, so if a cron job is
# running it it can still be stopped when the owner is not
# available.
# This is accomplished by deleting the gate file
# with the name of the owner of the cron job.
CRONGATE=/sdf/data/rubin/shared/scheduler/cron_gates/prenight/${USER}
echo "Checking gatefile ${CRONGATE}"
if test ! -e ${CRONGATE} ; then
    echo "Aborting because ${CRONGATE} does not exist."
    echo "See /sdf/data/rubin/shared/scheduler/cron_gates/README.txt"
    exit 1
fi

echo "Setting parameters"
date --iso=s

export ACCESS_TOKEN_FILE=${HOME}/.lsst/usdf_access_token

if [ -z ${SCHEDVIEW_DAY_OBS+xxx} ] ; then
    SCHEDVIEW_DAY_OBS=$(date '+%Y%m%d')
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

if [ -z ${SCHEDVIEW_INSTRUMENTS+xxx} ] ; then
  SCHEDVIEW_INSTRUMENTS="lsstcam latiss"
fi

for SCHEDVIEW_INSTRUMENT in ${SCHEDVIEW_INSTRUMENTS} ; do
  if [ ${SCHEDVIEW_INSTRUMENT} == "lsstcam" ] ; then SCHEDVIEW_TELESCOPE="simonyi" ; else SCHEDVIEW_TELESCOPE="auxtel" ; fi
  export SCHEDVIEW_INSTRUMENT
  export SCHEDVIEW_TELESCOPE

  IFS=' ' read SCHEDVIEW_SIM_DATE SCHEDVIEW_SIM_INDEX <<< $(prenight_inventory ${SCHEDVIEW_DAY_OBS} | awk -F "\t" '$4~/'${SCHEDVIEW_TELESCOPE}'/ && $8~/.*ideal.*/ && $8~/.*nominal.*/ {print $2, $3}' | tail -1 )
  export SCHEDVIEW_SIM_DATE
  export SCHEDVIEW_SIM_INDEX

  # If there are no simulations for this instrument, continue to the next.
  if [ -z ${SCHEDVIEW_SIM_DATE+xxx} ] ; then
    continue
  fi

  if [ -z ${SCHEDVIEW_SIM_INDEX+xxx} ] ; then
    continue
  fi

  echo "Preparing prenight directory for this prenight"
  date --iso=s
  # Make the directory in which to work and save the html file
  if [ -x ${PRENIGHT_BASE_DIR+xxx} ] ; then
    PRENIGHT_BASE_DIR="/sdf/data/rubin/shared/scheduler/reports/prenight"
  fi
  PRENIGHT_DIR="${PRENIGHT_BASE_DIR}/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
  mkdir -p ${PRENIGHT_DIR}
  chmod o+rx "${PRENIGHT_BASE_DIR}/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}/${DAYOBS_MM}"
  chmod o+rx "${PRENIGHT_BASE_DIR}/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}"
  chmod o+rx ${PRENIGHT_DIR}
  cd ${PRENIGHT_DIR}

  if [ -z ${PRENIGHT_SOURCE+xxx} ] ; then
    PRENIGHT_SOURCE="/sdf/data/rubin/shared/scheduler/packages/schedview_notebooks/prenight/prenight.ipynb"
  fi
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
  
  chmod o+r ${PRENIGHT_FNAME_BASE}.html

  echo "Preparing multiprenight directory for this dayobs"
  date --iso=s
  # Make the directory in which to work and save the html file
  if [ -x ${MULTIPRENIGHT_BASE_DIR+xxx} ] ; then
    MULTIPRENIGHT_BASE_DIR="/sdf/data/rubin/shared/scheduler/reports/multiprenight"
  fi
  MULTIPRENIGHT_DIR="${MULTIPRENIGHT_BASE_DIR}/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
  mkdir -p ${MULTIPRENIGHT_DIR}
  chmod go+rx "${MULTIPRENIGHT_BASE_DIR}/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}/${DAYOBS_MM}"
  chmod go+rx "${MULTIPRENIGHT_BASE_DIR}/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}"
  chmod go+rx ${MULTIPRENIGHT_DIR}
  cd ${MULTIPRENIGHT_DIR}

  if [ -z ${MULTIPRENIGHT_SOURCE+xxx} ] ; then
    MULTIPRENIGHT_SOURCE="/sdf/data/rubin/shared/scheduler/packages/schedview_notebooks/prenight/multiprenight.ipynb"
  fi
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

  chmod go+r ${MULTIPRENIGHT_FNAME_BASE}.html

done

echo "Rebuilding schedview report table of contents"
date --iso=s
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

echo "Done."
date --iso=s
