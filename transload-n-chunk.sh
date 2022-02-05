#!/usr/bin/env bash

set -eo pipefail

echo "::group:: [i] Prepare YT-DLP"
sudo apt-fast install -qqy mpv &>/dev/null
python3 -m pip install mutagen pycryptodome &>/dev/null
python3 -m pip install --no-deps -U yt-dlp
echo "::endgroup::"

export ChunkDir=$(openssl rand -hex 8)
echo "ChunkDir=${ChunkDir}" >> $GITHUB_ENV
export ChunkEncDir=$(openssl rand -hex 12)
echo "ChunkEncDir=${ChunkEncDir}" >> $GITHUB_ENV

[[ ${AudLang} == "en" ]] && export AudioType="EngDub"
[[ ${AudLang} == "ja" ]] && export AudioType="EngSub"
echo "AudioType=${AudioType}" >> $GITHUB_ENV

mkdir -p ${AnimeName}/${ChunkDir}/

echo "::group:: [i] Download the Original File Stream"
yt-dlp --concurrent-fragments 16 --add-header 'Origin':'https://vidstream.pro' --add-header 'Referer':'https://vidstream.pro/' \
  --add-header 'User-Agent':'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:94.0) Gecko/20100101 Firefox/94.0' \
  --output MEDIA.mp4 -- ${InputMediaURL}
echo "::endgroup::"

echo "::group:: [i] mediainfo for the Original File Stream"
mediainfo MEDIA.mp4
echo "::endgroup::"

echo "::group:: [i] Separating Audio+Video\n"
${FTOOL_CONVERTER} -loglevel warning -stats -stats_period 10 -y -i MEDIA.mp4 -map_metadata -1 \
  -map 0:V -c:v copy -avoid_negative_ts 1 -movflags +faststart primary_video.mp4 \
  -map 0:a -c:a copy -avoid_negative_ts 1 -movflags +faststart primary_audio.mp4
echo "::endgroup::"

rm MEDIA.mp4

echo "::group:: [i] Convert Audio"
${FTOOL_CONVERTER} -loglevel error -stats -stats_period 5 -y -i primary_audio.mp4 \
  -map_metadata -1 -map 0:a -c:a libfdk_aac -profile:a aac_he -b:a 48k -ac 2 \
  -metadata:s:0 language=${AudLang} -avoid_negative_ts 1 -movflags +faststart \
  ${AnimeName}/${AnimeName}.Ep${Episode}.audio-${AudLang}.mp4
echo "::endgroup::"

echo "::group:: [i] Split the Video into Parts"
export TotalFrames="$(mediainfo --Output='Video;%FrameCount%' primary_video.mp4)"
FrameRate="$(mediainfo --Output='Video;%FrameRate%' primary_video.mp4)"
if [[ ${FrameRate} == "23.976" || ${FrameRate} == "24.000" ]]; then
  export FrameRate="24"
elif [[ ${FrameRate} == "25.000" ]]; then
  export FrameRate="25"
elif [[ ${FrameRate} == "29.970" || ${FrameRate} == "30.000" ]]; then
  export FrameRate="30"
fi
echo "FrameRate=${FrameRate}" >> $GITHUB_ENV
export ChunkDur="80" # 1 minute 20 seconds
export ChunkFramecount="$((FrameRate * ChunkDur))"
export Partitions=$(( TotalFrames / ChunkFramecount ))
printf "[!] The Source Has \"%s\" Frames\n" "${TotalFrames}"
printf "Getting Positional Information of I-frames ...\n\n"
${FTOOL_PROBER} -loglevel warning -threads 8 -select_streams v -show_frames \
  -show_entries frame=pict_type -of csv primary_video.mp4 \
  | grep -n I | cut -d ':' -f 1 > Iframe_indices.txt
BOUNDARY_GOP=""
for x in $(seq 1 ${Partitions}); do
  for i in $(< Iframe_indices.txt); do
    if [[ ${i} -lt "$((ChunkFramecount * x))" ]]; then continue; fi
    BOUNDARY_GOP+="$((i - 1))," && break
  done
done
export BOUNDARY_GOP=$(echo ${BOUNDARY_GOP} | sed 's/,,$//;s/,$//')
# If last chunk size is less than 1/4 of the chunksize, then merge it with previous chunk
if [[ $(( TotalFrames - ${BOUNDARY_GOP##*,} )) -le $(( ChunkFramecount / 4 )) ]]; then
  export BOUNDARY_GOP=${BOUNDARY_GOP%,*}
fi
printf "[i] GOP Boundaries in Source Video:\n%s\n\n" "${BOUNDARY_GOP}"
printf "Splitting Source Video into Multiple Chunks\n\n"
mkvmerge --quiet --output ${AnimeName}/${ChunkDir}/${AnimeName}.Ep${Episode}.${AudioType}.part_%02d.mkv \
  -A -S -B -M -T --no-global-tags --no-chapters --split frames:"${BOUNDARY_GOP}" primary_video.mp4
ls -lAog ${AnimeName}/${ChunkDir}
echo "::endgroup::"

export Chunks=$(ls ${AnimeName}/${ChunkDir}/${AnimeName}.Ep${Episode}.${AudioType}.part_*.mkv | wc -l)
echo "Chunks=${Chunks}" >> $GITHUB_ENV

echo "::group:: [i] Upload All Chunks + Audio"
rclone copy ${AnimeName}/ ${LocationOnIndex}/${AnimeName}/ && printf "Audio + Chunks Uploading Done\n"
echo "::endgroup::"
