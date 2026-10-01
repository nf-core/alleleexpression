#!/usr/bin/env python3
"""
Compare pipeline gene-level ASE (phaser_gene_ae output) against the simulation truth.

Haplotype labels from Beagle/phASER are arbitrary per gene, so allelic ratios are
compared folded: major-haplotype fraction = max(a, b) / (a + b).

Usage:
    evaluate_ase.py --truth tests/data/ase_sim/truth/NA12878.truth_genes.tsv \
                    --gene-ae results/phaser_gene_ae/NA12878_gene_ae.tsv \
                    [--ase-calls results/ase/NA12878.chr11.ASE.tsv]
"""

import argparse
import csv
import math


def binom_two_sided(k, n, p=0.5):
    """Exact two-sided binomial test p-value (sum of outcomes no more likely than k)."""
    if n == 0:
        return 1.0
    logpmf = [math.lgamma(n + 1) - math.lgamma(i + 1) - math.lgamma(n - i + 1)
              + i * math.log(p) + (n - i) * math.log(1 - p) for i in range(n + 1)]
    ref = logpmf[k] + 1e-7
    return min(1.0, sum(math.exp(lp) for lp in logpmf if lp <= ref))


def read_tsv(path):
    with open(path) as fh:
        return list(csv.DictReader(fh, delimiter="\t"))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--truth", required=True)
    p.add_argument("--gene-ae", required=True)
    p.add_argument("--ase-calls", help="Pipeline's ASE gene list (EXTRACT_ASE_GENES output)")
    p.add_argument("--min-count", type=int, default=20, help="Min haplotypic reads to test a gene")
    p.add_argument("--alpha", type=float, default=0.05, help="Bonferroni-corrected significance level")
    args = p.parse_args()

    truth = {r["gene_id"]: r for r in read_tsv(args.truth)}
    obs = {r["name"]: r for r in read_tsv(args.gene_ae)}
    called = {r["name"] for r in read_tsv(args.ase_calls)} if args.ase_calls else None

    rows = []
    for gid, t in truth.items():
        o = obs.get(gid)
        a = int(o["aCount"]) if o else 0
        b = int(o["bCount"]) if o else 0
        n = a + b
        true_major = max(float(t["true_hap1_fraction"]), 1 - float(t["true_hap1_fraction"]))
        rows.append(dict(gene_id=gid, gene_name=t["gene_name"], het=int(t["n_exonic_het_snps"]),
                         truth_ase=int(t["ase"]), true_major=true_major, a=a, b=b, n=n,
                         obs_major=(max(a, b) / n) if n else float("nan"),
                         pval=binom_two_sided(min(a, b), n) if n else 1.0,
                         called=(gid in called) if called is not None else None))

    tested = [r for r in rows if r["n"] >= args.min_count]
    threshold = args.alpha / max(1, len(tested))
    for r in rows:
        r["sig"] = r["n"] >= args.min_count and r["pval"] < threshold

    hdr = f"{'gene':<18}{'het':>4}{'truth':>6}{'true_maj':>9}{'aCount':>8}{'bCount':>8}{'obs_maj':>8}{'p':>10}{'sig':>5}"
    if called is not None:
        hdr += f"{'called':>7}"
    print(hdr)
    for r in sorted(rows, key=lambda r: (-r["truth_ase"], r["gene_name"])):
        line = (f"{r['gene_name'][:17]:<18}{r['het']:>4}{r['truth_ase']:>6}{r['true_major']:>9.2f}"
                f"{r['a']:>8}{r['b']:>8}{r['obs_major']:>8.2f}{r['pval']:>10.1e}{'*' if r['sig'] else '':>5}")
        if called is not None:
            line += f"{'*' if r['called'] else '':>7}"
        print(line)

    def summarise(label, predicted):
        tp = sum(1 for r in rows if r["truth_ase"] and predicted(r))
        fp = sum(1 for r in rows if not r["truth_ase"] and predicted(r))
        fn = sum(1 for r in rows if r["truth_ase"] and not predicted(r))
        tn = sum(1 for r in rows if not r["truth_ase"] and not predicted(r))
        print(f"{label:<42} TP={tp:<3} FP={fp:<3} FN={fn:<3} TN={tn:<3}")

    print()
    print(f"Genes in truth: {len(rows)}; with >= {args.min_count} haplotypic reads: {len(tested)}; "
          f"Bonferroni threshold p < {threshold:.1e}")
    summarise("Binomial test on phaser_gene_ae counts:", lambda r: r["sig"])
    if called is not None:
        summarise("Pipeline ASE calls (EXTRACT_ASE_GENES):", lambda r: r["called"])

    het_with_reads = [r for r in rows if r["n"] >= args.min_count]
    if het_with_reads:
        err = sum(abs(r["obs_major"] - r["true_major"]) for r in het_with_reads) / len(het_with_reads)
        print(f"Mean |observed - true| major-haplotype fraction: {err:.3f}")


if __name__ == "__main__":
    main()
