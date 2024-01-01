# Default configuration is here.
# These settings are loaded at startup. Eventually config file is loaded, parsed, and merged with this
package grigs_defconfig;

# - Default configuration
our $def_cfg = {
   active_vfo => 'A',
   always_on_top => 0,			# 1 will keep window always on top by default
   always_on_top_meters => 1,		# 1 will keep meters window on top by default
   autoload_memories => 0,		# 1 will automatically load memory channels when selected in list
   default_icon => 'actions-gtk-save',
   floating_meters => 0,		# 1 will put the meters in their own window
   hamlib_loglevel => "bug",		# bug err warn verbose trace cache
   icon_error => "error.png",
   icon_idle => "idle.png",
   icon_settings => "settings.png",
   icon_transmit => "transmit.png",
   key_chan => 'C',			# open channel dropbown
   key_freq => 'F',
   key_lock => 'L',
   key_mem_edit => 'E',
   key_mem_load => 'D',
   key_mode => 'M',
   key_offset => 'O',
   key_ptt => 'A',
   key_power => 'P',
   key_rf_gain => 'G',
   key_split => 'X',
   key_tone_freq_tx => 'T',
   key_tone_freq_rx => 'R',
   key_tone_mode => 'N',
   key_vfo => 'V',
   key_volume => 'K',
   key_width => 'W',
   log_level => "debug",
   poll_interval => 1000,		# every 1 sec
   poll_tray_every => 10,		# at 1/10th the rate of normal
   rig_volume => 0,
   res_dir => "/usr/share/grigs/",
   rigctl_addr => 'localhost:4532',
   rigctl_model => $Hamlib::RIG_MODEL_NETRIGCTL,
#   shortcut_key => 'control-mask',	# ctrl
   shortcut_key => 'mod1-mask',	# alt
   show_alc => 1,
   show_comp => 1,
   show_pow => 1,
   show_swr => 1,
   show_temp => 1,
   show_vdd => 1,
   stay_hidden => 0,
   thresh_alc_min => 0,
   thresh_alc_max => 1,
   thresh_comp_min => 0,
   thresh_comp_max => 0,
   thresh_pow_min => 5,
   thresh_pow_max => 40,
   thresh_swr_min => 0,
   thresh_swr_max => 2.5,
   thresh_temp_min => 0,
   thresh_temp_max => 140,		# degF
   thresh_vdd_min => 12.8,
   thresh_vdd_max => 15,
   ui_alc_alt_bg => '#707070',
   ui_alc_bg => '#707070',		# ALC meter bg color
   ui_alc_fg => '#70f070',		# ALC meter active color
   ui_alc_font => 'Monospace',
   ui_alc_text => '#000000',		# ALC meter text color
   ui_comp_alt_bg => '#707070',
   ui_comp_bg => '#707070',		# CMP meter bg color
   ui_comp_fg => '#70f070',		# CMP meter active color
   ui_comp_font => 'Monospace',
   ui_comp_text => '#000000',		# CMP meter text color
   ui_pow_alt_bg => '#cc7070',
   ui_pow_bg => '#cc7070',		# power meter bg color
   ui_pow_fg => '#f07070',		# power meter active color
   ui_pow_font => 'Monospace',
   ui_pow_text => '#000000',		# power meter text color
   ui_swr_alt_bg => '#f09090',
   ui_swr_bg => '#909090',		# swr meter bg color
   ui_swr_fg => '#f0f0f0',		# swr meter fg color
   ui_swr_font => 'Monospace',
   ui_swr_text => '#000000',		# swr meter text color
   ui_temp_alt_bg => '#f07070',
   ui_temp_bg => '#707070',		# TMP meter bg color
   ui_temp_fg => '#70f070',		# TMP meter active color
   ui_temp_font => 'Monospace',
   ui_temp_text => '#000000',		# TMP meter text color
   ui_vdd_alt_bg => '#70cc70',
   ui_vdd_bg => '#70cc70',		# VDD meter bg color
   ui_vdd_fg => '#70f070',		# VDD meter active color
   ui_vdd_font => 'Monospace',
   ui_vdd_text => '#000000',		# VDD meter text color
   win_border => 10,
   win_height => 1024,
   win_resizable => 1,			# 1 means main window is resizable
   win_width => 682,
   win_visible => 0,
   win_x => 2252,
   win_y => 49,
   win_mem_edit_x => 1,
   win_mem_edit_y => 1,
   win_mem_edit_height => 278,
   win_mem_edit_width => 479,
   win_settings_x => 183,
   win_settings_y => 318,
   win_settings_height => 278,
   win_settings_width => 489
};

our $default_memories = {
   # stuff
};

1;
