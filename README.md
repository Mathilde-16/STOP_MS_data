>[!Warning]
>This repository was archived. New development is happening here: https://github.com/sct-pipeline/STOP-MS-data

# SCT pipeline for a large-scale clinical dataset

The STOP_MS_data repository contains [process_data.sh](https://github.com/Mathilde-16/STOP_MS_data/blob/4f20ca82a43991f722775eaac831c68f735f8951/Data_processing/ContrastAgnosticSeg_%26_Vertebral-labeling_BIDS-data/Batch_script.sh) batch script for the segmentation and the vertebral labeling of cervical spinal cord, using the spinal cord toolbox.
The dataset corresponds to brain MRI acquisitions which typically pass C2-C3 and a small part of the images go up to C4.


## Requirements

### Following dependencies are required
- SCT version 6.3 ([Install Spinal Cord Toolbox](https://spinalcordtoolbox.com/user_section/installation.html))
- [Install manual-correction](https://github.com/spinalcordtoolbox/manual-correction?tab=readme-ov-file#2-installation) : the SCT command for the vertebral labeling doesn't work for some subjects in the dataset (the identification of the levels is wrong), therefore it will be necessary to fix it manually for subjects who fail the vertebral labeling.


### Config YAML file

A config YAML file, as shown below, is needed to precise the path to the dataset and the path to save the output files. 
```
# Path to the folder containing the dataset 
path_data: 

# Path to save the output
path_output:

```

It is also necessary to create a main folder containing the dataset folder, the script and the config YAML file. Organisation within the main folder should look like this:

```bash
├── DATA
└── config.yml
```


## How to use the script

### First step 

Run processing across all subjects : 

```bash
cd PATH/TO/THE/MAIN/FOLDER

#To allow permissions 
chmod +x config.yml 
  
#SCT command to run the script across all subjects
sct_run_batch -script process_data.sh -config config.yml -jobs 9
  ```

### Second step

Launch the QC report and flag with a ❌ the subjects that need to be manually corrected for the vertebral labeling and download the config YAML file that list all the subjects 
which failed.

Then perform manual vertebral labeling as shown in the following video tutorial :

[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/IgJUu5CCHxY/0.jpg)](https://www.youtube.com/watch?v=IgJUu5CCHxY)


### Third step 

Rerun the script as in the second step. For each subject, if the manual correction exists, it will use it. If not, it will regenerate the vertebral labeling.
