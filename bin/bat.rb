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
#   * Show tags read from file (one-line/multi-line)
#   * Show vars
#   * Show list of xtags
#   * Default operation is to only show; add switch to "do it"
#   * Show help
#   * Use config file other than default
#   * Permit multiple audio files
# - Use symbols for hash @config_vars
# - Use symbols for hash @xtags
# - Derive hashes Rawtag2Xtag & Xtag2CmdOption from a single array
# - Add DEBUG
# - Consider using config file which is not ruby-code
##############################################################################
# Add dirs to the library path
$: << File.expand_path("../etc", File.dirname(__FILE__))
$: << File.expand_path(".", File.dirname(__FILE__))

# THIS_SCRIPT.rb will have default config: THIS_SCRIPT_conf.rb
default_config_fname = File.basename($0, File.extname($0)) + '_conf.rb'
require default_config_fname

##############################################################################
# mid3v2
class ExtendedAudioTags

  DEBUG = true
  #DEBUG = false

  Rawtag2Xtag = {
    "TPE1"	=> "artist",
    "TALB"	=> "album",
    "TIT2"	=> "title",
    "TRCK"	=> "track",

    "COMM"	=> "comment",
    "TCON"	=> "genre",
    "TDRC"	=> "year",
  }
  Xtag2CmdOption = {
    "artist"	=> "-a",
    "album"	=> "-A",
    "title"	=> "-t",
    "track"	=> "-T",

    "comment"	=> "-c",
    "genre"	=> "-g",
    "year"	=> "-y",
    "audio_file" => :no_option,
  }
=begin
  Xtag_rw_opt_tag = [
    [:artist,		:read_write,	"-a",		"TPE1"],
    [:album,		:read_write,	"-A",		"TALB"],
    [:title,		:read_write,	"-t",		"TIT2"],
    [:track,		:read_write,	"-T",		"TRCK"],

    [:comment,		:read_write,	"-c",		"COMM"],
    [:genre,		:read_write,	"-g",		"TCON"],
    [:year,		:read_write,	"-y",		"TDRC"],

    [:audio_file,	:read_write,	:no_option,	:no_tag],
    [:audio_file_dir,	:read,		:no_option,	:no_tag],
  ]
=end
  ############################################################################
  def initialize(audio_fname)
    @audio_fname = audio_fname
    @audio_file_abs = File.expand_path(@audio_fname)
    @audio_file_dir_abs = File.dirname(@audio_file_abs)
    @xtags = {}
    @config_vars = {}
  end

  ############################################################################
  def read_tags_from_audio_file
    cmd = "mid3v2 -l \"#{@audio_fname}\""
    result = IO.popen(cmd).gets(nil).chomp

    @xtags = {}
    result.each_line{|line|
      next unless line.match("=")
      puts "Initial audio tag: #{line}" if DEBUG
      rawtag, value = line.chomp.split("=", 2)
      tag = Rawtag2Xtag[rawtag]
      @xtags[tag] = value if tag
    }
    read_extended_tags
    puts "@xtags: #{@xtags.inspect}" if DEBUG
    @xtags		# Return hash of tags
  end

  ############################################################################
  def read_extended_tags
    # A read/write extension-tag (just like other music tags)
    @xtags['audio_file'] = File.basename(@audio_file_abs)
    # A read-only extension-tag (because changing the parent dir seems problematic)
    @xtags['audio_file_dir'] = File.basename(@audio_file_dir_abs)
  end

  ############################################################################
  def extract_config_vars
    input_rules = Xtag_read_rules
    #puts "input_rules: #{input_rules.inspect}" if DEBUG

    @config_vars = {}
    input_rules.each{|vars, xtag, regex|
      next unless @xtags[xtag]
      puts "Input rule: var=#{vars.inspect}; xtag='#{xtag}'; regex='#{regex}'" if DEBUG
      match = @xtags[xtag].match(regex)

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
    puts "@config_vars: #{@config_vars.inspect}" if DEBUG
  end

  ############################################################################
  def prepare_to_write_xtags
    output_rules = Xtag_write_rules

    opts = []
    rename = {}
    output_rules.each{|vars, xtag, fmt_str|
      puts "Output rule: vars=#{vars.inspect}; xtag=#{xtag}; fmt_str=#{fmt_str}" if DEBUG

      unless Xtag2CmdOption[xtag]
        STDERR.puts "WARNING: xtag '#{xtag}' is not recogised in output rule:"
        STDERR.puts "  vars:#{vars.inspect}; xtag:#{xtag}; fmt_str:#{fmt_str}" if DEBUG
        next
      end
      if xtag.match("^audio_file")
        hash_elements = vars.inject([]){|a,var| a << "@config_vars['#{var}']"}	# Eg. ["@config_vars['v1']"]
	statement = "sprintf(fmt_str, #{hash_elements.join(', ')})"		# Eg. "sprintf("%s", @config_vars['v1'])"
        dest_fname = eval(statement)						# Eg. "new_filename.mp3"
        if dest_fname.match('.\..')
          puts "Renaming '#{@audio_file_abs}' to '#{@audio_file_dir_abs}/#{dest_fname}'"
          rename[:old] = @audio_file_abs
          rename[:new] = "#{@audio_file_dir_abs}/#{dest_fname}"
        else
          STDERR.puts "Not renaming '#{@audio_file_abs}'"
          STDERR.puts "Destination file '#{dest_fname}' does not have basename.ext"
        end
      else
        hash_elements = vars.inject([]){|a,var| a << "@config_vars['#{var}']"}	# Eg. ["@config_vars['v1']"]
	statement = "sprintf(fmt_str, #{hash_elements.join(', ')})"		# Eg. "sprintf("%d", @config_vars['v1'])"
        value = eval(statement)							# Eg. "3"
        opt = "#{Xtag2CmdOption[xtag]} '#{value}'"				# Eg. "-T 3"
        opts << opt
      end

    }
    unless opts.empty?
      cmd = "mid3v2 #{opts.join(' ')} '#{@audio_fname}'"
      puts "COMMAND: #{cmd}"

      #IO.popen(cmd).gets(nil)					# DO IT!!!
    end
    #File.rename(rename[:old], rename[:new]) if rename[:new]	# DO IT!
  end

  ############################################################################
  def self.main
audio_fname = "#{ENV['HOME']}/My collection 1977-02-05/01_1977-02-05_MyMusic.mp3"
    puts "\n\n\nBULK AUDIO TAGGER (BAT)\n" + "-" * 23

    xtag = ExtendedAudioTags.new(audio_fname)
    xtag.read_tags_from_audio_file
    xtag.extract_config_vars
    xtag.prepare_to_write_xtags

puts "THE END"
  end
end

##############################################################################
# Main
##############################################################################
ExtendedAudioTags.main
exit 0

