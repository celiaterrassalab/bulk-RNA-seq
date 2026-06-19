#!/bin/bash
#SBATCH -p fast
#SBATCH -c 2
#SBATCH -N 1
#SBATCH --mem-per-cpu 5000
#SBATCH -t 05:00:00
#SBATCH -o trim_launcher.out
#SBATCH -e trim_launcher.err

# ============================================================
# 01_trim_galore.sh
# Trims adapters and filters by quality with Trim Galore.
# Submits one independent SLURM job per FASTQ pair.
# ============================================================

# ── Variables to configure ──────────────────────────────────

# Cluster shared root (used as Singularity bind path)
ROOT="/projects/cancer"

# CHANGE: folder with raw FASTQ files (R1/R2 per sample)
RAWDATA=""

# Folder with Singularity images (.sif)
IMAGES="/projects/cancer/images"

# CHANGE: output folder for trimmed FASTQ files
OUTPUT_DIR=""

# Text file with FASTQ filenames, two lines per sample
# (R1 on one line, R2 on the next). Must be inside RAWDATA,
# or adjust the path.
INPUT_FILE="${RAWDATA}/input_files.txt"

# Name of the Trim Galore Singularity image
TRIMGALORE_IMG="trimgalore_v0.6.6.sif"

# ── General ──────────────────────────────────────────────────
mkdir -p "${OUTPUT_DIR}"
cd "${RAWDATA}" || exit 1

# Read the input file and submit each pair as a separate job
while read -r LINE1 && read -r LINE2; do
    echo "Submitting job for: ${LINE1} and ${LINE2}"

    sbatch --export=ROOT="${ROOT}",RAWDATA="${RAWDATA}",IMAGES="${IMAGES}",OUTPUT_DIR="${OUTPUT_DIR}",LINE1="${LINE1}",LINE2="${LINE2}",TRIMGALORE_IMG="${TRIMGALORE_IMG}" << 'EOF'
#!/bin/bash
#SBATCH -p fast
#SBATCH -c 2
#SBATCH -N 1
#SBATCH --mem-per-cpu 5000
#SBATCH -t 05:00:00
#SBATCH -o trim_%j.out
#SBATCH -e trim_%j.err

singularity exec -B ${ROOT}:${ROOT} ${IMAGES}/${TRIMGALORE_IMG} trim_galore \
    -q 30 --paired -o ${OUTPUT_DIR} ${RAWDATA}/${LINE1} ${RAWDATA}/${LINE2}
EOF

done < "${INPUT_FILE}"
