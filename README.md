scrApps
=======

## Description
My custom scrApps - scripts and apps

Apps:
- transpose_chords.rb: Transpose a file containing lyrics and inline chords

## transpose_chords.rb

### Purpose
To tanspose a file containing lyrics and inline chords.

### Usage
```
  transpose_chords.rb  -h|--help
  transpose_chords.rb  -u|-d NUM_SEMITONES_UP_OR_DOWN  TEXT_FILE
  transpose_chords.rb  -f FROM_CHORD  -t TO_CHORD  TEXT_FILE
where: FROM_CHORD and TO_CHORD must start with a root-chord
  and: A root-chord is A-G, A#-G#, Ab-Gb, A##-G## or Abb-Gbb

TEXT_FILE must contain lyrics with inline chords. Chords must be placed between
square brackets, eg. [Bbmaj7]. The chord-part after the root-chord (eg. 'maj7')
shall be unchanged during the transposition unless one or more '/' characters
are present. In that case any root-chord (or note) which appears immediately
after the '/' shall also be transposed. Eg. [C7/G] to [D7/A]

The command:      transpose_chords.rb  -u 2  song.txt
will change this: [G]Or [Am]when [G/B]the [Am]valley's [F]hushed and ...
to this:          [A]Or [Bm]when [A/C#]the [Bm]valley's [G]hushed and ...

All of the following commands will transpose down by 3 semi-tones.
  transpose_chords.rb  -d 3  song.txt
  transpose_chords.rb  -f C   -t a   song.txt  # Upper or lower case chord
  transpose_chords.rb  -f G7  -t E7  song.txt  # '7' is ignored
```

### Features
- Either:
  * specify the number of semitones to transpose up or down, or
  * specify an example of a FROM_CHORD and TO_CHORD (from which the number of semitones to transpose shall be calculated by the program)
- Runs under Ruby 2.0.0 or 1.8.7 (and presumably every version in between)
- Runs under Linux (and presumably under Windows and MacOS)
- Understands chords given in upper or lower case
- Able to transpose root-chords eg. G,G#,G##,Gb,Gbb
- Able to transpose the part after the root-chord if it contains one or more '/' characters followed by a chord or note to be transposed
- Able to configure the following features by changing constants within the program.
  * The characters used to bracket the inline chords in TEXT_FILE. Default is [].
  * The characters used to bracket the inline chords in the transposed output. Default is [].
  * The characters used to signify that the next part of the chord (after the root chord) must also be transposed. Default is /.
  * The preferred representation of chords for output. Eg. Should the output show A# or Bb.

