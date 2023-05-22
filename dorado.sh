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
    for barcode_dir in $fast5_dir/barcode* 
    do
        barcode_base=$(basename $barcode_dir)
        pod5 convert fast5 $barcode_dir/* --output $out_dir/"$run"_"$barcode_base"_pod5/"$run"_"$barcode_base".pod5 &> \
                $out_dir/"$run"_"$barcode_base".pod5.log
        dorado basecaller --emit-moves $model $out_dir/"$run"_"$barcode_base"_pod5 \
                2> $out_dir/"$run"_"$barcode_base".dorado.log | \
                samtools view -b -o $out_dir/"$run"_"$barcode_base".bam -@ 20 -
        samtools fastq -@ 20 $out_dir/"$run"_"$barcode_base".bam | pigz > $out_dir/"$run"_"$barcode_base".fastq.gz
        porechop -i $out_dir/"$run"_"$barcode_base".fastq.gz -o $out_dir/"$run"_"$barcode_base".trimmed.fastq.gz \
                --format fastq.gz --threads 20 &> $out_dir/"$run"_"$barcode_base".porechop.log &
    done
else
    pod5 convert fast5 $fast5_dir/* --output $out_dir/"$run"_pod5/"$run".pod5 &> $out_dir/$run.pod5.log
    dorado basecaller --emit-moves $model $out_dir/"$run"_pod5 \
                2> $out_dir/$run.dorado.log | \
                samtools view -b -o $out_dir/$run.bam  -@ 20 -
    samtools fastq -@ 20 $out_dir/$run.bam | pigz > $out_dir/$run.fastq.gz
    porechop -i $out_dir/$run.fastq.gz -o $out_dir/$run.trimmed.fastq.gz --format fastq.gz \
            --threads 20 &> $out_dir/$run.porechop.log
fi
wait
echo END: `date`;
