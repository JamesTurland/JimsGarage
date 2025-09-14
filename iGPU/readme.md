# Tests:

# H265 4K -> H264 4K
- AMD: sudo ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi -i bbb-3840x2160-cfg02.mkv -c:v h264_vaapi output.mp4
- Intel: sudo ffmpeg -hwaccel qsv -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format qsv -i bbb-3840x2160-cfg02.mkv -c:v h264_qsv output.mp4

# H265 4K -> H264 1080P
- AMD: sudo ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi -i bbb-3840x2160-cfg02.mkv -vf "scale_vaapi=w=1920:h=1080" -c:v h264_vaapi output.mp4
- Intel: sudo ffmpeg -hwaccel qsv -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format qsv -i bbb-3840x2160-cfg02.mkv -vf "scale_qsv=w=1920:h=1080" -c:v h264_qsv output.mp4

# H265 4K -> H265 1080P
- AMD: sudo ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi -i bbb-3840x2160-cfg02.mkv -vf "scale_vaapi=w=1920:h=1080" -c:v hevc_vaapi output.mp4
- Intel: sudo ffmpeg -hwaccel qsv -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format qsv -i bbb-3840x2160-cfg02.mkv -vf "scale_qsv=w=1920:h=1080" -c:v hevc_qsv output.mp4

# AV1 1080P -> H265 1080P
- AMD: sudo ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi -i Sparks-5994fps-AV1-10bit-1920x1080-2194kbps.mp4 -c:v hevc_vaapi output.mp4
- Intel: sudo ffmpeg -hwaccel qsv -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format qsv -i Sparks-5994fps-AV1-10bit-1920x1080-2194kbps.mp4 -c:v hevc_qsv output.mp4

# AV1 1080P -> H264 1080P
- AMD: sudo ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi -i Sparks-5994fps-AV1-10bit-1920x1080-2194kbps.mp4 -vf "scale_vaapi=w=1920:h=1080" -c:v h264_vaapi output.mp4
- Intel: sudo ffmpeg -hwaccel qsv -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format qsv -i Sparks-5994fps-AV1-10bit-1920x1080-2194kbps.mp4 -c:v h264_qsv output.mp4

# H264 4K -> H264 1080P
- AMD: sudo ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi -i Meridian_UHD4k5994_HDR_P3PQ.mp4 -vf "scale_vaapi=w=1920:h=1080" -c:v h264_vaapi output.mp4
- Intel: sudo ffmpeg -hwaccel qsv -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format qsv -i Meridian_UHD4k5994_HDR_P3PQ.mp4 -vf "scale_qsv=w=1920:h=1080" -c:v h264_qsv output.mp4