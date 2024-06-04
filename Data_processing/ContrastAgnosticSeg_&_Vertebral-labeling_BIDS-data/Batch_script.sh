
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
T1_image=$(find . -type f -name "*_T1w.nii.gz" -print | head -n 1)



# Contrast agnostic segmentation
sct_deepseg -i "$T1_image" -task seg_sc_contrast_agnostic -o "${T1_image%.*}_seg.nii.gz" -qc ${PATH_QC} -qc-subject ${SUBJECT}

 
# Create a cylindrical mask centered around the spinal cord segmentation
sct_create_mask -i "$T1_image" -p centerline,"${T1_image%.*}_seg.nii.gz" -size 35mm -f cylinder -o "${T1_image%.*}_mask.nii.gz"

# Crop the image around the mask to focus on the region of interest
sct_crop_image -i "$T1_image" -m "${T1_image%.*}_mask.nii.gz" -o "${T1_image%.*}_crop.nii.gz"

# Flatten the spinal cord in the right-left direction (useful for visualization)
sct_flatten_sagittal -i "${T1_image%.*}_crop.nii.gz" -s "${T1_image%.*}_seg.nii.gz"
mv "${T1_image%.*}_crop_flat.nii.gz" "${T1_image%.*}_flat.nii.gz"

# Generate labeled segmentation
sct_label_vertebrae -i "$T1_image" -s "${T1_image%.*}_seg.nii.gz" -ofolder label_vertebrae -c t1 -qc ${PATH_QC} -qc-subject ${SUBJECT}
 

# (Not necessary if we only compute the CSA) Create 2 cervical vertebral labels to perform registration to the PAM50 template
sct_label_utils -i "${T1_image%.*}_seg_labeled.nii.gz" -vert-body 1,3 -o "${T1_image%.*}_labels_vert.nii.gz"

# (Not necessary if we only compute the CSA) Register T1 to the PAM50 template
sct_register_to_template -i "$T1_image" -s "${T1_image%.*}_seg.nii.gz" -l "${T1_image%.*}_labels_vert.nii.gz" -c t1 -qc ${PATH_QC} -qc-subject ${SUBJECT}




# Go back to parent folder
cd ..


# Verify presence of output files and write log file if error
FILES_TO_CHECK=(
  "anat/${SUBJECT}_acq-mprage_T1w.nii_seg.nii.gz"
  "anat/${SUBJECT}_acq-mprage_T1w.nii_mask.nii.gz"
  "anat/${SUBJECT}_acq-mprage_T1w.nii_crop.nii.gz"
  "anat/${SUBJECT}_acq-mprage_T1w.nii_crop_flatten.nii.gz"
  "anat/${SUBJECT}_acq-mprage_T1w.nii_seg_labeled.nii.gz"
  "anat/${SUBJECT}_acq-mprage_T1w.nii_seg_labeled_discs.nii.gz"
  "anat/${SUBJECT}_acq-mprage_T1w.nii_labels_vert.nii.gz"
)
for file in ${FILES_TO_CHECK[@]}; do
  if [[ ! -e $file ]]; then
    echo "${SUBJECT}/${file} does not exist" >> $PATH_LOG/_error_check_output_files.log
  fi
done



# Display useful info for the log
end=`date +%s`
runtime=$((end-start))
echo
echo "~~~"
echo "SCT version: `sct_version`"
echo "Ran on:      `uname -nsr`"
echo "Duration:    $(($runtime / 3600))hrs $((($runtime / 60) % 60))min $(($runtime % 60))sec"
echo "~~~"

