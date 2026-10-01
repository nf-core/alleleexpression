#!/usr/bin/env python3
"""
Call allele-specific expression from phaser_gene_ae output.

Each gene with at least --min-count haplotypic reads is tested with a two-sided
binomial test of aCount vs bCount against p = 0.5. P-values are corrected across
tested genes with Benjamini-Hochberg. Writes all genes with statistics, and the
subset with FDR < --fdr.
"""

import argparse
import csv
import math

from scipy.stats import binomtest


def bh_adjust(pvals):
    n = len(pvals)
    order = sorted(range(n), key=lambda i: pvals[i])
    adjusted = [1.0] * n
    running_min = 1.0
    for rank in range(n, 0, -1):
        i = order[rank - 1]
        running_min = min(running_min, pvals[i] * n / rank)
        adjusted[i] = running_min
    return adjusted


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input", required=True, help="phaser_gene_ae output (TSV with aCount, bCount)")
    p.add_argument("--min-count", type=int, default=20, help="Minimum aCount + bCount to test a gene")
    p.add_argument("--fdr", type=float, default=0.05, help="FDR threshold for calling ASE")
    p.add_argument("--out-all", required=True, help="All genes with test statistics")
    p.add_argument("--out-ase", required=True, help="Genes called as ASE")
    args = p.parse_args()

    with open(args.input) as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        fields = reader.fieldnames
        rows = list(reader)

    tested = []
    for row in rows:
        a, b = int(row["aCount"]), int(row["bCount"])
        n = a + b
        row["major_allele_fraction"] = f"{max(a, b) / n:.4f}" if n else "NA"
        row["pvalue"], row["padj"], row["ase"] = "NA", "NA", "0"
        if n >= args.min_count:
            row["pvalue"] = binomtest(a, n, 0.5).pvalue
            tested.append(row)

    for row, q in zip(tested, bh_adjust([r["pvalue"] for r in tested])):
        row["padj"] = q
        row["ase"] = "1" if q < args.fdr else "0"

    out_fields = fields + ["major_allele_fraction", "pvalue", "padj", "ase"]

    def fmt(v):
        return f"{v:.4g}" if isinstance(v, float) and not math.isnan(v) else v

    for path, subset in ((args.out_all, rows), (args.out_ase, [r for r in rows if r["ase"] == "1"])):
        with open(path, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=out_fields, delimiter="\t", lineterminator="\n")
            w.writeheader()
            for row in subset:
                w.writerow({k: fmt(row[k]) for k in out_fields})

    n_ase = sum(r["ase"] == "1" for r in rows)
    print(f"{len(rows)} genes, {len(tested)} tested (>= {args.min_count} reads), {n_ase} ASE at FDR < {args.fdr}")


if __name__ == "__main__":
    main()
