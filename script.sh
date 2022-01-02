#!/bin/bash

set -eo pipefail

# Make Sure The Environment Is Non-Interactive
export DEBIAN_FRONTEND=noninteractive

echo "::group:: Prepare Tools"
curl -sL "${RCLONE_INSTALL_MIRROR}" | sudo bash 1>/dev/null
mkdir -p ~/.config/rclone
curl -sL "${RCLONE_CONFIG_URL}" > ~/.config/rclone/rclone.conf
cd "$(mktemp -d)"
wget -q ${FTOOL_ARC_URL} || curl -sL ${FTOOL_ARC_URL} -O
tar -xJf ff*.tar.xz --strip-components 1
sudo mv bin/* /usr/local/bin/
cd -
echo "::endgroup::"

# ${InputMediaURL} >> ${InputMediaName} >>>+ FFMPEG +>>> ${OutputMediaName}

echo "::group:: [i] Download the File"
printf "Downloading Original Media\n"
${FTOOL_CONVERTER} -loglevel warning -stats -stats_period 5 -i ${InputMediaURL} \
  -codec copy -movflags +faststart ${InputMediaName}
echo "::endgroup::"

echo "::group:: [i] Mediainfo for original file"
mediainfo ${InputMediaName}
echo "::endgroup::"

echo "::group:: [i] Convert to WebM MP4 Media"
${FTOOL_CONVERTER} -loglevel warning -stats -stats_period 5 -i ${InputMediaName} -map_metadata -1 -map 0:V \
  -c:v libvpx-vp9 -vf "format=pix_fmts=yuv420p10le,scale=-2:576" -g 96 -keyint_min 24 -sc_threshold 0 \
  -b:v 0 -crf 27 -quality good -speed 2 -threads 4 -row-mt 1 -tile-columns 1 -tile-rows 0 \
  -lag-in-frames 24 -aq-mode 2 -qmin 13 -pass 1 -avoid_negative_ts 1 -f null /dev/null
sleep 2s && echo
${FTOOL_CONVERTER} -stats_period 2 -i ${InputMediaName} -map_metadata -1 -map 0:V \
  -c:v libvpx-vp9 -vf "format=pix_fmts=yuv420p10le,scale=-2:576" -g 96 -keyint_min 24 -sc_threshold 0 \
  -b:v 0 -crf 27 -quality good -speed ${SpeedProf:-2} -threads 4 -row-mt 1 -tile-columns 1 -tile-rows 0 \
  -lag-in-frames 24 -aq-mode 2 -qmin 13 -pass 2 -auto-alt-ref 1 \
  -map 0:a -c:a libfdk_aac -profile:a aac_he -b:a 64k -ac 2 \
  -avoid_negative_ts 1 -movflags +faststart \
  ${OutputMediaName} 2>&1 | tee ${OutputMediaName/mp4/log}
sed -i 's|\r|\n|g' ${OutputMediaName/mp4/log}
echo "::endgroup::"

echo "::group:: [i] Mediainfo for r3ncod3d file"
mediainfo ${OutputMediaName}
echo "::endgroup::"

echo "::group:: [+] Upload Necessary Files & Stats in GDrive/Server"
tar --create -I"zstd -19" --remove-file -f ${OutputMediaName/mp4/log}.tzst ${OutputMediaName/mp4/log}
today="$(date +%F)" && mkdir -p UploadZ/${today}
mv ${OutputMediaName/mp4/log}.tzst ${OutputMediaName} ${InputMediaName} UploadZ/
rclone copy UploadZ/ td:/Videos/StreamLoader_UploadZ/ && printf "Successfully Uploaded Files\n"
printf "Go to /Videos/StreamLoader_UploadZ/%s/ to get files\n" "${today}"
echo "::endgroup::"
