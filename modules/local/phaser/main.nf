process PHASER {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://zenodo.org/records/15772979/files/phASER.sif?download=1' :
    'docker.io/library/phaser:latest' }"

    input:
    tuple val(meta), path(vcf), path(tbi), path(bam), path(bai)

    output:
    tuple val(meta), path("${meta.id}.phaser_output.haplotypic_counts.txt"), emit: counts
    tuple val(meta), path("${meta.id}.phaser_output.allele_config.txt"), emit: allele_config
    tuple val(meta), path("${meta.id}.phaser_output.variant_connections.txt"), emit: variant_connections
    tuple val(meta), path("${meta.id}.phaser_output.haplotypes.txt"), emit: haplotypes
    path "versions.yml", emit: versions

    script:
    """
    # phASER builds variant lists from Python sets; fix the hash seed so their order is reproducible
    export PYTHONHASHSEED=0

    phaser.py \\
        --vcf $vcf \\
        --bam $bam \\
        --sample ${meta.id} \\
        --mapq 255 \\
        --baseq 10 \\
        --paired_end 1 \\
        --o ${meta.id}.phaser_output \\
        --threads $task.cpus

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        phaser: \$(sed -n 's/^\\s*version = "\\(.*\\)";/\\1/p' /opt/phaser/phaser/phaser.py | head -n1)
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.phaser_output.haplotypic_counts.txt
    touch ${meta.id}.phaser_output.allele_config.txt
    touch ${meta.id}.phaser_output.variant_connections.txt
    touch ${meta.id}.phaser_output.haplotypes.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        phaser: \$(sed -n 's/^\\s*version = "\\(.*\\)";/\\1/p' /opt/phaser/phaser/phaser.py | head -n1)
    END_VERSIONS
    """
}
