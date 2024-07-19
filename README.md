# SCT pipeline for a large-scale clinical dataset

Pipeline to run segmentation and vertebral labeling using the last version (6.3) of the spinal cord toolbox.
The dataset corresponds to brain MRI acquisitions which typically pass C2-C3 and a small part of the images go up to C4.


## How to use the script

###Following dependencies are required
- SCT version 6.3 ([Install Spinal Cord Toolbox](https://spinalcordtoolbox.com/user_section/installation.html))
- [Install manual-correction](https://github.com/spinalcordtoolbox/manual-correction?tab=readme-ov-file#2-installation) : the SCT command for the vertebral labeling doesn't work for some subjects in the datase (the identification of the levels is wrong) therefore it will be necessary to fix it manually for subjects who fail the vertebral labeling.


###YMLfile

A YML file, as shown below, is needed to precise the path to the dataset and the path to save the output files. 
```
#!/bin/sh

# Path to the folder containing the dataset 
path_data: 

# Path to save the output
path_output:

```

It's also necessary to create a main folder containing the dataset folder, the script and the YML file. Organisation within the main folder should look like this:
```bash
├── DATA
│           
│           
├── process_data.sh
│   
│           
└── config.yml
```


###First step 

Run processing across all subjects : 
```bash
  cd PATH/TO/THE/MAIN/FOLDER

#To allow permissions 
  chmod +x config.yml 
  chmod +x script.sh     
  
#SCT command to run the script across all subjects
sct_run_batch -script process_data.sh -config config.yml -jobs 9
  
  ```

###Second step

Launch the QC report and flag with a ❌ the subjects that need to be manually corrected for the vertebral labeling and download the YML file that list all the subjects 
which failed.

Then perform manual vertebral labeling as shown in the following video tutorial :

[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/IgJUu5CCHxY/0.jpg)](https://www.youtube.com/watch?v=IgJUu5CCHxY)


###Third step 

Rerun the script as in the second step. For each subject, if the manual correction exists, it will use it. If not, it will regenerate the vertebral labeling.
