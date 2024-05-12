#!/bin/sh

#  Script_batch_processing.sh
#  Created by Mathilde Brossard on 2024-05-02.
#  

# Base directory where the data is stored
BASE_DIR="/Users/mathilde/Desktop/Precision_stopms_sct_COPY/data"

# Loop through each subject directory
for SUBJECT_DIR in "$BASE_DIR"/sub-*; do
    echo "Processing subject in directory: $SUBJECT_DIR"

    # Loop through each session directory within the subject
    for SESSION_DIR in "$SUBJECT_DIR"/ses-*; do
        echo "Processing session in directory: $SESSION_DIR"

        # Define the directory containing the anatomical data
        ANAT_DIR="$SESSION_DIR/anat"

        # Search for the T1-weighted image file in the 'anat' directory
        T1_IMAGE=$(find "$ANAT_DIR" -type f -name "*.nii.gz" -print | head -n 1)

        if [ -f "$T1_IMAGE" ]; then
            echo "Processing T1-weighted image: $T1_IMAGE"

            # 1. Deep segmentation of the spinal cord
            sct_deepseg_sc -i "$T1_IMAGE" -c t1 -centerline cnn -o "$ANAT_DIR/t1_seg.nii.gz"

            # 2. Create a cylindrical mask centered around the spinal cord segmentation
            sct_create_mask -i "$T1_IMAGE" -p centerline,"$ANAT_DIR/t1_seg.nii.gz" -size 35mm -f cylinder -o "$ANAT_DIR/mask_t1.nii.gz"

            # 3. Crop the image around the mask to focus on the region of interest
            sct_crop_image -i "$T1_IMAGE" -m "$ANAT_DIR/mask_t1.nii.gz" -o "$ANAT_DIR/t1_crop.nii.gz"

            # 4. Registration of the cropped T1 to a template or another modality (if the template exists)
            TEMPLATE_IMAGE="$ANAT_DIR/template.nii.gz"
            if [ -f "$TEMPLATE_IMAGE" ]; then
                sct_register_multimodal -i "$ANAT_DIR/t1_crop.nii.gz" -d "$TEMPLATE_IMAGE" -o "$ANAT_DIR/t1_registered.nii.gz" -x linear
            else
                echo "Template image not found in $ANAT_DIR"
            fi

            # 5. Smooth spinal cord along superior-inferior axis
            sct_smooth_spinalcord -i "$ANAT_DIR/t1_crop.nii.gz" -s "$ANAT_DIR/t1_seg.nii.gz" -o "$ANAT_DIR/t1_smooth.nii.gz"

            # 6. Flatten the spinal cord in the right-left direction (useful for visualization)
            sct_flatten_sagittal -i "$ANAT_DIR/t1_crop.nii.gz" -s "$ANAT_DIR/t1_seg.nii.gz"
            mv "${ANAT_DIR}/$(basename "$ANAT_DIR")_crop_flat.nii.gz" "${ANAT_DIR}/$(basename "$ANAT_DIR")_flat.nii.gz"
        else
            echo "No T1-weighted image found in $ANAT_DIR"
        fi
    done
done

echo "Processing completed for all subjects."
