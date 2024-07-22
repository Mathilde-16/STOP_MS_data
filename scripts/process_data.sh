#!/bin/sh


# The following global variables are retrieved from the caller sct_run_batch
# but could be overwritten by uncommenting the lines below:
#PATH_DATA_PROCESSED="~/data_processed"
#PATH_RESULTS="~/results"
#PATH_LOG="~/log"
#PATH_QC="~/qc"


# Uncomment for full verbose
set -x

# Immediately exit if error
# set -e -o pipefail

# Retrieve input params
SUBJECT_SESSION=$1

# get starting time:
start=`date +%s`


# Display useful info for the log, such as SCT version, RAM and CPU cores available
sct_check_dependencies -short

# Update SUBJECT variable to the prefix for BIDS file names, considering the "ses" entity
SUBJECT=`cut -d "/" -f1 <<< "$SUBJECT_SESSION"`
SESSION=`cut -d "/" -f2 <<< "$SUBJECT_SESSION"`


# Go to folder where data will be copied and processed
cd $PATH_DATA_PROCESSED

# Copy list of participants in processed data folder
if [[ ! -f "participants.tsv" ]]; then
  rsync -avzh $PATH_DATA/participants.tsv .
fi

# Copy source images
mkdir -p $SUBJECT
rsync -avzh --copy-links $PATH_DATA/$SUBJECT_SESSION $SUBJECT/

# Go to anat folder where all structural data are located
cd ${SUBJECT_SESSION}/anat/

# Update SUBJECT variable to the prefix for BIDS file names, considering the "ses" entity
SUBJECT="${SUBJECT}_${SESSION}"

# T1 image file name
T1_image=$(find . -type f -name "*_MPRAGE.nii.gz" -print | head -n 1)

# Contrast agnostic segmentation
sct_deepseg -i "$T1_image" -task seg_sc_contrast_agnostic -o "${T1_image%.*}_seg.nii.gz" -qc ${PATH_QC} -qc-subject ${SUBJECT}

# Detect ponto-medullary junction
sct_detect_pmj -i "$T1_image" -c t1 -s "${T1_image%.*}_seg.nii.gz" -qc ${PATH_QC} -qc-subject ${SUBJECT}
 
# Compute average cord CSA at 64mm distance from the PMJ (which roughtly corresponds to C2-C3 disc, according to https://www.frontiersin.org/journals/neuroimaging/articles/10.3389/fnimg.2022.1031253/full)
# normalize them to PAM50 ('-normalize-PAM50' flag)
sct_process_segmentation -i "${T1_image%.*}_seg.nii.gz" -pmj "${T1_image%.*}_pmj.nii.gz" -pmj-distance 64 -perslice 1 -normalize-PAM50 1 -o ${PATH_RESULTS}/csa-SC_T1w.csv -append 1

# Go back to parent folder
cd ..


# Display useful info for the log
end=`date +%s`
runtime=$((end-start))
echo
echo "~~~"
echo "SCT version: `sct_version`"
echo "Ran on:      `uname -nsr`"
echo "Duration:    $(($runtime / 3600))hrs $((($runtime / 60) % 60))min $(($runtime % 60))sec"
echo "~~~"


