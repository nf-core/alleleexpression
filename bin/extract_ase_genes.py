#!/usr/bin/env python3
"""
Call allele-specific expression from phaser_gene_ae output.

Each gene with at least --min-count haplotypic reads (aCount + bCount) is tested
against a balanced 0.5 allelic ratio with a two-sided test:

  binomial      exact binomial test. Assumes counts vary only by sampling, so it
                over-calls genes when there is extra-binomial (technical or
                biological) variation.
  betabinomial  beta-binomial test with mean 0.5 and overdispersion rho. rho is
                estimated by trimmed maximum likelihood: fit rho, keep the
                (1 - --trim) fraction of tested genes that fit best (largest
                p-values), refit, and repeat until the kept set is stable. This
                stops truly imbalanced genes from inflating rho. Alternatively,
                fix rho with --overdispersion.

P-values are corrected with Benjamini-Hochberg across tested genes. A gene is
called ASE if padj < --fdr and |major_allele_fraction - 0.5| >= --min-effect.
"""

import argparse
import csv
import math
import sys

from scipy.optimize import minimize_scalar
from scipy.stats import betabinom, binomtest

RHO_BOUNDS = (1e-6, 0.5)
RHO_START = 0.01
MAX_TRIM_ITERATIONS = 50
# Below this many tested genes the rho estimate is unreliable
MIN_GENES_FOR_RHO = 50


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


def betabinom_shape(rho):
    """alpha = beta for a beta-binomial with mean 0.5 and intra-class correlation rho."""
    return (1.0 - rho) / rho / 2.0


def betabinom_pvalue(a, n, rho):
    # Symmetric around n/2, so the two-sided p-value is twice the smaller tail
    shape = betabinom_shape(rho)
    return min(1.0, 2.0 * betabinom.cdf(min(a, n - a), n, shape, shape))


def mle_overdispersion(counts):
    """MLE of rho for beta-binomial(mean 0.5) over (a, n) pairs."""

    def nll(log_rho):
        shape = betabinom_shape(math.exp(log_rho))
        return -sum(betabinom.logpmf(a, n, shape, shape) for a, n in counts)

    res = minimize_scalar(nll, bounds=(math.log(RHO_BOUNDS[0]), math.log(RHO_BOUNDS[1])), method="bounded")
    return math.exp(res.x)


def fit_overdispersion(counts, trim):
    """
    Trimmed MLE of rho: refit on the best-fitting (1 - trim) fraction of genes until
    that set stops changing. Returns (rho, number of genes used, iterations).
    """
    if not counts:
        return RHO_BOUNDS[0], 0, 0
    n_keep = max(1, int(round(len(counts) * (1 - trim))))
    rho, kept = RHO_START, None
    for iteration in range(1, MAX_TRIM_ITERATIONS + 1):
        pvals = [betabinom_pvalue(a, n, rho) for a, n in counts]
        new_kept = set(sorted(range(len(counts)), key=lambda i: -pvals[i])[:n_keep])
        if new_kept == kept:
            break
        kept = new_kept
        rho = mle_overdispersion([counts[i] for i in kept])
    return rho, n_keep, iteration


def call(rows, pvalue_fn, fdr, min_effect):
    pvals = [pvalue_fn(r["_a"], r["_n"]) for r in rows]
    padj = bh_adjust(pvals)
    for r, p, q in zip(rows, pvals, padj):
        r["pvalue"], r["padj"] = p, q
        r["ase"] = "1" if (q < fdr and r["_effect"] >= min_effect) else "0"


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--input", required=True, help="phaser_gene_ae output (TSV with aCount, bCount)")
    p.add_argument("--test", choices=["binomial", "betabinomial"], default="binomial")
    p.add_argument("--min-count", type=int, default=20, help="Minimum aCount + bCount to test a gene")
    p.add_argument("--fdr", type=float, default=0.05, help="FDR threshold for calling ASE")
    p.add_argument("--min-effect", type=float, default=0.0,
                   help="Minimum |major_allele_fraction - 0.5| to call ASE (0.1 = at least 60:40)")
    p.add_argument("--overdispersion", type=float, default=None,
                   help="Fixed beta-binomial overdispersion rho in (0, 1); estimated if omitted")
    p.add_argument("--trim", type=float, default=0.2,
                   help="Fraction of tested genes left out when estimating rho (expected max share of ASE genes)")
    p.add_argument("--out-all", required=True, help="All genes with test statistics")
    p.add_argument("--out-ase", required=True, help="Genes called as ASE")
    args = p.parse_args()

    if not 0.0 <= args.min_effect < 0.5:
        p.error("--min-effect must be in [0, 0.5)")
    if args.overdispersion is not None and not 0.0 < args.overdispersion < 1.0:
        p.error("--overdispersion must be in (0, 1)")
    if not 0.0 <= args.trim < 1.0:
        p.error("--trim must be in [0, 1)")

    with open(args.input) as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        fields = reader.fieldnames
        rows = list(reader)

    tested = []
    for row in rows:
        a, b = int(row["aCount"]), int(row["bCount"])
        n = a + b
        row["_a"], row["_n"] = a, n
        row["_effect"] = abs(a / n - 0.5) if n else 0.0
        row["major_allele_fraction"] = f"{max(a, b) / n:.4f}" if n else "NA"
        row["pvalue"], row["padj"], row["ase"] = "NA", "NA", "0"
        if n >= args.min_count:
            tested.append(row)

    rho_note = ""
    if args.test == "binomial":
        call(tested, lambda a, n: binomtest(a, n, 0.5).pvalue, args.fdr, args.min_effect)
    elif args.overdispersion is not None:
        rho = args.overdispersion
        call(tested, lambda a, n: betabinom_pvalue(a, n, rho), args.fdr, args.min_effect)
        rho_note = f", rho = {rho:.4g} (fixed)"
    else:
        rho, n_used, iterations = fit_overdispersion([(r["_a"], r["_n"]) for r in tested], args.trim)
        if len(tested) < MIN_GENES_FOR_RHO:
            print(f"WARNING: only {len(tested)} genes tested; the overdispersion estimate is unreliable "
                  f"below {MIN_GENES_FOR_RHO}. Consider setting it with --overdispersion.", file=sys.stderr)
        call(tested, lambda a, n: betabinom_pvalue(a, n, rho), args.fdr, args.min_effect)
        rho_note = f", rho = {rho:.4g} (estimated from {n_used} genes, {iterations} iteration(s))"

    out_fields = fields + ["major_allele_fraction", "pvalue", "padj", "ase"]

    def fmt(v):
        return f"{v:.4g}" if isinstance(v, float) else v

    for path, subset in ((args.out_all, rows), (args.out_ase, [r for r in rows if r["ase"] == "1"])):
        with open(path, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=out_fields, delimiter="\t", lineterminator="\n", extrasaction="ignore")
            w.writeheader()
            for row in subset:
                w.writerow({k: fmt(row[k]) for k in out_fields})

    n_ase = sum(r["ase"] == "1" for r in rows)
    print(f"{args.test} test{rho_note}: {len(rows)} genes, {len(tested)} tested (>= {args.min_count} reads), "
          f"{n_ase} ASE at FDR < {args.fdr} and effect >= {args.min_effect}")


if __name__ == "__main__":
    main()
