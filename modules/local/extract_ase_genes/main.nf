process EXTRACT_ASE_GENES {
    tag "$meta.id"
    label 'process_low'

    // Same image as PHASER_GENE_AE: python3 + scipy
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://zenodo.org/records/15772979/files/phASER.sif?download=1' :
    'docker.io/library/phaser:latest' }"

    input:
    tuple val(meta), path(ae_file)

    output:
    tuple val(meta), path("${prefix}.ASE.tsv")      , emit: ase_genes
    tuple val(meta), path("${prefix}.ase_stats.tsv"), emit: stats
    path "versions.yml"                              , emit: versions

    script:
    prefix = task.ext.prefix ?: "${meta.id}.${params.chromosome}"
    def overdispersion = params.ase_overdispersion != null ? "--overdispersion ${params.ase_overdispersion}" : ''
    """
    extract_ase_genes.py \\
        --input $ae_file \\
        --test ${params.ase_test} \\
        --min-count ${params.ase_min_count} \\
        --fdr ${params.ase_fdr} \\
        --min-effect ${params.ase_min_effect} \\
        --trim ${params.ase_overdispersion_trim} \\
        $overdispersion \\
        --out-all ${prefix}.ase_stats.tsv \\
        --out-ase ${prefix}.ASE.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
        scipy: \$(python3 -c 'import scipy; print(scipy.__version__)')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}.${params.chromosome}"
    """
    touch ${prefix}.ASE.tsv ${prefix}.ase_stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: 3
        scipy: 1
    END_VERSIONS
    """
}
