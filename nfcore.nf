include { TRIMGALORE } from './modules/nf-core/trimgalore/main'
params.modules_testdata_base_path = 'https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/'
params.condition_cpu = null
params.condition_memory = null

workflow {
    input = [
        [id: 'test', single_end: true],
        [file(params.modules_testdata_base_path + "genomics/sarscov2/illumina/fastq/test_1.fastq.gz", checkIfExists: true)]
    ]

    TRIMGALORE(input)
}
