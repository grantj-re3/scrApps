#!/usr/bin/ruby
# bat.rb -- Bulk Audio Tagger
#
# GPLv3
#
# Tag audio files according to rules in a config file The program
# uses the Python app mid3v2 to read and write audio file tags.
# This program does *not* perform any ID or fingerprint lookup.
#
# TODO:
# - Add command line opts
#   * DONE: Show xtags before & after rules
#   * DONE: Show vars
#   * DONE: Show list of xtags
#   * Show list of rules
#   * DONE: Default operation is to only show; add switch to "do it"
#   * DONE: Show help
#   * Use config file other than default
#   * DONE: Permit multiple audio files
# - DONE: Use symbols for hash @config_vars
# - DONE: Use symbols for hash @xtags
# - DONE: Derive hashes Rawtag2Xtag & Xtag2CmdOption from a single array
# - DONE: Add DEBUG
# - FIXME: Check input files
# - FIXME: Call method to check dest filename; file exists; src/dest filenames not same; etc
# - DONE: Add xtag :audio_file_path
# - DONE: FIXME: Write xtags_same?() to confirm xtags written are not identical to those read
# - Consider using config file which is not ruby-code
##############################################################################
# Add dirs to the library path
$: << File.expand_path("../etc", File.dirname(__FILE__))
$: << File.expand_path(".", File.dirname(__FILE__))

require 'set'

# THIS_SCRIPT.rb will have default config: THIS_SCRIPT_conf.rb
default_config_fname = File.basename($0, File.extname($0)) + '_rules.rb'
require default_config_fname

##############################################################################
class ExtendedAudioTags

  #DEBUG = true
  DEBUG = false

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


  ############################################################################
  def initialize(audio_fname, opts={})
    @opts = Default_options.merge(opts)	# Duplicate keys from opts overwrite Default_options
    @audio_fname = audio_fname
    @audio_file_abs = File.expand_path(@audio_fname)
    @audio_file_dir_abs = File.dirname(@audio_file_abs)
    puts "\nAudio filename: '#{@audio_fname}'" if @opts[:show_audio_file]

    @xtags = {}
    @new_xtags = {}
    @config_vars = {}
    @prepare2write = {}
  end

  ############################################################################
  def read_tags_from_audio_file
    cmd = "mid3v2 -l \"#{@audio_fname}\""
    result = IO.popen(cmd).gets(nil).chomp

    @xtags = {}
    result.each_line{|line|
      next unless line.match("=")
      #puts "Initial audio tag: #{line}" if DEBUG
      rawtag, value = line.chomp.split("=", 2)
      xtag = Rawtag2Xtag[rawtag]
      @xtags[xtag] = value if xtag
    }
    read_extended_tags
    puts "@xtags: #{@xtags.sort.inspect}" if DEBUG
    @xtags		# Return hash of tags
  end

  ############################################################################
  def read_extended_tags
    # A read/write extended-tag (just like other music tags)
    @xtags[:audio_file] = File.basename(@audio_file_abs)

    # Read-only extended-tags (because changing the parent dir/path seems problematic)
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
    @prepare2write = {}		# Info which we will write
    @new_xtags = {}
    output_rules.each{|xtag, fmt_str, vars|
      puts "Output rule: vars=#{vars.inspect}; xtag=:#{xtag}; fmt_str='#{fmt_str}'" if DEBUG

      unless Xtag2CmdOption[xtag]
        STDERR.puts "WARNING: xtag '#{xtag}' is not recogised in output rule:"
        STDERR.puts "  xtag:#{xtag}; fmt_str:#{fmt_str}; vars:#{vars.inspect}"
        next
      end
      hash_elements = vars.inject([]){|a,var| a << "@config_vars[:#{var}]"}	# Eg. ["@config_vars[:v1]"]
      statement = "sprintf(fmt_str, #{hash_elements.join(', ')})"		# Eg. "sprintf("%s", @config_vars[:v1])"
      value = eval(statement)							# Eg. "new_filename.mp3"
      @new_xtags[xtag] = value

      if xtag == :audio_file
        dest_fname = value
        # FIXME: Call method to check dest filename; file exists; src/dest filenames not same; etc
        if dest_fname.match('.\..')
          @prepare2write[:new_file_abs] = "#{@audio_file_dir_abs}/#{dest_fname}"
          @prepare2write[:is_done] = false
        else
          STDERR.puts "Not renaming '#{@audio_file_abs}'"
          STDERR.puts "Destination file '#{dest_fname}' does not have basename.ext"
        end
      else
        mopts << "#{Xtag2CmdOption[xtag]} '#{value}'"				# Eg. "-t 'Song'"
      end
    }
    unless mopts.empty?
      @prepare2write[:cmd] = "mid3v2 #{mopts.join(' ')} '#{@audio_fname}'"
      @prepare2write[:is_done] = false
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
  def write_xtags
    # Ensure a single prepare-hash can only be executed once
    if @prepare2write[:is_done]
      return false
    elsif xtags_same?
      STDERR.puts "NOTICE: All new xtags are identical to those read. Will not update audio file."
      return false
    else
      if @prepare2write[:cmd]
        puts "Command: #{@prepare2write[:cmd]}" if @opts[:show_commands]
        IO.popen(@prepare2write[:cmd]).gets(nil) if @opts[:execute]
      end
      if @prepare2write[:new_file_abs]
        puts "Rename: '#{@audio_file_abs}' To '#{@prepare2write[:new_file_abs]}'" if @opts[:show_commands]
        File.rename(@audio_file_abs, @prepare2write[:new_file_abs]) if @opts[:execute]
      end
      @prepare2write[:is_done] = true
      return true
    end
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
		    which will be performed to change the xtags. Default: -e

		  +e|--execute or -e|--do-not-execute or +e|--execute: Execute the changes
		    (or not). The program will not perform the changes if -e is specified.
		    Default: -e.

		  +f|--show-audio-file or -f|--do-not-show-audio-file: Show the audio file
		    name (or not). Default: +f

		  +v|--show-vars or -v|--do-not-show-vars: Show the variables extracted from
		    the xtags (or not). Default: +v

		  -h|--help:    These help instructions.

		Example:  #{File.basename $0} +f +2 -v -e /path/to/dir/*.mp3

		Readable xtags available in rules file:
		  #{AllXtags.sort.inspect.tr('[]', '').sub(/(:comment,)/, "\n  \\1")}
		Writable xtags available in rules file:
		  #{Xtag2CmdOption.keys.sort.inspect.tr('[]', '')}
    MSG_COMMAND_LINE_ARGS

    opts = {}
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

        else	# '-h', '--help' and invalid options
          STDERR.puts "Unrecognised option: '#{arg}'\n\n"
          STDERR.puts msg
          exit 0
      end
    end
    # Everything else in ARGV should be a list of filenames
    if ARGV.length == 0
      STDERR.puts "Error: No files were specified.\n\n"
      STDERR.puts msg
      exit 0
    end
    opts
  end

  ############################################################################
  def self.main
    opts = get_command_line_args
    puts "\n\n\nBULK AUDIO TAGGER (BAT)\n" + "-" * 23

    # FIXME: Check input files

    ARGV.each{|audio_fname|
      xtag = ExtendedAudioTags.new(audio_fname, opts)
      xtag.read_tags_from_audio_file
      xtag.extract_config_vars
      xtag.prepare_to_write_xtags
      xtag.write_xtags
    }
  end
end

##############################################################################
# Main
##############################################################################
ExtendedAudioTags.main
exit 0

