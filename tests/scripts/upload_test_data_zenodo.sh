#!/usr/bin/env bash
#
# Upload the simulated test dataset (tests/data/ase_sim, built by make_ase_sim_data.sh)
# to a new Zenodo DRAFT record. Nothing is published: review the draft on Zenodo and
# press "Publish" yourself.
#
# Files are uploaded flat (Zenodo has no folders). A samplesheet pointing at the
# record's download URLs is generated and uploaded too, and the URL base is printed
# for conf/test.config.
#
# Requires: curl, python3, a Zenodo personal access token with deposit:write and
# deposit:actions scopes in ~/.zenodo_token (or $ZENODO_TOKEN_FILE).
#
# Usage: tests/scripts/upload_test_data_zenodo.sh [DATA_DIR] [--sandbox]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${1:-$SCRIPT_DIR/../data/ase_sim}"
API=https://zenodo.org/api
WEB=https://zenodo.org
if [[ "${2:-}" == "--sandbox" ]]; then
    API=https://sandbox.zenodo.org/api
    WEB=https://sandbox.zenodo.org
fi
TOKEN_FILE="${ZENODO_TOKEN_FILE:-$HOME/.zenodo_token}"
[ -s "$TOKEN_FILE" ] || { echo "No token in $TOKEN_FILE" >&2; exit 1; }
AUTH="Authorization: Bearer $(tr -d '[:space:]' < "$TOKEN_FILE")"
SAMPLES=(NA12878 HG00096)

# published name -> local path
declare -A FILES=(
    [genome.fa]="$DATA/reference/genome.fa"
    [genes.gtf]="$DATA/reference/genes.gtf"
    [genes.bed]="$DATA/reference/genes.bed"
    [beagle_ref.chr11.vcf.gz]="$DATA/variants/beagle_ref.chr11.vcf.gz"
    [beagle_ref.chr11.vcf.gz.tbi]="$DATA/variants/beagle_ref.chr11.vcf.gz.tbi"
    [genetic_map.chr11.map]="$DATA/variants/genetic_map.chr11.map"
    [README.md]="$DATA/README.md"
)
for S in "${SAMPLES[@]}"; do
    FILES[${S}_R1.fastq.gz]="$DATA/fastq/${S}_R1.fastq.gz"
    FILES[${S}_R2.fastq.gz]="$DATA/fastq/${S}_R2.fastq.gz"
    FILES[${S}.vcf.gz]="$DATA/variants/${S}.vcf.gz"
    FILES[${S}.vcf.gz.tbi]="$DATA/variants/${S}.vcf.gz.tbi"
    FILES[${S}.truth_genes.tsv]="$DATA/truth/${S}.truth_genes.tsv"
    FILES[${S}.truth_het_snps.tsv]="$DATA/truth/${S}.truth_het_snps.tsv"
    FILES[${S}.phased_truth.vcf.gz]="$DATA/truth/${S}.phased_truth.vcf.gz"
    FILES[${S}.phased_truth.vcf.gz.tbi]="$DATA/truth/${S}.phased_truth.vcf.gz.tbi"
done
for f in "${FILES[@]}"; do [ -s "$f" ] || { echo "Missing $f" >&2; exit 1; }; done

# 1. Create an empty draft deposition
resp=$(curl -sS --fail-with-body -H "$AUTH" -H "Content-Type: application/json" -X POST "$API/deposit/depositions" -d '{}')
ID=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' <<< "$resp")
BUCKET=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["links"]["bucket"])' <<< "$resp")
BASE="$WEB/records/$ID/files"
echo "Draft deposition $ID"

# 2. Samplesheet with download URLs of this record
SHEET=$(mktemp)
trap 'rm -f "$SHEET"' EXIT
{
    echo "sample,fastq_1,fastq_2,vcf"
    for S in "${SAMPLES[@]}"; do
        echo "${S},${BASE}/${S}_R1.fastq.gz,${BASE}/${S}_R2.fastq.gz,${BASE}/${S}.vcf.gz"
    done
} > "$SHEET"
FILES[samplesheet.csv]="$SHEET"

# 3. Upload files
for name in "${!FILES[@]}"; do
    echo "  uploading $name"
    curl -sS --fail-with-body -o /dev/null -H "$AUTH" --upload-file "${FILES[$name]}" "$BUCKET/$name"
done

# 4. Metadata
python3 - "$ID" > "$SHEET.meta" <<'EOF'
import json, sys
desc = """Simulated test dataset for <a href="https://github.com/nf-core/alleleexpression">nf-core/alleleexpression</a>
(allele-specific expression with STAR-WASP, UMI-tools, Beagle and phASER).
<p>A 2 Mb window of GRCh38 chr11 (64,500,001-66,500,000) re-based to position 1 (contig name kept as chr11).
Paired-end, UMI-tagged RNA-seq reads are simulated from the true phased haplotypes of 1000 Genomes
individuals NA12878 and HG00096 (12 of 100 expressed genes with planted allelic imbalance; other genes
with beta-distributed allelic noise). Includes the matching reference, GENCODE v47 annotation,
per-sample VCFs, a Beagle reference panel (1000 Genomes 30x, test individuals and NA12878's parents
removed), the Beagle GRCh38 genetic map, a samplesheet using this record's URLs, and truth tables.</p>
<p>Sources: UCSC hg38; GENCODE v47; 1000 Genomes 30x phased panel (NYGC); Beagle PLINK GRCh38 map.
Built with tests/scripts/make_ase_sim_data.sh in the pipeline repository.</p>"""
meta = {"metadata": {
    "title": "nf-core/alleleexpression test data: simulated allele-specific expression on GRCh38 chr11",
    "upload_type": "dataset",
    "description": desc,
    "creators": [{"name": "Saadat, Abu"}],
    "license": "cc-by-4.0",
    "access_right": "open",
    "keywords": ["allele-specific expression", "RNA-seq", "nf-core", "test data", "simulation", "1000 Genomes"],
    "related_identifiers": [{"identifier": "https://github.com/nf-core/alleleexpression",
                             "relation": "isSupplementTo", "resource_type": "software"}],
}}
print(json.dumps(meta))
EOF
curl -sS --fail-with-body -o /dev/null -H "$AUTH" -H "Content-Type: application/json" \
    -X PUT "$API/deposit/depositions/$ID" --data @"$SHEET.meta"
rm -f "$SHEET.meta"

echo
echo "Uploaded ${#FILES[@]} files to DRAFT record $ID (not published)."
echo "Review and publish: $WEB/deposit/$ID"
echo "URL base for conf/test.config: $BASE"
