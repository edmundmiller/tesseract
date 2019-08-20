#!/usr/bin/env nextflow



/**
 * Create channel for input files.
 */
TRACE_FILES = Channel.fromPath("${params.input.dir}/${params.input.trace_files}").collect()
NVPROF_FILES = Channel.fromPath("${params.input.dir}/${params.input.nvprof_files}").collect()



/**
 * The aggregate process takes performance logs from previous pipeline
 * runs and aggregates them into a single dataframe.
 */
process aggregate {
	publishDir "${params.output.dir}"

	input:
		file(trace_files) from TRACE_FILES
		file(nvprof_files) from NVPROF_FILES

	output:
		set file("db.trace.txt"), file("db.nvprof.txt") into DATASETS

	when:
		params.aggregate.enabled == true

	script:
		"""
		for f in ${nvprof_files}; do
			grep -v "==" \$f > temp; mv temp \$f
		done

		aggregate.py \
			--trace-input ${trace_files} \
			--trace-output db.trace.txt \
			--nvprof-input ${nvprof_files} \
			--nvprof-output db.nvprof.txt \
			--nvprof-mapper ${params.aggregate.nvprof_mapper}
		"""
}



/**
 * The visualize process takes dataset files and visualizes them.
 */
process visualize {
	publishDir "${params.output.dir}"

	input:
		set file(trace_file), file(nvprof_file) from DATASETS
		val(plot) from Channel.from(params.visualize.plots)

	output:
		file("*.${params.visualize.format}")

	when:
		params.visualize.enabled == true

	script:
		"""
		visualize.py \
			${nvprof_file} \
			${plot.xaxis}.${plot.yaxis}.${params.visualize.format} \
			--xaxis ${plot.xaxis} \
			--xaxis-values ${plot.xaxis_values.join(' ')} \
			--yaxis ${plot.yaxis} \
			--yaxis-values ${plot.yaxis_values.join(' ')} \
			--hue1 ${plot.hue1} \
			--hue1-values ${plot.hue1_values.join(' ')} \
			--hue2 ${plot.hue2} \
			--hue2-values ${plot.hue2_values.join(' ')}
		"""
}
