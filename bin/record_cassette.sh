#!/bin/sh
# record_cassette.sh
#
# Copyright (C) 2014
# Licensed under GPLv3. GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# http://www.gnu.org/licenses/
#
# PURPOSE
# The purpose of this program is to perform a recording of one side of
# an audio cassette tape played on a sound-source device (in my case a
# Ezcap Super USB Cassette Capture cassette-to-MP3 device) into an MP3
# sound file. This is invoked from the command line for simplicity (so
# that a non-technical user does not have to operate some flexible but
# complicated program like Audacity).
#
# ENVIRONMENT
# The bash shell running under Fedora 17 or Fedora 20 Linux. I imagine it
# would also work under other Linux distributions.
#
# REQUIRES
# - Recorder for ALSA  soundcard driver:	man arecord
# - Pulse Audio:	man pacmd; man pulse-cli-syntax
# - LAME:		man lame
##############################################################################
app=`basename $0`

# For Ezcap Super USB Cassette Capture:
#  Fedora 17: alsa_input.usb-Solid_State_System_Co._Ltd._USB_PnP_Audio_Device-00-Device_1.analog-stereo
#  Fedora 20: alsa_input.usb-Solid_State_System_Co._Ltd._USB_PnP_Audio_Device-00-Device.analog-stereo
PA_SOURCE_RE="alsa_input.usb-Solid_State_System_Co._Ltd._USB_PnP_Audio_Device-"
PA_VOLUME=65536		# 0=mute; 65536=100% (ie. max without clipping)

DEFAULT_NOM_MINUTES=45	# Nominal duration of audio cassette side to be recorded
SECONDS_EXTRA=90	# Extra seconds to add to minutes to be recorded
SECONDS_TEST=15		# Total seconds to record in test-mode

DEFAULT_DIR=$HOME/rec_cassette
FNAME_PREFIX="recording."
FNAME_SUFFIX=".mp3"
FNAME_DATE_FMT="%Y%m%d.%H%M%S"

FNAME4MSG="${FNAME_PREFIX}yymmdd.HHMMSS$FNAME_SUFFIX"
DEFAULT_PATH="$DEFAULT_DIR/$FNAME_PREFIX`date \"+$FNAME_DATE_FMT\"`$FNAME_SUFFIX"

##############################################################################
# usage_exit(msg) -- Display specified message, then usage-message, then exit
##############################################################################
usage_exit() {
  msg="$1"
  cat <<-EO_USAGE_MSG |sed 's/^	//' >&2
	$msg

	Usage:  $app  [-m 15|30|45|60] [-o OUT_MP3_FILENAME | -p]
	Usage:  $app  --test|-t
	Usage:  $app  --help|-h

	Where:
	  -m specifies the nominal duration in [m]inutes of one side of the
	     cassette to be recorded.
	  -o specifies the [o]utput MP3 filename;
	     default filename is "$FNAME4MSG";
	     default directory is "$DEFAULT_DIR";
             you can write to your current directory using "-o ./OUT_MP3_FILENAME"
	  -p causes the program to [p]rompt the user for the output MP3 filename.
	  --test|-t causes the program to perform a [t]est recording for $SECONDS_TEST seconds.
	  --help|-h shows this [h]elp message.

	The names of the pulse-audio input devices connected now are:
	EO_USAGE_MSG
  pacmd list-sources |egrep "^[[:space:]]*name: "
  exit 1
}

##############################################################################
# get_cli_option(cli_args) -- Return the command line options in vars:
#   copt_nom_minutes, copt_path, copt_prompt4path, copt_test
##############################################################################
get_cli_option() {
  copt_nom_minutes="$DEFAULT_NOM_MINUTES"	# Assume the default nominal-minutes
  copt_path="$DEFAULT_PATH"		# Assume the default file path
  copt_prompt4path=0			# Assume we will not prompt for path
  copt_test=0				# Assume we will not use test-mode

  while [ $# -gt 0 ] ; do
    case "$1" in
      -m )
        shift
        copt_nom_minutes="$1"
        shift
        ;;

      -o )
        shift
        copt_path="$1"
        shift
        ;;

      -p )
        copt_prompt4path=1
        shift
        ;;

      --test | -t )
        copt_test=1
        shift
        ;;

      --help | -h )
        usage_exit
        ;;

      *)
        usage_exit "Invalid option '$1'"
    esac
  done
}

##############################################################################
# Setup program variables
##############################################################################
setup_vars() {
  copt_nom_minutes="$1"
  copt_path="$2"
  copt_prompt4path="$3"
  copt_test="$4"

  path="$copt_path"
  if ! echo "$path" |egrep -q "^/|^\."; then
    path="$DEFAULT_DIR/$copt_path"	# Use default dir
  fi

  # Test mode
  if [ $copt_test = 1 ]; then
    seconds=$SECONDS_TEST
    return
  fi

  # Calculate number of seconds to record
  if ! echo "$copt_nom_minutes" |egrep -q "^(15|30|45|60)$"; then
    usage_exit "Nominal minutes must be one of 15,30,45,60."
  fi
  seconds=`expr \( $copt_nom_minutes \* 60 \) + $SECONDS_EXTRA`

  # Prompt for file path
  if [ $copt_prompt4path = 1 ]; then
    echo     "[The default MP3 output filename is: $copt_path]"
    echo -ne "Enter MP3 output filename [Press Enter for default]: "
    read path			# Filename or absolute path or relative path

    if [ "$path" = "" ]; then
      path="$copt_path"		# Use default or command line filename

    elif ! echo "$path" |egrep -q "^/|^\."; then
      path="$DEFAULT_DIR/$path"	# Use default dir

    fi
  fi
}

##############################################################################
# Make directory if is doesn't already exist
##############################################################################
make_dir() {
  [ ! -d "$DEFAULT_DIR" ] && mkdir "$DEFAULT_DIR"
}

##############################################################################
# Find audio device from the Pulse Audio list of sources matching
# the regular expression given in PA_SOURCE_RE.
##############################################################################
find_source_audio_device() {
  pa_source=`pacmd list-sources |
    egrep "^[[:space:]]*name: " |
    egrep "$PA_SOURCE_RE" |
    tail -1 |
    sed 's/^[ 	]*name: *//; s/^<//; s/>$//'`

  if [ -z "$pa_source" ]; then
    echo "No sound source found matching the regular expression:" >&2
    echo "  \"$PA_SOURCE_RE\"" >&2
    usage_exit "Is sound device configured (in regular expression PA_SOURCE_RE) and plugged in?"
  fi
}

##############################################################################
# main()
##############################################################################
get_cli_option $@
setup_vars "$copt_nom_minutes" "$copt_path" "$copt_prompt4path" "$copt_test"
find_source_audio_device

echo -e "\nSetting USB cassette as default audio device..."
pacmd set-default-source "$pa_source"
echo -e "\n\nSetting USB cassette volume..."
pacmd set-source-volume "$PA_SOURCE" $pa_source

echo -e "\n\nWriting to file:  $path"
if [ $copt_test = 1 ]; then
  echo -e "Recording for:    $seconds seconds (for testing)\n\n"
else
  echo -e "Recording for:    $copt_nom_minutes minutes (plus $SECONDS_EXTRA seconds extra)\n\n"
fi

make_dir "$DEFAULT_DIR"
arecord -f cd -d $seconds -t raw |lame -r - "$path"

echo -e "\nFINISHED!  Press any key to close program."
read ans

