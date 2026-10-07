process BCFTOOLS_VIEW {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::bcftools=1.15.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.15.1--h0ea216a_0' :
        'quay.io/biocontainers/bcftools:1.15.1--h0ea216a_0' }"

    input:
    tuple val(meta ), path(vcf), path(tbi)
    val chromosome

    output:
    tuple val(meta), path("*.vcf.gz"), path("*.vcf.gz.tbi"), emit: vcf
    path "versions.yml", emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    bcftools view \\
        --output ${prefix}.vcf.gz \\
        -r $chromosome \\
        -f PASS -Oz \\
        --threads $task.cpus \\
        $vcf

    tabix -p vcf ${prefix}.vcf.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
        tabix: \$(tabix --version 2>&1 | head -n1 | sed 's/^.*(htslib) //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.vcf.gz
    touch ${prefix}.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
        tabix: \$(tabix --version 2>&1 | head -n1 | sed 's/^.*(htslib) //')
    END_VERSIONS
    """
}
