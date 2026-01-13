# nf-core/alleleexpression
: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [FastQC](#fastqc) - Raw read QC
- [STAR](#star) - Alignment with WASP mode
- [WASP Filtering](#wasp-filtering) - Remove reads with allelic mapping bias
- [UMI-tools](#umi-tools) - UMI-based deduplication
- [SAMtools](#samtools) - BAM file processing
- [BCFtools](#bcftools) - VCF processing
- [Beagle](#beagle) - Haplotype phasing
- [phaser](#phaser) - Allele-specific expression analysis
- [MultiQC](#multiqc) - Aggregate report describing results and QC from the whole pipeline
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

## FastQC

<details markdown="1">
<summary>Output files</summary>

- `fastqc/`
  - `*_fastqc.html`: FastQC report containing quality metrics.
  - `*_fastqc.zip`: Zip archive containing the FastQC report, tab-delimited data file and plot images.

</details>

[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) gives general quality metrics about your sequenced reads. It provides information about the quality score distribution across your reads, per base sequence content (%A/C/G/T), adapter contamination and overrepresented sequences. For further reading and documentation see the [FastQC help pages](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/).

![MultiQC - FastQC sequence counts plot](images/mqc_fastqc_counts.png)

![MultiQC - FastQC mean quality scores plot](images/mqc_fastqc_quality.png)

![MultiQC - FastQC adapter content plot](images/mqc_fastqc_adapter.png)

> **NB:** The FastQC plots displayed in the MultiQC report shows _untrimmed_ reads. They may contain adapter sequence and potentially regions with low quality.

## STAR

<details markdown="1">
<summary>Output files</summary>

- `star/`
  - `*.Log.final.out`: STAR alignment log with summary statistics.
  - `*.Log.out`: Full STAR log output.
  - `*.Log.progress.out`: STAR progress log.
  - `*.SJ.out.tab`: Splice junction information.
  - `*.Aligned.sortedByCoord.out.bam`: STAR aligned, coordinate sorted BAM file.

</details>

[STAR](https://github.com/alexdobin/STAR) is a read aligner designed for RNA sequencing. The pipeline uses STAR in WASP mode to perform allele-aware alignment, which helps reduce reference mapping bias in allele-specific expression analysis.

STAR is run with the following key parameters for ASE analysis:
- `--waspOutputMode SAMtag`: Adds WASP tags to output
- `--varVCFfile`: Uses provided VCF for allele-aware alignment
- `--outSAMattributes NH HI AS nM NM MD jM jI rB MC vA vG vW`: Includes necessary SAM attributes
- `--alignEndsType EndToEnd`: Ensures end-to-end alignment
- `--outFilterMultimapNmax 1`: Filters multi-mapping reads

![MultiQC - STAR alignment scores plot](images/mqc_star_alignment_plot.png)

The STAR section of the MultiQC report shows a summary of STAR alignment statistics including:
- Number of input reads
- Uniquely mapped reads percentage
- Multi-mapping reads percentage
- Unmapped reads percentage

## WASP Filtering

<details markdown="1">
<summary>Output files</summary>

- `wasp/`
  - `*.wasp_filtered.bam`: BAM file containing only reads that passed WASP filtering.

</details>

WASP (Workflow for Allele-Specific analysis Pipeline) filtering removes reads that show mapping bias toward the reference allele. This step is crucial for accurate allele-specific expression analysis.

The filtering process:
1. Identifies reads with the `vW:i:1` tag (WASP-passed reads)
2. Removes reads that failed WASP filtering (`vW:i:0`)
3. Retains only unbiased reads for downstream analysis

## UMI-tools

<details markdown="1">
<summary>Output files</summary>

- `umi/`
  - `*.dedup.bam`: Deduplicated BAM file.
  - `*.dedup.log`: UMI-tools deduplication log with statistics.

</details>

[UMI-tools](https://umi-tools.readthedocs.io/) removes duplicate reads based on mapping coordinates and UMI sequences. This is essential for accurate quantification when using UMI-tagged libraries.

The deduplication process:
1. Groups reads by mapping position
2. Clusters UMIs within each group
3. Retains one representative read per UMI cluster
4. Provides detailed statistics on deduplication efficiency

![MultiQC - UMI-tools deduplication plot](images/mqc_umitools_dedup.png)

## SAMtools

<details markdown="1">
<summary>Output files</summary>

- `bam/`
  - `*.sorted.bam`: Coordinate-sorted BAM files.
  - `*.sorted.bam.bai`: BAM index files.

</details>

[SAMtools](http://www.htslib.org/) is used for BAM file processing, including sorting and indexing operations required for downstream analysis.

## BCFtools

<details markdown="1">
<summary>Output files</summary>

- `vcf/`
  - `*.filtered.vcf.gz`: Chromosome-specific, PASS-filtered VCF file.
  - `*.filtered.vcf.gz.tbi`: Tabix index for the VCF file.

</details>

[BCFtools](http://www.htslib.org/) processes VCF files by:
1. Extracting variants for the specified chromosome
2. Filtering for PASS variants only
3. Preparing files for phasing with Beagle

## Beagle

<details markdown="1">
<summary>Output files</summary>

- `beagle/`
  - `*_beagle.vcf.gz`: Phased VCF file from Beagle.
  - `*.log`: Beagle phasing log.

</details>

[Beagle](https://faculty.washington.edu/browning/beagle/beagle.html) performs haplotype phasing of genetic variants. Phasing is essential for accurate allele-specific expression analysis as it determines which variants are on the same chromosome.

Beagle phasing features:
- Uses population reference panels when provided (`--beagle_ref`)
- Incorporates genetic maps for accurate recombination modeling (`--beagle_map`)
- Outputs phased genotypes with phase probabilities
- Handles missing genotypes through imputation

## phaser

<details markdown="1">
<summary>Output files</summary>

- `phaser/`
  - `*.phaser_output.haplotypic_counts.txt`: Read counts per haplotype per variant.
  - `*.phaser_output.allele_config.txt`: Allele configuration for each variant.
  - `*.phaser_output.variant_connections.txt`: Variant phasing connections.
  - `*.phaser_output.haplotypes.txt`: Haplotype information.
  - `*_gene_ae.tsv`: Gene-level allele-specific expression results.

</details>

[phaser](https://github.com/secastel/phaser) performs the core allele-specific expression analysis by:

1. **Haplotypic read counting**: Assigns reads to haplotypes based on phased variants
2. **ASE quantification**: Calculates allele-specific expression for each gene
3. **Statistical testing**: Determines significant ASE events

### Key output files:

#### Haplotypic counts (`*.haplotypic_counts.txt`)
Contains read counts for each haplotype at each heterozygous variant:
```
contig	start	stop	variantID	totalCount	haplotypeA	haplotypeB	aCount	bCount
chr11	123456	123456	rs123456	50	A	G	25	25
```

#### Gene-level ASE (`*_gene_ae.tsv`)
Gene-level allele-specific expression results:
```
contig	start	stop	geneID	totalCount	aCount	bCount	log2FC	pValue
chr11	1000000	2000000	ENSG00000123456	1000	600	400	0.585	0.001
```

Key columns:
- `totalCount`: Total reads mapping to the gene
- `aCount`/`bCount`: Reads supporting each allele
- `log2FC`: Log2 fold-change between alleles
- `pValue`: Statistical significance of ASE

## Extract ASE Genes

<details markdown="1">
<summary>Output files</summary>

- `ase/`
  - `*.ASE.tsv`: Filtered list of genes showing significant allele-specific expression.

</details>

This step filters the gene-level ASE results to identify genes with evidence of allele-specific expression (where `totalCount > 0`), providing a curated list of ASE candidates for further investigation.

## MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: A standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: Directory containing parsed statistics from the different tools used in the pipeline.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools including:
- FastQC
- STAR
- UMI-tools
- SAMtools

The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

### Pipeline summary metrics

The pipeline collects various metrics throughout the analysis:

![MultiQC - Pipeline summary table](images/mqc_general_stats_table.png)

### Workflow summary

![MultiQC - Workflow summary plot](images/mqc_workflow_summary.png)

## Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.

## Interpreting Results

### Quality Control Checkpoints

1. **FastQC**: Ensure reads have good quality scores and no excessive adapter contamination
2. **STAR alignment**: Check for reasonable alignment rates (typically >70% for RNA-seq)
3. **WASP filtering**: Monitor the fraction of reads passing WASP filtering
4. **UMI deduplication**: Verify appropriate deduplication levels (depends on library complexity)

### ASE Analysis

1. **Variant coverage**: Ensure adequate read coverage at heterozygous sites
2. **Phasing quality**: Check Beagle phasing statistics and phase probabilities
3. **ASE significance**: Focus on genes with significant p-values and adequate read counts
4. **Effect sizes**: Consider both statistical significance and biological relevance (log2FC)

### Troubleshooting

#### Low alignment rates
- Check read quality and potential adapter contamination
- Verify reference genome compatibility
- Consider read trimming if quality is poor

#### Few ASE genes detected
- Verify VCF quality and variant density
- Check phasing quality and coverage
- Ensure adequate sequencing depth
- Validate UMI processing if applicable

#### High duplicate rates
- Normal for UMI-based libraries
- Concerning for non-UMI libraries (may indicate PCR over-amplification)
- Review library preparation protocols

### File Formats

#### VCF Requirements
- Must contain heterozygous variants for the sample
- Should include genotype quality scores
- Variants should be filtered (PASS only)
- Chromosome naming must match reference genome

#### FASTQ Requirements
- Paired-end reads required
- UMI information should be in read headers (if using UMIs)
- Gzipped format recommended
- Standard Illumina naming conventions

## Citation

If you use nf-core/alleleexpression
 for your analysis, please cite:

> **nf-core/alleleexpression
: Allele-specific expression analysis pipeline**
>
> doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX)

In addition, references for the tools used in this pipeline are as follows:

> **FastQC** (Andrews, S. (2010). FastQC: A Quality Control Tool for High Throughput Sequence Data. Available online at: http://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
>
> **STAR** Dobin A, Davis CA, Schlesinger F, Drenkow J, Zaleski C, Jha S, Batut P, Chaisson M, Gingeras TR. STAR: ultrafast universal RNA-seq aligner. Bioinformatics. 2013 Jan 1;29(1):15-21. doi: 10.1093/bioinformatics/bts635.
>
> **UMI-tools** Smith T, Heger A, Sudbery I. UMI-tools: modeling sequencing errors in Unique Molecular Identifiers to improve quantification accuracy. Genome Res. 2017 Mar;27(3):491-499. doi: 10.1101/gr.209601.116.
>
> **SAMtools** Li H, Handsaker B, Wysoker A, Fennell T, Ruan J, Homer N, Marth G, Abecasis G, Durbin R; 1000 Genome Project Data Processing Subgroup. The Sequence Alignment/Map format and SAMtools. Bioinformatics. 2009 Aug 15;25(16):2078-84. doi: 10.1093/bioinformatics/btp352.
>
> **BCFtools** Danecek P, Bonfield JK, et al. Twelve years of SAMtools and BCFtools. Gigascience. 2021 Feb 16;10(2):giab008. doi: 10.1093/gigascience/giab008.
>
> **Beagle** Browning BL, Tian X, Zhou Y, Browning SR. Fast two-stage phasing of large-scale sequence data. Am J Hum Genet. 2021 Oct 7;108(10):1880-1890. doi: 10.1016/j.ajhg.2021.08.005.
>
> **phaser** Castel SE, Levy-Moonshine A, Mohammadi P, Banks E, Lappalainen T. Tools and best practices for data processing in allelic expression analysis. Genome Biol. 2015 Sep 30;16:195. doi: 10.1186/s13059-015-0762-6.
>
> **MultiQC** Ewels P, Magnusson M, Lundin S, Käller M. MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics. 2016 Oct 1;32(19):3047-8. doi: 10.1093/bioinformatics/btw354.
>
> **Nextflow** Di Tommaso P, Chatzou M, Floden EW, Barja PP, Palumbo E, Notredame C. Nextflow enables reproducible computational workflows. Nat Biotechnol. 2017 Apr 11;35(4):316-319. doi: 10.1038/nbt.3820.
