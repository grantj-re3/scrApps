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


##############################################################################
# Class to process musical chords
##############################################################################
class Chord
  SHARP_CHAR = '#'
  FLAT_CHAR = 'b'

  SHOW_BAD_ROOT = '??'	# What to display for an invalid root-chord

  # Delimiter to subdivide @remainder into parts (for transposition).
  # Assign nil to disable transposition of @remainder.
  DELIM = '/'	

  # - All arrays of chords below must be of length 12.
  #
  # - For a given subscript, each value (in the various arrays) must
  #   represent the *same* root-chord. Eg. The values of subscript 1
  #   in the various arrays are 'A#', 'Bb' and 'Cbb' and these values
  #   all represent the same root-chord.
  CHROMATIC_ROOT_CHORDS = {
    # All possible representations of chords for input-detection
    :input => {
      # - All natural chords; Most single sharps (except B# & E#)
      # - B# & E#; All double sharps; Some repeats
      :sharp1 => %w{A   A#  B   C   C#  D     D#  E   F   F#  G   G#},
      :sharp2 => %w{G## A#  A## B#  B## C##   D#  D## E#  E## F## G#},

      # - All natural chords; Most single flats (except Cb & Fb)
      # - Cb & Fb; All double flats; Some repeats
      :flat1  => %w{A   Bb  B   C   Db  D     Eb  E   F   Gb  G   Ab},
      :flat2  => %w{Bbb Cbb Cb  Dbb Db  Ebb   Fbb Fb  Gbb Gb  Abb Ab},
    },

    # Preferred representation of chords for output
    :output => {
      :normal => %w{A   Bb  B   C   C#  D     D#  E   F   F#  G   G#},
    },
  }

  # Default number of semitones to transpose (positive or negative integer)
  @@transpose_hm_semitones = 0

  attr_reader :chord, :root, :remainder, :root_index

  ############################################################################
  # Create a new object
  ############################################################################
  def initialize(chord_text)
    @chord = chord_text

    # BEWARE: str[N] has different behaviour in Ruby 1.8.7 vs 1.9.
    # Use str[N..N] to return a single char in both versions.
    if @chord.length > 1 && (@chord[1..1] == SHARP_CHAR || @chord[1..1] == FLAT_CHAR)
      if @chord.length > 2 && @chord[1..1] == @chord[2..2]
        # @root = A##,B##,C##...G##,Abb,Bbb,Cbb...Gbb
        max_idx = 2
      else
        # @root = A#,B#,C#...G#,Ab,Bb,Cb...Gb
        max_idx = 1
      end

    else
      # @root = A,B,C...G
      max_idx = 0
    end

    @root = @chord[0 .. max_idx].capitalize	# Eg. G,G#,G##,Gb,Gbb
    @remainder = @chord[(max_idx+1) .. -1]	# Eg. 7,m,maj7,sus4,+,aug,dim
    calc_root_index	# @root_index==nil means chord-root is invalid
  end

  ############################################################################
  # Set the number of (positive or negative) semitones to transpose
  ############################################################################
  def self.transpose_hm_semitones=(hm_semitones)
    @@transpose_hm_semitones = hm_semitones
  end

  ############################################################################
  # Calculate the index of @root within the CHROMATIC_ROOT_CHORDS arrays.
  # Return index 0..11 or nil if the root-chord is invalid.
  ############################################################################
  def calc_root_index
    @root_index = nil
    CHROMATIC_ROOT_CHORDS[:input].each_value{|roots|
      @root_index = roots.find_index(@root)
      return if @root_index
    }
  end

  ############################################################################
  # Transpose the root-chord by the amount @@transpose_hm_semitones.
  # Return the transposed root-cord as a string else return nil if the
  # original chord was invalid.
  # Valid root-chords are listed in CHROMATIC_ROOT_CHORDS.
  ############################################################################
  def transpose_root
    return nil unless @root_index
    new_index = (@root_index + @@transpose_hm_semitones) % 12
    CHROMATIC_ROOT_CHORDS[:output][:normal][new_index]
  end

  ############################################################################
  # Transpose @remainder parts of the chord. Parts to be transposed are
  # components immediately followed by DELIM (usually '/') by the amount
  # @@transpose_hm_semitones. You can have several DELIM characters to
  # transpose several parts.
  # Eg. For @@transpose_hm_semitones = 2, this string:
  #   [Cm/Bb] [Cm/F#] [C/D] [Cm/E_bass/Fplucked]
  # is transposed to:
  #   [Dm/C] [Dm/G#] [D/E] [Dm/F#_bass/Gplucked]
  ############################################################################
  def transpose_remainder
    return @remainder unless DELIM
    transposed_parts = []
    @remainder.split(DELIM).each_with_index{|part_str, i|
      if i == 0		# First part before note-modifer. Eg. 7, m, maj7
        transposed_parts << part_str
      else	# Note-modifer part. Must start with a valid note (ie. chord-root) Eg. G,Gb,Gbb,G#,G##
        transposed_parts << "#{DELIM}#{Chord.new(part_str).transpose}"
      end
    }
    transposed_parts.join
  end

  ############################################################################
  # Transpose the chord. Return as a new Chord object.
  ############################################################################
  def transpose
    transpose_root ? Chord.new(transpose_root+transpose_remainder) : Chord.new(SHOW_BAD_ROOT+transpose_remainder)
  end

  ############################################################################
  # To string
  ############################################################################
  def to_s
    @root+@remainder
  end
end


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
    if other_args.length == 1		# TEXT_FILE
      fname = other_args[0]
      usage_exit "Error: File '#{fname}' must exist and be readable." unless File.readable?(fname)

    elsif other_args.length == 0	# No TEXT_FILE
      usage_exit "No text file specified."

    else				# Too many files or unexpected params
      msg_lines = []
      msg_lines << "Error: Unexpected parameters:"
      other_args.each{|arg| msg_lines << "* #{arg}"}
      usage_exit msg_lines.join("\n")
    end

    { :num_semitones_up => num_semitones_up, :filename => fname } # Return hash
  end

  ############################################################################
  # main()
  ############################################################################
  def self.main
    clopts = self.get_command_line_options
    fname = clopts[:filename]
    LyricChordLine.transpose_hm_semitones = clopts[:num_semitones_up]

    File.open(fname) {|file|
      file.each_line{|line_text| puts LyricChordLine.new(line_text).transpose}
    }
  end

end

##############################################################################
# Invoke main()
##############################################################################
LyricChordLine.main
exit 0

