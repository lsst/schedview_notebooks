#!/usr/bin/env bash
#SBATCH --account=rubin:developers      # Account name
#SBATCH --job-name=lsstcam_prenight_daily   # Job name
#SBATCH --output=/sdf/data/rubin/shared/scheduler/schedview/sbatch/prenight_%A_%a.out # Output file (stdout)
#SBATCH --error=/sdf/data/rubin/shared/scheduler/schedview/sbatch/prenight_%A_%a.err  # Error file (stderr)
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
  conda activate /sdf/data/rubin/shared/scheduler/envs/prenight
  export PYTHONPATH=/sdf/data/rubin/shared/scheduler/packages/schedview-0.18.1.dev27+g2dced97
fi

set -o xtrace

echo "Setting parameters"
date --iso=s

export ACCESS_TOKEN_FILE=${HOME}/.usdf_access_token

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

  IFS=' ' read SCHEDVIEW_SIM_DATE SCHEDVIEW_SIM_INDEX <<< $(prenight_inventory ${SCHEDVIEW_DAY_OBS} | awk -F "\t" '$4~/'${SCHEDVIEW_TELESCOPE}'/ && $8~/.*ideal.*/ && $8~/.*nominal.*/ {print $2, $3}' )
  export SCHEDVIEW_SIM_DATE
  export SCHEDVIEW_SIM_INDEX

  echo "Preparing prenight directory for this prenight"
  date --iso=s
  # Make the directory in which to work and save the html file
  PRENIGHT_DIR="/sdf/data/rubin/shared/scheduler/reports/prenight/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
  mkdir -p ${PRENIGHT_DIR}
  chmod o+rx "/sdf/data/rubin/shared/scheduler/reports/prenight/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}/${DAYOBS_MM}"
  chmod o+rx "/sdf/data/rubin/shared/scheduler/reports/prenight/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}"
  chmod o+rx ${PRENIGHT_DIR}
  cd ${PRENIGHT_DIR}

  PRENIGHT_SOURCE="/sdf/data/rubin/shared/scheduler/packages/schedview_notebooks/prenight/prenight.ipynb"
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
  MULTIPRENIGHT_DIR="/sdf/data/rubin/shared/scheduler/reports/multiprenight/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
  mkdir -p ${MULTIPRENIGHT_DIR}
  chmod go+rx "/sdf/data/rubin/shared/scheduler/reports/multiprenight/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}/${DAYOBS_MM}"
  chmod go+rx "/sdf/data/rubin/shared/scheduler/reports/multiprenight/${SCHEDVIEW_INSTRUMENT}/${DAYOBS_YY}"
  chmod go+rx ${MULTIPRENIGHT_DIR}
  cd ${MULTIPRENIGHT_DIR}

  MULTIPRENIGHT_SOURCE="/sdf/data/rubin/shared/scheduler/packages/schedview_notebooks/prenight/multiprenight.ipynb"
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
