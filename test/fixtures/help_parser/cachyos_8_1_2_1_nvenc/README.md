# Captured FFmpeg profile

Captured locally from CachyOS package `ffmpeg 2:8.1.2-1.1` (GCC 16.1.1).
The binary advertises `--enable-nvenc`, `--enable-nvdec`, VAAPI and QSV.

Files are unmodified excerpts of `-encoders`, `-filters`, and
`-h encoder=h264_nvenc`. They exercise listing flags, filter media directions,
headers, AVOptions, ranges, defaults, and enum choices.
