#!/usr/bin/env bash
[ $# -lt 1 ] && { echo "run dir required"; exit 1; };

echo START: `date`;
run_dir=$1

# check run and grab some metadata
run=$(basename $run_dir)
report=$(find $run_dir -name "report_*.md")
[ -z "$report" ] && { echo "Couldn't find report_*.md for $run at "$(dirname $run_dir); exit 1; };
echo "Report: $report"

cell=$(grep "flow_cell_product_code" $report | grep -oP "FLO-MIN\d+");
echo "Cell:   $cell"

# select model
declare -A models=(
    ["FLO-MIN106"]="dna_r9.4.1_e8_sup@v3.3"
    ["FLO-MIN111"]="dna_r10.3@v3.3"
    ["FLO-MIN112"]="dna_r10.4_e8.1_sup@v3.4"
    ["FLO-MIN114"]="dna_r10.4.1_e8.2_400bps_sup@v4.1.0")
model=${models[$cell]}
echo "Model:  $model"

# run 
# bonito basecaller $model
fast5_dir=$(dirname $report)/fast5_pass
out_dir=$(basename $run_dir)

mkdir $out_dir

if [ -n "$(ls -A $fast5_dir/barcode* 2>/dev/null)" ]
then
    pod5-convert-fast5 $fast5_dir/* $out_dir/"$run"_pod5 &> $out_dir/$run.pod5.log
    dorado basecaller --emit-fastq $model $out_dir/"$run"_pod5 > $out_dir/$run.fastq 2> $out_dir/$run.dorado.log
    porechop -i $out_dir/$run.fastq -b $out_dir/"$run"_demux --format fastq.gz --threads 20 &> $out_dir/$run.porechop.log
else
    pod5-convert-fast5 $fast5_dir/* $out_dir/"$run"_pod5 &> $out_dir/$run.pod5.log
    dorado basecaller --emit-fastq $model $out_dir/"$run"_pod5 > $out_dir/$run.fastq 2> $out_dir/$run.dorado.log
    porechop -i $out_dir/$run.fastq -o $out_dir/$run.trimmed.fastq.gz --format fastq.gz --threads 20 &> $out_dir/$run.porechop.log
fi

echo END: `date`;
