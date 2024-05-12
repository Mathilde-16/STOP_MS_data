#!/bin/sh

#  Script_batch_processing_1.sh
#  Created by Mathilde Brossard on 2024-05-08.


IMAGE=$(find . -type f -name "*.nii.gz" | head -n 1)

if [ -z "${IMAGE}" ]; then
    echo "Image not found"
    exit 1
fi

BASENAME=$(basename ${IMAGE} .nii.gz)


# Contrast agnostic segmentation
sct_deepseg -i ${IMAGE} -task seg_sc_contrast_agnostic -o ${IMAGE}_seg.nii.gz


# Generate labeled segmentation
# As we´d like to compute CSA we´re interested in the full body labels (not in the point labels)
sct_label_vertebrae -i ${IMAGE} -s ${IMAGE}_seg.nii.gz -ofolder ./label_vertebrae -c t1 -qc ./qc_label_vertebrae


# Compute CSA of spinal cord and average it across levels C2 and C3, so CSA results are : mean and STD.
# If a segmentation is not perfect, the computed CSA will be impacted, so make sure the segmentation is correct before quantifying CSA
sct_process_segmentation -i ${IMAGE}_seg.nii.gz -vert 2:3 -vertfile ${IMAGE}_seg_labeled.nii.gz -o csa_c2c3.csv -qc ./qc_process_segmentation




# Other solution to compute CSA : Aggregate CSA value per level
# sct_process_segmentation -i file_seg.nii.gz -vert 2:3 -vertfile t1_seg_labeled.nii.gz -perlevel 1 -o csa_perlevel.csv


# Other solution to compute CSA : using the flag -normalize-PAM50 (bring shape metrics to the PAM50 anatomical dimensions)
# sct_process_segmentation -i file_seg.nii.gz -vertfile t1_seg_labeled.nii.gz -perslice 1 -normalize-PAM50 1 -o csa_PAM50.csv
