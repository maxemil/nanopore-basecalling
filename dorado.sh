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
  -h  show this help
EOF
exit 0;
}

echo START: `date`;

## prep
[[ $# -eq 0 ]] && usage;

# Execute getopt
ARGS=`getopt --name "dorado.sh" \
    --options "d:c:m:p:h" \
    -- "$@"`
echo $@
#Bad arguments
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
    ["FLO-MIN106"]="dna_r9.4.1_e8_sup@v3.3"
    ["FLO-MIN111"]="dna_r10.3@v3.3"
    ["FLO-MIN112"]="dna_r10.4_e8.1_sup@v3.4"
    ["FLO-MIN114"]="dna_r10.4.1_e8.2_400bps_sup@v4.3.0")
[ -z ${model+set} ] && model=${models[$cell]}
echo "Model:  $model"

pod5_dir=$(dirname $report)/"$raw_format"_pass
out_dir=$(basename $run_dir)
mkdir -p $out_dir

if [ $raw_format == 'fast5' ] ;
then 
    pod5 convert fast5 $pod5_dir -O $pod5_dir --threads 20 -r -o $out_dir/pod5_pass
    pod5_dir=$out_dir/pod5_pass
fi

if [ -n "$(ls -A $pod5_dir/barcode* 2>/dev/null)" ]
then
    for barcode_dir in $pod5_dir/barcode* 
    do
        barcode_base=$(basename $barcode_dir)
        dorado duplex $model $barcode_dir 2> $out_dir/"$run"_"$barcode_base".dorado.log > $out_dir/"$run"_"$barcode_base".bam
        if [[ $(samtools quickcheck $out_dir/"$run"_"$barcode_base".bam) -eq 0 ]]; 
        then 
            samtools view -O fastq -d dx:0 $out_dir/"$run"_"$barcode_base".bam | pigz > $out_dir/"$run"_"$barcode_base".simplex.fastq.gz
            samtools view -O fastq -d dx:1 $out_dir/"$run"_"$barcode_base".bam | pigz > $out_dir/"$run"_"$barcode_base".duplex.fastq.gz

            porechop -i $out_dir/"$run"_"$barcode_base".simplex.fastq.gz -o $out_dir/"$run"_"$barcode_base".simplex.trimmed.fastq.gz \
                            --format fastq.gz --threads 20 &> $out_dir/"$run"_"$barcode_base".simplex.porechop.log
            porechop -i $out_dir/"$run"_"$barcode_base".duplex.fastq.gz -o $out_dir/"$run"_"$barcode_base".duplex.trimmed.fastq.gz \
                            --format fastq.gz --threads 20 &> $out_dir/"$run"_"$barcode_base".duplex.porechop.log 
        else 
            echo 'no data found'; 
        fi
    done
else
    dorado duplex $model $pod5_dir 2> $out_dir/$run.dorado.log > $out_dir/$run.bam
    samtools view -O fastq -d dx:0 $out_dir/"$run".bam | pigz > $out_dir/"$run".simplex.fastq.gz
    samtools view -O fastq -d dx:1 $out_dir/"$run".bam | pigz > $out_dir/"$run".duplex.fastq.gz
    porechop -i $out_dir/"$run".simplex.fastq.gz -o $out_dir/"$run".simplex.trimmed.fastq.gz \
                    --format fastq.gz --threads 20 &> $out_dir/"$run".simplex.porechop.log
    porechop -i $out_dir/"$run".duplex.fastq.gz -o $out_dir/"$run".duplex.trimmed.fastq.gz \
                    --format fastq.gz --threads 20 &> $out_dir/"$run".duplex.porechop.log
fi
wait
echo END: `date`;
