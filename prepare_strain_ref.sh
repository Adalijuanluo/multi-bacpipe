#!/bin/bash 

##   v0.3 - streamlined to run as one-command prep
##   this script would generate everything in the working directory, which generally should be $WDIR/study_strains
##   no Prokka annotation of proteins - just find the CDS, Roary will do the rest. 
##   no Rsem/kallisto - they don't work correctly anyway. 

## next snippet is adapted from https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f

GRN='\033[1;32m'
GRN2='\033[0;32m'
RED='\033[1;31m'
BL='\033[0;34m'
NC='\033[0m' # No Color

if [[ $# < 5 ]]
then
  echo 
  printf "Step 1 of reference preparation: prepare reference for a single ${RED}study${NC} strain.\n"
  echo "============================================================================="
  printf "Usage: ${GRN}prepare_strain_ref.sh ${GRN2}<working_directory> <genome_fa> <prophage_bed> [-p CPUs]${NC}\n"
  echo "       (to predict ncRNAs using Prokka's Rfam DB)"
  echo "       - or - " 
  printf "       ${GRN}prepare_strain_ref.sh ${GRN2}<working_directory> <genome_fa> <prophage_bed> [-p CPUs] [-r ref_ncRNA_fasta]${NC}\n"
  echo "       (to assign ncRNAs by simply blasting the existing reference ncRNA fasta to the genome)"
  echo 
  exit 1
fi

PARAMS=""
NC_REF=""
CPUS=""

while (( "$#" )); do
  case "$1" in
    -r|--ref_ncrna)
      NC_REF=$2
      shift 2
      if [[ $NC_REF == "" ]]
      then
        echo "ERROR: -r flag requires a non-empty argument (reference ncRNA fasta file)!" 
        exit 1 
      fi
      ;;  
    -p|--cpus)
      CPUS=$2
      shift 2
      if [[ $CPUS == "" ]]
      then
        echo "ERROR: -p flag requires a non-empty argument (number of CPUs)!" 
        exit 1 
      fi
      echo "==> Invoking -p option: parallel jobs will be run on $CPUS cores."
      ;;  
    --) # end argument parsing
      shift
      break
      ;;  
    -*|--*=) # unsupported flags
      echo "ERROR: unsupported flag $1" >&2
      exit 1
      ;;  
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;  
  esac
done
eval set -- "$PARAMS"

WDIR=$1
FA=$2
PROPHAGE=$3
TAG=${FA%%.fa}

if [[ -d "$WDIR/study_strains/$TAG" ]]
then
  echo "Found $WDIR/study_strains/$TAG! Will add files to the existing directory."
  rm -rf $WDIR/study_strains/$TAG/*.STAR $WDIR/study_strains/$TAG/*.prokka 
else 
  echo "Directory $WDIR/study_strains/$TAG was not found and will be created." 
  mkdir $WDIR/study_strains/$TAG
fi

if [[ $CPUS == "" ]]
  then 
  echo "==> Parallel jobs will be ran on 16 cores (default)."
  CPUS=16
fi


######################################################

source activate prokka 
set -euo pipefail

cp $FA $TAG.genome.fa
samtools faidx $TAG.genome.fa
cut -f 1,2 $TAG.genome.fa.fai > $TAG.chrom.sizes 

## annotate with Prokka - either 
if [[ $NC_REF == "" ]]
then
  ## Rfam database here is OK, but still quite outdated. 
  ## However, it does successfully find quite few leader peptides that are overlooked by Prokka otherwise. 
  echo "Running Prokka annotation; using --noanno option to only discover CDS."
  echo "Annotating noncoding RNAs using default Prokka Rfam database!" 
  prokka --noanno --cpus $CPUS --outdir $TAG.prokka --prefix $TAG.prokka --locustag ${TAG%%_*} --rfam $TAG.genome.fa &> /dev/null 
  grep -P "\tCDS\t" $TAG.prokka/$TAG.prokka.gff | sed "s/$/;gene_biotype=protein_coding;/g" > $TAG.CDS.gff
  grep -P "\tmisc_RNA\t" $TAG.prokka/$TAG.prokka.gff | sed "s/misc_RNA/ncRNA/g" | sed "s/$/;gene_biotype=noncoding_rna;/g" > $TAG.ncRNA.gff
  N_CDS=`grep -c -P "\tCDS\t" $TAG.CDS.gff`
  N_NCR=`grep -c -P "\tncRNA\t" $TAG.ncRNA.gff`
  echo
  echo "==> Found $N_CDS protein-coding (CDS) and $N_NCR non-coding RNA (misc_RNA/ncRNA) features."
  echo 
else 
  ## Make sure you have correct ncRNA names in the reference fasta - they will be used as a Name in GFF. 
  echo "Running Prokka annotation; using --noanno option to only discover CDS."
  echo "Annotating noncoding RNAs using blastn and custom reference file $NC_REF!" 
 
  ## find all CDS
  prokka --noanno --cpus $CPUS --outdir $TAG.prokka --prefix $TAG.prokka --locustag ${TAG%%_*} $TAG.genome.fa &> /dev/null 
  grep -P "\tCDS\t" $TAG.prokka/$TAG.prokka.gff | sed "s/$/;gene_biotype=protein_coding;/g" > $TAG.CDS.gff
  ## find all sORF and ncRNA
  makeblastdb -dbtype nucl -in $TAG.genome.fa -out ${TAG}_blast &> /dev/null 
  blastn -query $NC_REF -db ${TAG}_blast -evalue 1 -task megablast -outfmt 6 > $TAG.ncRNA_blast.out 2> /dev/null 

  ## new version of this script drops all mia- sORFs overlapping a Prokka CDS 
  make_ncRNA_gff_from_blast.pl $NC_REF $TAG.CDS.gff ${TAG%%_*} $TAG.ncRNA_blast.out > $TAG.ncRNA.gff
  
  ## note no --rfam option in this case  
  N_CDS=`grep -c -P "\tCDS\t" $TAG.CDS.gff`
  N_NCR=`wc -l $TAG.ncRNA.gff | awk '{print $1}'`
  echo
  echo "==> Found $N_CDS protein-coding (CDS) and $N_NCR non-coding RNA (misc_RNA/ncRNA) features."
  echo
  rm ${TAG}_blast.n* $TAG.ncRNA_blast.out
fi 

sed "s/\tCDS\t/\tgene\t/g"   $TAG.CDS.gff   >  $TAG.gene.gff
sed "s/\tncRNA\t/\tgene\t/g" $TAG.ncRNA.gff >> $TAG.gene.gff

echo "Files $TAG.genome.fa, $TAG.CDS.gff, $TAG.ncRNA.gff, and $TAG.gene.gff successfully generated."

## make STAR reference for small genome size 
mkdir ${TAG}.STAR 
STAR --runThreadN $CPUS --runMode genomeGenerate --genomeDir ${TAG}.STAR --genomeFastaFiles $TAG.genome.fa --genomeSAindexNbases 10 &> /dev/null
mv Log.out $TAG.star.log 

##make rRNA/tRNA interval file  
make_rrna_operon.pl $TAG.prokka/$TAG.prokka.gff $TAG.ncRNA.gff | sort -k1,1 -k2,2n | bedtools merge -i - > $TAG.rRNA.bed

## mv all to the ref dir 
mv $TAG.genome.fa $TAG.genome.fa.fai $TAG.chrom.sizes $WDIR/study_strains/$TAG
mv $TAG.gene.gff $TAG.CDS.gff $TAG.ncRNA.gff $WDIR/study_strains/$TAG
mv $TAG.prokka ${TAG}.STAR $TAG.star.log $WDIR/study_strains/$TAG
cp $PROPHAGE $WDIR/study_strains/$TAG/$TAG.prophage.bed
mv $TAG.rRNA.bed $WDIR/study_strains/$TAG

echo "All the generated files and indexes have been moved to $WDIR/study_strains/$TAG."
echo "Strain $TAG: all done generating reference!" 
