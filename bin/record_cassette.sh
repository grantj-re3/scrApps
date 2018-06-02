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
#  Fedora 25: alsa_input.usb-Solid_State_System_Co._Ltd._USB_PnP_Audio_Device-00.analog-stereo
PA_SOURCE_RE="alsa_input.usb-Solid_State_System_Co._Ltd._USB_PnP_Audio_Device-"
PA_SOURCE_LABEL="USB Cassette"
PA_VOLUME=65536		# 0=mute; 65536=100% (ie. max without clipping)

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

	Usage1:  $app  -d H:M:S [-o OUT_MP3_FILENAME]
	Usage2:  $app  -p
	Usage3:  $app  --help|-h

	  -d specifies the [d]uration in H:M:S (hours:minutes:seconds) format
	     where H, M and S can be any non-negative integer (eg. 0:91:30).
	  -o specifies the [o]utput MP3 filename;
	     default filename is "$FNAME4MSG";
	     default directory is "$DEFAULT_DIR";
	     you can write to your current directory using "-o ./OUT_MP3_FILENAME"
	  -p causes the program to [p]rompt the user for the duration and output
	     MP3 filename.
	  --help|-h shows this [h]elp message.

	The names of the pulse-audio input devices connected now are:
	EO_USAGE_MSG
  pacmd list-sources |grep -P "^\s*name: "
  exit 1
}

##############################################################################
# get_cli_option(cli_args) -- Return the command line options in vars:
#   copt_hms, copt_path, copt_prompt4params
##############################################################################
get_cli_option() {
  copt_hms=""
  copt_path="$DEFAULT_PATH"		# Assume the default file path
  copt_prompt4params=0			# Assume we will not prompt for path

  while [ $# -gt 0 ] ; do
    case "$1" in
      -d )
        shift
        copt_hms="$1"
        shift
        ;;

      -o )
        shift
        copt_path="$1"
        shift
        ;;

      -p )
        copt_prompt4params=1
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
  hms="$1"
  path="$2"
  copt_prompt4params="$3"

  [ $copt_prompt4params = 1 ] && prompt4params "$path"
  if ! echo "$path" |egrep -q "^/|^\."; then
    path="$DEFAULT_DIR/$path"	# Use default dir
  fi

  # Calculate number of seconds to record
  if ! echo "$hms" |grep -q -P "^\d+:\d+:\d+$"; then
    usage_exit "Duration must be in the format H:M:S"
  fi
  seconds=`echo "$hms" |awk -F: '{print $1*3600 + $2*60 + $3}'`
}

##############################################################################
# Prompt for parameters: H:M:S & path
# Return: hms & path
##############################################################################
prompt4params() {
  copt_path="$1"

  echo -ne "Enter duration in the format 'H:M:S': "
  read hms

  echo -e "\n[The default MP3 output filename is: $copt_path]"
  echo -ne  "Enter MP3 output filename [Press Enter for default]: "
  read path			# Filename or absolute path or relative path

  [ "$path" = "" ] && path="$copt_path"		# Use default or command line filename
  echo "--------------------"
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
    grep -P "^\s*name: " |
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
setup_vars "$copt_hms" "$copt_path" "$copt_prompt4params"
find_source_audio_device

echo -e "\n$PA_SOURCE_LABEL device is:"
echo "  $pa_source"

echo -e "\nSetting $PA_SOURCE_LABEL as default audio device..."

pacmd set-default-source "$pa_source"
echo "Setting $PA_SOURCE_LABEL volume..."
pacmd set-source-volume "$pa_source" $PA_VOLUME

echo -e "\n\nWriting to file:  $path"
echo -e     "Recording for:    $seconds seconds (ie. Hr:Min:Sec = $hms)\n\n"

make_dir "$DEFAULT_DIR"
cmd="arecord -f cd -d $seconds -t raw |lame -r - \"$path\""
echo "Command: $cmd"
echo
eval $cmd

echo -e "\nFINISHED!  Press any key to close program."
read ans

