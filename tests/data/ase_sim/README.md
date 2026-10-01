# ase_sim: simulated end-to-end test data

Built by `tests/scripts/make_ase_sim_data.sh` (≈1.5 min, downloads cached in `../testdata_cache`).

- **Region**: GRCh38 chr11:64,500,001-66,500,000, re-based to 1 (contig still `chr11`).
  Every coordinate in every file is `GRCh38 position - 64,500,000`.
- **Samples**: NA12878, HG00096 (1000 Genomes 30x phased panel). Reads are simulated from
  their true haplotypes: 2x100 bp, unstranded, spliced via GENCODE v47 canonical transcripts,
  10 bp UMI as the last `:` field of the read name, ~20% PCR duplicates, 0.2% base errors.
- **ASE**: 100 expressed genes per sample, 12 with planted allelic imbalance (75-90% one haplotype).
  The other genes get a haplotype ratio drawn from Beta(mean 0.5, rho = 0.02) instead of exactly
  0.5, mimicking the extra-binomial noise of real data (`--allelic-overdispersion`).
- **Beagle panel**: same window, 3198 samples (test samples and NA12878's parents removed).

| Path | Content |
|---|---|
| `samplesheet.csv` | Pipeline input (absolute paths; regenerate if the repo moves) |
| `fastq/` | Paired FASTQs |
| `variants/<sample>.vcf.gz` | Unphased, PASS, non-ref SNPs (pipeline input) |
| `variants/beagle_ref.chr11.vcf.gz`, `genetic_map.chr11.map` | Beagle reference + PLINK map |
| `reference/` | `genome.fa`, `genes.gtf`, `genes.bed`, `star_index/` (STAR 2.7.11b) |
| `truth/<sample>.truth_genes.tsv` | True hap1 fraction per gene (`ase` = planted), simulated molecules per haplotype |
| `truth/<sample>.truth_het_snps.tsv` | Exonic het SNPs with true phase |
| `truth/<sample>.phased_truth.vcf.gz` | True phased genotypes (to score Beagle) |

Run and score:

```bash
nextflow run . -profile test,singularity --outdir results
python3 tests/scripts/evaluate_ase.py \
    --truth tests/data/ase_sim/truth/NA12878.truth_genes.tsv \
    --gene-ae results/phaser/NA12878_gene_ae.tsv \
    --ase-calls results/ase/NA12878.chr11.ASE.tsv
```

Note: overlapping genes (e.g. DPF2 / ENSG00000289231) share SNPs in an unstranded library,
so a balanced gene overlapping an ASE gene shows the same imbalance. That is expected.
