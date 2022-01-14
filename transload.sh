#!/bin/bash

set -eo pipefail

# >> ${LocationOnIndex##*/}/${AnimeName}/

cd ${WorkDir}
mkdir -p ${LocationOnIndex##*/}/{${AnimeName}/SourceVideoChunks,ChunkRegistry}

echo "::group:: [i] Download the File"
printf "Downloading Original Media\n"
${FTOOL_CONVERTER} -loglevel warning -stats -stats_period 5 -y \
  -headers "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:94.0) Gecko/20100101 Firefox/94.0" \
  -headers "Origin: https://vidstream.pro" -headers "Referer: https://vidstream.pro/" \
  -i ${InputMediaURL} -codec copy -movflags +faststart ${LocationOnIndex##*/}/${AnimeName}/${AnimeName}.${InputRes}.${AudioType}.mp4
echo "::endgroup::"

echo "::group:: [i] Mediainfo for original file"
mediainfo ${LocationOnIndex##*/}/${AnimeName}/${AnimeName}.${InputRes}.${AudioType}.mp4
echo "::endgroup::"

echo "::group:: [i] Split the Video into Parts"
TotalFrames="$(mediainfo --Output='Video;%FrameCount%' ${LocationOnIndex##*/}/${AnimeName}/${AnimeName}.${InputRes}.${AudioType}.mp4)"
ChunkDur="180" # 3 minutes
ChunkFramecount="$((FrameRate * ChunkDur))" # 4320
Partitions=$(( TotalFrames / ChunkFramecount ))
printf "[!] The Source \"%s\" Has \"%s\" Frames\n" "${AnimeName}.${InputRes}.${AudioType}.mp4" "${TotalFrames}"
printf "Getting Positional Information of I-frames ...\n\n"
${FTOOL_PROBER} -loglevel warning -threads 8 -select_streams v -show_frames \
  -show_entries frame=pict_type -of csv ${LocationOnIndex##*/}/${AnimeName}/${AnimeName}.${InputRes}.${AudioType}.mp4 \
  | grep -n I | cut -d ':' -f 1 > Iframe_indices.txt
BOUNDARY_GOP=""
for x in $(seq 1 ${Partitions}); do
  for i in $(< Iframe_indices.txt); do
    if [[ ${i} -lt "$((ChunkFramecount * x))" ]]; then continue; fi
    BOUNDARY_GOP+="$((i - 1))," && break
  done
done
BOUNDARY_GOP=$(echo ${BOUNDARY_GOP} | sed 's/,,$//;s/,$//')
# If last chunk size is less than 1/4 of the chunksize, then merge it with previous chunk
if [[ $(( TotalFrames - ${BOUNDARY_GOP##*,} )) -le $(( ChunkFramecount / 4 )) ]]; then
  BOUNDARY_GOP=${BOUNDARY_GOP%,*}
fi
printf "[i] GOP Boundaries in Source Video:\n%s\n\n" "${BOUNDARY_GOP}"
printf "Splitting Source Video into Multiple Chunks\n\n"
mkvmerge --quiet --output ${LocationOnIndex##*/}/${AnimeName}/SourceVideoChunks/${AnimeName}.${InputRes}.${AudioType}.part_%02d.mkv \
  -A -S -B -M -T --no-global-tags --no-chapters --split frames:"${BOUNDARY_GOP}" \
  "${LocationOnIndex##*/}/${AnimeName}/${AnimeName}.${InputRes}.${AudioType}.mp4"
ls -lAog ${LocationOnIndex##*/}/${AnimeName}/SourceVideoChunks
echo "::endgroup::"

export Chunks=$(ls ${LocationOnIndex##*/}/${AnimeName}/SourceVideoChunks/${AnimeName}.${InputRes}.${AudioType}.part_*.mkv | wc -l)
export input_matrix=$(for i in $(seq -w 01 ${Chunks}); do printf "%s, " "${i}"; done)
export matrix="[${input_matrix%,*}]"
echo "matrix=${matrix}" >> $GITHUB_ENV

if [[ ${AudioType} == "EngSub" ]]; then
  export AudLang="en"
elif [[ ${AudioType} == "EngDub" ]]; then
  export AudLang="ja"
fi
echo "AudLang=${AudLang}" >> $GITHUB_ENV

echo "::group:: [i] Separate the Audio"
${FTOOL_CONVERTER} -loglevel warning -stats -stats_period 5 -y \
  -i ${LocationOnIndex##*/}/${AnimeName}/${AnimeName}.${InputRes}.${AudioType}.mp4 \
  -map 0:a -c:a libfdk_aac -profile:a aac_he -b:a 64k -ac 2 \
  -metadata:s:0 language=${AudLang} -avoid_negative_ts 1 -movflags +faststart \
  ${LocationOnIndex##*/}/${AnimeName}/${AnimeName}.audio.mp4
echo "::endgroup::"

echo "::group:: [i] Upload All Original + Split Media"
rclone copy ${LocationOnIndex##*/}/ ${LocationOnIndex##*/}/ && printf "All Files Uploading Done\n"
echo "::endgroup::"
