#!/bin/bash

# + ${LocationOnIndex##*/}/${AnimeName}/SourceVideoChunks/${AnimeName}.Ep${Episode}.${InputRes}.${AudioType}.part_%02d.mkv
# > ${LocationOnIndex##*/}/${AnimeName}/ArchiveChunks/${AnimeName}.Ep${Episode}.${OutputRes}.vp9.${AudioType}.part_%02d.mkv

cd -- "$GITHUB_WORKSPACE"
mkdir -p ${LocationOnIndex##*/}/${AnimeName}/{ArchiveChunks,VP9_Stats}

echo "::group:: [i] Download the File Chunk"
export InputChunkFullName="${AnimeName}.Ep${Episode}.${InputRes}.${AudioType}.part_${partnum}.mkv"
rclone copy ${LocationOnIndex}/${AnimeName}/SourceVideoChunks/${InputChunkFullName} . \
  && printf "Downloaded %s\n" "${InputChunkFullName}"
export R3ncod3dChunkName=$(echo ${InputChunkFullName} | sed 's|'"${InputRes}"'|'"${OutputRes}"'.vp9|;s|.mkv||')
echo "::endgroup::"

# Set Tuning Parameters According to Output Resolution
# QScale/CRF, TileCol, Threads, etc.
if [[ ${OutputRes} == 720p ]]; then
  export QScale="27" TileCol="1" Threads="6" Period="2.5" xPeriod="6"
elif [[ ${OutputRes} == 576p ]]; then
  export QScale="28" TileCol="1" Threads="4" Period="2.0" xPeriod="5"
fi

echo "::group:: [i] Pass the Media through r3ncod3r - Archival Phase"
printf "Archival r3ncode - Pass 1 of 2\n"
${FTOOL_CONVERTER} -loglevel warning -stats -stats_period ${xPeriod} \
  -i ${InputChunkFullName} -map_metadata -1 -map_chapters -1 -map 0:V -c:v libvpx-vp9 \
  -vf "format=pix_fmts=yuv420p10le,scale=-2:${OutputRes%p*}" \
  -g $((FrameRate * 4)) -keyint_min $((FrameRate * 2)) -sc_threshold 0 \
  -b:v 0 -crf ${QScale} -quality good -speed 2 \
  -threads ${Threads} -row-mt 1 -tile-columns ${TileCol} -tile-rows ${TileRow:-0} \
  -lag-in-frames ${FrameRate} -aq-mode 2 -qmin $((QScale / 2)) \
  -pass 1 -avoid_negative_ts 1 -f null /dev/null
sleep 2s && echo && sleep 1s

printf "Archival r3ncode - Pass 2 of 2\n"
${FTOOL_CONVERTER} -loglevel info -stats -stats_period ${Period} \
  -i ${InputChunkFullName} -map_metadata -1 -map_chapters -1 -map 0:V -c:v libvpx-vp9 \
  -vf "format=pix_fmts=yuv420p10le,scale=-2:${OutputRes%p*}" \
  -g $((FrameRate * 4)) -keyint_min $((FrameRate * 2)) -sc_threshold 0 \
  -b:v 0 -crf ${QScale} -quality good -speed ${SpeedProf} \
  -threads ${Threads} -row-mt 1 -tile-columns ${TileCol} -tile-rows ${TileRow:-0} \
  -lag-in-frames ${FrameRate} -aq-mode 2 -qmin $((QScale / 2)) \
  -pass 2 -auto-alt-ref 1 -avoid_negative_ts 1 -f webm -dash 1 \
  ${LocationOnIndex##*/}/${AnimeName}/ArchiveChunks/${R3ncod3dChunkName}.webm \
  2>&1 | tee "${LocationOnIndex##*/}/${AnimeName}/VP9_Stats/${R3ncod3dChunkName}.arc.log"
sed -i 's|\r|\n|g' "${LocationOnIndex##*/}/${AnimeName}/VP9_Stats/${R3ncod3dChunkName}.arc.log"
echo "::endgroup::"

echo "::group:: [i] Mediainfo for r3ncod3d chunk"
mediainfo ${LocationOnIndex##*/}/${AnimeName}/ArchiveChunks/${R3ncod3dChunkName}.webm
echo "::endgroup::"

echo "::group:: [+] Upload Necessary Files & Stats in GDrive/Server"
tar --create -I"zstd -19" --remove-file -f ${LocationOnIndex##*/}/${AnimeName}/VP9_Stats/${R3ncod3dChunkName}.arc.log.tzst \
  ${LocationOnIndex##*/}/${AnimeName}/VP9_Stats/${R3ncod3dChunkName}.arc.log
rclone copy ${LocationOnIndex##*/}/${AnimeName}/ ${LocationOnIndex}/${AnimeName}/ \
  && printf "Uploaded All R3NCOD3D Files+Stats\n"
echo "::endgroup::"
