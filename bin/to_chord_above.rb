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
class ChordLyricLineParts
 
  DELIM_RE0 = '\['	# Regex version of start of chord-token
  DELIM_RE1 = '\]'	# Regex version of end of chord-token

  MATCH_TOKEN = Regexp.new("#{DELIM_RE0}([^#{DELIM_RE1}]*)#{DELIM_RE1}")
  MATCH_PARTS = Regexp.new("^([^#{DELIM_RE0}]*)(#{DELIM_RE0}[^#{DELIM_RE1}]+#{DELIM_RE1})(.*)$")

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
  def to_s_chord_above_line
    @has_tokens ? make_2_lines : @line
  end

  ############################################################################
  def make_2_lines
    puts '=' * 70
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
        if next_part.chord?
          chord_line << part.chord + ' '
          lyric_line << self.class.pad(part.chord + ' ')
        else
          diff_length = next_part.lyric.length - part.chord.length
          if diff_length > 0
            chord_line << part.chord << self.class.pad(nil, diff_length)
          else
            chord_line << part.chord + ' '	# chord.length + 1
            num_pad_next_lyric_part = 1 - diff_length
          end
        end
      else
        chord_line << self.class.pad(nil, part.lyric.length) if i == 1  # Line starts with lyric
        lyric_line << part.lyric + self.class.pad(nil, num_pad_next_lyric_part)
        num_pad_next_lyric_part = 0
      end
    }
    if next_part.chord?
      chord_line << next_part.chord
    else
      lyric_line << next_part.lyric
    end
  
    puts "chord_line<#{chord_line}>"
    puts "lyric_line<#{lyric_line}>"
  end

  ############################################################################
  def self.pad(string, num_extra_chars=0)
    ' ' * ("#{string}".length + num_extra_chars)
  end

  ############################################################################
  def self.main
    fname = "mary_cbf.txt"
    File.open(fname){|file|
      file.each_line{|line|
        parts = ChordLyricLineParts.new(line)
        puts parts.to_s_chord_above_line
      }
    }
  end
end

##############################################################################
# Main()
##############################################################################
ChordLyricLineParts.main

