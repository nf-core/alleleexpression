process TABIX_INDEX {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::htslib=1.15.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/htslib:1.15.1--h9753748_0' :
        'quay.io/biocontainers/htslib:1.15.1--h9753748_0' }"

    input:
    tuple val(meta ), path(vcf)

    output:
    tuple val(meta), path(vcf), path("*.tbi"), emit: vcf_indexed
    path "versions.yml", emit: versions

    script:
    """
    tabix -p vcf $vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tabix: \$(echo \$(tabix --version 2>&1) | sed 's/^.*tabix (htslib) //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    touch ${vcf}.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tabix: \$(echo \$(tabix --version 2>&1) | sed 's/^.*tabix (htslib) //; s/ .*\$//')
    END_VERSIONS
    """
}
