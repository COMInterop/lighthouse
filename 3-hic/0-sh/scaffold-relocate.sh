#!/bin/bash

cd /data_HPC02/bpike/lh/a/drafts/pecat/21dic2023/output/9-hic/per-chr-pr/3-scaf/purge-2/

# Files
SOURCE="chr6-hap1_scaffolds_renamed.fa"
SCAFFOLD="chr6-hap1-scaffold4"
DEST="chr3-hap0_scaffolds_renamed.fa"
NEW_SCAFFOLD="chr3-hap0-scaffold99"

# Temporary files
TMP_SOURCE="tmp_source.fasta"
TMP_SCAFFOLD="tmp_scaffold.fasta"

# Step 1: Extract chr6-hap1-scaffold3 to its own FASTA file
seqkit grep -r -p "${SCAFFOLD}" "$SOURCE" > "$TMP_SCAFFOLD"
grep ">" "$TMP_SCAFFOLD"

# Step 2: Use seqkit grep with a reverse filter to copy every contig from SOURCE to a new file, excluding chr6-hap1-scaffold3
seqkit grep -v -r -p "${SCAFFOLD}" "$SOURCE" > "$TMP_SOURCE"
grep ">" "$TMP_SOURCE"

# Step 3: Rename the new file to the old one
mv "$TMP_SOURCE" "$SOURCE"

# Step 4: Rename chr6-hap1-scaffold3 to chr3-hap0-scaffold4 in the extracted file
sed -i "s/^>${SCAFFOLD}$/>${NEW_SCAFFOLD}/" "$TMP_SCAFFOLD"
grep ">" "$TMP_SCAFFOLD"

# Step 5: Concatenate the renamed scaffold to DEST
cat "$TMP_SCAFFOLD" >> "$DEST"
grep ">" "$DEST"

# Clean up
rm "$TMP_SCAFFOLD"

echo "Scaffold ${SCAFFOLD} removed from ${SOURCE}, renamed to ${NEW_SCAFFOLD}, and added to ${DEST}."


