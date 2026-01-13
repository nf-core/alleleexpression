# nf-core/alleleexpression
: Usage

## Table of contents

- [Introduction](#introduction)
- [Pipeline summary](#pipeline-summary)
- [Quick start](#quick-start)
- [Pipeline parameters](#pipeline-parameters)
  - [Input/output options](#inputoutput-options)
  - [Reference genome options](#reference-genome-options)
  - [Chromosome and phasing options](#chromosome-and-phasing-options)
  - [UMI options](#umi-options)
  - [Institutional config options](#institutional-config-options)
  - [Max job request options](#max-job-request-options)
  - [Generic options](#generic-options)
- [Samplesheet format](#samplesheet-format)
- [Reference files](#reference-files)
- [Running the pipeline](#running-the-pipeline)
  - [Updating the pipeline](#updating-the-pipeline)
  - [Reproducibility](#reproducibility)
- [Core Nextflow arguments](#core-nextflow-arguments)
  - [`-profile`](#-profile)
  - [Resuming a workflow](#resuming-a-workflow)
  - [Custom configuration](#custom-configuration)
    - [Resource requests](#resource-requests)
    - [Custom Containers](#custom-containers)
    - [Custom Tool Arguments](#custom-tool-arguments)
    - [nf-core/configs](#nf-coreconfigs)
- [Azure Resource Requests](#azure-resource-requests)
- [Running in the background](#running-in-the-background)
- [Nextflow memory requirements](#nextflow-memory-requirements)

## Introduction

**nf-core/alleleexpression
** is a bioinformatics pipeline that performs allele-specific expression (ASE) analysis using:

- **STAR-WASP** for allele-aware alignment
- **UMI-tools** for molecular deduplication
- **Beagle** for haplotype phasing
- **phaser** for ASE quantification

The pipeline is designed for paired-end RNA-seq data with UMI barcodes and requires corresponding VCF files containing genetic variants for each sample.

## Pipeline summary

The Alleleexpression
 pipeline performs the following main steps:

1. **Quality Control** ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
2. **VCF Preparation** - Process VCF files for STAR and Beagle compatibility
3. **Alignment** ([`STAR`](https://github.com/alexdobin/STAR) with WASP mode)
4. **WASP Filtering** - Remove reads with allelic mapping bias
5. **UMI Deduplication** ([`UMI-tools`](https://umi-tools.readthedocs.io/))
6. **BAM Processing** ([`SAMtools`](http://www.htslib.org/))
7. **Variant Phasing** ([`Beagle`](https://faculty.washington.edu/browning/beagle/beagle.html))
8. **ASE Analysis** ([`phaser`](https://github.com/secastel/phaser))
9. **Report Generation** ([`MultiQC`](http://multiqc.info/))

## Quick start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=21.10.3`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) (you can follow [this tutorial](https://singularity-tutorial.github.io/01-installation/)), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(you can use [`Conda`](https://conda.io/miniconda.html) both to install Nextflow itself and also to manage software within pipelines. Please only use it within pipelines as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_.

3. Download the pipeline and test it on a minimal dataset with a single command:

   ```bash
   nextflow run nf-core/alleleexpression
 -profile test,docker --outdir <OUTDIR>
   ```

   Note that some form of configuration will be needed so that Nextflow knows how to fetch the required software. This is usually done in the form of a config profile (`YOURPROFILE` in the example command above). You can chain multiple config profiles in a comma-separated string.

   > - The pipeline comes with config profiles called `docker`, `singularity`, `podman`, `shifter`, `charliecloud` and `conda` which instruct the pipeline to use the named tool for software management. For example, `-profile test,docker`.
   > - Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines on your institution's infrastructure already exists before creating your own!
   > - If you are using `singularity`, please use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to download images first, before running the pipeline. Set the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options to be able to store and re-use the images from a central location for future pipeline runs.
   > - If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.

4. Start running your own analysis!

   ```bash
   nextflow run nf-core/alleleexpression
 --input samplesheet.csv --outdir <OUTDIR> --genome GRCh38 --chromosome chr11 -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
   ```

## Pipeline parameters

### Input/output options

Define where the pipeline should find input data and save output data.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-------------|------|---------|----------|--------|
| `input` | Path to comma-separated file containing information about the samples in the experiment. | `string` | | ✓ | |
| `outdir` | The output directory where the results will be saved. You have to use absolute paths to storage on Cloud infrastructure. | `string` | | ✓ | |
| `email` | Email address for completion summary. | `string` | | | |
| `multiqc_title` | MultiQC report title. Written as "title" in the MultiQC config file. | `string` | | | |

### Reference genome options

Reference genome related files and options required for the workflow.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-------------|------|---------|----------|--------|
| `genome` | Name of iGenomes reference. | `string` | | | |
| `fasta` | Path to FASTA genome file. | `string` | | | ✓ |
| `gtf` | Path to GTF annotation file. | `string` | | | ✓ |
| `star_index` | Path to directory containing STAR indices. | `string` | | | ✓ |
| `gene_features` | Path to BED file with gene features for phaser_gene_ae. | `string` | | | ✓ |
| `igenomes_base` | Directory / URL base for iGenomes references. | `string` | `s3://ngi-igenomes/igenomes/` | | ✓ |
| `igenomes_ignore` | Do not load the iGenomes reference config. | `boolean` | | | ✓ |

### Chromosome and phasing options

Options for chromosome selection and variant phasing.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-------------|------|---------|----------|--------|
| `chromosome` | Chromosome to analyze (e.g., 'chr11', 'chr1'). | `string` | `chr11` | | |
| `beagle_ref` | Path to Beagle reference panel VCF file for phasing. | `string` | | | |
| `beagle_map` | Path to Beagle genetic map file for phasing. | `string` | | | |

### UMI options

Options for UMI processing.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-------------|------|---------|----------|--------|
| `umi_separator` | UMI separator character in read IDs. | `string` | `:` | | |

### Institutional config options

Parameters used to describe centralised config profiles. These should not be edited.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-------------|------|---------|----------|--------|
| `custom_config_version` | Git commit id for Institutional configs. | `string` | `master` | | ✓ |
| `custom_config_base` | Base directory for Institutional configs. | `string` | `https://raw.githubusercontent.com/nf-core/configs/master` | | ✓ |
| `config_profile_name` | Institutional config name. | `string` | | | ✓ |
| `config_profile_description` | Institutional config description. | `string` | | | ✓ |
| `config_profile_contact` | Institutional config contact information. | `string` | | | ✓ |
| `config_profile_url` | Institutional config URL link. | `string` | | | ✓ |

### Max job request options

Set the top limit for requested resources for any single job.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-------------|------|---------|----------|--------|
| `max_cpus` | Maximum number of CPUs that can be requested for any single job. | `integer` | `16` | | ✓ |
| `max_memory` | Maximum amount of memory that can be requested for any single job. | `string` | `128.GB` | | ✓ |
| `max_time` | Maximum amount of time that can be requested for any single job. | `string` | `240.h` | | ✓ |

### Generic options

Less common options for the pipeline, typically set in a config file.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-------------|------|---------|----------|--------|
| `help` | Display help text. | `boolean` | | | ✓ |
| `version` | Display version and exit. | `boolean` | | | ✓ |
| `publish_dir_mode` | Method used to save pipeline results to output directory. | `string` | `copy` | | ✓ |
| `email_on_fail` | Email address for completion summary, only when pipeline fails. | `string` | | | ✓ |
| `plaintext_email` | Send plain-text email instead of HTML. | `boolean` | | | ✓ |
| `max_multiqc_email_size` | File size limit when attaching MultiQC reports to summary emails. | `string` | `25.MB` | | ✓ |
| `monochrome_logs` | Do not use coloured log outputs. | `boolean` | | | ✓ |
| `hook_url` | Incoming hook URL for messaging service | `string` | | | ✓ |
| `multiqc_config` | Custom config file to supply to MultiQC. | `string` | | | ✓ |
| `multiqc_logo` | Custom logo file to supply to MultiQC. File name must be the same when using MultiQC. | `string` | | | ✓ |
| `tracedir` | Directory to keep pipeline Nextflow logs and reports. | `string` | `${params.outdir}/pipeline_info` | | ✓ |
| `validate_params` | Boolean whether to validate parameters against the schema at runtime | `boolean` | `true` | | ✓ |
| `show_hidden_params` | Show all params when using `--help` | `boolean` | | | ✓ |

## Samplesheet format

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 4 columns, and a header row as shown in the examples below.

```console
--input '[path to samplesheet file]'
```

### Full samplesheet

The pipeline will auto-detect whether a sample is single- or paired-end using the information provided in the samplesheet. The samplesheet can have as many columns as you desire, however, there is a strict requirement for the first 4 columns to match those defined in the table below.

A final samplesheet file consisting of paired-end reads may look something like the one below. This is for 3 samples, where `SAMPLE3` has been sequenced twice.

```console
sample,fastq_1,fastq_2,vcf
SAMPLE1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz,SAMPLE1.vcf.gz
SAMPLE2,AEG588A2_S2_L002_R1_001.fastq.gz,AEG588A2_S2_L002_R2_001.fastq.gz,SAMPLE2.vcf.gz
SAMPLE3,AEG588A3_S3_L002_R1_001.fastq.gz,AEG588A3_S3_L002_R2_001.fastq.gz,SAMPLE3.vcf.gz
```

| Column    | Description                                                                                                                                                                            |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`  | Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `fastq_1` | Full path to FastQ file for Illumina short reads 1. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".                                                             |
| `fastq_2` | Full path to FastQ file for Illumina short reads 2. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".                                                             |
| `vcf`     | Full path to VCF file containing genetic variants for the sample. File can be gzipped (".vcf.gz") or uncompressed (".vcf").                                                           |

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

## Reference files

The Alleleexpression
 pipeline requires several reference files to run successfully:

### Required files

1. **Reference genome FASTA** (`--fasta`): The reference genome sequence
2. **GTF annotation** (`--gtf`): Gene annotation file
3. **STAR index** (`--star_index`): Pre-built STAR genome index
4. **Gene features BED** (`--gene_features`): BED file with gene coordinates for ASE analysis

### Optional files for phasing

1. **Beagle reference panel** (`--beagle_ref`): Population reference for improved phasing
2. **Beagle genetic map** (`--beagle_map`): Recombination map for phasing

### Using iGenomes

The pipeline is compatible with reference files from [AWS iGenomes](https://ewels.github.io/AWS-iGenomes/). You can use the `--genome` parameter to automatically configure reference files:

```bash
nextflow run nf-core/alleleexpression
 --input samplesheet.csv --genome GRCh38 --outdir results
```

Supported genomes include:
- `GRCh38` - Human (Homo sapiens)
- `GRCh37` - Human (Homo sapiens) 
- `GRCm38` - Mouse (Mus musculus)

### Preparing custom reference files

#### STAR index generation

If you need to create a STAR index:

```bash
STAR --runMode genomeGenerate \
     --genomeDir /path/to/star_index \
     --genomeFastaFiles genome.fa \
     --sjdbGTFfile genes.gtf \
     --runThreadN 8
```

#### Gene features BED file

The gene features BED file should contain gene coordinates for ASE analysis. It can be generated from your GTF file:

```bash
# Extract gene coordinates from GTF
awk '$3=="gene" {print $1"\t"$4-1"\t"$5"\t"$10"\t"$6"\t"$7}' genes.gtf | \
    sed 's/";//g' | sed 's/"//g' > gene_features.bed
```

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/alleleexpression
 --input ./samplesheet.csv --outdir ./results --genome GRCh38 --chromosome chr11 -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>           # Finished results in specified location (defined with --outdir)
.nextflow_log      # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> ⚠️ Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run nf-core/alleleexpression
 -params-file params.yaml
```

with `params.yaml` containing:

```yaml
input: './samplesheet.csv'
outdir: './results/'
genome: 'GRCh38'
chromosome: 'chr11'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/alleleexpression

```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/alleleexpression
 releases page](https://github.com/nf-core/alleleexpression
/releases) and find the latest pipeline version (numeric only, no `v`). Then specify this when running the pipeline with `-r` (one hyphen) - e.g. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducibility, you can use share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> 💡 If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> **NB:** These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Conda) - see below.

> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to see if your system is available in these configs please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer enviroment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter or Charliecloud.

### Resuming a workflow

A pipeline might be restarted at any time with the `-resume` flag to continue exactly where it left off. This requires the Nextflow cache to be intact.

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### Custom configuration

#### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

#### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in the pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/usage/configuration#customising-tool-arguments) section of the nf-core website.

#### Custom Containers

In some cases you may wish to change which container or conda environment a step of the pipeline uses for a particular tool. By default nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/usage/configuration#updating-tool-versions) section of the nf-core website.

#### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need similar settings then you can request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Azure Resource Requests

To be used with the `azurebatch` profile by specifying the `-profile azurebatch`.
We recommend providing a compute environment name and queue name as environment variables.

See the list of [Azure instance types and their properties](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes).

The pipeline will auto-detect the following environment variables to determine the appropriate compute environment and queue name:

- `AZURE_COMPUTE_ENV` - Batch compute environment name.
- `AZURE_QUEUE` - Batch queue name.

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
