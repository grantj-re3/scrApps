#!/usr/bin/ruby
#
# File:		transpose_chords.rb
# Author:	Grant Jackson
# Package:	N/A
# Environment:	Ruby 2.0.0 & 1.8.7
#
# Copyright (C) 2014
# Licensed under GPLv3. GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# http://www.gnu.org/licenses/
#
# Transpose a text file which contains song lyrics and inline chords
# within square brackets. Square brackets must not be used anywhere
# within the file unless they contain a single chord. Chords must:
# - be in the range A..G
# - be optionally followed by 1 or 2 sharps or flats
# - be optionally followed by the remainder of the chord (eg. '7', 'm', 'sus4')
#
# Examples of *valid* chords within square brackets:
#   [A] [Bb7] [Cm] [cm] [D#maj7] [E##+] [Gbbsus4]
# Examples of *invalid* chords within square brackets:
#   [H] [h] [Zm] [zm]
##############################################################################

# Add dirs to the library path
$: << File.expand_path("../lib", File.dirname(__FILE__))

require 'chord'

##############################################################################
# Class to process a line of lyrics with embedded chords
##############################################################################
class LyricChordLine
  # Output chords using these delimiters
  DELIM_OUT0 = '['	# String used to *output* start of chord-token
  DELIM_OUT1 = ']'	# String used to *output* end of chord-token

  # Read chords from input using these delimiters
  DELIM_RE0 = '\['	# Regex version of start of chord-token
  DELIM_RE1 = '\]'	# Regex version of end of chord-token

  MATCH_TOKEN = Regexp.new("#{DELIM_RE0}[^#{DELIM_RE1}]*#{DELIM_RE1}")	# Used by gsub()
  SPLIT_RE = Regexp.new("#{DELIM_RE0} *| *#{DELIM_RE1}")		# Used by split()

  ############################################################################
  # Create a new object
  ############################################################################
  def initialize(line_text)
    @line_text = line_text
  end

  ############################################################################
  # Transpose the LyricChordLine object by the amount specified by
  # @@transpose_hm_semitones
  ############################################################################
  def transpose
    @line_text.gsub(MATCH_TOKEN){|chord_token|		# Eg. chord_token="[Bbm]"
      chord_token_parts = chord_token.split(SPLIT_RE)
      chord = chord_token_parts[1]			# Eg. chord="Bbm"
      "#{DELIM_OUT0}#{Chord.new(chord).transpose}#{DELIM_OUT1}"
    }
  end

  ############################################################################
  # Set the number of (positive or negative) semitones to transpose
  ############################################################################
  def self.transpose_hm_semitones=(hm_semitones)
    Chord.transpose_hm_semitones = hm_semitones
  end

  ############################################################################
  # Show an optional message (given by the argument), then the usage
  # info, then exit the program
  ############################################################################
  def self.usage_exit(message=nil)
    STDERR.puts "#{message}\n" if message
    app = File.basename($0)

    STDERR.puts <<-MSG_COMMAND_LINE_ARGS.gsub(/^\t*/, '')
	Usage:
	  #{app}  -h|--help
	  #{app}  -u|-d NUM_SEMITONES_UP_OR_DOWN  TEXT_FILE
	  #{app}  -f FROM_CHORD  -t TO_CHORD  TEXT_FILE
	where: FROM_CHORD and TO_CHORD must start with a root-chord
	  and: A root-chord is A-G, A#-G#, Ab-Gb, A##-G## or Abb-Gbb

	TEXT_FILE must contain lyrics with inline chords. Chords must be placed between
	square brackets, eg. [Bbmaj7]. The chord-part after the root-chord (eg. 'maj7')
	shall be unchanged during the transposition unless one or more '/' characters
	are present. In that case any root-chord (or note) which appears immediately
	after the '/' shall also be transposed. Eg. [C7/G] to [D7/A]

	The command:      #{app}  -u 2  song.txt
	will change this: [G]Or [Am]when [G/B]the [Am]valley's [F]hushed and ...
	to this:          [A]Or [Bm]when [A/C#]the [Bm]valley's [G]hushed and ...

	All of the following commands will transpose down by 3 semi-tones.
	  #{app}  -d 3  song.txt
	  #{app}  -f C   -t a   song.txt  # Upper or lower case chord
	  #{app}  -f G7  -t E7  song.txt  # '7' is ignored
    MSG_COMMAND_LINE_ARGS
    exit 1
  end

  ############################################################################
  # Process the command line options then return the calculated variables
  ############################################################################
  def self.get_command_line_options
    other_args = []
    num_semitones_up = nil
    from_key = nil
    to_key = nil

    while !ARGV.empty?
      arg = ARGV.shift
      case arg
      when "-u"			# NUM_SEMITONES_UP
        num_semitones_up = ARGV.shift.to_i

      when "-d"			# NUM_SEMITONES_DOWN
        num_semitones_up = 0 - ARGV.shift.to_i

      when "-f"			# FROM_CHORD
        from_key = ARGV.shift

      when "-t"			# TO_CHORD
        to_key = ARGV.shift

      when "-h","--help"	# HELP
        usage_exit

      else			# TEXT_FILE or unexpected params
        other_args << arg
      end	# case
    end		# while

    if from_key && !to_key || !from_key && to_key
      usage_exit "Error: You must use '-f' and '-t' options together."
    end
    if from_key && to_key
      from_index = Chord.new(from_key).root_index
      to_index = Chord.new(to_key).root_index
      usage_exit "Error: Unrecognised FROM_KEY: '#{from_key}'" unless from_index
      usage_exit "Error: Unrecognised TO_KEY: '#{to_key}'" unless to_index
      num_semitones_up = to_index - from_index
    end
    usage_exit "Error: Use one of the commands below." unless num_semitones_up

    # Examine args which are not preceded by a known switch
    if other_args.length <= 1		# 0 = read STDIN; 1 = read TEXT_FILE
      other_args.each{|arg| ARGV << arg}	# Reinstate ARGV filename(s)

    else				# Too many files or unexpected params
      msg_lines = []
      msg_lines << "Error: Unexpected parameters:"
      other_args.each{|arg| msg_lines << "* #{arg}"}
      usage_exit msg_lines.join("\n")
    end

    { :num_semitones_up => num_semitones_up } # Return hash
  end

  ############################################################################
  # main()
  ############################################################################
  def self.main
    clopts = self.get_command_line_options
    LyricChordLine.transpose_hm_semitones = clopts[:num_semitones_up]

    begin
      while line_text = gets	# Read lines from command-line args or STDIN
        puts LyricChordLine.new(line_text).transpose
      end

    rescue Exception => e
      usage_exit e
    end
  end

end

##############################################################################
# Invoke main()
##############################################################################
LyricChordLine.main
exit 0

