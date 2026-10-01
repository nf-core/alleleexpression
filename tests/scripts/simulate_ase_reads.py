#!/usr/bin/env python3
"""
Simulate paired-end, UMI-tagged RNA-seq reads with known allele-specific expression.

Reads are drawn from the two true haplotypes of one individual (phased VCF), spliced
according to a GTF, with a chosen subset of genes given allelic imbalance. A truth
table of the planted allelic ratios is written next to the FASTQs.

Read names carry the UMI as the last ':'-separated field, so that
`umi_tools dedup --extract-umi-method=read_id --umi-separator=":"` works directly.

Only numpy is required.
"""

import argparse
import gzip
import random
import re
from collections import defaultdict

import numpy as np

COMP = bytes.maketrans(b"ACGTNacgtn", b"TGCANtgcan")


def revcomp(seq):
    return seq.translate(COMP)[::-1]


def read_fasta(path):
    name, chunks = None, []
    with open(path) as fh:
        for line in fh:
            if line.startswith(">"):
                name = line[1:].split()[0]
            else:
                chunks.append(line.strip())
    return name, "".join(chunks).upper().encode()


def read_phased_snps(path, sample):
    """Return list of (pos0, ref, alt, h1, h2) for biallelic SNPs where sample is non-ref."""
    snps = []
    opener = gzip.open if path.endswith(".gz") else open
    col = None
    with opener(path, "rt") as fh:
        for line in fh:
            if line.startswith("##"):
                continue
            f = line.rstrip("\n").split("\t")
            if line.startswith("#"):
                col = f.index(sample)
                continue
            ref, alt = f[3], f[4]
            if len(ref) != 1 or len(alt) != 1:
                continue
            gt = f[col].split(":")[0]
            if "|" not in gt:
                continue
            a, b = gt.split("|")
            if a == "." or b == ".":
                continue
            h1, h2 = int(a), int(b)
            if h1 == 0 and h2 == 0:
                continue
            snps.append((int(f[1]) - 1, ref, alt, h1, h2))
    return snps


def read_transcripts(gtf):
    """One transcript per gene: Ensembl_canonical if tagged, else the longest."""
    tx_exons = defaultdict(list)
    tx_info = {}
    attr_re = re.compile(r'(\S+) "([^"]*)"')
    with open(gtf) as fh:
        for line in fh:
            if line.startswith("#"):
                continue
            f = line.rstrip("\n").split("\t")
            if f[2] != "exon":
                continue
            attrs = dict(attr_re.findall(f[8]))
            tags = re.findall(r'tag "([^"]*)"', f[8])
            tid = attrs["transcript_id"]
            tx_exons[tid].append((int(f[3]) - 1, int(f[4])))  # 0-based half-open
            tx_info[tid] = dict(
                gene_id=attrs["gene_id"],
                gene_name=attrs.get("gene_name", attrs["gene_id"]),
                gene_type=attrs.get("gene_type", ""),
                strand=f[6],
                canonical="Ensembl_canonical" in tags,
            )
    by_gene = defaultdict(list)
    for tid, info in tx_info.items():
        exons = sorted(tx_exons[tid])
        length = sum(e - s for s, e in exons)
        by_gene[info["gene_id"]].append((info["canonical"], length, tid, exons, info))
    genes = {}
    for gid, txs in by_gene.items():
        txs.sort(key=lambda t: (t[0], t[1]), reverse=True)
        canonical, length, tid, exons, info = txs[0]
        genes[gid] = dict(info, transcript_id=tid, exons=exons, length=length)
    return genes


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--fasta", required=True)
    p.add_argument("--gtf", required=True)
    p.add_argument("--vcf", required=True, help="Phased VCF containing --sample (truth haplotypes)")
    p.add_argument("--sample", required=True)
    p.add_argument("--out-prefix", required=True)
    p.add_argument("--n-molecules", type=int, default=60000, help="Unique fragments before PCR duplication")
    p.add_argument("--n-expressed", type=int, default=40, help="Number of expressed genes")
    p.add_argument("--n-ase", type=int, default=12, help="Expressed genes given allelic imbalance")
    p.add_argument("--read-len", type=int, default=100)
    p.add_argument("--frag-mean", type=float, default=250)
    p.add_argument("--frag-sd", type=float, default=40)
    p.add_argument("--umi-len", type=int, default=10)
    p.add_argument("--dup-rate", type=float, default=0.25, help="Mean extra PCR copies per molecule (Poisson)")
    p.add_argument("--error-rate", type=float, default=0.002)
    p.add_argument("--allelic-overdispersion", type=float, default=0.02,
                   help="Non-ASE genes get hap1 fraction ~ Beta(mean 0.5, rho) instead of exactly 0.5; "
                        "mimics extra-binomial noise in real data. 0 disables")
    p.add_argument("--seed", type=int, default=1)
    args = p.parse_args()

    rng = np.random.default_rng(args.seed)
    random.seed(args.seed)

    chrom, ref_seq = read_fasta(args.fasta)
    snps = read_phased_snps(args.vcf, args.sample)
    genes = read_transcripts(args.gtf)

    # Build the two haplotype sequences
    haps = [bytearray(ref_seq), bytearray(ref_seq)]
    for pos, ref, alt, h1, h2 in snps:
        assert ref_seq[pos:pos + 1].decode() == ref, f"REF mismatch at {pos + 1}: fasta={ref_seq[pos:pos + 1]} vcf={ref}"
        if h1:
            haps[0][pos] = ord(alt)
        if h2:
            haps[1][pos] = ord(alt)
    haps = [bytes(h) for h in haps]

    # Exonic heterozygous SNPs per gene
    het = sorted((pos, ref, alt, h1, h2) for pos, ref, alt, h1, h2 in snps if h1 != h2)
    het_pos = np.array([s[0] for s in het], dtype=np.int64)

    def exonic_hets(exons):
        out = []
        for s, e in exons:
            lo, hi = np.searchsorted(het_pos, s), np.searchsorted(het_pos, e)
            out.extend(het[lo:hi])
        return out

    min_len = args.frag_mean + 3 * args.frag_sd
    eligible = [
        gid for gid, g in genes.items()
        if g["gene_type"] in ("protein_coding", "lncRNA") and g["length"] >= min_len
    ]
    with_het = [gid for gid in eligible if exonic_hets(genes[gid]["exons"])]
    without_het = [gid for gid in eligible if gid not in set(with_het)]

    # Mostly genes with informative SNPs, plus a few without (they should report no ASE)
    n_het_genes = min(len(with_het), int(round(args.n_expressed * 0.85)))
    expressed = random.sample(sorted(with_het), n_het_genes)
    expressed += random.sample(sorted(without_het), min(len(without_het), args.n_expressed - n_het_genes))
    expressed.sort(key=lambda gid: genes[gid]["exons"][0][0])

    ase_genes = set(random.sample([g for g in expressed if g in set(with_het)], min(args.n_ase, n_het_genes)))
    hap1_frac = {}
    for gid in expressed:
        if gid in ase_genes:
            strength = random.choice([0.75, 0.8, 0.85, 0.9])
            hap1_frac[gid] = strength if random.random() < 0.5 else 1 - strength
        elif args.allelic_overdispersion > 0:
            shape = (1 - args.allelic_overdispersion) / args.allelic_overdispersion / 2
            hap1_frac[gid] = float(rng.beta(shape, shape))
        else:
            hap1_frac[gid] = 0.5

    # Expression weights proportional to abundance * length (fragments per gene)
    abundance = rng.lognormal(mean=0.0, sigma=1.0, size=len(expressed))
    weights = np.array([a * genes[g]["length"] for a, g in zip(abundance, expressed)])
    weights /= weights.sum()

    # Spliced transcript sequences per haplotype, in transcript orientation
    tx_seq = {}
    for gid in expressed:
        g = genes[gid]
        for h in (0, 1):
            seq = b"".join(haps[h][s:e] for s, e in g["exons"])
            tx_seq[(gid, h)] = revcomp(seq) if g["strand"] == "-" else seq

    bases = np.frombuffer(b"ACGT", dtype=np.uint8)
    qual_hi, qual_lo = "F", ":"

    def mutate(read):
        arr = np.frombuffer(read, dtype=np.uint8).copy()
        mask = rng.random(arr.size) < args.error_rate
        if mask.any():
            arr[mask] = rng.choice(bases, size=int(mask.sum()))
        qual = np.where(rng.random(arr.size) < 0.9, ord(qual_hi), ord(qual_lo)).astype(np.uint8)
        qual[mask] = ord("#")
        return arr.tobytes().decode(), qual.tobytes().decode()

    gene_counts = {gid: [0, 0] for gid in expressed}
    choices = rng.choice(len(expressed), size=args.n_molecules, p=weights)

    r1_fh = gzip.open(f"{args.out_prefix}_R1.fastq.gz", "wt", compresslevel=6)
    r2_fh = gzip.open(f"{args.out_prefix}_R2.fastq.gz", "wt", compresslevel=6)
    n_reads = 0
    for mol, gi in enumerate(choices):
        gid = expressed[gi]
        hap = 0 if rng.random() < hap1_frac[gid] else 1
        gene_counts[gid][hap] += 1
        seq = tx_seq[(gid, hap)]
        flen = int(np.clip(rng.normal(args.frag_mean, args.frag_sd), args.read_len + 20, len(seq)))
        start = int(rng.integers(0, len(seq) - flen + 1))
        frag = seq[start:start + flen]
        if rng.random() < 0.5:  # unstranded library
            frag = revcomp(frag)
        umi = "".join(rng.choice(list("ACGT"), size=args.umi_len))
        copies = 1 + rng.poisson(args.dup_rate)
        for c in range(copies):
            n_reads += 1
            name = f"SIM:{args.sample}:{mol}:{c}:{umi}"
            s1, q1 = mutate(frag[:args.read_len])
            s2, q2 = mutate(revcomp(frag)[:args.read_len])
            r1_fh.write(f"@{name}\n{s1}\n+\n{q1}\n")
            r2_fh.write(f"@{name}\n{s2}\n+\n{q2}\n")
    r1_fh.close()
    r2_fh.close()

    with open(f"{args.out_prefix}.truth_genes.tsv", "w") as fh:
        fh.write("gene_id\tgene_name\tgene_type\tstrand\tstart\tend\tn_exonic_het_snps\tase\ttrue_hap1_fraction\tmolecules_hap1\tmolecules_hap2\n")
        for gid in expressed:
            g = genes[gid]
            fh.write("\t".join(map(str, [
                gid, g["gene_name"], g["gene_type"], g["strand"],
                g["exons"][0][0] + 1, g["exons"][-1][1],
                len(exonic_hets(g["exons"])), int(gid in ase_genes), f"{hap1_frac[gid]:.3f}",
                gene_counts[gid][0], gene_counts[gid][1],
            ])) + "\n")

    with open(f"{args.out_prefix}.truth_het_snps.tsv", "w") as fh:
        fh.write("chrom\tpos\tref\talt\ttrue_phased_gt\tgene_id\n")
        for gid in expressed:
            for pos, ref, alt, h1, h2 in exonic_hets(genes[gid]["exons"]):
                fh.write(f"{chrom}\t{pos + 1}\t{ref}\t{alt}\t{h1}|{h2}\t{gid}\n")

    print(f"{args.sample}: {len(snps)} non-ref SNPs ({len(het)} het), {len(expressed)} expressed genes "
          f"({len(ase_genes)} with ASE), {args.n_molecules} molecules, {n_reads} read pairs")


if __name__ == "__main__":
    main()
