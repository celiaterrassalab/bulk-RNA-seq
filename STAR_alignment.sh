#!/bin/bash
# ============================================================
# 02_STAR_alignment.sh
# STAR alignment (2-pass) and BAM sorting/indexing with
# samtools. Generates and submits one SLURM job per detected
# sample.
#
# Requires trimmed FASTQ files to follow the Trim Galore
# naming convention: <sample>_1_val_1.fq.gz / <sample>_2_val_2.fq.gz
# ============================================================

# ── Directories to configure ────────────────────────────────

# CHANGE: folder with trimmed FASTQ files (output of 01_trim_galore.sh)
DATA=""

# STAR index (mm10 / GRCm38.102, 50bp reads)
INDEX="/projects/cancer/db_files/Genomes/Ensembl/mouse/mm10/release-102/STAR_v2.7.8a_index_50bp"

# Folder with Singularity images (.sif)
IMAGES_PATH="/projects/cancer/images"

# CHANGE: project root folder where BAMs, logs and generated scripts will be saved
WKD=""

OUT="${WKD}/bam_files/logs"
OUTBAM="${WKD}/bam_files"

# Names of the STAR and samtools Singularity images
STAR_IMG="star_2.7.8a.sif"
SAMTOOLS_IMG="samtools_v1.15.sif"

# ── Alignment parameters ──────────────────────────────
T=4              # threads per job
MISMATCH=2       # --outFilterMismatchNmax
MULTIMAP=10      # --outFilterMultimapNmax

mkdir -p "$OUT" "$OUTBAM" "$WKD/scripts" "$WKD/logs"

echo "### Detecting samples in $DATA"

for FILENAME in "$DATA"/*_1_val_1.fq.gz; do
    NAME=${FILENAME%_1_val_1.fq.gz}
    SAMPLE=$(basename "$NAME")
    READ1="${NAME}_1_val_1.fq.gz"
    READ2="${NAME}_2_val_2.fq.gz"

    if [[ ! -f "$READ2" ]]; then
        echo "⚠ Missing R2 for $SAMPLE → skipping"
        continue
    fi

    SCRIPT="$WKD/scripts/align_${SAMPLE}.sh"

    cat << EOF > "$SCRIPT"
#!/bin/bash
#SBATCH -p long
#SBATCH --nodes=1
#SBATCH --cpus-per-task=$T
#SBATCH --mem=80G
#SBATCH -o $WKD/logs/star_alignment_${SAMPLE}.out
#SBATCH -e $WKD/logs/star_alignment_${SAMPLE}.err

echo "### Processing sample: $SAMPLE"

singularity exec -B /projects/cancer:/projects/cancer $IMAGES_PATH/$STAR_IMG STAR \\
  --runThreadN $T \\
  --genomeDir $INDEX \\
  --readFilesIn $READ1 $READ2 \\
  --readFilesCommand zcat \\
  --outSAMtype BAM SortedByCoordinate \\
  --quantMode GeneCounts \\
  --outFilterMismatchNmax $MISMATCH \\
  --outFilterMultimapNmax $MULTIMAP \\
  --alignSJoverhangMin 8 \\
  --alignSJDBoverhangMin 1 \\
  --twopassMode Basic \\
  --outFileNamePrefix $OUTBAM/${SAMPLE}_

singularity exec -B /projects/cancer:/projects/cancer $IMAGES_PATH/$SAMTOOLS_IMG \\
  samtools index $OUTBAM/${SAMPLE}_Aligned.sortedByCoord.out.bam
EOF

    chmod +x "$SCRIPT"
    echo "Submitting job for $SAMPLE"
    sbatch "$SCRIPT"
done

echo "Submission complete."
