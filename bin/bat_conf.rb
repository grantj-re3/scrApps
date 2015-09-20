
Xtag_read_rules = [
  # The first N parentheised regex matches will populate N variables.
  # [ ["var1", "var2", ...],	"xtag",		"regex_to_extract_myvars_from_xtag" ]

  [ ["trackno", "year"],	"title",		"^([0-9]+) ([0-9]{4})" ],
  [ ["album_name", "date"],	"audio_file_dir",	'^(.*(\d{4}-\d{2}-\d{2}))$' ],
  [ ["ext"],			"audio_file",		'\.([^\.]+)$' ],
]

Xtag_write_rules = [
  # The number of format sequences (eg. "%s" or "%04d") must match
  # the number of variables.
  # [ ["var1", "var2", ...],	"xtag",		"c_style_format_string" ],

  [ ["trackno"],		"track",	"%d" ],
  [ ["year"],			"year",		"%s" ],
  [ ["album_name"],		"album",	"%s" ],
  [ ["trackno", "date"],	"title",	"%02d %s My Collection" ],
  [ ["trackno", "date", "ext"],	"audio_file",	"%02d %s My Collection.%s" ],
]
