# nf-core/alleleexpression

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.04.0-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.3.1-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.3.1)

## Overview
Alleleexpression is a Nextflow pipeline for allele-specific expression (ASE) analysis using STAR-WASP for alignment, UMI-tools for deduplication, and phaser for haplotype phasing and ASE detection.

## Features
- STAR alignment with WASP mode for allele-specific mapping
- UMI-based deduplication
- Chromosome-specific analysis with configurable chromosome selection
- Beagle phasing integration
- Phaser-based allele-specific expression analysis
- Comprehensive QC with FastQC and MultiQC reporting

## Requirements
- Nextflow (>=25.04.0)
- Singularity or Docker
- Reference genome and annotation files
- Beagle reference panel and genetic map (for phasing)

With `-profile docker`, the phASER image must be built locally first:

```bash
docker build -t phaser:latest containers/phaser
```

With `-profile singularity` it is pulled automatically from Zenodo.

## Testing

The `test` profile downloads a simulated dataset from [Zenodo](https://zenodo.org/records/23215419)
(2 Mb of GRCh38 chr11, two 1000 Genomes samples with planted allele-specific expression, plus
truth tables):

```bash
nextflow run nf-core/alleleexpression -profile test,docker --outdir results
```

To rebuild the dataset locally, run `tests/scripts/make_ase_sim_data.sh` (see
`tests/data/ase_sim/README.md`).

## Pipeline steps
1. Input validation and VCF preparation
2. FastQC for raw reads
3. STAR alignment with WASP mode
4. Filtering of WASP-passing reads
5. UMI-based deduplication
6. Sorting and indexing of BAM files
7. Chromosome extraction from VCF
8. Beagle phasing
9. Phaser for haplotype-level expression
10. Phaser_gene_ae for gene-level ASE
11. ASE calling per gene: binomial or beta-binomial test (`--ase_test`), Benjamini-Hochberg FDR (`--ase_fdr`) and optional minimum effect size (`--ase_min_effect`); see [usage](docs/usage.md#choosing-an-ase-test)
12. MultiQC report generation

## Output
The pipeline organizes outputs by sample name in the specified output directory:
- `fastqc/`: FastQC reports
- `star/`: STAR alignment results
- `wasp/`: WASP-filtered BAM files
- `umi/`: UMI-deduplicated BAM files
- `beagle/`: Phased VCF files
- `phaser/`: Phaser results
- `ase/`: Allele-specific expression results
- `multiqc/`: MultiQC report

## Credits
- Pipeline framework: nf-core
- Tools: FastQC, STAR, UMI-tools, samtools, bcftools, Beagle, phaser, MultiQC

## Contributing

Alleleexpression is under active development and we welcome contributions!
If you find a bug, have an idea to improve it, or want to help implement new features (like better sex-chromosome support), feel free to open an issue or submit a pull request.

Let’s build this together.
