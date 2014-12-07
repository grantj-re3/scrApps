#!/usr/bin/ruby
#
# File:		to_chord_above.rb
# Author:	Grant Jackson
# Package:	N/A
# Environment:	Ruby 2.0.0
#
# Copyright (C) 2014
# Licensed under GPLv3. GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# http://www.gnu.org/licenses/
#
# Convert lyric-chord sheets from Chord-Between-Lyrics (CBL) format
# to Chord-Above-Lyrics (CAL) format.
#
# Chord-Between-Lyrics (CBL) format example:
#   [G]Mary had a little lamb, [D7]little lamb, [G]little lamb
#
# Chord-Above-Lyrics (CAL) format example:
#   G                       D7           G
#   Mary had a little lamb, little lamb, little lamb 
##############################################################################

##############################################################################
# An object which takes a CBL-format line-part and understands whether
# it is a chord-token string or a lyric string.
##############################################################################
class ChordLyricPart

  attr_reader :part, :chord, :lyric

  ############################################################################
  def initialize(line_part)
    @part = line_part
    @chord = @part.match(ChordLyricLineParts::MATCH_TOKEN) ? $~[1].strip : nil
    @lyric = @chord ? nil : @part
  end

  ############################################################################
  def chord?
    @chord != nil
  end

  ############################################################################
  def lyric?
    @chord == nil
  end

  ############################################################################
  def empty?
    @part.empty?
  end

end

##############################################################################
# An object which takes a CBL-format line; is able to divide it
# into chord-token and lyric parts; is able to convert it into
# a CAL-format line.
##############################################################################
class ChordLyricLineParts
 
  DELIM_RE0 = '\['	# Regex version of start of chord-token
  DELIM_RE1 = '\]'	# Regex version of end of chord-token

  MATCH_TOKEN = /#{DELIM_RE0}([^#{DELIM_RE1}]*)#{DELIM_RE1}/	# Eg. "[C7]"
  MATCH_PARTS = /^([^#{DELIM_RE0}]*)(#{DELIM_RE0}[^#{DELIM_RE1}]+#{DELIM_RE1})(.*)$/
  MATCH_EOL_SPACES = / $/

  # Special "key-lines" like "Key: [Dm]" (indicating the key of the song)
  # will not be converted into 2 lines during CBL to CAL conversion.
  # We would like such lines to contain a valid chord-token so that
  # it can be recognised as a chord and transposed if required.
  MATCH_KEY_LINE = /^[[:space:]]*key:[[:space:]]*#{MATCH_TOKEN}[[:space:]]*$/i

  # A character to extend the span of a sylable when a long chord is above it.
  # If you are going to convert back and forth between CBL and CAL formats,
  # it would be best to choose a character which does not appear in normal
  # song text (eg. '_' or '~' or '|' but not '-' or '.').
  SPAN_CHAR = '_'

  # Insert multiple SPAN_CHARs (true) or a single SPAN_CHAR (false) into lyrics
  INSERT_MULTI_SPAN_CHARS = true

  NEWLINE = "\n"

  ############################################################################
  # Create an object. If the line contains chord-tokens, divide into
  # parts consisting of chord-tokens and lyrics (ie. non chord-tokens).
  ############################################################################
  def initialize(cbl_line)
    @line = cbl_line
    @has_tokens = @line.match(MATCH_TOKEN)
    @parts = []		# Array of chord-tokens & lyrics

    if @has_tokens
      rest_of_line = @line.chomp
      while(true)
        # If chord-token found: creates [pre_match, match_token, post_match]
        # else: creates empty array
        matches = rest_of_line.scan(MATCH_PARTS).flatten
        break if matches.length == 0
        @parts << ChordLyricPart.new(matches[0])	# Lyric
        @parts << ChordLyricPart.new(matches[1])	# Chord-token
        rest_of_line = matches[2]
      end
      @parts << ChordLyricPart.new(rest_of_line)	# Lyric

      @parts.delete_if{|p| p.empty?}
    end
  end

  ############################################################################
  # If the line contains chord-tokens, return it in the 2-line CAL format
  # else return the original line.
  ############################################################################
  def to_s_chord_above_line
    @has_tokens && !@line.match(MATCH_KEY_LINE) ? to_s_2_lines : @line
  end

  ############################################################################
  # Return a string containing the 2-line CAL format from the line-parts.
  ############################################################################
  def to_s_2_lines
    #puts '=' * 70
    #puts "@parts=#{@parts.inspect}"

    chord_line = ''
    lyric_line = ''
    next_part = nil
    num_pad_next_lyric_part = 0

    # Iterate thru parts (while also looking at the next part)
    @parts.each_with_index{|np, i|
      part = next_part
      next_part = np
      next if i == 0

      if part.chord?
        if next_part.chord?	# Is chord + next is chord
          chord_line << part.chord + ' '
          lyric_line << self.class.pad(0, part.chord + ' ')

        else			# Is chord + next is lyric
          diff_length = next_part.lyric.length - part.chord.length
          if diff_length > 0	# next lyric length > chord length
            chord_line << part.chord << self.class.pad(diff_length)
          else			# next lyric length <= chord length
            chord_line << part.chord + ' '	# chord.length + 1
            num_pad_next_lyric_part = 1 - diff_length
          end

        end
      else			# Is lyric
        chord_line << self.class.pad(part.lyric.length) if i == 1  # Line starts with lyric
        if part.lyric.match(MATCH_EOL_SPACES)
          lyric_line << part.lyric + self.class.pad(num_pad_next_lyric_part)
        else
          lyric_line << ( INSERT_MULTI_SPAN_CHARS ?
            part.lyric + self.class.pad(num_pad_next_lyric_part, nil, SPAN_CHAR) :
            part.lyric + self.class.pad(num_pad_next_lyric_part, nil, ' ', SPAN_CHAR ,1)
          )
        end
        num_pad_next_lyric_part = 0
      end
    }
    if next_part.chord?
      chord_line << next_part.chord
    else
      lyric_line << next_part.lyric
    end
  
    #puts "chord_line<#{chord_line.rstrip}>"
    #puts "lyric_line<#{lyric_line.rstrip}>"

    chord_line.rstrip + NEWLINE + lyric_line.rstrip
  end

  ############################################################################
  # If a single argument is present:
  #   Return a padded string of the length specified by char_count.
  # If 2 arguments are present:
  #   Return a padded string of length specified by char_count plus
  #   the length of to_s_length after it is converted to a string. To
  #   specify a zero-length string you can either use nil or an empty
  #   string (ie. '') for to_s_length.
  # If 3 arguments are present:
  #   As per 2 arguments, but be default pad-character can be specified
  #   to be something other than space.
  # If 5 arguments are present:
  #   As per 3 arguments, but one can specify one or more alternative
  #   characters to be prepended to the front (or left side) of the
  #   default characters.
  ############################################################################
  def self.pad(
      char_count, to_s_length='', default_pad_char=' ',
      front_pad_char=' ', front_pad_char_count=0
    )

    pad_length = char_count + to_s_length.to_s.length
    return '' if pad_length <= 0
    return default_pad_char * pad_length if front_pad_char_count <= 0
    return front_pad_char * pad_length if front_pad_char_count >= pad_length

    front_pad_char * front_pad_char_count + default_pad_char * (pad_length - front_pad_char_count)
  end

  ############################################################################
  def self.main
    while gets		# Read lines from command-line args or STDIN
      line = $_
      parts = ChordLyricLineParts.new(line)
      puts parts.to_s_chord_above_line
    end
  end
end

##############################################################################
# Main()
##############################################################################
=begin
# Add dirs to the library path
$: << File.expand_path("../test/test_to_chord_above", File.dirname(__FILE__))
require 'test_01'

ChordLyricLineParts.test_pad
=end

ChordLyricLineParts.main

