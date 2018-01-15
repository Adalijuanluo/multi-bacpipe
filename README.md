# bacpipe
A pipeline for processing of bacterial RNA-seq

## Author
[Alexander Predeus](https://www.researchgate.net/profile/Alexander_Predeus), [Jay Hinton Laboratory](http://www.hintonlab.com/), [University of Liverpool](https://www.liverpool.ac.uk/)

## Installation and requirements 
Clone the pipeline scripts into your home directory and add them to $PATH variable in bash: 

`cd ~`
`git clone https://github.com/apredeus/bacpipe`
`echo "export ~/bacpipe:$PATH" >> .bashrc`


To install the requirements, use [Bioconda](https://bioconda.github.io/). These are the programs that need to be installed: 

`conda install fastqc`
`conda install bowtie2`
`conda install samtools`
`conda install bedtools` 
`conda install picard`
`conda install igvtools` 
`conda install rsem`
`conda install kallisto` 
`conda install subread`

## Reference preparation
In order to start using the pipeline, you would need two things: a genomic *fasta* file, and genome annotation in *gff3* format. It is very much recommended to develop a system of "tags" that you would use to identify references; for example, if you are processing data for P125109 strain of Salmonella enterica, and intend to use the assembly and annotation available from NCBI, rename the downloaded files to P125109_ncbi.fa and P125109_ncbi.gff3. After you set the reference directory, and run the reference-maker script, all of the reference indexes etc would be appropriately named and placed. For example, rsem reference would be in $REFDIR/rsem/P125109_ncbi_rsem, bowtie2 reference in $REFDIR/bowtie2/P125109_ncbi.\*.bt2, and so on. 

After you have procured the *fasta* and the *gff3* and selected a (writeable) reference directory, simply run 

`prepare_bacpipe_reference.sh <tag>.fa <tag>.gff3 <reference_dir>` 

## One-command RNA-seq processing
After all the references are successfully created, simply run 

`run_bacpipe.sh <reference_dir> <tag> <CPUs>`

Bacpipe needs to be ran in a writeable directory with fastqs folder in it. 

Bacpipe
* handles archived (.gz) and non-archived fastq files; 
* handles single-end and paired-end reads; 
* automatically detects strand-specificity of the experiment; 
* performs quantification according to the calculated parameters. 

The following steps are performed during the pipeline execution: 
* FastQC is ran on all of the fastq files; 
* bowtie2 is used to align the fastq files to the rRNA reference to accurately estimate rRNA content; 
* bowtie2 is used to align the fastq files to the genomic reference using --very-sensitive-local mode;
* sam alignments are filtered by quality (q10), sorted, converted to bam, and indexed; 
* tdf files are prepared for visualization in IGV; 
* bigWig (bw) files are prepared for vizualization in majority of other genomic browsers; 
* featureCounts is ran on genomic bam with two settings; 
* strandedness and other statistics are evaluated using Picard Tools CollectRnaSeqMetrics; 
* featureCounts is ran again to quantify RNA-seq with all the correct settings; 
* rsem is ran for EM-based quantification; 
* kallisto is ran for shits and giggles; 
* appropriately formatted logs are generated; 
* multiqc is ran to summarize everything as a nicely formatted report. 
    
In the end you are expected to obtain a number of new directories: FastQC, bams, tdfs, bigWigs, rsem, kallisto, stats, featureCounts, expression_tables. Each directory would contain the files generated by its namesake, as well as all appropriate logs. The executed commands with all of the versions and exact options are recorded in the master log. 
    
    
