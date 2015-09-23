
Xtag_read_rules = [
  # The first N parentheised regex matches will populate N variables.
  # [ [:var1, :var2, ...],	:xtag,			"regex_to_extract_myvars_from_xtag" ]

  [ [:trackno],			:audio_file,		"^([0-9]+)" ],
  [ [:ext],			:audio_file,		'\.([^\.]+)$' ],
  [ [:alb_name, :date],		:audio_file_dir,	'^(.*(\d{4}-\d{2}-\d{2}))$' ],
  [ [:year],			:audio_file_dir,	'(\d{4})-\d{2}-\d{2}$' ],
]

Xtag_write_rules = [
  # The number of format sequences (eg. "%s" or "%04d") must match
  # the number of variables.
  # [ [:var1, :var2, ...],	:xtag,			"c_style_format_string" ],

  [ [:trackno],			:track,			"%d" ],
  [ [:year],			:year,			"%s" ],
  [ [:alb_name],		:album,			"%s" ],
  [ [:trackno, :date],		:title,			"%02d %s My Collection" ],
  [ [:trackno, :alb_name, :ext], :audio_file,		"%02d %s.%s" ],
  [ [],				:genre,			"Musical parody" ],

  # Consider alternate Xtag_write_rules [which do not require eval()]
  #[ :audio_file,	[["%02d ", "trackno"], ["%s My Collection.", "date"], ["%s", "ext"]] ],
]
