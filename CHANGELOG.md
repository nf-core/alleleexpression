# nf-core/alleleexpression: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0dev - [date]

Initial release of nf-core/alleleexpression, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- ASE calling with a choice of test (`--ase_test binomial|betabinomial`), Benjamini-Hochberg FDR (`--ase_fdr`), minimum read count (`--ase_min_count`) and minimum effect size (`--ase_min_effect`). The beta-binomial overdispersion is estimated per sample by trimmed maximum likelihood (`--ase_overdispersion_trim`) or fixed with `--ase_overdispersion`. Per-gene statistics are written to `ase/*.ase_stats.tsv`.
- Simulated end-to-end test dataset (`tests/scripts/make_ase_sim_data.sh`) with planted ASE and a truth-based evaluation script (`tests/scripts/evaluate_ase.py`).

### `Fixed`

- Only one sample was processed when several were given (single-use reference channels).
- `EXTRACT_ASE_GENES` reported every gene with `bCount > 0` as ASE.
- `SAMTOOLS_SORT` / `UMITOOLS_DEDUP` `ext.prefix` closures crashed.
- Container profiles (`docker`, `conda`, `podman`, ...) did not enable their engine.
- phASER Dockerfile no longer built (EOL base image).
- UMI-tools stats files were named `--random-seed=100_*`.
- Parameters were never validated against `nextflow_schema.json`; `validateParameters()` now runs at start-up (`--validate_params`). `assets/schema_input.json` switched to JSON Schema draft-07, which nf-validation requires, and the `max_*` parameters were added to the schema.

### `Dependencies`

### `Deprecated`
