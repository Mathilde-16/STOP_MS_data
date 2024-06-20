#!/bin/bash


# Function to label vertebrae with SPINEPS
label_with_spineps(){
    local img_dir=$(cd "$(dirname "$1")" && pwd)
    local img_name=$(basename "$1")
    local img_path="${img_dir}/${img_name}"
    
    local out_path="$2"
    local contrast="$3"
    (
        # Create temporary directory
        tmpdir="$(mktemp -d)"
        echo "$tmpdir" was created

        # Copy image to temporary directory
        tmp_img_path="${tmpdir}/${img_name}"
        cp "$img_path" "$tmp_img_path"

        # Activate conda env
        eval "$(conda shell.bash hook)"
        conda activate spineps

        # Select semantic weights
        if [ "$contrast" = "t1" ];
            then semantic=t1w_segmentor;
            else semantic=t2w_segmentor_2.0;
        fi
       
        # Run SPINEPS on image with CPU
        spineps sample -i "$tmp_img_path" -model_semantic "$semantic" -model_instance inst_vertebra_3.0 -dn derivatives -cpu -iic
        
        # Run vertebral labeling with SPINEPS vertebrae prediction
        vert_path="$(echo ${tmpdir}/derivatives/*_seg-vert_msk.nii.gz)"
        python3 "${IVADOMED_UTILITIES_REPO}/training_scripts/generate_discs_labels_with_SPINEPS.py" --path-vert "$vert_path" --path-out "$out_path"

        # Remove temporary directory
        rm -r "$tmpdir"
        echo "$tmpdir" was removed

        # Deactivate conda environment
        conda deactivate
    )
}



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

# Generate labeled segmentation using SPINEPS
label_with_spineps "${T1_image}" "${PATH_DATA_PROCESSED}/${SUBJECT_SESSION}/anat/label_vertebrae" "t1"

 


# Go back to parent folder
cd ..


# Verify presence of output files and write log file if error
FILES_TO_CHECK=(
  "anat/${SUBJECT}_acq-mprage_T1w.nii_seg.nii.gz"
  "anat/${SUBJECT}_acq-mprage_T1w.nii_mask.nii.gz"
  "anat/${SUBJECT}_acq-mprage_T1w.nii_crop.nii.gz"
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
