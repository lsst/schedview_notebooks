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
CRONGATE=/sdf/data/rubin/shared/scheduler/cron_gates/scheduler_nightsum/${USER}
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

if [ -z ${SCHEDVIEW_INSTRUMENTS+xxx} ] ; then
  SCHEDVIEW_INSTRUMENTS="lsstcam latiss"
fi

for SCHEDVIEW_VISIT_ORIGIN in ${SCHEDVIEW_INSTRUMENTS} ; do
  export SCHEDVIEW_VISIT_ORIGIN

  echo "Preparing directory for this nightsum"
  date --iso=s
  # Make the directory in which to work and save the html file
  NIGHTSUM_DIR="/sdf/data/rubin/shared/scheduler/reports/nightsum/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
  mkdir -p ${NIGHTSUM_DIR}
  chmod go+rx "/sdf/data/rubin/shared/scheduler/reports/nightsum/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}"
  chmod go+rx "/sdf/data/rubin/shared/scheduler/reports/nightsum/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}/${DAYOBS_MM}"
  chmod go+rx ${NIGHTSUM_DIR}

  for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do 
    setfacl -m ${SCHEDULER_GROUP_USER}:rwX "/sdf/data/rubin/shared/scheduler/reports/nightsum/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}"
    setfacl -m ${SCHEDULER_GROUP_USER}:rwX "/sdf/data/rubin/shared/scheduler/reports/nightsum/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}/${DAYOBS_MM}"
    setfacl -m ${SCHEDULER_GROUP_USER}:rwX "${NIGHTSUM_DIR}"
  done

  cd ${NIGHTSUM_DIR}

  SCHEDULER_NIGHTSUM_SOURCE="/sdf/data/rubin/shared/scheduler/packages/schedview_notebooks/nightly/scheduler-nightsum.ipynb"
  echo "Copying scheduler_nightsum.ipynb from ${SCHEDULER_NIGHTSUM_SOURCE}"
  date --iso=s
  # Get the notebook
  NIGHTSUM_FNAME_BASE="nightsum_${DAYOBS_YY}-${DAYOBS_MM}-${DAYOBS_DD}"
  NIGHTSUM_FNAME=${NIGHTSUM_FNAME_BASE}.ipynb
  # Do not just blindly check out of git, but copy from somewhere hand
  # checked.
  cp ${SCHEDULER_NIGHTSUM_SOURCE} $NIGHTSUM_FNAME
  for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do setfacl -m ${SCHEDULER_GROUP_USER}:rw ${NIGHTSUM_FNAME} ; done

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

  chmod go+r ${NIGHTSUM_FNAME_BASE}.html
  for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do setfacl -m ${SCHEDULER_GROUP_USER}:rw ${NIGHTSUM_FNAME_BASE} ; done

  echo "Preparing directory for this prenight comparison"
  date --iso=s
  # Make the directory in which to work and save the html file
  if [ -x ${COMPARE_NIGHT_BASE_DIR+xxx} ] ; then
    COMPARE_NIGHT_BASE_DIR="/sdf/data/rubin/shared/scheduler/reports/compareprenight"
  fi
  COMPARE_NIGHT_DIR="${COMPARE_NIGHT_BASE_DIR}/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
  mkdir -p ${COMPARE_NIGHT_DIR}
  chmod go+rx "${COMPARE_NIGHT_BASE_DIR}/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}"
  chmod go+rx "${COMPARE_NIGHT_BASE_DIR}/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}/${DAYOBS_MM}"
  chmod go+rx ${COMPARE_NIGHT_DIR}

  for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do 
    setfacl -m ${SCHEDULER_GROUP_USER}:rwX "${COMPARE_NIGHT_BASE_DIR}/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}"
    setfacl -m ${SCHEDULER_GROUP_USER}:rwX "${COMPARE_NIGHT_BASE_DIR}/${SCHEDVIEW_VISIT_ORIGIN}/${DAYOBS_YY}/${DAYOBS_MM}"
    setfacl -m ${SCHEDULER_GROUP_USER}:rwX "${COMPARE_NIGHT_DIR}"
  done

  cd ${COMPARE_NIGHT_DIR}

  if [ -z ${COMPARE_NIGHT_SOURCE+xxx} ] ; then
    COMPARE_NIGHT_SOURCE="/sdf/data/rubin/shared/scheduler/packages/schedview_notebooks/nightly/compareprenight.ipynb"
  fi
  echo "Copying compareprenight.ipynb from ${COMPARE_NIGHT_SOURCE}"
  date --iso=s
  # Get the notebook
  COMPARE_NIGHT_FNAME_BASE="comparenight_${DAYOBS_YY}-${DAYOBS_MM}-${DAYOBS_DD}"
  COMPARE_NIGHT_FNAME=${COMPARE_NIGHT_FNAME_BASE}.ipynb
  # Do not just blindly check out of git, but copy from somewhere hand
  # checked.
  cp ${COMPARE_NIGHT_SOURCE} $COMPARE_NIGHT_FNAME
  for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do setfacl -m ${SCHEDULER_GROUP_USER}:rw ${COMPARE_NIGHT_FNAME} ; done

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

  chmod go+r ${COMPARE_NIGHT_FNAME_BASE}.html
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

chmod o+r "/sdf/data/rubin/shared/scheduler/reports/report_toc.html"
for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do setfacl -m ${SCHEDULER_GROUP_USER}:rw /sdf/data/rubin/shared/scheduler/reports/report_toc.html ; done
echo "Building the public nightsum"

SCHEDVIEW_VISIT_ORIGIN='lsstcam'
PUBLIC_NIGHTSUM_DIR="/sdf/group/rubin/web_data/sim-data/schedview/reports/nightsum/lsstcam/${DAYOBS_YY}/${DAYOBS_MM}/${DAYOBS_DD}"
mkdir -p ${PUBLIC_NIGHTSUM_DIR}
chmod go+rx "/sdf/group/rubin/web_data/sim-data/schedview/reports/nightsum/lsstcam/${DAYOBS_YY}"
chmod go+rx "/sdf/group/rubin/web_data/sim-data/schedview/reports/nightsum/lsstcam/${DAYOBS_YY}/${DAYOBS_MM}"
chmod go+rx ${PUBLIC_NIGHTSUM_DIR}

for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do 
  setfacl -m ${SCHEDULER_GROUP_USER}:rwX "/sdf/group/rubin/web_data/sim-data/schedview/reports/nightsum/lsstcam/${DAYOBS_YY}"
  setfacl -m ${SCHEDULER_GROUP_USER}:rwX "/sdf/group/rubin/web_data/sim-data/schedview/reports/nightsum/lsstcam/${DAYOBS_YY}/${DAYOBS_MM}"
  setfacl -m ${SCHEDULER_GROUP_USER}:rwX ${PUBLIC_NIGHTSUM_DIR}
done

cd ${PUBLIC_NIGHTSUM_DIR}

PUBLIC_SCHEDULER_NIGHTSUM_SOURCE="/sdf/data/rubin/shared/scheduler/packages/schedview_notebooks/public/nightsum.ipynb"
NIGHTSUM_FNAME_BASE="nightsum_${DAYOBS_YY}-${DAYOBS_MM}-${DAYOBS_DD}"
NIGHTSUM_FNAME=${NIGHTSUM_FNAME_BASE}.ipynb
cp ${PUBLIC_SCHEDULER_NIGHTSUM_SOURCE} $NIGHTSUM_FNAME

jupyter nbconvert \
    --to html \
    --execute \
    --no-input \
    --ExecutePreprocessor.kernel_name=python3 \
    --ExecutePreprocessor.startup_timeout=3600 \
    --ExecutePreprocessor.timeout=3600 \
    ${NIGHTSUM_FNAME}

chmod go+r ${NIGHTSUM_FNAME_BASE}.html
for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do setfacl -m ${SCHEDULER_GROUP_USER}:rw ${NIGHTSUM_FNAME_BASE}.html ; done
echo "Building the public index"

cd /sdf/group/rubin/web_data/sim-data/schedview/reports
cp /sdf/data/rubin/shared/scheduler/packages/schedview_notebooks/public/schedview_reports_toc.ipynb .
for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do setfacl -m ${SCHEDULER_GROUP_USER}:rw schedview_reports_toc.ipynb ; done
jupyter nbconvert \
    --to html \
    --execute \
    --no-input \
    --ExecutePreprocessor.kernel_name=python3 \
    --ExecutePreprocessor.startup_timeout=3600 \
    --ExecutePreprocessor.timeout=3600 \
    schedview_reports_toc.ipynb

cp schedview_reports_toc.html index.html
chmod go+r schedview_reports_toc.html index.html
for SCHEDULER_GROUP_USER in ${SCHEDULER_GROUP_USERS}; do 
  setfacl -m ${SCHEDULER_GROUP_USER}:rw schedview_reports_toc.html
  setfacl -m ${SCHEDULER_GROUP_USER}:rw index.html
done

echo "Done."
date --iso=s
