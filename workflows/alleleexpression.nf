#!/usr/bin/env nextflow

/*
========================================================================================
    Alleleexpression Workflow
========================================================================================
    Main workflow for Alleleexpression pipeline
----------------------------------------------------------------------------------------
*/

include { SAMPLESHEET_CHECK } from '../modules/local/input_check'
include { PREPARE_VCF } from '../modules/local/prepare_vcf'
include { CHROMOSOME_CHECK } from '../modules/local/chromosome_check'
include { FASTQC } from '../modules/nf-core/fastqc/main'
include { STAR_ALIGN_WASP } from '../modules/local/star_align_wasp/main'
include { FILTER_WASP_READS } from '../modules/local/filter_wasp_reads/main'
include { UMITOOLS_DEDUP } from '../modules/nf-core/umitools/dedup/main'
include { SAMTOOLS_SORT } from '../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_INDEX } from '../modules/nf-core/samtools/index/main'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_FINAL } from '../modules/nf-core/samtools/index/main'
include { BCFTOOLS_VIEW } from '../modules/local/bcftools_view/main'
include { BEAGLE5_BEAGLE } from '../modules/local/beagle5_beagle/main'
include { TABIX_INDEX } from '../modules/local/tabix_index/main'
include { PHASER } from '../modules/local/phaser/main'
include { PHASER_GENE_AE } from '../modules/local/phaser_gene_ae/main'
include { EXTRACT_ASE_GENES } from '../modules/local/extract_ase_genes/main'
include { MULTIQC } from '../modules/nf-core/multiqc/main'

workflow alleleexpression {
    take:
    ch_input                // channel: path to input CSV
    ch_multiqc_config       // channel: /path/to/multiqc_config.yaml
    ch_multiqc_custom_config // channel: /path/to/multiqc_custom_config.yaml

    // Fixed channel definitions
main:
    ch_versions = Channel.empty()

    // Read in samplesheet, validate and stage input files
    SAMPLESHEET_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(SAMPLESHEET_CHECK.out.versions)

    // Create explicitly structured channels for different processes
    SAMPLESHEET_CHECK.out.csv.splitCsv(header:true, sep:',')
        .map { row ->
            def meta = [id: row.sample, single_end: false]
            def fastq_1 = file(row.fastq_1)
            def fastq_2 = file(row.fastq_2)
            def reads = [fastq_1, fastq_2]
            def vcf = file(row.vcf)
            return [meta, reads, vcf]
        }
        .set { ch_vcf_input }

    // Extract just the reads for FastQC
    ch_vcf_input
        .map { meta, reads, _vcf -> [meta, reads] }
        .set { ch_reads }

    // Run FastQC
    FASTQC (
        ch_reads
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions)

    // Prepare VCF files for STAR and Beagle
    PREPARE_VCF (
        ch_vcf_input,
        params.chromosome
    )
    ch_versions = ch_versions.mix(PREPARE_VCF.out.versions)

    // FIXED: Create properly formatted reference channels
    ch_star_index = Channel.fromPath(params.star_index)
        .map { file -> [['id': 'star_index'], file] }
    ch_gtf = Channel.fromPath(params.gtf)
        .map { file -> [['id': 'gtf'], file] }

    // FIXED: Use direct values instead of Channel.value()
    def star_ignore_sjdbgtf = false
    def seq_platform = "illumina"
    def seq_center = false

    // Combine reads with VCF for STAR alignment
    ch_reads_with_vcf = ch_reads.join(PREPARE_VCF.out.vcf_star)

    // Run STAR alignment with WASP
    STAR_ALIGN_WASP (
        ch_reads_with_vcf.map { meta, reads, _vcf -> [meta, reads] },
        ch_star_index,
        ch_gtf,
        ch_reads_with_vcf.map { _meta, _reads, vcf -> vcf },
        star_ignore_sjdbgtf,
        seq_platform,
        seq_center
    )
    ch_versions = ch_versions.mix(STAR_ALIGN_WASP.out.versions)

    // Filter WASP reads
    FILTER_WASP_READS (
        STAR_ALIGN_WASP.out.bam_sorted_aligned.map { meta, bam -> [meta, bam, []] }
    )
    ch_versions = ch_versions.mix(FILTER_WASP_READS.out.versions)

    // FIXED: Sort the filtered BAM files with proper empty fasta structure
    SAMTOOLS_SORT (
        FILTER_WASP_READS.out.bam,
        Channel.value([['id': 'dummy'], []])
    )
    ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions)

    // Index the sorted BAM
    SAMTOOLS_INDEX (
        SAMTOOLS_SORT.out.bam
    )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions)

    // UMI deduplication
    ch_bam_with_index = SAMTOOLS_SORT.out.bam.join(SAMTOOLS_INDEX.out.bai)

    UMITOOLS_DEDUP (
        ch_bam_with_index,
        false  // FIXED: Direct boolean instead of Channel.value()
    )
    ch_versions = ch_versions.mix(UMITOOLS_DEDUP.out.versions)

    // Index the final deduplicated BAM
    SAMTOOLS_INDEX_FINAL (
        UMITOOLS_DEDUP.out.bam
    )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX_FINAL.out.versions)

    // Extract chromosome from VCF
    BCFTOOLS_VIEW (
        PREPARE_VCF.out.vcf_beagle,
        params.chromosome
    )
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW.out.versions)

    // FIXED: Format beagle reference and map files properly
    ch_beagle_ref = params.beagle_ref ?
        Channel.fromPath(params.beagle_ref).first() :
        Channel.empty()
    ch_beagle_map = params.beagle_map ?
        Channel.fromPath(params.beagle_map).first() :
        Channel.empty()

    // Phase with Beagle
    BEAGLE5_BEAGLE (
        BCFTOOLS_VIEW.out.vcf,
        ch_beagle_ref,
        ch_beagle_map
    )
    ch_versions = ch_versions.mix(BEAGLE5_BEAGLE.out.versions)

    // Index the Beagle output VCF
    TABIX_INDEX (
        BEAGLE5_BEAGLE.out.vcf
    )
    ch_versions = ch_versions.mix(TABIX_INDEX.out.versions)

    // Combine final BAM with its index for phaser
    ch_final_bam_with_index = UMITOOLS_DEDUP.out.bam.join(SAMTOOLS_INDEX_FINAL.out.bai)

    // Combine VCF and BAM for phaser
    ch_phaser_input = TABIX_INDEX.out.vcf_indexed
        .join(ch_final_bam_with_index)
        .map { meta, vcf, tbi, bam, bai -> [meta, vcf, tbi, bam, bai] }

    // Run phaser
    PHASER (
        ch_phaser_input
    )
    ch_versions = ch_versions.mix(PHASER.out.versions)

    // FIXED: Gene features with proper structure
    ch_gene_features = Channel.fromPath(params.gene_features).first()

    // Run phaser_gene_ae
    PHASER_GENE_AE (
        PHASER.out.counts,
        ch_gene_features
    )
    ch_versions = ch_versions.mix(PHASER_GENE_AE.out.versions)

    // Extract ASE genes
    EXTRACT_ASE_GENES (
        PHASER_GENE_AE.out.ae
    )
    ch_versions = ch_versions.mix(EXTRACT_ASE_GENES.out.versions)

    // FIXED: MultiQC with proper channel handling
    ch_multiqc_files = Channel.empty()
        .mix(FASTQC.out.zip.collect{it[1]})
        .collect()

    MULTIQC (
        ch_multiqc_files,
        ch_multiqc_config.ifEmpty([]),
        ch_multiqc_custom_config.ifEmpty([]),
        Channel.empty(),  // multiqc_logo
        Channel.empty(),  // replace_names
        Channel.empty()   // sample_names
    )
    ch_versions = ch_versions.mix(MULTIQC.out.versions)

    emit:
    multiqc_report = MULTIQC.out.report.toList()
    versions       = ch_versions.ifEmpty(null)
}
