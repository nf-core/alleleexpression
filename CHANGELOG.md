# nf-core/alleleexpression: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0dev - [date]

Initial release of nf-core/alleleexpression, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- ASE calling with a choice of test (`--ase_test binomial|betabinomial`), Benjamini-Hochberg FDR (`--ase_fdr`), minimum read count (`--ase_min_count`) and minimum effect size (`--ase_min_effect`). The beta-binomial overdispersion is estimated per sample by trimmed maximum likelihood (`--ase_overdispersion_trim`) or fixed with `--ase_overdispersion`. Per-gene statistics are written to `ase/*.ase_stats.tsv`.
- `--star_index` is optional: if not given, the STAR index is built from `--fasta` and `--gtf` (nf-core `star/genomegenerate`); `--save_reference` saves it.
- Simulated end-to-end test dataset (`tests/scripts/make_ase_sim_data.sh`) with planted ASE and a truth-based evaluation script (`tests/scripts/evaluate_ase.py`), hosted on Zenodo ([10.5281/zenodo.23215419](https://doi.org/10.5281/zenodo.23215419)) and used by `-profile test`.

### `Fixed`

- Only one sample was processed when several were given (single-use reference channels).
- `EXTRACT_ASE_GENES` reported every gene with `bCount > 0` as ASE.
- `SAMTOOLS_SORT` / `UMITOOLS_DEDUP` `ext.prefix` closures crashed.
- Container profiles (`docker`, `conda`, `podman`, ...) did not enable their engine.
- phASER Dockerfile no longer built (EOL base image).
- UMI-tools stats files were named `--random-seed=100_*`.
- Beagle VCF indexes were published to `<outdir>/results/` instead of `<outdir>/beagle/`.
- MultiQC never ran (empty optional inputs); it now also reports STAR, UMI-tools and software versions.
- Software versions are collated into `pipeline_info/nf_core_alleleexpression_software_mqc_versions.yml`; fixed version commands that wrote invalid YAML (phASER, awk) or wrong values (tabix, Beagle).
- phASER variant lists were in random order between runs; `PYTHONHASHSEED=0` makes outputs reproducible.
- `-stub` runs: added stubs to all local modules and fixed STAR stub output names.
- nf-test: added snapshot and `tests/.nftignore`; CI tests the Docker profile (building the phASER image) and Nextflow 25.04.0.
- Parameters were never validated against `nextflow_schema.json`; `validateParameters()` now runs at start-up (`--validate_params`).
- `nf-core pipelines lint` failures: pipeline renamed from `asenext` to `alleleexpression` in the manifest and schemas, template files restored, logos added, unused `lib/` removed, `nf-test.config` aligned with the template.

### `Dependencies`

- Migrated parameter validation from `nf-validation` to `nf-schema@2.3.0` (JSON Schema draft 2020-12).
- Minimum Nextflow version is now 25.04.0 (resourceLimits, nf-schema, topic channels in nf-core modules).

### `Removed`

- `--max_cpus`, `--max_memory` and `--max_time`. Cap resources with Nextflow's `process.resourceLimits` instead (see usage docs).

### `Deprecated`
