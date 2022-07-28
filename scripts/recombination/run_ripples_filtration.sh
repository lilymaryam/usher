#!/bin/bash -ex
#
# Run script to run filtration and QC pipeline on putative recombinants detected by RIPPLES

mat="$1"
raw_sequences="$2"
reference="$3"
results="$4"
out="$5"

# Outputs from ripples (recombination.tsv and descendants.tsv) placed in "filtering/data"

python3 filtering/combineAndGetPVals.py

# filtering/data/sample_paths.txt is also generated by ripplesUtils
# with same format as matUtils in UShER commit a6f65ade7a6606ef75902ee290585c6db23aeba6 
ripplesUtils $mat
echo "getAllNodes Completed.  Retrieved all relevant nodes."

# Generates allRelevantNodes.vcf
matUtils extract -i $mat -s filtering/data/allRelevantNodeNames.txt -v filtering/data/allRelevantNodes.vcf -T 10

python3 filtering/getABABA.py

python3 filtering/makeMNK.py   

python3 filtering/getDescendants.py

python3 filtering/makeSampleInfo.py

# Get raw sequences for all descendant nodes,
# align them to reference and perform QC steps 
# to generate final_report.txt (see report_meaning.txt)
./filtering/generate_report.sh $raw_sequences $reference
echo "Successfully generated final_report.txt"

# Run 3seq program on mnk_no_duplicates.txt values
( cd filtering && ./3seq/3seq -c 3seq/my3seqTable700 )
echo "mnk.log output from 3seq program written to recombination/filtering/data"

python3 filtering/finish_MNK.py

python3 filtering/checkClusters.py  
awk '$21 <= .20 {print}' filtering/data/combinedCatOnlyBestWithPValsFinalReportWithInfSitesNoClusters.txt > filtering/data/combinedCatOnlyBestWithPValsFinalReportWithInfSitesNoClusters3SeqP02.txt  

python3 filtering/doNewTieBreakers.py 

# Copy filtered recombinants to GCP bucket
mkdir -p results
mkdir -p results/$out
python3 filtering/removeRedundant.py   
mv results/final_recombinants.txt results/$out/
gsutil cp -r results/$out $results/

# Copy ripples unfiltered recombinants to GCP bucket
gsutil cp filtering/data/recombination.tsv $results/$out
gsutil cp filtering/data/descendants.tsv $results/$out

echo "Pipeline finished. List of recombinants detected in 'results/' directory."