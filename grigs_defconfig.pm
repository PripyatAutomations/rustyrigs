# Default configuration is here.
# These settings are loaded at startup. Eventually config file is loaded, parsed, and merged with this
package grigs_defconfig;

# - Default configuration
our $def_cfg = {
   active_vfo => 'A',
   always_on_top => 0,		# 1 will keep window always on top by default
   autoload_memories => 0,	# 1 will automatically load memory channels when selected in list
   default_icon => 'actions-gtk-save',
   hamlib_loglevel => "bug",		# bug err warn verbose trace cache
   log_level => "debug",
   icon_error => "error.png",
   icon_idle => "idle.png",
   icon_settings => "settings.png",
   icon_transmit => "transmit.png",
   res_dir => "./res",
   rigctl_addr => 'localhost:4532',
   rigctl_model => $Hamlib::RIG_MODEL_NETRIGCTL,
   poll_interval => 1000,		# every 1 sec
   poll_tray_every => 10,		# at 1/10th the rate of normal
#   shortcut_key => 'control-mask',	# ctrl
   shortcut_key => 'mod1-mask',	# alt
   stay_hidden => 0,
   rig_volume => 0,
   win_visible => 0,
   win_x => 2252,
   win_y => 49,
   win_height => 1024,
   win_width => 682,
   win_border => 10,
   win_resizable => 1,			# 1 means main window is resizable
   win_mem_edit_x => 1,
   win_mem_edit_y => 1,
   win_mem_edit_height => 278,
   win_mem_edit_width => 479,
   win_settings_x => 183,
   win_settings_y => 318,
   win_settings_height => 278,
   win_settings_width => 489,
   ui_pow_bg => '#cc7070',		# power meter bg color
   ui_pow_fg => '#f07070',		# power meter active color
   ui_pow_text => '#000000',		# power meter text color
   ui_swr_bg => '#909090',		# swr meter bg color
   ui_swr_fg => '#f0f0f0',		# swr meter fg color
   ui_swr_text => '#000000',		# swr meter text color
   key_chan => 'C',			# open channel dropbown
   key_freq => 'F',
   key_rf_gain => 'G',
   key_mem_edit => 'E',
   key_mem_load => 'L',
   key_mode => 'M',
   key_offset => 'O',
   key_ptt => 'A',
   key_power => 'P',
   key_split => 'X',
   key_tone_freq_tx => 'T',
   key_tone_freq_rx => 'R',
   key_tone_mode => 'N',
   key_vfo => 'V',
   key_volume => 'K',
   key_width => 'W'
};
