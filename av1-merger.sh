#!/usr/bin/env bash

set -eo pipefail

mkdir -p Chunks/ ${AnimeName}/

echo "::group:: [i] Download All the File Chunks"
rclone copy ${LocationOnIndex}/${AnimeName}/${ChunkEncDir}/ Chunks/ && printf "Downloaded All Chunks\n"
rclone copy ${LocationOnIndex}/${AnimeName}/${AnimeName}.Ep${Episode}.audio-${AudLang}.mp4 . && printf "Downloaded Audio\n"
ls -lAog Chunks/ *.mp4
rclone purge ${LocationOnIndex}/${AnimeName}/${ChunkDir}/
rclone purge ${LocationOnIndex}/${AnimeName}/${ChunkEncDir}/
echo "::endgroup::"

echo "::group:: [i] Merge the File Chunks"
cd Chunks/
mkvmerge --quiet --output ../${AnimeName}/${AnimeName}.Ep${Episode}.${AudioType}.480p.av1.video.mkv '[' $(ls *.webm) ']'
cd ..
${FTOOL_CONVERTER} -loglevel warning -stats -stats_period 2 -y \
  -i ${AnimeName}/${AnimeName}.Ep${Episode}.${AudioType}.480p.av1.video.mkv \
  -i ${AnimeName}.Ep${Episode}.audio-${AudLang}.mp4 \
  -map_metadata -1 -codec copy -metadata:s:1 language=${AudLang} -avoid_negative_ts 1 -movflags +faststart \
  ${AnimeName}/${AnimeName}.Ep${Episode}.${AudioType}.480p.av1.mp4
echo "::endgroup::"

echo "::group:: [i] Mediainfo"
mediainfo ${AnimeName}/${AnimeName}.Ep${Episode}.${AudioType}.480p.av1.mp4
echo "::endgroup::"

echo "::group:: [i] Upload Final Rendition"
rclone copy ${AnimeName}/ ${LocationOnIndex}/${AnimeName}/ && printf "Upload Complete\n"
echo "::endgroup::"
