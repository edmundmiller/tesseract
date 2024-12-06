#!/usr/bin/env nextflow

nextflow.enable.dsl = 2



workflow {
    // TODO Replace with nf-schema
    // load conditions file and split each line into
    // a set of input conditions
    cpu_values = channel.of(4..6)
    memory_values = channel.of(4..6)

    // run pipeline if specified
    trials = Channel.fromList(0..params.run_trials - 1)

    run_pipeline(cpu_values.combine(memory_values), trials)
    trace_files = run_pipeline.out.trace_files.flatMap()

    // Load trace files for the current pipeline from the
    // '_trace' directory and merge with trace files from
    // the run process.
    //
    // Remove duplicate files as trace files from run are
    // saved to the '_trace' directory.
    //
    // Group trace files into a list.
    trace_files = Channel
        .fromPath("_trace/${params.pipeline_name}.*.txt")
        .mix(trace_files)
        .unique { it -> it.name }
        .map { it -> [it.name.split(/\./)[0], it] }
        .groupTuple()

    // run aggregate if specified
    if (params.aggregate == true) {
        aggregate(trace_files)
        datasets = aggregate.out.datasets.flatMap()
    }
    else {
        datasets = Channel.empty()
    }

    // Load dataset files for the current pipeline from the
    // '_datasets' directory and merge with dataset files from
    // the aggregate process.
    //
    // Remove duplicate files as dataset files from aggregate
    // are saved to the '_datasets' directory.
    datasets = Channel
        .fromPath("_datasets/${params.pipeline_name}.*.txt")
        .mix(datasets)
        .unique { it -> it.name }
        .map { it -> [it.name.split(/\./), it] }
        .map { it -> [it[0][0], it[0][1], it[1]] }

    // run train if specified
    train_targets = Channel.fromList(params.train_targets)
    train_merge_args = params.train_merge_args
        .collect { arg -> "--merge ${arg}" }
        .join(" ")

    if (params.train == true) {
        train(datasets, train_targets)
    }

    // create a single resource prediction query from the params
    predict_queries = Channel.value(
        [
            params.pipeline_name,
            params.predict_process,
            params.predict_inputs
        ]
    )

    if (params.predict == true) {
        predict(predict_queries)
    }
}

/**
 * The run_pipeline process performs a single run of a Nextflow
 * pipeline for each set of input conditions. All trace
 * files are saved to the '_trace' directory.
 */
process run_pipeline {
    publishDir "_trace", mode: "copy"
    debug false
    maxForks 1
    tag "cpu: ${cpu} mem: ${mem}"

    input:
    tuple val(cpu), val(mem)
    each trial

    output:
    path ("trace-*.txt"), emit: trace_files

    script:
    """
    nextflow run ${workflow.launchDir}/nfcore.nf \\
        -ansi-log false \\
        -latest \\
        -process.cpus=${cpu} \\
        -process.memory=${mem + '.GB'} \\
        -with-trace \\
        -resume
    """
}

/**
 * The aggregate process combines the input features from
 * execution logs with resource metrics from trace files to
 * produce a performance dataset for each process in the
 * pipeline under test. All performance datasets are saved
 * to the '_datasets' directory.
 */
process aggregate {
    publishDir "_datasets", mode: "copy"
    echo true

    input:
    tuple val(pipeline_name), path(trace_files)

    output:
    path ("${params.pipeline_name}.*.trace.txt"), emit: datasets

    script:
    """
        # initialize environment
        module purge
        module load anaconda3/5.1.0-gcc/8.3.1

        # run aggregate script
        aggregate.py \
            ${trace_files} \
            --pipeline-name ${pipeline_name} \
            --fix-exit-na -1
        """
}



/**
 * The train process creates a prediction model for each
 * resource metric for each performance dataset. All models
 * are saved to the '_models' directory.
 */
process train {
    publishDir "_models", mode: "copy"
    echo true

    input:
    tuple val(pipeline_name), val(process_name), path(dataset)
    each target

    output:
    tuple val(pipeline_name), path("*.json"), path("*.pkl"), emit: models

    when:
    params.train_inputs.containsKey(process_name)

    script:
    """
        # initialize environment
        module purge
        module load anaconda3/5.1.0-gcc/8.3.1

        source activate ${params.conda_env}

        # train model
        export TF_CPP_MIN_LOG_LEVEL="3"

        echo
        echo ${pipeline_name} ${process_name} ${target}
        echo

        train.py \
            ${dataset} \
            --base-dir ${workflow.launchDir}/_datasets \
            ${train_merge_args} \
            --inputs ${params.train_inputs[process_name].join(' ')} \
            --target ${target} \
            --scaler ${params.train_scaler} \
            --model-type ${params.train_model_type} \
            --model-name ${pipeline_name}.${process_name}.${target} \
            ${params.train_intervals == true ? "--intervals" : ""}
        """
}



/**
 * The predict process queries the predicted resource usage
 * of a process from a trained model, if one is available in
 * the '_models' directory.
 */
process predict {
    echo true

    input:
    tuple val(pipeline_name), val(process_name), val(inputs)

    script:
    """
        # initialize environment
        module purge
        module load anaconda3/5.1.0-gcc/8.3.1

        source activate ${params.conda_env}

        # query predicted usage for each resource metric
        export TF_CPP_MIN_LOG_LEVEL="3"

        for TARGET in ${params.predict_targets.join(' ')}; do
            predict.py \
                ${workflow.launchDir}/_models/${pipeline_name}.${process_name}.\${TARGET} \
                ${inputs}
        done
        """
}
