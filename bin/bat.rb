#!/usr/bin/ruby
# Bulk Audio Tagger
#
# File:		bat.rb
# Author:	Grant Jackson
# Package:	N/A
# Environment:	Ruby 2.0.0
#
# Copyright (C) 2015
# Licensed under GPLv3. GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# http://www.gnu.org/licenses/
#
# Tag audio files according to rules in a config file. The program
# uses the Python app mid3v2 to read and write audio file tags.
# This program does *not* perform any ID or fingerprint lookup.
#
# TODO:
# - Add command line opts
#   * DONE: Show xtags before & after rules
#   * DONE: Show vars
#   * DONE: Show list of xtags
#   * N/A: Show list of rules
#   * DONE: Default operation is to only show; add switch to "do it"
#   * DONE: Show help
#   * DONE Use rules-file other than default
#   * DONE: Permit multiple audio files
# - DONE: Use symbols for hash @config_vars
# - DONE: Use symbols for hash @xtags
# - DONE: Derive hashes Rawtag2Xtag & Xtag2CmdOption from a single array
# - DONE: Add DEBUG
# - DONE: FIXME: Check input files
# - DONE: FIXME: Call method to check dest filename; file exists; no dup dest fnames; etc
# - DONE: Add xtag :audio_file_path
# - DONE: FIXME: Write xtags_same?() to confirm xtags written are not identical to those read
# - Consider using config file which is not ruby-code
##############################################################################
#require 'set'

##############################################################################
# ID3v2 Audio tags plus extras:
# - The audio file name is also treated as a read/write tag.
# - The audio file's parent dir and absolute path are treated as read-only tags.
class XAudioTags

  #DEBUG = true
  DEBUG = false

  # Search path for rules-file if no path specified. Earlier dirs are searched
  # first. The first matching filename found will be used.
  Rules_file_search_dirs = [
    # The first dir to search will be the audio-file dir (not listed below).
    # Subsequent paths (listed below) are relative to this script.
    "../etc",
    ".",
  ]

  # THIS_SCRIPT.rb will have default config: THIS_SCRIPT_conf.rb
  Default_rules_fname = File.basename($0, File.extname($0)) + '_rules.rb'
  Rules_file_bytes_max = 1000000

  Regex_audio_file = /audio|MPEG ADTS/i

  Default_options = {
    :execute		=> false,
    :show_commands	=> false,
    :show_audio_file	=> true,
    :show_vars		=> true,
    :show_tags_both	=> true,
=begin
    :show_tags_before	=> false,
    :show_tags_after	=> false,
    :show_rules		=> false,
=end
  }

  Xtag_rw_opt_tag = [
    # [:xtag,		:read_or_write,	"-option",	"IDv2_tagname"],
    [:artist,		:read_write,	"-a",		"TPE1"],
    [:album,		:read_write,	"-A",		"TALB"],
    [:title,		:read_write,	"-t",		"TIT2"],
    [:track,		:read_write,	"-T",		"TRCK"],

    [:comment,		:read_write,	"-c",		"COMM"],
    [:genre,		:read_write,	"-g",		"TCON"],
    [:year,		:read_write,	"-y",		"TDRC"],

    [:audio_file,	:read_write,	:no_option,	:no_tag],
    [:audio_file_dir,	:read,		:no_option,	:no_tag],
    [:audio_file_path,	:read,		:no_option,	:no_tag],
  ]
  Rawtag2Xtag    = Xtag_rw_opt_tag.inject({}){|h,(xtag,rw,opt,tag)| h[tag] = xtag unless tag == :no_tag; h}
  Xtag2CmdOption = Xtag_rw_opt_tag.inject({}){|h,(xtag,rw,opt,tag)| h[xtag] = opt if rw == :read_write; h}
  AllXtags = Xtag_rw_opt_tag.inject([]){|a,(xtag,rw,opt,tag)| a << xtag}

  attr_reader :audio_fname, :write_info

  ############################################################################
  def initialize(audio_fname, opts={})
    @opts = Default_options.merge(opts)	# Duplicate keys from opts overwrites Default_options
    @opts.each{|opt,value|
    next unless opt.to_s =~ /^show_/
    if value
      puts @opts[:execute] ? "" : "## Test-run only ##"	# Newline if any other output
      break
    end
    }
    @audio_fname = audio_fname
    puts "Audio filename: '#{@audio_fname}'" if @opts[:show_audio_file]
    self.class.verify_audio_fname_rw(@audio_fname)

    @audio_file_abs = File.expand_path(@audio_fname)
    @audio_file_dir_abs = File.dirname(@audio_file_abs)

    @xtags = {}
    @new_xtags = {}
    @config_vars = {}
    @write_info = {}
  end

  ############################################################################
  def self.verify_audio_fname_rw(fname)
    unless File.exists?(fname)
      STDERR.puts "ERROR: File not found: '#{fname}'"
      exit 3
    end
    unless File.readable?(fname)
      STDERR.puts "ERROR: File not readable: '#{fname}'"
      exit 3
    end
    unless File.writable?(fname)
      STDERR.puts "ERROR: File not writable: '#{fname}'"
      exit 3
    end

    # Check this is an audio file
    cmd = "file -bL '#{fname}'"
    result = IO.popen(cmd).gets(nil).chomp
    unless result =~ Regex_audio_file
      STDERR.puts "ERROR: File is not audio: '#{fname}'\nIt is:  #{result}"
      exit 3
    end
  end

  ############################################################################
  def read_tags_from_audio_file
    cmd = "mid3v2 -l '#{@audio_fname}'"
    result = IO.popen(cmd).gets(nil).chomp

    @xtags = {}
    result.each_line{|line|
      next unless line.match("=")
      #puts "Initial audio tag: #{line}" if DEBUG
      rawtag, value = line.chomp.split("=", 2)
      xtag = Rawtag2Xtag[rawtag]
      @xtags[xtag] = value if xtag
    }
    read_extra_tags
    puts "@xtags: #{@xtags.sort.inspect}" if DEBUG
    @xtags		# Return hash of tags
  end

  ############################################################################
  def read_extra_tags
    # A read/write extra-tag (just like other music tags)
    @xtags[:audio_file] = File.basename(@audio_file_abs)

    # Read-only extra-tags (because changing the parent dir/path seems problematic)
    @xtags[:audio_file_dir] = File.basename(@audio_file_dir_abs)
    @xtags[:audio_file_path] = @audio_file_abs
  end

  ############################################################################
  def extract_config_vars
    input_rules = Xtag_read_rules
    #puts "input_rules: #{input_rules.inspect}" if DEBUG

    @config_vars = {}
    input_rules.each{|xtag, regex, vars|
      next unless @xtags[xtag]
      puts "Input rule: var=#{vars.inspect}; xtag=:#{xtag}; regex='#{regex}'" if DEBUG
      match = @xtags[xtag].match(regex)

      match = [] unless match
      if vars.length != match.length-1
        bracketed_matchs = match.length==0 ? [] : match.to_a[1, match.length-1]
        STDERR.puts <<-MSG_WARN_MATCH_LENGTH.gsub(/^\t*/, '')
		WARNING: Number of config variables (#{vars.length}) differs from number of regex bracketed-matches (#{bracketed_matchs.length}).
		  Config variables: #{vars.inspect}
		  Regex bracketed matches: #{bracketed_matchs}
        MSG_WARN_MATCH_LENGTH
      end
      vars.each_with_index{|var,i|
        @config_vars[var] = (i+1)<match.length ? match[i+1] : ""
      }
    }
    puts "Rule variables: #{@config_vars.sort.inspect}" if @opts[:show_vars]
  end

  ############################################################################
  def prepare_to_write_xtags
    output_rules = Xtag_write_rules
    mopts = []			# List of command line options (for Music tags)
    @write_info = {}		# Info which we will write
    @new_xtags = {}
    output_rules.each{|xtag, fmt_str, vars|
      puts "Output rule: vars=#{vars.inspect}; xtag=:#{xtag}; fmt_str='#{fmt_str}'" if DEBUG

      unless Xtag2CmdOption[xtag]
        STDERR.puts "WARNING: xtag '#{xtag}' is not recogised in output rule:"
        STDERR.puts "  xtag:#{xtag}; fmt_str:#{fmt_str}; vars:#{vars.inspect}"
        next
      end
      hash_elements = vars.inject([]){|a,var| a << "@config_vars[:#{var}]"}	# Eg. ["@config_vars[:v1]"]
      statement = "sprintf('#{fmt_str}', #{hash_elements.join(', ')})"		# Eg. "sprintf("%s", @config_vars[:v1])"
      begin
        value = eval(statement)							# Eg. "new_filename.mp3"
      rescue Exception => e
        STDERR.puts "Eval error in: #{statement}"
        STDERR.puts e
        exit 5
      end
      @new_xtags[xtag] = value

      if xtag == :audio_file
        dest_fname = value
        # FIXME: Call method to check dest filename; file exists; src/dest filenames not same; etc
        if dest_fname.match('.\..')
          @write_info[:new_file_abs] = "#{@audio_file_dir_abs}/#{dest_fname}"
          @write_info[:is_done] = false
        else
          STDERR.puts "Not renaming '#{@audio_file_abs}'"
          STDERR.puts "Destination file '#{dest_fname}' does not have basename.ext"
        end
      else
        mopts << "#{Xtag2CmdOption[xtag]} '#{value}'"				# Eg. "-t 'Song'"
      end
    }
    unless mopts.empty?
      @write_info[:cmd] = "mid3v2 #{mopts.join(' ')} '#{@audio_fname}'"
      @write_info[:is_done] = false
    end
    show_xtags
  end

  ############################################################################
  def show_xtags
    #keys = Set.new(@xtags.keys) | Set.new(@new_xtags.keys)
    keys = AllXtags
    keys.sort.each{|xtag|
      next unless @opts[:show_tags_both]
      if Xtag2CmdOption[xtag]
        printf "  :%-15s ['%s' -> '%s']\n", xtag, @xtags[xtag], @new_xtags[xtag]
      else
        printf "  :%-15s ['%s' -> CannotWriteXtag]\n", xtag, @xtags[xtag]
      end
    }
  end

  ############################################################################
  def xtags_same?
    @new_xtags.each{|xtag, new_value| return false if new_value != @xtags[xtag] }
    true
  end

  ############################################################################
  def write_xtags(enable_execute=true, enable_messages=true)
    # Ensure a single prepare-hash can only be executed once
    if @write_info[:is_done]
      return false
    elsif xtags_same?
      STDERR.puts "NOTICE: All new xtags are identical to those read. Will not update audio file." if enable_messages
      return false
    else
      if @write_info[:cmd]
        puts "Command: #{@write_info[:cmd]}" if @opts[:show_commands] && enable_messages
        IO.popen(@write_info[:cmd]).gets(nil) if @opts[:execute] && enable_execute
      end
      if @write_info[:new_file_abs]
        puts "Rename: '#{@audio_file_abs}' To '#{@write_info[:new_file_abs]}'" if @opts[:show_commands] && enable_messages
        File.rename(@audio_file_abs, @write_info[:new_file_abs]) if @opts[:execute] && enable_execute
      end
      @write_info[:is_done] = true if enable_execute
      return true
    end
  end

  ############################################################################
  def self.load_rules_file(opts)
    if opts[:rules_fname] =~ /\//
      # Absolute or relative path was specified on command line
      rules_fname = opts[:rules_fname]

      unless File.exists?(rules_fname)
        STDERR.puts "ERROR: Rules-file not found: '#{rules_fname}'"
        exit 4
      end

    else
      # Rules filename here does not have a path. It is either the default
      # filename or specified on command line without a path. Hence search
      # in known dirs.
      rules_fname = nil
      opts[:rules_file_search_dirs].each{|dir|
        try_fname = "#{dir}/#{opts[:rules_fname]}"
        if File.exists?(try_fname)
          puts "Rules file FOUND at:     #{try_fname}"
          rules_fname = try_fname
          break
        end
        puts "Rules file NOT found at: #{try_fname}"
      }

      unless rules_fname
        STDERR.puts "ERROR: Rules-file not found."
        exit 4
      end
    end

    unless File.readable?(rules_fname)
      STDERR.puts "ERROR: Rules-file not readable: '#{rules_fname}'"
      exit 4
    end
    unless rules_fname =~ /^.+\.rb/
      STDERR.puts "ERROR: Rules-file is not a ruby file with extension '.rb'"
      exit 4
    end
    unless File.size(rules_fname) <= Rules_file_bytes_max
      STDERR.puts "ERROR: Rules-file must be #{Rules_file_bytes_max} bytes or less"
      exit 4
    end

    rules_str = File.new(rules_fname, 'r').read
    unless rules_str =~ /Xtag_read_rules *=/ && rules_str =~ /Xtag_write_rules *=/
      STDERR.puts "ERROR: Rules-file must assign 'Xtag_read_rules' and 'Xtag_write_rules'"
      exit 4
    end
    require rules_fname
  end

  ############################################################################
  def self.get_command_line_args
    msg = <<-MSG_COMMAND_LINE_ARGS.gsub(/^\t*/, '')
		Usage:  #{File.basename $0} OPTIONS AUDIO_FILES
		where
		  AUDIO_FILES is a list of audio files (eg. mp3) which support ID3v2 tags for
		  artist, title, track, etc. So you can keep track of what is happening, it is
		  recommended that all the audio files being processed per run are in the same
		  directory so that they have the same rules applied.

		  OPTIONS are listed below.

		  +2|--show-both-tags or -2|--do-not-show-both-tags: Show what the tag values
		    will be before and after changes are applied (or not). Default: +2

		  +c|--show-commands or -c|--do-not-show-commands: Show the commands (or not)
		    which will be performed to change the xtags. Default: -c

		  +e|--execute or -e|--do-not-execute or +e|--execute: Execute the changes
		    (or not). The program will not perform the changes if -e is specified.
		    Default: -e.

		  +f|--show-audio-file or -f|--do-not-show-audio-file: Show the audio file
		    name (or not). Default: +f

		  +v|--show-vars or -v|--do-not-show-vars: Show the variables extracted from
		    the xtags (or not). Default: +v

		  -r RULES_FNAME.rb|--load-rules-file RULES_FNAME.rb: Read the rules from
		    the ruby file RULES_FNAME.rb instead of from the default ruby file
		    '#{Default_rules_fname}'. Here you can specify an absolute path, a
		    relative path or a basename (ie. filename without a directory path).
		    In the latter case and for the default ruby file '#{Default_rules_fname}',
		    the program will search for the file in the following sequence:
		    * in the same directory as the first audio file in the list
		    * in ../etc directory (relative to this program)
		    * in the same directory as this program

		  -h|--help: These help instructions.

		Example:  #{File.basename $0} -r myrules.rb +f +2 -v -e /path/to/dir/*.mp3

		Readable xtags available in rules file:
		  #{AllXtags.sort.inspect.tr('[]', '').sub(/(:comment,)/, "\n  \\1")}
		Writable xtags available in rules file:
		  #{Xtag2CmdOption.keys.sort.inspect.tr('[]', '')}
    MSG_COMMAND_LINE_ARGS

    opts = {
      :rules_fname => Default_rules_fname	# Might be overridden from command line
    }
    while ARGV[0] =~ /^[\-\+]/
      arg = ARGV.shift
      case arg
        # Reserved:
        # * '+a', '--show-tags-after'
        # * '+b', '--show-tags-before'
        # * '+r', '--show-rules'

        when '-2', '--do-not-show-both-tags'
          opts[:show_tags_both] = false
        when '+2', '--show-both-tags'
          opts[:show_tags_both] = true

        when '-c', '--do-not-show-commands'
          opts[:show_commands] = false
        when '+c', '--show-commands'
          opts[:show_commands] = true

        when '-e', '--do-not-execute'
          opts[:execute] = false
        when '+e', '--execute'
          opts[:execute] = true

        when '-f', '--do-not-show-audio-file'
          opts[:show_audio_file] = false
        when '+f', '--show-audio-file'
          opts[:show_audio_file] = true

        when '-v', '--do-not-show-vars'
          opts[:show_vars] = false
        when '+v', '--show-vars'
          opts[:show_vars] = true

        when '-r', '--load-rules-file'
          if ARGV.length > 0
            opts[:rules_fname] = ARGV.shift
          else
            STDERR.puts "ERROR: #{arg} must be followed by the name of a file containing rules."
            exit 1
          end

        when '-h', '--help'
          STDERR.puts msg
          exit 0

        else	# Invalid options
          STDERR.puts "Unrecognised option: '#{arg}'\n\n"
          STDERR.puts msg
          exit 1
      end
    end
    # Everything else in ARGV should be a list of filenames
    if ARGV.length == 0
      STDERR.puts "Error: No files were specified.\n\n"
      STDERR.puts msg
      exit 2
    end

    audio_file_dirname_abs = File.expand_path( File.dirname(ARGV[0]) )
    opts[:rules_file_search_dirs] = Rules_file_search_dirs.inject([audio_file_dirname_abs]){|a,dir|
      a << File.expand_path(dir, File.dirname(__FILE__))
    }
    opts
  end

  ############################################################################
  def self.main
    opts = get_command_line_args
    puts "\n\n\nBULK AUDIO TAGGER (BAT)\n" + "-" * 23
    load_rules_file(opts)

    xtags = []			# Store every xtag object
    xtags_by_dest_fname = {}	# Store each xtag object which results in the specified dest filename
    ARGV.each{|audio_fname|
      xtag = XAudioTags.new(audio_fname, opts)
      xtag.read_tags_from_audio_file
      xtag.extract_config_vars
      xtag.prepare_to_write_xtags

      if xtag.write_info[:new_file_abs]
        xtags_by_dest_fname[ xtag.write_info[:new_file_abs] ] ||= []
        xtags_by_dest_fname[ xtag.write_info[:new_file_abs] ] << xtag
      end
      xtags << xtag		# Store so we can write xtags later
      xtag.write_xtags(false, true)
    }
    # This will give error if dest filenames are not unique (but it will NOT
    # detect if a dest filename clashes with an original filename)
    will_halt = false
    xtags_by_dest_fname.each{|dest_fname, xtags|
      if xtags.length > 1
        will_halt = true
        STDERR.puts "\nERROR: The following original filenames result in the same destination filename:\nDestination filename: '#{dest_fname}'"
        xtags.each{|t| STDERR.puts "  Original filename:  '#{t.audio_fname}'"}
      end
    }
    if will_halt
      STDERR.puts "\nQuitting due to errors: No files were changed"
      exit 6
    end

    # Perform all the changes (provided options are set to :execute)
    xtags.each{|xtag| xtag.write_xtags(true, false) }
  end
end

##############################################################################
# Main
##############################################################################
XAudioTags.main
exit 0

