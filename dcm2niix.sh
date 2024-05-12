#!/bin/bash
# Created by russell.ouellette@ki.se, 16-04-2024
# Directories
dcm_dir="/Volumes/LaCie/preliminary-SCT_multivendor-repro/bids-data/derivatives/bids-dcm"
nifti_dir="/Volumes/LaCie/preliminary-SCT_multivendor-repro/bids-data"

# Loop through subject folders
for subj_folder in ${dcm_dir}/sub-*; do
  echo "Processing subject folder: $subj_folder"
  cd "${subj_folder}" || continue
  subjID=$(basename "$(pwd)")
  echo "Current subject: $subjID"

  # Loop through session folders
  for sesfolder in ${subj_folder}/ses-*; do
    echo "Processing session folder: $sesfolder"
    cd "${sesfolder}" || continue
    sesID=$(basename "$(pwd)")
    echo "Current session: $sesID"

    # Set output directory for NIfTI files
    output_dir="${nifti_dir}/${subjID}/${sesID}/anat"

    # Check if the NIfTI output directory exists, create if not
    if [ ! -d "${output_dir}" ]; then
      echo "Creating directory: $output_dir"
      mkdir -p "${output_dir}"
    fi

    # Convert DICOMs to NIfTI for T1_Scan1
    dcm2niix -o "${output_dir}" "${sesfolder}/anat/T1_Scan1/"

    # Convert DICOMs to NIfTI for T1_Scan2
    dcm2niix -o "${output_dir}" "${sesfolder}/anat/T1_Scan2/"

  done

done
