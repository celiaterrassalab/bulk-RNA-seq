# bulk-RNA-seq


Pipeline de análisis de RNA-seq bulk para datos paired-end, desde
FASTQ crudos hasta resultados de expresión diferencial. Diseñada
para ejecutarse en un cluster HPC con gestor de colas SLURM y
contenedores Singularity.

## Resumen del flujo

```
FASTQ crudos
   │
   ▼
01_trim_galore.sh        → recorte de adaptadores y filtrado por calidad
   │
   ▼
02_STAR_alignment.sh     → alineamiento al genoma de referencia (2-pass)
   │
   ▼
03_featurecounts.sh      → cuantificación de lecturas a nivel de gen
   │
   ▼
04_DEA_DESeq2.R           → expresión diferencial, PCA, volcano, heatmaps
```

## Requisitos

- Acceso a un cluster con SLURM y Singularity/Apptainer
- Imágenes Singularity (`.sif`) para:
  - [Trim Galore](https://github.com/FelixKrueger/TrimGalore) (usado: v0.6.6)
  - [STAR](https://github.com/alexdobin/STAR) (usado: v2.7.8a)
  - [samtools](http://www.htslib.org/) (usado: v1.15)
  - [Subread/featureCounts](https://subread.sourceforge.net/) (usado: v2.0.1)
- Índice de STAR pregenerado para tu genoma de referencia
- Archivo GTF de anotación (la misma versión usada para generar el índice de STAR)
- R (≥4.2) con los paquetes: `DESeq2`, `ashr`, `ggplot2`, `ggrepel`,
  `pheatmap`, `AnnotationDbi`, y el paquete de anotación de tu organismo
  (ej. `org.Mm.eg.db`, `org.Hs.eg.db`)

## Uso

Cada script tiene una sección de configuración al principio marcada
con comentarios `# CAMBIAR:` — son las únicas líneas que hace falta
editar para adaptar la pipeline a un proyecto nuevo. Ver
[`docs/CONFIGURATION.md`](docs/CONFIGURATION.md) para el detalle de
cada variable.

### 1. Trimming

```bash
sbatch scripts/01_trim_galore.sh
```

Requiere un `input_files.txt` dentro de la carpeta de FASTQ crudos,
con los nombres de archivo R1/R2 alternados (una muestra cada dos
líneas). Ver `docs/CONFIGURATION.md` para el formato exacto.

### 2. Alineamiento

```bash
bash scripts/02_STAR_alignment.sh
```

Detecta automáticamente las muestras a partir de los FASTQ trimados
(convención `<muestra>_1_val_1.fq.gz` / `<muestra>_2_val_2.fq.gz`,
generada por Trim Galore) y lanza un job SLURM por muestra.

> **Nota:** si tus muestras tienen `+` o `-` en el nombre (ej.
> condiciones tipo `tratamiento+` / `tratamiento-`), revisa que estos
> caracteres se conserven correctamente en los nombres de BAM
> resultantes — algunos pasos posteriores (lectura en R) pueden
> convertirlos a `.` al leer nombres de columna. Ver
> `docs/TROUBLESHOOTING.md`.

### 3. Cuantificación

```bash
sbatch scripts/03_featurecounts.sh
```

Genera una única matriz de cuantificación con todas las muestras
(`<PROJECT>_gene_quantification.txt`), con las primeras 6 columnas
de metadatos de featureCounts y el resto con una columna por BAM.

### 4. Expresión diferencial

```r
# Desde RStudio, tras editar la sección de configuración del script
source("scripts/04_DEA_DESeq2.R")
```

Por cada comparación definida en `COMPARISONS`, genera en su propia
carpeta:

| Archivo | Descripción |
|---|---|
| `DESeq2_results_all.csv` | Resultados completos de DESeq2 (todos los genes) |
| `GSEA_ranked.rnk` | Genes ordenados por log2FC, sin cabecera, para GSEA preranked |
| `Volcano_unannotated.png` | Volcano plot sin anotar |
| `Volcano_top10annotated.png` | Volcano plot con los genes más significativos anotados |
| `Heatmap_sig_genes.png` | Heatmap de genes significativos (up + down) |
| `genes_upregulated.csv` / `genes_downregulated.csv` | Listas separadas de DEGs |

Además, a nivel global: `PCA/PCA_global.png`, `normalized_counts.csv`
y `VST_matrix.csv` (ambas con símbolo génico en vez de ID de Ensembl).

## Estructura del repositorio

```
.
├── README.md
├── scripts/
│   ├── 01_trim_galore.sh
│   ├── 02_STAR_alignment.sh
│   ├── 03_featurecounts.sh
│   └── 04_DEA_DESeq2.R
└── docs/
    ├── CONFIGURATION.md
    └── TROUBLESHOOTING.md
```

## Notas de diseño

- Los scripts 01-03 son SLURM/Singularity-first: están pensados para
  clusters HPC y no para ejecución local directa.
- `02_STAR_alignment.sh` y `03_featurecounts.sh` esperan rutas
  absolutas accesibles tanto desde el nodo de login como desde los
  nodos de cómputo (bind path de Singularity).
- `04_DEA_DESeq2.R` es agnóstico de especie y diseño experimental:
  basta con rellenar `sample_columns`, `COMPARISONS` y el paquete de
  anotación correspondiente.
- Si tu diseño experimental incluye réplicas pareadas (mismo animal,
  pase o donante en distintas condiciones), añade un factor de
  réplica al diseño de DESeq2 (`~ replicate + condition`) para
  controlar esa variabilidad — ver comentarios en el propio script.

## Licencia

Añadir la licencia que corresponda (ej. MIT) según las políticas del
grupo/institución.
