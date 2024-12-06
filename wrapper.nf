#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow {
    // load conditions file and split each line into
    // a set of input conditions
    cpu_values = channel.of(1..6)
    memory_values = channel.of(1..6)

    run_pipeline(cpu_values.combine(memory_values))

}

/**
 * The run_pipeline process performs a single run of a Nextflow
 * pipeline for each set of input conditions. All trace
 * files are saved to the '_trace' directory.
 */
process run_pipeline {
    publishDir "_trace", mode: "copy"
    echo true
    maxForks 1

    input:
    tuple val(cpu), val(mem)
    // each trial

    output:
    path ("trace-*.txt"), emit: trace_files

    script:
    // # create params file from conditions
    // echo "${c.toString().replace('[': '', ']': '', ', ': '\n', ':': ': ')}" > params.yaml
    // # make-params.py params.yaml

    // cd ${workflow.launchDir}/trimgalore
    """
    # run nextflow pipeline
    nextflow run ${workflow.launchDir}/nfcore.nf \\
        -ansi-log false \\
        -latest \\
        -process.cpus=$cpu \\
        -process.memory=${mem + '.GB'} \\
        -with-trace \\
        -resume

    # save trace file
    HASH=`printf %04x%04x \${RANDOM} \${RANDOM}`
    """
    // cp ${params.run_trace_file} ${params.pipeline_name}.trace.\${HASH}.txt
    // # cleanup
    // rm -rf ${params.run_output_dir}
}
