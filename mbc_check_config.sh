#!/bin/bash 

WDIR=$1

## this is where we shall check 
## - if fastq exists and is non-empty; 
## - if all other necessary dirs exist or need to be created; 
## - if all the reference dirs exist and contain all the necessary files; 
## - if roary dir exists and has all the necessary files

cd $WDIR

if [[ -d fastqs && "$(ls -A fastqs)" ]]; then
  echo "==> Found non-empty directory named fastqs! Continuing."
else
  echo "ERROR: directory fastqs does not exist or is empty!"
  exit 1
fi

if [[ -d roary && "$(ls -A roary)" ]]; then ## add extra checks for properly parsed Roary output 
  echo "==> Found non-empty directory named roary! Continuing."
else
  echo "ERROR: directory roary does not exist or is empty! Please make sure you've ran \"prepare_multiref.sh\" on your config file."
  exit 1
fi

if [[ ! -d bams || ! -d stats || ! -d strand || ! -d tdfs_and_bws || ! -d featureCounts || ! -d FastQC || ! -d exp_tables  ]]  
then
  echo "One (or more) of the required directories is missing, I will try to create them."
  mkdir featureCounts FastQC bams stats strand tdfs_and_bws exp_tables
else
  echo "All the necessary directories found, continuing." 
fi
