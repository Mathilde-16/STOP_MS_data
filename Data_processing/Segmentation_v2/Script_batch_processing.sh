#!/bin/sh

#  Script_batch_processing_1.sh
#  Created by Mathilde Brossard on 2024-05-06.

 
# Retrieve input params
SUBJECT="${1}"

# Define processed data path and original data path
PATH_DATA_PROCESSED="/Users/mathilde/Desktop/Precision_stopms_sct_COPY_2/data_processed"
PATH_DATA="/Users/mathilde/Desktop/Precision_stopms_sct_COPY_2/data"

# Go to the folder where data will be copied and processed
cd "${PATH_DATA_PROCESSED}"

# Copy source images from original data location to processed data location
rsync -avzh "${PATH_DATA}/${SUBJECT}" .

# Change directory to the anatomical folder of the subject
cd "${SUBJECT}/anat"

# Set ANAT_DIR to the directory containing the anatomical data
ANAT_DIR="$PWD"

# Define the T1-weighted image filename (update this pattern if necessary)
T1_image=$(find . -type f -name "${SUBJECT}*.nii.gz" -print | head -n 1)

if [ -f "$T1_image" ]; then
    echo "Processing T1-weighted image: $T1_image"

    # 1. Deep segmentation of the spinal cord
    sct_deepseg_sc -i "$T1_image" -c t1 -centerline cnn -o "${T1_image%.*}_seg.nii.gz"

    # 2. Create a cylindrical mask centered around the spinal cord segmentation
    sct_create_mask -i "$T1_image" -p centerline,"${T1_image%.*}_seg.nii.gz" -size 35mm -f cylinder -o "${T1_image%.*}_mask.nii.gz"

    # 3. Crop the image around the mask to focus on the region of interest
    sct_crop_image -i "$T1_image" -m "${T1_image%.*}_mask.nii.gz" -o "${T1_image%.*}_crop.nii.gz"

    # 4. Registration of the cropped T1 to a template or another modality (if the template exists)
    TEMPLATE_IMAGE="$ANAT_DIR/template.nii.gz"
    if [ -f "$TEMPLATE_IMAGE" ]; then
        sct_register_multimodal -i "${T1_image%.*}_crop.nii.gz" -d "$TEMPLATE_IMAGE" -o "$ANAT_DIR/t1_registered.nii.gz" -x linear
    else
        echo "Template image not found in $ANAT_DIR"
    fi

    # 5. Smooth spinal cord along superior-inferior axis
    sct_smooth_spinalcord -i "${T1_image%.*}_crop.nii.gz" -s "${T1_image%.*}_seg.nii.gz" -o "$ANAT_DIR/t1_smooth.nii.gz"

    # 6. Flatten the spinal cord in the right-left direction (useful for visualization)
    sct_flatten_sagittal -i "${T1_image%.*}_crop.nii.gz" -s "${T1_image%.*}_seg.nii.gz"
    mv "$(basename "${T1_image%.*}_crop_flat.nii.gz")" "$(basename "${T1_image%.*}_flat.nii.gz")"
else
    echo "No T1-weighted image found in $ANAT_DIR"
fi

echo "Processing completed for subject: $SUBJECT."


