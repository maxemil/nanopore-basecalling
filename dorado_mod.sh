#!/usr/bin/env bash

## subs
usage(){
cat <<EOF
Usage:
  dorado.sh
run dorado basecalling.
  -d  Base directory from the MinIon 
  -c  cell (e.g. FLO-MIN114)
  -m  model (e.g. dna_r10.4.1_e8.2_400bps_sup@v4.2.0)
  -p  pod5 or fast5, default pod5
  -o  modification, eg. 4mC_5mC,6mA
  -f  fasta reference
  -h  show this help
EOF
exit 0;
}

echo START: `date`;

## prep
[[ $# -eq 0 ]] && usage;

# Execute getopt
ARGS=`getopt --name "dorado.sh" \
    --options "d:c:m:p:o:f:h" \
    -- "$@"`
echo $@
#Bad argumentscd
[ $? -ne 0 ] && exit 1;

# A little magic
eval set -- "$ARGS"

raw_format='pod5'

# Now go through all the options
while [ : ]; do
    case "$1" in
        -d)
            [ ! -n "$2" ] && (echo "$1: value required" 1>&2 && exit 1);
            run_dir="$2";
            shift 2;;
        -c)
            cell="$2";
            shift 2;;
        -m)
            model="$2";
            shift 2;;
        -p)
            [ -n "$2" ] && [[ "$2" != 'pod5' && "$2" != 'fast5' ]] && (echo "$1: only pod5 or fast5 allowed" 1>&2 && exit 1);
            raw_format="$2";
            shift 2;;
        -o)
            [ ! -n "$2" ] && (echo "$1: value required" 1>&2 && exit 1);
            mod="$2";
            shift 2;;
        -f)
            [ ! -n "$2" ] && (echo "$1: value required" 1>&2 && exit 1);
            reference="$2";
            shift 2;;
        -h)
	    usage && exit 0;;
        --)
            shift
            break;;
        *)
            echo "$1: Unknown option" 1>&2 && exit 1;;
    esac
done

# check run and grab some metadata
run=$(basename $run_dir)
report=$(find $run_dir -name "report_*.md")
[ -z "$report" ] && { echo "Couldn't find report_*.md for $run at "$(dirname $run_dir); exit 1; };
echo "Report: $report"

[ -z ${cell+set} ] && cell=$(grep "flow_cell_product_code" $report | grep -oP "FLO-MIN\d+");
echo "Cell:   $cell"

# select model
declare -A models=(
    ["FLO-MIN114"]="sup@latest")
[ -z ${model+set} ] && model=${models[$cell]} 
echo "Model:  $model"

echo "Reference:    $reference"
refbase=$(basename ${reference%.f*})

out_dir=$(basename $run_dir)_mod
mkdir -p $out_dir/$raw_format
pod5_dir=$out_dir/$raw_format
rsync -ah --update $(dirname $report)/"$raw_format"*/* $pod5_dir

dorado -vv 2> $out_dir/$run.dorado.log
dorado basecaller -v "$model",$mod $pod5_dir --models-directory /data/mschoen/models/ $dorado_options 2>> $out_dir/$run.dorado.log | samtools view -F 3584 -u -S -@ 20 - | samtools sort -@ 20 -o $out_dir/"$run"_mod.bam
# dorado basecaller "$model",$mod $pod5_dir --reference $reference 2> $out_dir/$run.dorado.log | samtools view -F 3584 -u -S -@ 10 - | samtools sort -@ 30 -o $out_dir/"$refbase"_mod.bam
# dorado aligner $reference $out_dir/"$run"_mod.bam | samtools view -F 3588 -u -S -@ 10 - | samtools sort -@ 30 -o $out_dir/"$refbase"_mod.bam
samtools index  $out_dir/"$run"_mod.bam
# modkit pileup --filter-threshold 0.6 --only-tabs $out_dir/"$refbase"_mod.bam $out_dir/"$refbase"_mod.bed

wait
echo END: `date`;
