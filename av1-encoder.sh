#!/usr/bin/env bash

set -eo pipefail

echo "::group:: [i] Download the File Chunk"
export InputChunkFullName="${AnimeName}.Ep${Episode}.${AudioType}.part_${ChunkNum}.mkv" # ${ChunkNum} <<${{ matrix.ChunkNum }}
rclone copy ${LocationOnIndex}/${AnimeName}/${ChunkDir}/${InputChunkFullName} . && printf "Downloaded Working Chunk\n"
export R3ncod3dChunkName=$(echo ${InputChunkFullName} | sed 's|mkv|480p.av1.mkv|;s|.mkv||')
echo "::endgroup::"

mkdir -p ${ChunkEncDir}

echo "::group:: [i] Pass the SubChunk through r3ncod3r - RCMode=Q"
printf "Archival r3ncode - Pass 1 of 2\n"
${FTOOL_CONVERTER} -loglevel warning -stats -stats_period 4 \
  -i ${InputChunkFullName} -map_metadata -1 -map_chapters -1 -map 0:V -c:v libaom-av1 \
  -vf "format=pix_fmts=yuv420p10le,scale=-2:480" -g $((FrameRate * 4)) -keyint_min ${FrameRate} \
  -usage good -cpu-used 2 -crf ${QScale} -b:v 0 -aq-mode 2 -tune ssim \
  -lag-in-frames ${FrameRate} -tile-columns 2 -tile-rows 1 -frame-parallel true -row-mt true \
  -pass 1 -avoid_negative_ts 1 -f null /dev/null
sleep 2s && echo && sleep 1s

printf "Archival r3ncode - Pass 2 of 2\n"
${FTOOL_CONVERTER} -loglevel warning -stats -stats_period 20 \
  -i ${InputChunkFullName} -map_metadata -1 -map_chapters -1 -map 0:V -c:v libaom-av1 \
  -vf "format=pix_fmts=yuv420p10le,scale=-2:480" -g $((FrameRate * 4)) -keyint_min ${FrameRate} \
  -usage good -cpu-used ${SpeedProf} -crf ${QScale} -b:v 0 -aq-mode 2 -tune ssim \
  -lag-in-frames ${FrameRate} -tile-columns 2 -tile-rows 1 -frame-parallel true -row-mt true \
  -pass 2 -auto-alt-ref 1 -avoid_negative_ts 1 -f webm -dash 1 \
  ${ChunkEncDir}/${R3ncod3dChunkName}.webm 2>&1 | tee ${R3ncod3dChunkName}.log
sed -i 's|\r|\n|g' "${R3ncod3dChunkName}.log"
echo "::endgroup::"

rm ffmpeg2pass*.log
sleep 2s
date

echo "::group:: [i] Mediainfo for r3ncod3d SubChunk"
mediainfo ${ChunkEncDir}/${R3ncod3dChunkName}.webm
echo "::endgroup::"

echo "::group:: [+] Upload Necessary Files & Stats in GDrive/Server"
tar --create -I"zstd -19" --remove-file -f ${ChunkEncDir}/${R3ncod3dChunkName}.log.tzst ${R3ncod3dChunkName}.log
rclone copy ${ChunkEncDir}/ ${LocationOnIndex}/${AnimeName}/${ChunkEncDir}/ && printf "Uploaded AV1-R3NCOD3D File + Stats\n"
echo "::endgroup::"
