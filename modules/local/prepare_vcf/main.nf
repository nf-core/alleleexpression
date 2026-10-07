process PREPARE_VCF {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::bcftools=1.15.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.15.1--h0ea216a_0' :
        'quay.io/biocontainers/bcftools:1.15.1--h0ea216a_0' }"

    input:
    tuple val(meta), path(reads), path(vcf)
    val chromosome

    output:
    tuple val(meta), path("${meta.id}.GTonly.vcf"), emit: vcf_star
    tuple val(meta), path("${meta.id}.filtered.vcf.gz"), path("${meta.id}.filtered.vcf.gz.tbi"), emit: vcf_beagle
    path "versions.yml", emit: versions

    script:
    """
    # Create index if it doesn't exist
    if [ ! -f "${vcf}.tbi" ]; then
    tabix -p vcf "$vcf"
    fi
    # Create GT-only uncompressed VCF for STAR
    bcftools view -f PASS "$vcf" | bcftools annotate -x INFO,^FORMAT/GT -Ov -o "${meta.id}.GTonly.vcf"

    # Create PASS-filtered compressed and indexed VCF for Beagle
    bcftools view -r $chromosome -f PASS -Oz -o "${meta.id}.filtered.vcf.gz" "$vcf"
    tabix -p vcf "${meta.id}.filtered.vcf.gz"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
        tabix: \$(tabix --version 2>&1 | head -n1 | sed 's/^.*(htslib) //')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.GTonly.vcf
    echo "" | gzip > ${meta.id}.filtered.vcf.gz
    touch ${meta.id}.filtered.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
        tabix: \$(tabix --version 2>&1 | head -n1 | sed 's/^.*(htslib) //')
    END_VERSIONS
    """
}
