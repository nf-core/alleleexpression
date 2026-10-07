process BEAGLE5_BEAGLE {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/beagle:5.2_21Apr21.304--hdfd78af_0':
        'biocontainers/beagle:5.2_21Apr21.304--hdfd78af_0' }"

    input:
    tuple val(meta ), path(vcf), path(tbi)
    path refpanel
    path genmap

    output:
    tuple val(meta), path("*.vcf.gz"), emit: vcf  // Only output the VCF file
    path "versions.yml", emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}_beagle"
    def refpanel_cmd = refpanel.name != 'NO_FILE' ? "${refpanel}" : ""
    def genmap_cmd = genmap.name != 'NO_FILE' ? "${genmap}" : ""
    """
    beagle \\
        gt=${vcf} \\
        out=${prefix} \\
        ref=${refpanel_cmd} \\
        map=${genmap_cmd} \\
        nthreads=2

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        beagle: \$(beagle 2>&1 | head -n 1 | sed -n 's/.*version \\([0-9.]*\\).*/\\1/p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}_beagle"
    """
    echo "" | gzip > ${prefix}.vcf.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        beagle: \$(beagle 2>&1 | head -n 1 | sed -n 's/.*version \\([0-9.]*\\).*/\\1/p')
    END_VERSIONS
    """
}
