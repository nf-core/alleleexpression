process PHASER_GENE_AE {
    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://zenodo.org/records/15772979/files/phASER.sif?download=1' :
    'docker.io/library/phaser:latest' }"

    input:
    tuple val(meta), path(counts)
    path gene_features

    output:
    tuple val(meta), path("${meta.id}_gene_ae.tsv"), emit: ae
    path "versions.yml", emit: versions

    script:
    """
    # phASER builds variant lists from Python sets; fix the hash seed so their order is reproducible
    export PYTHONHASHSEED=0

    phaser_gene_ae.py \\
        --haplotypic_counts $counts \\
        --features $gene_features \\
        --o ${meta.id}_gene_ae.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        phaser_gene_ae: \$(sed -n 's/^\\s*version = "\\(.*\\)";/\\1/p' /opt/phaser/phaser/phaser.py | head -n1)
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_gene_ae.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        phaser_gene_ae: \$(sed -n 's/^\\s*version = "\\(.*\\)";/\\1/p' /opt/phaser/phaser/phaser.py | head -n1)
    END_VERSIONS
    """
}
