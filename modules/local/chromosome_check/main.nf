process CHROMOSOME_CHECK {
    tag "chromosome_check"
    label 'process_low'

    conda "bioconda::bcftools=1.15.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.15.1--h0ea216a_0' :
        'quay.io/biocontainers/bcftools:1.15.1--h0ea216a_0' }"

    input:
    tuple val(meta), path(vcf)
    path beagle_ref
    path beagle_map
    val chromosome

    output:
    path "chromosome_check.log", emit: log
    path "versions.yml", emit: versions

    script:
    """
    # Check chromosome naming in VCF
    VCF_CHR=\$(bcftools view -h $vcf | grep -v "^##" | head -n1 | cut -f1)
    
    # Check chromosome naming in Beagle reference
    BEAGLE_CHR=\$(bcftools view -h $beagle_ref | grep -v "^##" | head -n1 | cut -f1)
    
    # Check chromosome naming in Beagle map (if available)
    if [[ -f "$beagle_map" ]]; then
        MAP_CHR=\$(head -n1 $beagle_map | awk '{print \$1}')
    else
        MAP_CHR=\$BEAGLE_CHR
    fi
    
    # Check if chromosome parameter matches VCF
    echo "Checking chromosome naming consistency..." > chromosome_check.log
    echo "User-specified chromosome: $chromosome" >> chromosome_check.log
    echo "VCF chromosome format: \$VCF_CHR" >> chromosome_check.log
    echo "Beagle reference chromosome format: \$BEAGLE_CHR" >> chromosome_check.log
    echo "Beagle map chromosome format: \$MAP_CHR" >> chromosome_check.log
    
    # Check for discrepancies
    if [[ "\$VCF_CHR" != "\$BEAGLE_CHR" ]]; then
        echo "WARNING: Chromosome naming differs between VCF (\$VCF_CHR) and Beagle reference (\$BEAGLE_CHR)" >> chromosome_check.log
        echo "This may cause issues with phasing. Please ensure consistent chromosome naming." >> chromosome_check.log
    fi
    
    if [[ "\$VCF_CHR" != "\$MAP_CHR" ]]; then
        echo "WARNING: Chromosome naming differs between VCF (\$VCF_CHR) and Beagle map (\$MAP_CHR)" >> chromosome_check.log
        echo "This may cause issues with phasing. Please ensure consistent chromosome naming." >> chromosome_check.log
    fi
    
    # Check if user-specified chromosome exists in VCF
    if ! bcftools view -h $vcf | grep -q "contig=<ID=$chromosome"; then
        echo "ERROR: User-specified chromosome '$chromosome' not found in VCF" >> chromosome_check.log
        echo "Available chromosomes in VCF:" >> chromosome_check.log
        bcftools view -h $vcf | grep "contig=<ID=" | sed 's/.*ID=//; s/,.*\$//' >> chromosome_check.log
        exit 1
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}
