# Default configuration is here.
# These settings are loaded at startup.
# Eventually config file is loaded, parsed, and merged with this.
# Any values set in the configuration will override the defaults.
# New settings will get combined
package RustyRigs::Defconfig;
use Hamlib;
use strict;
use warnings;

# - Default configuration
our $def_cfg = {
    # Addresses for the backends
    ampctl_addr         => 'localhost:4531',
    ampctl_model        => $Hamlib::AMP_MODEL_NETAMPCTL,
    rigctl_addr         => 'localhost:4532',
    rigctl_model        => $Hamlib::RIG_MODEL_NETRIGCTL,
    rotctl_addr         => 'localhost:4533',
    rotctl_model        => $Hamlib::ROT_MODEL_NETROTCTL,
    # CAT commands (defaults are for ft891/991) for send_raw
    cat_line_term       => ';',
    cat_mic_front       => "EX11050;EX09010;EX08090;EX06050;",
    cat_mic_rear        => "EX11051;EX09011;EX08091;EX06051;",
    # general configuration
    active_vfo          => 'A',
    always_on_top       => 0,       # 1 will keep window always on top by default
    always_on_top_gridtools => 1,   # 1 will keep grid tools window on top by default
    always_on_top_log   => 0,	    # 1 will keep log viewer window on top by default
    always_on_top_meters=> 1,       # 1 will keep meters window on top by default
    autoload_memories   => 0,       # 1 will avoid needing to click Load Chan button
    floating_meters     => 0,       # 1 will put the meters in their own window
    hamlib_loglevel     => "bug",   # bug err warn verbose trace cache
    hide_logview_at_start   => 1,   # 1 will hide the logview by default
    hide_logview_too        => 1,   # 1 will hide the logview with the main window
    hide_gridtools_at_start => 1,   # 1 will hide the gridtools by default
    hide_gridtools_too  => 0,       # 1 will hide gridtools with the main window
    icon_error          => "error.png",
    icon_idle           => "idle.png",
    icon_logview        => "logview.png",
    icon_gridtools      => "gridtools.png",
    icon_meters         => "meters.png",
    icon_settings       => "settings.png",
    icon_transmit       => "transmit.png",
    key_chan            => 'C',                      # open channel dropbown
    key_dnr             => 'J',			     # DSP Noise Reduction
    key_freq            => 'F',
    key_lock            => 'L',
    key_mem_edit        => 'E',
    key_mem_load        => 'D',
    key_mem_write       => 'W',
    key_mode            => 'M',
    key_offset          => 'O',
    key_ptt             => 'A',
    key_power           => 'P',
    key_rf_gain         => 'G',
    key_split           => 'X',
    key_squelch         => 'Q',
    key_tone_freq_tx    => 'T',
    key_tone_freq_rx    => 'R',
    key_tone_mode       => 'N',
    key_vfo             => 'V',
    key_volume          => 'K',
    key_width           => 'Z',
    log_file		=> "none",	  	  # put none here to disable log file
    log_level           => "debug",
    meters_in_main      => 1,			  # 1 will show meters in main window
    mic_select          => 0,
    my_qth              => "AA00aa",		  # my 6 digit gridsquare
    my_qth_elev         => 300,			  # QTH elevation in *METERS*
    poll_interval       => 250,                   # every 1/4 sec
    poll_tray_every     => 4,                     # at 1/3th the rate of normal (every 1 sec)
    res_dir             => "./res",
    scrollback_lines    => 200,		   # number of lines to hold in logview buffer
    sip_au_indev        => "pipewire",	   # microphone device
    sip_au_outdev       => "pipewire",     # headphone/speaker device
    sip_expect_debug    => 2,              # debug level for Expect in baresip wrapper
    sip_dest            => "0@10.187.0.10",  # address to call
    sip_host            => "10.187.0.10",  # SIP *REMOTE* address
    sip_port            => 5060,           # SIP *REMOTE* port
    sip_laddr           => "127.0.0.1",    # SIP *LOCAL* address
    sip_lport           => 5061,           # SIP *LOCAL* port
    sip_logfile         => 'none',	   # Log file or none for SIP client
    sip_ctrl_port       => 14103,          # this must be unique and listens on localhost, port to control baresip via; someday we'll support 'auto'
    sip_user            => 'netrig',       # SIP username
    sip_pass            => 'insecure',     # SIP password
    sip_volume          => 0,              # If 1, volume slider controls baresip volume not rig
    shortcut_key        => 'mod1-mask',    # alt (use control-mask for ctrl)
    show_alc            => 1,		   # show ALC meter
    show_comp           => 1,		   # show Compression meter
    show_power          => 1,		   # show POWER meter
    show_swr            => 1,		   # show SWR meter
    show_temp           => 0,		   # show temperature
    show_volt           => 0,		   # show voltage
    show_elev_in_gridtools => 1,	   # show elevation control in grid tools?
    start_locked        => 1,		   # 1 will start with controls locked
    stay_hidden         => 0,
    thresh_alc_min      => 0,
    thresh_alc_max      => 1,
    thresh_comp_min     => 0,
    thresh_comp_max     => 0,
    thresh_power_min    => 5,
    thresh_power_max    => 50,
    thresh_swr_min      => 0,
    thresh_swr_max      => 2.5,
    thresh_temp_min     => 0,
    thresh_temp_max     => 140,            # degF
    thresh_volt_min     => 12.8,
    thresh_volt_max     => 15,
    ui_button_active    => '#900000',      # Active button background color
    ui_alc_alarm_bg     => '#707070',	   # alarm color
    ui_alc_bg           => '#707070',      # ALC meter bg color
    ui_alc_fg           => '#70f070',      # ALC meter active color
    ui_alc_font         => 'Monospace',
    ui_alc_text         => '#000000',      # ALC meter text color
    ui_comp_alarm_bg    => '#707070',
    ui_comp_bg          => '#707070',      # CMP meter bg color
    ui_comp_fg          => '#70f070',      # CMP meter active color
    ui_comp_font        => 'Monospace',
    ui_comp_text        => '#000000',      # CMP meter text color
    ui_logview_font      => 'Monospace',
    ui_logview_font_size => '12',
    ui_power_alarm_bg   => '#cc7070',
    ui_power_bg         => '#cc7070',      # power meter bg color
    ui_power_fg         => '#f07070',      # power meter active color
    ui_power_font       => 'Monospace',
    ui_power_text       => '#000000',      # power meter text color
    ui_swr_alarm_bg     => '#f09090',
    ui_swr_bg           => '#909090',      # swr meter bg color
    ui_swr_fg           => '#f0f0f0',      # swr meter fg color
    ui_swr_font         => 'Monospace',
    ui_swr_text         => '#000000',      # swr meter text color
    ui_temp_alarm_bg    => '#f07070',
    ui_temp_bg          => '#707070',      # TMP meter bg color
    ui_temp_fg              => '#70f070',      # TMP meter active color
    ui_temp_font            => 'Monospace',
    ui_temp_text            => '#000000',      # TMP meter text color
    ui_volt_alarm_bg        => '#70cc70',
    ui_volt_bg              => '#70cc70',      # VDD meter bg color
    ui_volt_fg              => '#70f070',      # VDD meter active color
    ui_volt_font            => 'Monospace',
    ui_volt_text            => '#000000',      # VDD meter text color

    # User toggles
    use_amp                 => 0,              # 1 will enable amplifier support
    use_rotator             => 0,              # 1 will enable rotator support
    use_metric              => 0,	       # 1 will use metric (miles, etc)
    use_sip                 => 0,              # 1 will enable experimental baresip code

    # misc
    vfo_digits              => 8,              # digits to display on VFO

    # Default window properties
    win_border              => 10,
    win_visible             => 0,
    win_x                   => 0,
    win_y                   => 0,
    # center, mouse, center_always, center_on_parent, none (place at x,y below)
    win_baresip_settings_placement => 'none',
    win_baresip_settings_x  => 0,
    win_baresip_settings_y  => 0,
    win_gridtools_placement => 'none',
    win_gridtools_x         => 0,
    win_gridtools_y         => 0,
    win_logview_placement   => 'none',
    win_logview_height      => 480,
    win_logview_width       => 1024,
    win_logview_x           => 0,
    win_logview_y           => 0,
    win_mem_edit_x          => 1,
    win_mem_edit_y          => 1,
    win_settings_placement  => 'none',
    win_settings_x          => 183,
    win_settings_y          => 318,
};

our $default_memories = {
    # stuff
};

1;
