#!/usr/bin/env python3

import argparse
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import sys



def select_rows_by_values(df, column, values):
	return pd.DataFrame().append([df[df[column].astype(str) == v] for v in values], sort=False)



def is_continuous(df, column):
	return column != None and df[column].dtype.kind in "fcmM"



def is_discrete(df, column):
	return column != None and df[column].dtype.kind in "biuOSUV"



def contingency_table(x, y, data, **kwargs):
	# compute indices for categorical variables
	x_values = sorted(list(set(x)))
	y_values = sorted(list(set(y)))
	x_idx = [x_values.index(x_i) for x_i in x]
	y_idx = [y_values.index(y_i) for y_i in y]

	# create contingency table
	ct = pd.DataFrame(
		np.zeros((len(y_values), len(x_values))),
		index=y_values,
		columns=x_values,
		dtype=np.int32)

	for x_i, y_i in zip(x_idx, y_idx):
		ct.iloc[y_i, x_i] += 1

	# plot contingency table
	sns.heatmap(ct, annot=True, fmt="d", cbar=False, square=True, **kwargs)



def rotate_xticklabels(angle):
	for tick in plt.gca().get_xticklabels():
		tick.set_horizontalalignment("right")
		tick.set_rotation(angle)



if __name__ == "__main__":
	# parse command-line arguments
	parser = argparse.ArgumentParser()
	parser.add_argument("input", help="input dataset")
	parser.add_argument("outfile", help="output plot")
	parser.add_argument("--plot-type", help="plot type (automatically determined by default)", choices=["hist", "count", "scatter", "ct", "bar"])
	parser.add_argument("--xaxis", help="column name of x-axis", required=True)
	parser.add_argument("--yaxis", help="column name of y-axis", nargs="?")
	parser.add_argument("--row", help="column name of row-wise category", nargs="?")
	parser.add_argument("--col", help="column name of column-wise category", nargs="?")
	parser.add_argument("--hue", help="column name of hue category", nargs="?")
	parser.add_argument("--select", help="select a set of values from a column", action="append", default=[], metavar="column=value,value,...")
	parser.add_argument("--mapper", help="mappping file of display names for axis columns", nargs="?")
	parser.add_argument("--mapper-term", help="additional display name mapping (overwrites mapping file)", action="append", default=[], metavar="column_name=display_name")
	parser.add_argument("--color", help="color for all barplot elements", nargs="?")
	parser.add_argument("--palette", help="palette for all barplot elements", nargs="?")
	parser.add_argument("--aspect", help="aspect ratio to control figure width", type=float, default=0)
	parser.add_argument("--sharey", help="whether to use uniform y-axis across subplots", action="store_true")

	args = parser.parse_args()

	# load dataframe
	data = pd.read_csv(args.input, sep="\t", na_values="-")

	# prepare axis columns in dataframe
	axes = [
		args.xaxis,
		args.yaxis,
		args.row,
		args.col,
		args.hue
	]

	for column in axes:
		# skip columns which were not specified
		if column == None:
			continue

		# remove rows which have missing values in column
		data = data[~data[column].isna()]

	# apply selects to dataframe
	for select in args.select:
		# parse column and selected values
		column, values = select.split("=")
		values = values.split(",")

		# select rows from dataframe
		if values != None and len(values) > 0:
			data = select_rows_by_values(data, column, values)

	if len(data.index) == 0:
		print("error: no data to visualize")
		sys.exit(-1)

	# apply column name mapper to dataframe
	if args.mapper != None:
		mapper = pd.read_csv(args.mapper, sep="\t")
		mapper = {mapper.loc[i, "column_name"]: mapper.loc[i, "display_name"] for i in mapper.index}
	else:
		mapper = {}

	for mapper_term in args.mapper_term:
		column_name, display_name = mapper_term.split("=")
		mapper[column_name] = display_name

	args.xaxis = mapper[args.xaxis] if args.xaxis in mapper else args.xaxis
	args.yaxis = mapper[args.yaxis] if args.yaxis in mapper else args.yaxis
	args.row = mapper[args.row] if args.row in mapper else args.row
	args.col = mapper[args.col] if args.col in mapper else args.col
	args.hue = mapper[args.hue] if args.hue in mapper else args.hue
	data.rename(columns=mapper, copy=False, inplace=True)

	# sort data by row and col values
	if args.row != None:
		data.sort_values(by=args.row, inplace=True)

	if args.col != None:
		data.sort_values(by=args.col, inplace=True)

	# sort data by y-axis if specified
	if False:
		data.sort_values(by=args.yaxis, inplace=True)

	# apply aspect ratio if specified
	if args.aspect != 0:
		plt.figure(figsize=(5 * args.aspect, 5))

	# create a facet grid for plotting
	g = sns.FacetGrid(
		data,
		row=args.row,
		col=args.col,
		sharey=args.sharey,
		margin_titles=True)

	# determine plot type if not specified
	if args.plot_type == None:
		# if x is continuous, use histogram
		if is_continuous(data, args.xaxis) and args.yaxis == None:
			args.plot_type = "hist"

		# if x is discrete, use count plot
		elif is_discrete(data, args.xaxis) and args.yaxis == None:
			args.plot_type = "count"

		# if x and y are continuous, use scatter plot
		elif is_continuous(data, args.xaxis) and is_continuous(data, args.yaxis):
			args.plot_type = "scatter"

		# if x and y are discrete, use contingency table
		elif is_discrete(data, args.xaxis) and is_discrete(data, args.yaxis):
			args.plot_type = "ct"

		# if x is discrete and y is continuous, use bar plot
		elif is_discrete(data, args.xaxis) and is_continuous(data, args.yaxis):
			args.plot_type = "bar"

		# otherwise throw an error
		else:
			print("error: could not find a plotting method for the given axes")
			sys.exit(-1)

	# create plot
	if args.plot_type == "hist":
		g.map(
			sns.distplot,
			args.xaxis,
			color=args.color,
			norm_hist=False)

	elif args.plot_type == "count":
		g.map(
			sns.countplot,
			args.xaxis,
			hue=args.hue,
			color=args.color,
			palette=args.palette)

	elif args.plot_type == "scatter":
		g = g.map(
			sns.scatterplot,
			args.xaxis,
			args.yaxis,
			hue=args.hue,
			data=data,
			color=args.color)

		if args.hue != None:
			g.add_legend()

	elif args.plot_type == "ct":
		g = g.map(
			contingency_table,
			args.xaxis,
			args.yaxis,
			data=data,
			color=args.color)

	elif args.plot_type == "bar":
		x_values = sorted(list(set(data[args.xaxis])))
		g = g.map(
			sns.barplot,
			args.xaxis,
			args.yaxis,
			hue=args.hue,
			data=data,
			ci=68,
			color=args.color,
			palette=args.palette) #,
			# order=x_values)

		if args.hue != None:
			g.add_legend()

	# rotate x-axis ticks if specified
	if False:
		rotate_xticklabels(45)

	# disable x-axis ticks if there are too many categories
	if len(set(data[args.xaxis])) >= 100:
		plt.xticks([])

	# save output figure
	plt.savefig(args.outfile)
	plt.close()
