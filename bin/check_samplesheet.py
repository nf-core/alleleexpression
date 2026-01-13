#!/usr/bin/env python

"""Provide a command line tool to validate and transform tabular samplesheets."""

import argparse
import csv
import logging
import sys
from collections import Counter
from pathlib import Path

logger = logging.getLogger()


def parse_args(args=None):
    """Parse command line arguments."""
    Description = "Reformat nf-core/alleleexpression samplesheet file and check its contents."
    Epilog = "Example usage: python check_samplesheet.py <FILE_IN> <FILE_OUT>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("FILE_IN", help="Input samplesheet file.")
    parser.add_argument("FILE_OUT", help="Output file.")

    return parser.parse_args(args)


def check_samplesheet(file_in, file_out):
    """Check samplesheet and write to output."""
    required_columns = ["sample", "fastq_1", "fastq_2", "vcf"]

    sample_mapping_dict = {}
    with open(file_in, "r") as fin:
        reader = csv.DictReader(fin)

        # Check header
        if not all(col in reader.fieldnames for col in required_columns):
            print(f"ERROR: Missing required columns. Expected: {required_columns}")
            sys.exit(1)

        for i, row in enumerate(reader):
            sample = row["sample"]
            if sample in sample_mapping_dict:
                print(f"ERROR: Sample {sample} appears multiple times!")
                sys.exit(1)

            for col in required_columns:
                if not row[col]:
                    print(f"ERROR: Missing value for {col} in row {i+1}")
                    sys.exit(1)

            # Check if files exist
            for col in ["fastq_1", "fastq_2", "vcf"]:
                if not Path(row[col]).exists():
                    print(f"WARNING: File does not exist: {row[col]}")

            sample_mapping_dict[sample] = [row]

    # Write validated samplesheet
    with open(file_out, "w") as fout:
        writer = csv.DictWriter(fout, fieldnames=required_columns)
        writer.writeheader()
        for sample in sample_mapping_dict:
            for row in sample_mapping_dict[sample]:
                writer.writerow(row)


def main(args=None):
    args = parse_args(args)
    check_samplesheet(args.FILE_IN, args.FILE_OUT)


if __name__ == "__main__":
    sys.exit(main())
