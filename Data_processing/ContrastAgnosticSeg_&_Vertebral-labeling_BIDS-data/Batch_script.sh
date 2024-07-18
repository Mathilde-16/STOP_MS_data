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


label_if_does_not_exist(){
  local file="$1"
  local file_seg="$2"
  # Update global variable with segmentation file name
  FILELABEL="${file}_label-disc"
  FILELABELMANUAL="${PATH_DATA}/derivatives/labels/${SUBJECT_SESSION}/anat/${FILELABEL}.nii.gz"
  echo "Looking for manual label: $FILELABELMANUAL"
  if [[ -e $FILELABELMANUAL ]]; then
    echo "Found! Using manual labels."
    rsync -avzh $FILELABELMANUAL ${FILELABEL}.nii.gz
    # Generate labeled segmentation from manual disc labels
    sct_label_vertebrae -i ${file}.nii.gz -s ${file_seg}.nii.gz -discfile ${FILELABEL}.nii.gz -c t1 -ofolder label_vertebrae
  else
    echo "Not found. Proceeding with automatic labeling."
    # Generate labeled segmentation
    sct_label_vertebrae -i "$T1_image" -s "${T1_image%.*}_seg.nii.gz" -ofolder label_vertebrae -c t1 -qc ${PATH_QC} -qc-subject ${SUBJECT}
  fi
}


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
T1_image=$(find . -type f -name "*_T1w.nii.gz" -print | head -n 1)


# Contrast agnostic segmentation
sct_deepseg -i "$T1_image" -task seg_sc_contrast_agnostic -o "${T1_image%.*}_seg.nii.gz" -qc ${PATH_QC} -qc-subject ${SUBJECT}


# Create a cylindrical mask centered around the spinal cord segmentation
sct_create_mask -i "$T1_image" -p centerline,"${T1_image%.*}_seg.nii.gz" -size 35mm -f cylinder -o "${T1_image%.*}_mask.nii.gz"


# Crop the image around the mask to focus on the region of interest
sct_crop_image -i "$T1_image" -m "${T1_image%.*}_mask.nii.gz" -o "${T1_image%.*}_crop.nii.gz"


# Create mid-vertebral levels in the cord (only if it does not exist)
label_if_does_not_exist "${SUBJECT}_acq-mprage_T1w" "${SUBJECT}_acq-mprage_T1w.nii_seg"
file_label=$FILELABEL

 
# Compute average cord CSA between C2 and C3 and other morphometric measures, and normalize them to PAM50 ('-normalize-PAM50' flag)
sct_process_segmentation -i "${T1_image%.*}_seg.nii.gz" -vert 2:3 -vertfile ${T1_image%.*}._seg_labeled.nii.gz -perslice 1 -normalize-PAM50 1 -o ${PATH_RESULTS}/csa-SC_T1w.csv -append 1



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


