# tesseract

Tesseract is an intelligent resource prediction tool for scientific applications and workflows. It provides a generic and user-friendly way to predict resource usage from historical performance data. Tesseract is used primarily to predict resource usage of scientific workflows for the purpose of resource provisioning, but it can also be used to collect and analyze performance data for whatever purpose, such as identifying execution anomalies or predicting failures.

This repository contains the code for Tesseract as well as some additional scripts that were used to generate performance data for a number of scientific workflows:
- [GEMmaker](https://github.com/SystemsGenetics/GEMmaker)
- [gene-oracle](https://github.com/SystemsGenetics/gene-oracle)
- [HemeLB](https://github.com/Clemson-MSE/hemelb-gpu)
- [KINC-nf](https://github.com/SystemsGenetics/KINC-nf)
- [TSPG](https://github.com/ctargon/TSPG)

_Note: Not to be confused with the [Tesseract OCR Engine](https://github.com/tesseract-ocr)._

## Installation

Tesseract is a collection of Python scripts, so you will need a Python or Anaconda environment that provides the packages listed in `requirements.txt`. Additionally, Tesseract is intended to work with [Nextflow](https://www.nextflow.io/) pipelines, so you will need to install Nextflow as well.

## Offline Usage

### Select an Application

Tesseract can be applied to any application or Nextflow workflow. Individual applications can be easily wrapped into a Nextflow pipeline, refer to the HemeLB pipeline in this repository. Workflows based on a different workflow manager must be converted into a Nextflow pipeline, which should also not be difficult as Nextflow is highly generic and easy to use. Tesseract relies on Nextflow's trace feature, which automatically collects a performance trace of every process that is executed. Again, refer to the example pipelines in this repository. In particular, the `trace` section in any of the example config files shows how to enable this feature.

### Define Input Features

Once you have your application in a Nextflow pipeline, you must annotate each process statement by adding "trace" directives to the process script. These directives will specify the input features of the execution, which will be parsed by Tesseract and supplied as the input features of your performance dataset. You can specify whatever features you like, and each process can have different features, as Tesseract will create separate prediction models for each process.

Here are some trace directives that might be used for the KINC example pipeline:
```bash
echo "#TRACE dataset=${dataset}"
echo "#TRACE n_rows=`tail -n +1 ${emx_txt_file} | wc -l`"
echo "#TRACE n_cols=`head -n +1 ${emx_txt_file} | wc -w`"
echo "#TRACE hardware_type=${c.hardware_type}"
echo "#TRACE np=${c.np}"
```

In this example, `dataset`, `hardware_type`, and `np` are Nextflow variables supplied by input channels. On the other hand, `emx_txt_file` is a tab-delimited text file, also supplied by an input channel, but the dimensions of this dataset must be computed by the script itself. All of these directives will be printed to the execution log. After the workflow completes, Tesseract will parse the execution logs to obtain these input features for each executed task.

The variables in this example have been determined to be the most relevant input features for KINC. You will have to make a similar selection for each process in your pipeline. It is better to be inclusive rather than exclusive at this stage; you can include as many features as you want and you can always remove them from your dataset later, but to add a new feature after the fact you will have to redo all of your application runs.

Keep in mind that trace directives should be fast and easy to compute, otherwise they may affect the execution trace.

### Collect Performance Data

Once you have an annotated Nextflow pipeline, you just need to run it many times to generate plenty of performance data. There are multiple ways to do this; you can do a parameter sweep like the examples in this repo, or you can simply use it in your normal work and allow the performance data to accumulate. Tesseract provides a Nextflow "meta-pipeline" to run a Nextflow pipeline several times in order to generate performance data quickly. For example, to generate performance data for the KINC pipeline:
```bash
# provide input data for kinc
mkdir kinc/input
# ...

# generate conditions file
kinc/bin/make-conditions.sh

# run meta-pipeline
nextflow run main.nf -params-file kinc/params.json
```

In any case, each workflow run will create a performance trace called `trace.txt`. You must collect these trace files into one location and aggregate them into a performance dataset:
```bash
python bin/aggregate.py <trace-files>
```

This script will concatenate the trace files, obtain the input features for each individual run, and output a performance dataset for each process in your pipeline. These datasets can then be used for normal data science tasks such as visualization and training models.

_Note_: Tesseract parses the `#TRACE` directives from the execution logs, which are located in Nextflow's work directory tree. If you delete this work directory, or if it gets automatically deleted by some data retention policy, the input features for your application runs will be lost. So make sure to aggregate your performance data in a timely fashion!

### Visualization

The `visualize.py` script provides a simple but powerful interface for creating many kinds of visualizations from a dataframe. You can visualize one or two variables, and you can disaggregate across up to three dimensions. The script supports both discrete and continuous variables, and it will by default select the most appropriate type of plot for the variables that you specify. Refer to the example pipelines for example uses of this script.

### Train Prediction Models

Use the `train.py` script to train prediction models on your performance dataset. You can use any columns as inputs or outputs, you can specify transforms such as one-hot encoding and log2, and you can pick from a variety of machine learning models. The multi-layer perceptron (MLP) with default settings is a good start. This script will save your trained model to a file so that you can use it later for inference. Refer to the example pipelines to see how this script is used.

### Deploy Prediction Models

Use the `predict.py` script to make predictions on new input data. Refer to the example pipelines to see how this script is used.

## Online Usage

Tesseract is integrated into [Nextflow-API](https://github.com/SciDAS/nextflow-api), a workflow-as-a-service that allows you to run Nextflow pipelines through a browser interface atop any execution environment. Nextflow-API automatically collects execution traces, including any custom trace directives, and provides interfaces for visualizing performance data, training models, and downloading the raw data for manual analysis. Refer to the Nextflow-API repo for more information on these features.