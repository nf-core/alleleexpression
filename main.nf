#!/usr/bin/env nextflow

/*
========================================================================================
    Alleleexpression
========================================================================================
    Github : https://github.com/nf-core/alleleexpression
    Author : Abu Saadat
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    IMPORT WORKFLOWS
========================================================================================
*/

include { alleleexpression } from './workflows/alleleexpression'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow {
    // Print parameter summary
    log.info "alleleexpression pipeline parameters:"
    params.each { k, v -> log.info "  --${k}=${v}" }

    // Check input parameters
    if (!params.input) {
        error 'Input samplesheet not specified!'
    }
    
    def ch_input = file(params.input)

    // Create config channels
    def ch_multiqc_config = params.multiqc_config ? 
        channel.fromPath(params.multiqc_config) : 
        channel.fromPath("${projectDir}/assets/multiqc_config.yml", checkIfExists: true)
    
    def ch_multiqc_custom_config = params.multiqc_config ? 
        channel.fromPath(params.multiqc_config) : 
        channel.empty()

    // Run main workflow
    alleleexpression (
        ch_input,
        ch_multiqc_config,
        ch_multiqc_custom_config
    )
}

/*
========================================================================================
    THE END
========================================================================================
*/
