#!/usr/bin/env bash

set -eo pipefail

echo "::group:: [i] Download the File Chunk"
export InputChunkFullName="${AnimeName}.Ep${Episode}.${AudioType}.part_${ChunkNum}.mkv" # ${ChunkNum} <<${{ matrix.ChunkNum }}
rclone copy ${LocationOnIndex}/${AnimeName}/${ChunkDir}/${InputChunkFullName} . && printf "Downloaded Working Chunk\n"
export R3ncod3dChunkName=$(echo ${InputChunkFullName} | sed 's|mkv|480p.av1.mkv|;s|.mkv||')
export ScaleFlags="format=pix_fmts=yuv420p10le,scale=w=-2:h=480:out_color_matrix=bt709:out_range=tv:flags=lanczos"
export AomParams="tune=ssim:enable-qm=1:arnr-maxframes=5:arnr-strength=2"
echo "::endgroup::"

mkdir -p ${ChunkEncDir}

echo "::group:: [i] Archival r3ncode - Pass 1 of 2"
${FTOOL_CONVERTER} -loglevel warning -stats -stats_period 4 \
  -i ${InputChunkFullName} -map_metadata -1 -map_chapters -1 -map 0:V -c:v libaom-av1 \
  -vf ${ScaleFlags} -g $((FrameRate * 4)) -keyint_min ${FrameRate} \
  -usage good -cpu-used 2 -crf ${QScale} -b:v 0 -lag-in-frames 48 -threads 4 \
  -tile-columns 1 -tile-rows 0 -frame-parallel false -row-mt true \
  -aq-mode 1 -aom-params ${AomParams} -qmin $((QScale/3)) -qmax $((QScale + QScale/3 + 2)) \
  -pass 1 -avoid_negative_ts 1 -f null /dev/null
echo "::endgroup::"

sleep 2s && date && sleep 2s

echo "::group:: [i] Archival r3ncode - Pass 2 of 2"
${FTOOL_CONVERTER} -loglevel warning -stats -stats_period 20 \
  -i ${InputChunkFullName} -map_metadata -1 -map_chapters -1 -map 0:V -c:v libaom-av1 \
  -vf ${ScaleFlags} -g $((FrameRate * 4)) -keyint_min ${FrameRate} \
  -usage good -cpu-used ${SpeedProf} -crf ${QScale} -b:v 0 -lag-in-frames 48 -threads 4 \
  -tile-columns 1 -tile-rows 0 -frame-parallel false -row-mt true \
  -aq-mode 1 -aom-params ${AomParams} -qmin $((QScale/3)) -qmax $((QScale + QScale/3 + 2)) \
  -pass 2 -auto-alt-ref 1 -avoid_negative_ts 1 -f webm -dash 1 \
  ${ChunkEncDir}/${R3ncod3dChunkName}.webm 2>&1 | tee ${R3ncod3dChunkName}.log
sed -i 's|\r|\n|g' "${R3ncod3dChunkName}.log"
echo "::endgroup::"

date
rm ffmpeg2pass*.log
sleep 2s

echo "::group:: [i] Mediainfo for r3ncod3d SubChunk"
mediainfo ${ChunkEncDir}/${R3ncod3dChunkName}.webm
echo "::endgroup::"

echo "::group:: [+] Upload Necessary Files & Stats in GDrive/Server"
tar --create -I"zstd -19" --remove-file -f ${ChunkEncDir}/${R3ncod3dChunkName}.log.tzst ${R3ncod3dChunkName}.log
rclone copy ${ChunkEncDir}/ ${LocationOnIndex}/${AnimeName}/${ChunkEncDir}/ && printf "Uploaded AV1-R3NCOD3D File + Stats\n"
echo "::endgroup::"
