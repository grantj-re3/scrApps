
Xtag_read_rules = [
  # The first N parentheised regex matches will populate N variables.
  # [ :xtag,		'regex_to_extract_myvars_from_xtag',	[:var1, :var2, ...] ]

  # Regex '^0*(\d+)' is used (rather that '^(\d+)') to strip leading zeros
  # and hence prevent :trackno being interpreted as octal in Xtag_write_rules
  # (preventing tracks 08 and 09 from giving an eval error).
  [ :audio_file,	'^0*(\d+)',		 [:trackno] ],
  [ :audio_file,	'\.([^\.]+)$',		 [:ext] ],
  #[ :audio_file_dir,	'(\d{4})-\d{2}-\d{2}$',	 [:year] ],
  [ :audio_file_dir,	'^(.*) *- *(.*)$',	 [:artist_name, :album_name] ],
  [ :audio_file_dir,	'^(.*)$',		 [:title2] ],
  [ :audio_file_path,	'/([^/]+)/[^/]+/[^/]+$', [:grandparent_dir] ],
]

Xtag_write_rules = [
  # The number of format sequences (eg. "%s" or "%04d") must match
  # the number of variables.
  # [ :xtag,		"printf_format_string",	[:var1, :var2, ...] ],

  [ :artist,		"%s",			[:artist_name] ],
  [ :track,		"%d",			[:trackno] ],
  #[ :year,		"%s",			[:year] ],
  [ :album,		"%s",			[:album_name] ],
  [ :audio_file,	"%02d %s.%s",		[:trackno, :title2, :ext] ],
  [ :title,		"%02d %s, %s (%s)",	[:trackno, :artist_name, :album_name, :grandparent_dir] ],
  [ :genre,		"Musical parody",	[] ],

  # Consider alternate Xtag_write_rules [which do not require eval()]
  #[ :audio_file,	[["%02d ", "trackno"], ["%s My Collection.", "date"], ["%s", "ext"]] ],
]
