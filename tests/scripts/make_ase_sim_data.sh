#!/usr/bin/env bash
#
# Build an end-to-end test dataset for nf-core/alleleexpression from public resources:
#   - GRCh38 chr11 sequence (UCSC), GENCODE v47 annotation
#   - 1000 Genomes 30x phased panel (3202 samples, NYGC/EBI)
#   - Beagle GRCh38 PLINK genetic map
#
# A 2 Mb window of chr11 is cut out and re-based to position 1, keeping the contig
# name "chr11" (so params.chromosome = 'chr11' still applies). Every coordinate in the
# FASTA, GTF, BED, VCFs and genetic map is shifted by -OFFSET consistently.
#
# RNA-seq reads are simulated from the true haplotypes of real 1000G individuals with
# planted allele-specific expression; those individuals (and NA12878's parents) are
# removed from the Beagle reference panel.
#
# Requires: bcftools, samtools, python3 + numpy, wget, unzip, docker (for STAR index).
#
# Usage: tests/scripts/make_ase_sim_data.sh [CACHE_DIR] [OUT_DIR]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CACHE="${1:-$REPO_DIR/../testdata_cache}"
OUT="${2:-$REPO_DIR/tests/data/ase_sim}"

CHROM=chr11
START=64500001          # 1-based, inclusive (GRCh38)
END=66500000
OFFSET=$((START - 1))
LEN=$((END - OFFSET))
SAMPLES=(NA12878 HG00096)
EXCLUDE_FROM_PANEL=NA12878,NA12891,NA12892,HG00096
STAR_CONTAINER=community.wave.seqera.io/library/htslib_samtools_star_gawk:ae438e9a604351a4

KGP_URL=http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000G_2504_high_coverage/working/20220422_3202_phased_SNV_INDEL_SV/1kGP_high_coverage_Illumina.${CHROM}.filtered.SNV_INDEL_SV_phased_panel.vcf.gz

mkdir -p "$CACHE" "$OUT"/{reference,variants,fastq,truth}
CACHE="$(cd "$CACHE" && pwd)"
OUT="$(cd "$OUT" && pwd)"

# ----------------------------------------------------------------------------
# Download (cached)
# ----------------------------------------------------------------------------
cd "$CACHE"
[ -s chr11.fa.fai ] || {
    wget -q -c https://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/chr11.fa.gz
    gunzip -kf chr11.fa.gz
    samtools faidx chr11.fa
}
[ -s gencode.v47.primary_assembly.annotation.gtf.gz ] || \
    wget -q -c https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_47/gencode.v47.primary_assembly.annotation.gtf.gz
[ -s plink.chrchr11.GRCh38.map ] || {
    wget -q -c https://bochet.gcc.biostat.washington.edu/beagle/genetic_maps/plink.GRCh38.map.zip
    unzip -o -j -q plink.GRCh38.map.zip chr_in_chrom_field/plink.chrchr11.GRCh38.map
}
[ -s kgp_chr11_region.vcf.gz ] || \
    bcftools view -r "${CHROM}:$((START - 100000))-$((END + 100000))" -Oz -o kgp_chr11_region.vcf.gz "$KGP_URL"
[ -s kgp_chr11_region.vcf.gz.tbi ] || bcftools index -t kgp_chr11_region.vcf.gz

# ----------------------------------------------------------------------------
# Reference: FASTA, GTF, gene BED
# ----------------------------------------------------------------------------
echo "[reference]"
samtools faidx chr11.fa "${CHROM}:${START}-${END}" | sed "1s/.*/>${CHROM}/" > "$OUT/reference/genome.fa"
samtools faidx "$OUT/reference/genome.fa"

# Keep genes lying entirely inside the window (and all their child features)
zcat gencode.v47.primary_assembly.annotation.gtf.gz \
    | awk -F'\t' -v OFS='\t' -v c="$CHROM" -v s="$START" -v e="$END" -v o="$OFFSET" '
        $1 != c { next }
        $3 == "gene" { keep = ($4 >= s && $5 <= e) }
        keep { $4 -= o; $5 -= o; print }' \
    > "$OUT/reference/genes.gtf"

# BED6 of genes (0-based start) for phaser_gene_ae; name = gene_id
awk -F'\t' -v OFS='\t' '$3 == "gene" {
        match($9, /gene_id "[^"]+"/); id = substr($9, RSTART + 9, RLENGTH - 10)
        print $1, $4 - 1, $5, id, 0, $7 }' "$OUT/reference/genes.gtf" \
    | sort -k1,1 -k2,2n > "$OUT/reference/genes.bed"

# ----------------------------------------------------------------------------
# Variants: shift to window coordinates, biallelic SNPs only
# ----------------------------------------------------------------------------
echo "[variants]"
shift_vcf() {
    # stdin: VCF text; stdout: VCF text with POS shifted and a single contig line
    awk -F'\t' -v OFS='\t' -v c="$CHROM" -v o="$OFFSET" -v len="$LEN" '
        /^##contig=/ { next }
        /^#CHROM/ { print "##contig=<ID=" c ",length=" len ",assembly=GRCh38_" c "_" o+1 "_" o+len ">"; print; next }
        /^#/ { print; next }
        { $2 -= o; if ($2 >= 1 && $2 <= len) print }'
}

bcftools view -m2 -M2 -v snps -r "${CHROM}:${START}-${END}" kgp_chr11_region.vcf.gz 2>/dev/null \
    | shift_vcf | bcftools view -Oz -o "$CACHE/window_snps_all.vcf.gz"
bcftools index -f -t "$CACHE/window_snps_all.vcf.gz"

# Beagle reference panel: everyone except the test individuals; drop monomorphic sites
bcftools view -s "^${EXCLUDE_FROM_PANEL}" --force-samples "$CACHE/window_snps_all.vcf.gz" 2>/dev/null \
    | bcftools view -c 1:minor -Ou \
    | bcftools annotate -x INFO -Oz -o "$OUT/variants/beagle_ref.${CHROM}.vcf.gz"
bcftools index -f -t "$OUT/variants/beagle_ref.${CHROM}.vcf.gz"

# Genetic map (PLINK format), shifted, restricted to the window
awk -v OFS='\t' -v o="$OFFSET" -v len="$LEN" '{ p = $4 - o; if (p >= 1 && p <= len) print $1, $2, $3, p }' \
    plink.chrchr11.GRCh38.map > "$OUT/variants/genetic_map.${CHROM}.map"

# Per-sample input VCFs: what a variant caller would give (unphased, PASS, non-ref only)
for S in "${SAMPLES[@]}"; do
    bcftools view -s "$S" -c 1 "$CACHE/window_snps_all.vcf.gz" 2>/dev/null -Ou \
        | bcftools annotate -x INFO -Ov \
        | awk -F'\t' -v OFS='\t' '
            /^##/ { print; next }
            /^#CHROM/ { print "##FILTER=<ID=PASS,Description=\"All filters passed\">"; print; next }
            { $6 = 60; $7 = "PASS"; sub(/\|/, "/", $10); print }' \
        | bcftools view -Oz -o "$OUT/variants/${S}.vcf.gz"
    bcftools index -f -t "$OUT/variants/${S}.vcf.gz"

    # Truth phased genotypes for this sample (for evaluating Beagle)
    bcftools view -s "$S" -c 1 "$CACHE/window_snps_all.vcf.gz" 2>/dev/null \
        | bcftools annotate -x INFO -Oz -o "$OUT/truth/${S}.phased_truth.vcf.gz"
    bcftools index -f -t "$OUT/truth/${S}.phased_truth.vcf.gz"
done

# ----------------------------------------------------------------------------
# Reads
# ----------------------------------------------------------------------------
echo "[reads]"
seed=1
for S in "${SAMPLES[@]}"; do
    python3 "$SCRIPT_DIR/simulate_ase_reads.py" \
        --fasta "$OUT/reference/genome.fa" \
        --gtf "$OUT/reference/genes.gtf" \
        --vcf "$OUT/truth/${S}.phased_truth.vcf.gz" \
        --sample "$S" \
        --seed $seed \
        --out-prefix "$OUT/fastq/${S}"
    mv "$OUT/fastq/${S}".truth_*.tsv "$OUT/truth/"
    seed=$((seed + 1))
done

# ----------------------------------------------------------------------------
# STAR index (same STAR as the pipeline's STAR_ALIGN_WASP container)
# ----------------------------------------------------------------------------
echo "[star index]"
rm -rf "$OUT/reference/star_index"
mkdir -p "$OUT/reference/star_index"
docker run --rm -u "$(id -u):$(id -g)" -v "$OUT/reference:/ref" "$STAR_CONTAINER" \
    STAR --runMode genomeGenerate --runThreadN 4 \
        --genomeDir /ref/star_index \
        --genomeFastaFiles /ref/genome.fa \
        --sjdbGTFfile /ref/genes.gtf --sjdbOverhang 99 \
        --genomeSAindexNbases 9 \
        --outFileNamePrefix /ref/star_index/ > /dev/null
rm -f "$OUT/reference/star_index/Log.out"

# ----------------------------------------------------------------------------
# Samplesheet (absolute paths; regenerate if the repo moves)
# ----------------------------------------------------------------------------
{
    echo "sample,fastq_1,fastq_2,vcf"
    for S in "${SAMPLES[@]}"; do
        echo "${S},${OUT}/fastq/${S}_R1.fastq.gz,${OUT}/fastq/${S}_R2.fastq.gz,${OUT}/variants/${S}.vcf.gz"
    done
} > "$OUT/samplesheet.csv"

echo "Done: $OUT"
du -sh "$OUT"/*
