FROM python:3.8-slim-bookworm

LABEL \
    author="Abu Saadat" \
    description="Docker image containing phaser tools for the alleleexpression pipeline" \
    maintainer="Abu Saadat"

# procps provides `ps`, which Nextflow needs for task metrics
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        procps \
        samtools \
        bcftools \
        tabix \
        bedtools \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Versions match the published phASER.sif (zenodo record 15772979)
RUN pip install --no-cache-dir \
    numpy==1.24.4 \
    scipy==1.10.1 \
    pysam==0.23.3 \
    intervaltree==3.1.0 \
    pandas==2.0.3

ARG PHASER_COMMIT=a2355aa7b532e109ce957ba409716d6eb845b699
RUN git clone https://github.com/secastel/phaser.git /opt/phaser && \
    git -C /opt/phaser checkout ${PHASER_COMMIT}

# Create wrapper scripts in /usr/local/bin
RUN printf '#!/bin/bash\npython3 /opt/phaser/phaser/phaser.py "$@"\n' > /usr/local/bin/phaser.py && \
    printf '#!/bin/bash\npython3 /opt/phaser/phaser_gene_ae/phaser_gene_ae.py "$@"\n' > /usr/local/bin/phaser_gene_ae.py && \
    chmod +x /usr/local/bin/phaser.py /usr/local/bin/phaser_gene_ae.py

# Test installation
RUN phaser.py --help > /dev/null && phaser_gene_ae.py --help > /dev/null

WORKDIR /data/
