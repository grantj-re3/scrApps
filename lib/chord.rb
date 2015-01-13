#!/usr/bin/ruby
#
# File:		chord.rb
# Author:	Grant Jackson
# Package:	N/A
# Environment:	Ruby 2.0.0 & 1.8.7
#
# Copyright (C) 2014
# Licensed under GPLv3. GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# http://www.gnu.org/licenses/
#
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

  # List of chord-types (ie. remainder-types which follow a root-chord)
  CHORD_TYPES = %w{ + 6 7 aug dim m m6 m7 maj maj7 o sus sus4 }

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
  # Return true if @root is a valid root chord; else return false.
  ############################################################################
  def is_root_chord_valid?
    @root_index != nil
  end

  ############################################################################
  # Return true if @remainder is a valid chord-type; else return false.
  ############################################################################
  def is_remainder_valid?
#puts "  ^^^ @remainder=#{@remainder.inspect}"
    r = @remainder.split(DELIM)[0]	# Get remainder part before any note-modifiers
#puts "  ^^^ r=#{r.inspect}"
    return true if !r || r.empty?
    return true if CHORD_TYPES.include?(r.downcase)
    false
  end

  ############################################################################
  # Return true if whole-chord (@root_chord and @remainder) is valid;
  # else return false.
  ############################################################################
  def is_chord_valid?
    is_root_chord_valid? && is_remainder_valid?
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

