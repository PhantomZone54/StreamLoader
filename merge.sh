#!/bin/bash

set -eo pipefail

# ++ ${LocationOnIndex##*/}/${AnimeName}/ArchiveChunks/${AnimeName}.${OutputRes}.vp9.${AudioType}.part_%02d.mkv
# -> ${LocationOnIndex##*/}/${AnimeName}/ArchiveRenditions/${AnimeName}.${OutputRes}.vp9.${AudioType}.video.mkv
# ++ ${LocationOnIndex##*/}/${AnimeName}/${AnimeName}.audio.mp4
# >> ${LocationOnIndex##*/}/${AnimeName}/Renditions/${AnimeName}.${OutputRes}.vp9.${AudioType}.mp4

cd ${WorkDir}
mkdir -p ${LocationOnIndex##*/}/{${AnimeName}/ArchiveChunks,ArchiveRenditions,Renditions}

echo "::group:: [i] Download All the File Chunks and Merge Them"
rclone copy ${LocationOnIndex##*/}/${AnimeName}/ArchiveChunks/ ${LocationOnIndex##*/}/${AnimeName}/ArchiveChunks/ && printf "Downloaded All Recon Chunks for All Resolutions\n"

printf "Work with %sp Archive Chunks...\n\n" "${Res}"
cd ${LocationOnIndex##*/}/${AnimeName}/ArchiveChunks/
mkvmerge --quiet --output ${LocationOnIndex##*/}/${AnimeName}/ArchiveRenditions/${AnimeName}.${OutputRes}.vp9.${AudioType}.video.mkv \
  '[' $(ls ${AnimeName}.${OutputRes}.vp9.${AudioType}.part_*.webm) ']'
cd ${WorkDir}

${FTOOL_CONVERTER} -loglevel warning -y -i ${LocationOnIndex##*/}/${AnimeName}/ArchiveRenditions/${AnimeName}.${OutputRes}.vp9.${AudioType}.video.mkv \
  -codec copy -avoid_negative_ts 1 -movflags +faststart \
  ${LocationOnIndex##*/}/${AnimeName}/ArchiveRenditions/${AnimeName}.${OutputRes}.vp9.${AudioType}.video.mp4
rm -rf ${LocationOnIndex##*/}/${AnimeName}/{ArchiveChunks,ArchiveRenditions/${AnimeName}.${OutputRes}.vp9.${AudioType}.video.mkv}
echo "::endgroup::"

echo "::group:: [i] Merge Audio with Video"
rclone copy ${LocationOnIndex##*/}/${AnimeName}/${AnimeName}.audio.mp4 . && printf "Downloaded audio\n"
${FTOOL_CONVERTER} -loglevel warning -y -i ${LocationOnIndex##*/}/${AnimeName}/ArchiveRenditions/${AnimeName}.${OutputRes}.vp9.${AudioType}.video.mkv \
  -i ${AnimeName}.audio.mp4 -map_metadata -1 -map 0:V:0 -map 1:a:0 -matadata:s:1 language=${AudLang} \
  -avoid_negative_ts 1 -movflags +faststart ${LocationOnIndex##*/}/${AnimeName}/Renditions/${AnimeName}.${OutputRes}.vp9.${AudioType}.mp4
rm ${AnimeName}.audio.mp4
echo "::endgroup::"

echo "::group:: [i] Mediainfo"
mediainfo ${LocationOnIndex##*/}/${AnimeName}/Renditions/${AnimeName}.${OutputRes}.vp9.${AudioType}.mp4
echo "::endgroup::"

echo "::group:: [i] Upload Final Rendition"
rclone copy ${LocationOnIndex##*/}/${AnimeName}/ ${LocationOnIndex##*/}/${AnimeName}/ \
  && printf "Upload Complete\n"
echo "::endgroup::"
