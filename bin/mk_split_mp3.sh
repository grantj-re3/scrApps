#/bin/sh
# mk_split_mp3.sh
#
# Split big MP3 file (18 hours; 2.6GB) into smaller files (9x 2h10m)
# This quick hack creates a script which then needs to be run. Eg.
#
#   ./mk_split_mp3.sh > split_9xmp3.sh  # Create split_9xmp3.sh script
#   sh split_9xmp3.sh			# Create 9 mp3 files


echo
echo "# Duration 18:03:29.59"
echo

hour=0
while [ $hour -lt 18 ]; do
  #ffmpeg -i big.mp3  -vn -acodec copy -ss 00:00:00 -t 02:10:00 out_00hour.mp3
  printf "ffmpeg -i big.mp3  -vn -acodec copy -ss %02d:00:00 -t 02:10:00 out_%02dhour.mp3\n" $hour $hour
  hour=`expr $hour + 2`
done

