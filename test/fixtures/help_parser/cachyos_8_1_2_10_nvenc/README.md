# Captured FFmpeg profile

Captured locally from CachyOS package `ffmpeg 2:8.1.2-10.1` (GCC 16).
This later package revision disables the `magicyuv` decoder and advertises
`--enable-nvenc`, `--enable-nvdec`, VAAPI and QSV.

Files are unmodified excerpts of `-encoders`, `-filters`, and
`-h encoder=h264_nvenc`. Keeping a separate profile means future parser
changes run against each captured binary profile.
