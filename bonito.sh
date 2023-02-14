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
    ["FLO-MIN114"]="dna_r10.4.1_e8.2_400bps_sup@v3.5.2")
model=${models[$cell]}
echo "Model:  $model"

# run 
# bonito basecaller $model
fast5_dir=$(dirname $report)/fast5_pass
out_dir=$(basename $run_dir)

mkdir $out_dir

if [ -n "$(ls -A $fast5_dir/barcode* 2>/dev/null)" ]
then
    for barcode_dir in $fast5_dir/barcode* 
    do
        barcode=$(basename $barcode_dir)
        bonito basecaller $model $barcode_dir > $out_dir/$run.$barcode.fq 2> $out_dir/$run.$barcode.log
    done
else
    (set -x;
     bonito basecaller $model $fast5_dir > $out_dir/$run.fq 2> $out_dir/$run.log
    )
fi

echo END: `date`;
