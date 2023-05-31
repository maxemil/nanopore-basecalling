#!/usr/bin/env bash
set -e

## subs
usage(){
cat <<EOF
Usage:
  run_dorado_duplex.sh -p POD5 -f FLOWCELL -s BAM
run prodigal on genome.
  -p folder containing pod5 file(s)
  -b simplex basecalled bam file with moves
  -f FLOWCELL model, eg. FLO-MIN114
  -h  show this help
EOF
exit 0;
}

## prep
[[ $# -eq 0 ]] && usage;

# Execute getopt
ARGS=`getopt --name "run_dorado_duplex.sh" \
    --options "p:b:f:h" \
    -- "$@"`
echo $@
#Bad arguments
[ $? -ne 0 ] && exit 1;

# A little magic
eval set -- "$ARGS"

# Now go through all the options
while [ : ]; do
    case "$1" in
        -p)
            [ ! -n "$2" ] && (echo "$1: value required" 1>&2 && exit 1);
            POD5="$2";
            shift 2;;
        -b)
            [ ! -n "$2" ] && (echo "$1: value required" 1>&2 && exit 1);
            BAM="$2";
            shift 2;;
        -f)
            [ ! -n "$2" ] && (echo "$1: value required" 1>&2 && exit 1);
            FLOWCELL="$2";
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
echo START: `date`;
echo "Cell:   $FLOWCELL"

# select model
declare -A models=(
    ["FLO-MIN106"]="dna_r9.4.1_e8_sup@v3.3"
    ["FLO-MIN111"]="dna_r10.3@v3.3"
    ["FLO-MIN112"]="dna_r10.4_e8.1_sup@v3.4"
    ["FLO-MIN114"]="dna_r10.4.1_e8.2_400bps_sup@v4.1.0")
model=/nfs/bmm/crov/mschoen/databases/dorado_models/${models[$FLOWCELL]}
echo "Model:  $model"

out_dir=$(dirname $BAM)
run=$(basename $BAM .bam)

echo "RUN main duplex basecalling"
duplex_tools pair --output_dir $out_dir/"$run"_pairs $BAM
dorado duplex --emit-fastq $model $POD5 --pairs $out_dir/"$run"_pairs/pair_ids_filtered.txt 2> \
        $out_dir/$run.dorado_duplex.log | pigz > $out_dir/"$run"_duplex.fastq.gz
porechop -i $out_dir/"$run"_duplex.fastq.gz -o $out_dir/"$run"_duplex.trimmed.fastq.gz --format fastq.gz \ 
            --threads 20 &> $out_dir/"$run"_duplex.porechop.log

echo "RUN additional duplex basecalling on non-split reads"
duplex_tools split_pairs $BAM $POD5 $out_dir/"$run"_splitduplex
cat $out_dir/"$run"_splitduplex/*_pair_ids.txt > $out_dir/"$run"_split_duplex_pair_ids.txt
dorado duplex --emit-fastq $model $out_dir/"$run"_splitduplex/ --pairs $out_dir/"$run"_split_duplex_pair_ids.txt 2> \
        $out_dir/$run.dorado_splitduplex.log | pigz > $out_dir/"$run"_splitduplex.fastq.gz
porechop -i $out_dir/"$run"_splitduplex.fastq.gz -o $out_dir/"$run"_splitduplex.trimmed.fastq.gz --format fastq.gz \ 
            --threads 20 &> $out_dir/"$run"_splitduplex.porechop.log
echo END: `date`;
