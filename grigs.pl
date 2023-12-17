#!/usr/bin/perl
# grigs.pl: GTK rigctld frontend for the system tray
# You need to run rigctld with -o such as in ./run-dummy-rigctld

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Sys::Hostname;
use Data::Dumper;
use Hamlib;
use YAML::XS;
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday tv_interval usleep);
use Gtk3 '-init';
use Glib qw(TRUE FALSE);
use Data::Structure::Util qw/unbless/;
use FindBin;
use lib $FindBin::Bin;
use woodpile;
use grigs_hamlib;
use grigs_settings;
use grigs_fm;
use grigs_memory;
use Getopt::Long;

# project settings
my $app_name = 'grigs';
my $app_descr = "GTK frontend for rigctld";

my $default_cfg_file = $ENV{"HOME"} . "/.config/${app_name}.yaml";
my $cfg_file = $default_cfg_file;
my $log_file = $ENV{"HOME"} . "/${app_name}.log";

# Start logging in debug mode until config is loaded and we quiet down...
our $log = woodpile::Log->new($log_file, "debug");

################################################

our @vfo_widths_fm = ( 12500, 25000 );
our @vfo_widths_am = ( 6000, 5000, 3800, 3200, 3000, 2800 );
our @vfo_widths_ssb = ( 3000, 3800, 3200, 2800, 2700, 2500 );
my @pl_tones = (
    67.0, 71.9, 77.0, 88.5, 94.8, 100.0, 103.5, 107.2, 110.9, 114.8,
    118.8, 123.0, 127.3, 131.8, 136.5, 141.3, 146.2, 151.4, 156.7, 162.2,
    167.9, 173.8, 179.9, 186.2, 192.8, 203.5, 210.7, 218.1, 225.7, 233.6,
    241.8, 250.3
);

############################
# Configuration File Stuff #
############################
# run-time state
my $vfos = $grigs_hamlib::vfos;
my $settings_open = 0;
my $tray_icon;		# systray icon
my $w_main;		# main window
my $rig_timer;	# the timer for rig loop, so we can cancel and restart it
my $connected = 0;
my $hamlib_riginfo;
my $w_settings;
my $mode_entry;
my $rig_vol_entry;
my $tone_freq_tx_entry;
my $tone_freq_rx_entry;
my $vfo_freq_entry;
my $vfo_sel_button;
my $width_entry;
my $box;
my $fm_box;
my $rig;

# icons for our various run-time states
my $icon_error_pix;
my $icon_idle_pix;
my $icon_main_pix;
my $icon_settings_pix;
my $icon_transmit_pix;

my $cfg_readonly = 0;

# - Default configuration
my $def_cfg = {
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
   key_freq => 'F',
   key_rf_gain => 'G',
   key_mem_edit => 'E',
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
# Set config to defconfig, until we load config...
my $cfg = $def_cfg;
my $cfg_p;

# Function to resize window height based on visible boxes
# Call this when widgets in a window are hidden or shown, to calculate needed dimensions
sub autosize_height {
    my ($window) = @_;

    # Get preferred height for the current width
    my ($min_height, $nat_height) = $box->get_preferred_height_for_width($cfg->{'win_x'});

    # Set window height based on the preferred height of visible boxes
    $window->resize($window->get_allocated_width(), $min_height);
}

# main menu
my $main_menu_open = 0;
sub main_menu_item_clicked {
   my ($item, $window, $menu) = @_;

   if ($item->get_label() eq 'Toggle Window') {
      $window->set_visible(!$window->get_visible());
   } elsif ($item->get_label() eq 'Quit') {
      close_main_win();
   } elsif ($item->get_label() eq 'Settings') {
      grigs_settings::show_settings($cfg, $window);
   }

   $main_menu_open = 0;
   $menu->hide(); # Hide the menu after the choice is made
}

sub main_menu {
   my ($status_icon, $button, $time) = @_;
   if ($main_menu_open) {
      return;
   }

   $main_menu_open = 1;
   my $menu = Gtk3::Menu->new();
   my $sep1 = Gtk3::SeparatorMenuItem->new();
   my $sep2 = Gtk3::SeparatorMenuItem->new();
   my $toggle_item = Gtk3::MenuItem->new("Toggle Window");
   $toggle_item->signal_connect(activate => sub { main_menu_item_clicked($toggle_item, $w_main, $menu) });
   $menu->append($toggle_item);
   $menu->append($sep1);

   my $settings_item = Gtk3::MenuItem->new("Settings");
   $settings_item->signal_connect(activate => sub { main_menu_item_clicked($settings_item, $w_main, $menu) });
   $menu->append($settings_item);
   $menu->append($sep2);

   my $quit_item = Gtk3::MenuItem->new("Quit");
   $quit_item->signal_connect(activate => sub { main_menu_item_clicked($quit_item, $w_main, $menu) });
   $menu->append($quit_item);

   $menu->show_all();
   $menu->popup(undef, undef, undef, undef, $button, $time);
}

sub save_config {
   if (!$cfg_readonly && (!defined($cfg->{'readonly'}) || !$cfg->{'readonly'})) {
      $cfg_p->save_config($cfg_file);
   } else {
      $log->Log("core", "info", "Not saving configuration as it's read-only");
   }
}

sub close_main_win {
   my ($widget, $event) = @_;

   save_config();
   Gtk3->main_quit();
   return TRUE;
}

sub w_main_state {
   my ($widget, $event) = @_;
   my $on_top = 0;
   my $focused = 0;

   # instead of minimizing, hide the window to tray so it doesnt clutter app tray
   if ($event->new_window_state =~ m/\biconified\b/) {
      # Prevent the window from being iconified
      $w_main->deiconify();
      # and minimize it to the system tray icon
      w_main_hide();
      return TRUE;
   }
   if ($event->new_window_state =~ m/\babove\b/) {
      $on_top = 1;
   }
   if ($event->new_window_state =~ m/\bfocused\b/) {
      $focused = 1;
   }

   # the window shouldn't ever be maximized...
   if ($event->new_window_state =~ m/\bmaximized\b/) {
      $w_main->unmaximize();
   }
   if (defined($event->new_window_state)) {
      $log->Log("ui", "debug", "window state event: " . $event->new_window_state . " (ontop: $on_top, focused: $focused)");
   }
   return FALSE;
}

sub w_main_click {
    my ($widget, $event) = @_;
    # Right mouse click (display menu)
    if ($event->type eq 'button-press' && $event->button == 3) {
        main_menu($tray_icon, 3, $event->time);
    }
}

sub w_main_hide {
   $cfg->{'win_visible'} = 0;
   $w_main->set_visible(0);
   return FALSE;
}

sub w_main_fm_toggle {
   # hide the FM box, unless in FM mode
   my $curr_vfo = $cfg->{'active_vfo'};
   my $vfo = $vfos->{$curr_vfo};
   my $mode = uc($vfo->{'mode'});

   if ($mode eq "FM") {
      $fm_box->show_all();
      autosize_height($w_main);
   } else {
      $fm_box->hide();
      autosize_height($w_main);
   }
}

sub w_main_show {
   $cfg->{'win_visible'} = 1;
   $w_main->deiconify();
   $w_main->set_visible(1);
   $w_main->show_all();
   w_main_fm_toggle();

   return FALSE; 
}

sub w_main_toggle {
   if ($cfg->{'win_visible'}) {
      $log->Log("ui", "debug", "hide w_main");
      w_main_hide();
   } else {
      $log->Log("ui", "debug", "show w_main");
      w_main_show();
   }
   return FALSE;
}
 
sub w_main_keypress {
   my ($widget, $event) = @_;

   # if ESCape, minimize to the tray
   if ($event->keyval == 65307) {
      w_main_hide();
   }
   return;
}

sub load_icon {
   my ($icon_filename) = @_;
   my $pixbuf;

   if (-f $icon_filename) {
      $log->Log("ui", "debug", "loading icon $icon_filename");
      $pixbuf = Gtk3::Gdk::Pixbuf->new_from_file($icon_filename) or die "Failed loading icon $icon_filename\n";
   } else {
      die "Missing icon file $icon_filename - can't continue!\n";
   }
   return $pixbuf;
}

# XXX: make this
sub unload_icons {
}

sub load_icons {
   my ($state) = @_;
   my $res = $cfg->{'res_dir'};
   my $icon_error = $res . "/" . $cfg->{'icon_error'};
   my $icon_idle = $res . "/" . $cfg->{'icon_idle'};
   my $icon_settings = $res . "/" . $cfg->{'icon_settings'};
   my $icon_transmit = $res . "/" . $cfg->{'icon_transmit'};

   # Load images, if not already loaded
   if (!defined($icon_error_pix)) {
      $icon_error_pix = load_icon($icon_error);
   }
   if (!defined($icon_idle_pix)) {
      $icon_idle_pix = load_icon($icon_idle);
   }
   if (!defined($icon_settings_pix)) {
      $icon_settings_pix = load_icon($icon_settings);
   }
   if (!defined($icon_transmit_pix)) {
      $icon_transmit_pix = load_icon($icon_transmit);
   }

   # initialize the tray icon
   if (!defined($tray_icon)) {
      $log->Log("ui", "debug", "creating tray icon");
      $tray_icon = Gtk3::StatusIcon->new();
      # Create a system tray icon with the loaded icon
      $tray_icon->signal_connect('activate' => \&w_main_toggle );
      $tray_icon->signal_connect('popup-menu' => \&main_menu );
   }
}

sub switch_vfo {
   my $vfo = shift;

   $log->Log("vfo", "info", "Switching to VFO $vfo");
   $vfo_sel_button->set_label("VFO: " . grigs_hamlib::next_vfo($vfo) . " (" . $cfg->{'key_vfo'} . ")");
   $cfg->{active_vfo} = $vfo;

   grigs_hamlib::read_rig();
}

sub w_main_ontop {
   my $val = shift;
   if (!defined($val)) {
      $val = 0;
   }

   $w_main->set_keep_above($val);
}

sub next_vfo {
    my $nval = grigs_hamlib::next_vfo($cfg->{'active_vfo'});
    switch_vfo($nval);
    print "nval: $nval, curr: " . $cfg->{'active_vfo'} . "\n";
    return FALSE;
}

sub find_offset {
    my $array_ref = shift;
    my @a = @$array_ref;
    my $val = shift;
    my $index = -1;

    if (!defined($val)) {
       return -1;
    }

    for my $i (0 .. $#a) {
        if (looks_like_number($a[$i]) && looks_like_number($val)) {
            # Compare as numbers if both values are numeric
            if ($a[$i] == $val) {
                $index = $i;
                last;
            }
        } else {
            # Compare as strings if either value is non-numeric
            if ("$a[$i]" eq "$val") {
                $index = $i;
                last;
            }
        }
    }
    return $index;
}

sub refresh_available_widths {
   my $curr_vfo = $cfg->{'active_vfo'};
   my $vfo = $vfos->{$curr_vfo};
   my $val = $vfo->{'width'};
   my $rv = -1;

   # empty the list
   $width_entry->remove_all();

   if (!defined($val)) {
      $vfo->{'width'} = $val = 3000;
   }

   if ($vfo->{'mode'} eq "FM") {
      foreach my $value (@vfo_widths_fm) {
         $width_entry->append_text($value);
      }
      $rv = find_offset(\@vfo_widths_fm, $val);
   } elsif ($vfo->{'mode'} =~ m/AM/) {
      foreach my $value (@vfo_widths_am) {
         $width_entry->append_text($value);
      }
      $rv = find_offset(\@vfo_widths_am, $val);
   } elsif ($vfo->{'mode'} =~ qr/(D-[UL]|USB|LSB)/) {
      foreach my $value (@vfo_widths_ssb) {
         $width_entry->append_text($value);
      }
      $rv = find_offset(\@vfo_widths_ssb, $val);
   } elsif ($vfo->{'mode'} =~ m/C4FM/) {
      $width_entry->append_text(12500);
      $rv = 0;
   }
   if ($rv == -1) {
      $rv = 0;
   }
   $log->Log("ui", "debug", "refresh avail widths: VFO $curr_vfo, mode " . $vfo->{'mode'} . " val: $val (rv: $rv)");
   $width_entry->set_active($rv);
}

sub channel_list {
    my $store = Gtk3::ListStore->new('Glib::String', 'Glib::String', 'Glib::String');

    my $iter = $store->append();
    $store->set($iter, 0, '1', 1, ' WWV 5MHz', 2, ' 5,000.000 KHz AM');

    $iter = $store->append();
    $store->set($iter, 0, '2', 1, ' WWV 10MHz', 2, ' 10,000.000 KHz AM');

    $iter = $store->append();
    $store->set($iter, 0, '3', 1, ' WWV 15MHz', 2, ' 15,000.000 KHz AM');

    $iter = $store->append();
    $store->set($iter, 0, '4', 1, ' WWV 20MHz', 2, ' 20,000.000 KHz AM');

    $iter = $store->append();
    $store->set($iter, 0, '5', 1, ' WWV 25MHz', 2, ' 25,000.000 KHz AM');


#$combo->set_active(1);
    return $store;
}

sub draw_main_win {
   $w_main = Gtk3::Window->new('toplevel');

   # XXX: We need to set the window icon
   $w_main->set_title("grigs: Not connected");
   $w_main->set_default_size($cfg->{'win_width'}, $cfg->{'win_height'});
   $w_main->set_border_width($cfg->{'win_border'});
   my $resizable = 0;

   if (defined($cfg->{'win_resizable'})) {
      $resizable = $cfg->{'win_resizable'};
   }

   $w_main->set_resizable($resizable);

   if ($cfg->{'always_on_top'}) {
      w_main_ontop(1)
   }

   $w_main->set_default_size($cfg->{'win_width'}, $cfg->{'win_height'});  # Replace $width and $height with desired values
   $w_main->move($cfg->{'win_x'}, $cfg->{'win_y'});  # Replace $x and $y with desired coordinates

   $w_main->signal_connect('button-press-event' => \&w_main_click);
   $w_main->signal_connect(delete_event => \&close_main_win);
   $w_main->signal_connect(window_state_event => \&w_main_state);
   $w_main->signal_connect('key-press-event' => \&w_main_keypress);

   $w_main->signal_connect('configure-event' => sub {
       my ($widget, $event) = @_;
       
       # Retrieve the size and position information
       my ($width, $height) = $widget->get_size();
       my ($x, $y) = $widget->get_position();

       # Save the data...
       $cfg->{'win_x'} = $x;
       $cfg->{'win_y'} = $y;
       $cfg->{'win_height'} = $height;
       $cfg->{'win_width'} = $width;

       # Return FALSE to allow the event to propagate
       return FALSE;
   });

   #####################
   # Layout the window #
   #####################
   my $w_main_accel = Gtk3::AccelGroup->new();
   $w_main->add_accel_group($w_main_accel);
   $box = Gtk3::Box->new('vertical', 5);

   my $curr_vfo = $cfg->{active_vfo};
   if ($curr_vfo eq '') {
      $curr_vfo = $cfg->{active_vfo} = 'A';
   }

   # Show the channel choser combobox
   my $chan_combo = Gtk3::ComboBox->new_with_model(channel_list());
   $chan_combo->set_active(1);
   $chan_combo->set_entry_text_column(1);
   my $render1 = Gtk3::CellRendererText->new();
   $chan_combo->pack_start($render1, FALSE);
   $chan_combo->add_attribute($render1, text => 0);
   my $render2 = Gtk3::CellRendererText->new();
   $chan_combo->pack_start($render2, FALSE);
   $chan_combo->add_attribute($render2, text => 1);
   my $render3 = Gtk3::CellRendererText->new();
   $chan_combo->pack_start($render3, FALSE);
   $chan_combo->add_attribute($render3, text => 2);
   $box->pack_start($chan_combo, FALSE, FALSE, 0);

   # Memory edit button
   my $mem_edit_button = Gtk3::Button->new("Edit Chan (" . $cfg->{'key_mem_edit'} . ")");
   $mem_edit_button->set_tooltip_text("Add or Edit Memory slot");

   $mem_edit_button->signal_connect(clicked => sub {
      grigs_memory::show_window();
   });
   $mem_edit_button->grab_focus();
   $box->pack_start($mem_edit_button, FALSE, FALSE, 0);
   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_mem_edit'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $mem_edit_button->grab_focus();
      grigs_memory::show_window();
   });

   # VFO choser:
   $vfo_sel_button = Gtk3::Button->new("VFO: " . $curr_vfo . " (" . $cfg->{'key_vfo'} . ")");
   $vfo_sel_button->set_tooltip_text("Toggle active VFO");

   $vfo_sel_button->signal_connect(clicked => sub {
      next_vfo();
   });
   $vfo_sel_button->grab_focus();
   $box->pack_start($vfo_sel_button, FALSE, FALSE, 0);
   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_vfo'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $vfo_sel_button->grab_focus();
      next_vfo();
   });

   # rig volume
   my $rig_vol_label = Gtk3::Label->new("Volume % (" . $cfg->{'key_volume'} . ")");
   my $rig_vol_entry = Gtk3::Scale->new_with_range('horizontal', 0, 100, 1);
   $rig_vol_entry->set_digits(0);           # Disable decimal places
   $rig_vol_entry->set_draw_value(TRUE);    # Display the current value on the slider
   $rig_vol_entry->set_has_origin(FALSE);   # Disable origin value
   $rig_vol_entry->set_value_pos('right');  # Set the position of the value indicator
   $rig_vol_entry->set_value($cfg->{'rig_volume'});
   $rig_vol_entry->set_tooltip_text("Please click and drag to set RX volume");
   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_volume'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $rig_vol_entry->grab_focus();
   });

   # Active VFO settings
   my $vfo_freq_label = Gtk3::Label->new('Frequency (Hz) (' . $cfg->{'key_freq'} . ')');
   $vfo_freq_entry = Gtk3::SpinButton->new_with_range($vfos->{$curr_vfo}{'min_freq'}, $vfos->{$curr_vfo}{'max_freq'}, $vfos->{$curr_vfo}{'vfo_step'});
   $vfo_freq_entry->set_numeric(TRUE);  # Display only numeric input
   $vfo_freq_entry->set_wrap(FALSE);    # Do not wrap around on reaching min/max values
   $vfo_freq_entry->set_value($vfos->{$curr_vfo}{'freq'});
   $vfo_freq_entry->set_tooltip_text("VFO frequency input");

   $vfo_freq_entry->signal_connect(changed => sub {
       my ($widget, $event) = @_;

       my $freq = $vfo_freq_entry->get_text();
       $log->Log("vfo", "debug", "Changing freq on VFO $curr_vfo to $freq");
       grigs_hamlib::rig_set_freq($freq);
       return FALSE;
   });

   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_freq'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $vfo_freq_entry->grab_focus();
   });

   $vfo_freq_entry->signal_connect('button-press-event' => sub {
       my ($widget, $event) = @_;

       $log->Log("vfo btn", "debug", Dumper($event) . "\n");

       if ($event->button() == 3) { # Right-click
           my $menu = Gtk3::Menu->new();
#           my $clipboard = Gtk3::Clipboard->get();
           my $menu_item_copy = Gtk3::MenuItem->new_with_label('Copy');
#           $menu_item_copy->signal_connect('activate' => sub {
#              print "Copy to clipboard\n";
#              # Get the text from the SpinButton and copy it to the clipboard
#              my $text = $vfo_freq_entry->get_text();
#              $clipboard->set_text($text, -1); # Use -1 to indicate automatic length detection
#           });
           $menu->append($menu_item_copy);

           my $menu_item_paste = Gtk3::MenuItem->new_with_label('Paste');
#           $menu_item_paste->signal_connect('activate' => sub {
#              # Perform paste operation (insert value from clipboard if available)
#              my $text = $clipboard->wait_for_text();
#              if (defined $text && is_numeric($text)) {
#                 $vfo_freq_entry->set_text($text);
#              } else {
#                 $log->Log("ui", "info", "no clipboard text to paste");
#              }
#           });
           $menu->append($menu_item_paste);

           # Create menu items
           my $menu_item_step = Gtk3::MenuItem->new_with_label('Set step');
           $menu_item_step->signal_connect('activate' => sub {
               print "show freq step menu!\n"; # Perform your custom action here
           });
           $menu->append($menu_item_step);

           # Show the menu
           $menu->show_all();
           $menu->popup(undef, undef, undef, undef, $event->button(), $event->time());
           return TRUE;
       }
       return FALSE;
   });

   # XXX: we need to TAB key presses in the drop downs and move to next widget...
   my $mode_label = Gtk3::Label->new('Mode (' . $cfg->{'key_mode'} . ')');
   $mode_entry = Gtk3::ComboBoxText->new();
   $mode_entry->set_tooltip_text("Modulation Mode. Some options my not be supported by your rig.");
   $mode_entry->append_text('D-U');
   $mode_entry->append_text('D-L');
   $mode_entry->append_text('USB');
   $mode_entry->append_text('LSB');
   $mode_entry->append_text('FM');
   $mode_entry->append_text('AM');
   $mode_entry->append_text('C4FM');
   $mode_entry->append_text('CW');
   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_mode'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $mode_entry->grab_focus();
   });
   $mode_entry->set_active(0);

   # Callback function to handle selection change
   $mode_entry->signal_connect(changed => sub {
       my $selected_item = $mode_entry->get_active_text();
       print "Mode Selected: $selected_item\n";  # Print the selected item (for demonstration)
       my $curr_vfo = $cfg->{'active_vfo'};
       my $vfo = $vfos->{$curr_vfo};
       my $mode = uc($vfo->{'mode'});
       $vfo->{'mode'} = uc($selected_item);
       # apply it
#       grigs_hamlib::set_mode($curr_vfo, $mode);
       # update the GUI
       w_main_fm_toggle();
       refresh_available_widths();
   });

   my $width_label = Gtk3::Label->new('Width (hz) (' . $cfg->{'key_width'} . ')');
   $width_entry = Gtk3::ComboBoxText->new();
   $width_entry->set_tooltip_text("Modulation bandwidth");
   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_width'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $width_entry->grab_focus();
   });
   refresh_available_widths();

   # Callback function to handle selection change
   $width_entry->signal_connect(changed => sub {
       my $selected_item = $width_entry->get_active_text();
       if (defined($selected_item)) {
          $log->Log("ui", "debug", "Width Selected: $selected_item\n");  # Print the selected item (for demonstration)
          my $curr_vfo = $cfg->{'active_vfo'};
          my $vfo = $vfos->{$curr_vfo};
          $vfo->{'width'} = $selected_item;
       }
   });

   my $rf_gain_label = Gtk3::Label->new('RF Gain (' . $cfg->{'key_rf_gain'} . ')');
   my $rf_gain_entry = Gtk3::Scale->new_with_range('horizontal', 0, 40, 1);
   $rf_gain_entry->set_digits(0);           # Disable decimal places
   $rf_gain_entry->set_draw_value(TRUE);    # Display the current value on the slider
   $rf_gain_entry->set_has_origin(FALSE);   # Disable origin value
   $rf_gain_entry->set_value_pos('right');  # Set the position of the value indicator
   $rf_gain_entry->set_value($vfos->{$curr_vfo}{'rf_gain'});
   $rf_gain_entry->set_tooltip_text("Please Click and DRAG to change RF gain");
   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_rf_gain'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $rf_gain_entry->grab_focus();
   });
   $rf_gain_entry->signal_connect(value_changed => sub {
       my $curr_vfo = $cfg->{'active_vfo'};
       my $vfo = $vfos->{$curr_vfo};
       my $value = $rf_gain_entry->get_value();
       $vfo->{'rf_gain'} = $value;
   });
   # Variable to track if the scale is being dragged
   my $dragging = 0;

   my $vfo_power_label = Gtk3::Label->new('Power (Watts) (' . $cfg->{'key_power'} . ')');
   my $vfo_power_entry = Gtk3::Scale->new_with_range('horizontal', $vfos->{$curr_vfo}{'min_power'}, $vfos->{$curr_vfo}{'max_power'}, $vfos->{$curr_vfo}{'power_step'});
   $vfo_power_entry->set_digits(0);           # Disable decimal places
   $vfo_power_entry->set_draw_value(TRUE);    # Display the current value on the slider
   $vfo_power_entry->set_has_origin(FALSE);   # Disable origin value
   $vfo_power_entry->set_value_pos('right');  # Set the position of the value indicator
   $vfo_power_entry->set_value($vfos->{$curr_vfo}{'power'});
   $vfo_power_entry->set_tooltip_text("Please Click and DRAG to change TX power");
   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_power'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $vfo_power_entry->grab_focus();
   });

   #### Here we do some ugly stuff to try and prevent sudden jumps in power ####
   # Connect a signal to track button press
   $vfo_power_entry->signal_connect('button-press-event' => sub {
       my ($widget, $event) = @_;
       $dragging = 1;  # Set dragging flag when the slider is clicked

       # reset the value to our stored state to discard this change
       return FALSE;   # Prevent the default behavior
   });

   # Connect a signal to track button release
   $vfo_power_entry->signal_connect('button-release-event' => sub {
       $dragging = 0;  # Reset dragging flag on button release
       if (!defined($vfos->{$curr_vfo}{'power'}) ||$vfos->{$curr_vfo}{'power'} eq "") {
          $vfos->{$curr_vfo}{'power'} = $rig->get_vfo();
       }
       # reset it
       $vfo_power_entry->set_value($vfos->{$curr_vfo}{'power'});
       return FALSE;
   });

   $vfo_power_entry->signal_connect(value_changed => sub {
       my $value = $vfo_power_entry->get_value();
       my $oldval = $vfos->{$curr_vfo}{'power'};
       my $change = 0;
       my $step = $vfos->{$curr_vfo}{'power_step'};

       if (!defined($oldval) || !defined($step)) {
          $oldval = 0;
          $step = 2;
       }

       my $max_change = $step * 5;

       # round it
       $value = int($value + 0.5);

       # calculate how much change occurred
       if ($value > $oldval) {
          $change = $value - $oldval;
       }  elsif ($value < $oldval) {
          $change = $oldval - $value;
       }

#       $log->Log("ui", "debug", "change power: dragging: $dragging - change: $change. val $value oldval: $oldval");
       
       if ($dragging < 2) {
          return FALSE;
       }

       # Ensure no abrupt changes occurred
       if ($change <= $max_change) {
          $vfos->{$curr_vfo}{'power'} = $value;
          # XXX: Send hamlib command for power
          # grigs_hamlib::set_power($curr_vfo);
       } else {		# reject change otherwise
          return FALSE;
       }
       return TRUE;
   });

   $vfo_power_entry->signal_connect('motion-notify-event' => sub {
       my ($widget, $event) = @_;
       $dragging = 2;
       return FALSE;  # Propagate the event further
   });

   # XXX: This will change soon as _accel will be wrapped in window object
   $fm_box = grigs_fm::new($cfg, $w_main, $w_main_accel);

   #########
   $box->pack_start($vfo_freq_label, FALSE, FALSE, 0);
   $box->pack_start($vfo_freq_entry, FALSE, FALSE, 0);
   $box->pack_start($rig_vol_label, FALSE, FALSE, 0);
   $box->pack_start($rig_vol_entry, FALSE, FALSE, 0);
   $box->pack_start($rf_gain_label, FALSE, FALSE, 0);
   $box->pack_start($rf_gain_entry, FALSE, FALSE, 0);
   $box->pack_start($vfo_power_label, FALSE, FALSE, 0);
   $box->pack_start($vfo_power_entry, FALSE, FALSE, 0);
   $box->pack_start($mode_label, FALSE, FALSE, 0);
   $box->pack_start($mode_entry, FALSE, FALSE, 0);
   $box->pack_start($width_label, FALSE, FALSE, 0);
   $box->pack_start($width_entry, FALSE, FALSE, 0);
   $box->pack_start($fm_box, FALSE, FALSE, 0);

   # Add the Buttons
   ##################
   my $hide_button = Gtk3::Button->new_with_mnemonic('_Hide');
   $hide_button->signal_connect(clicked => \&w_main_hide);
   $hide_button->set_tooltip_text("Minimize to the system try");

   my $settings_button = Gtk3::Button->new_with_mnemonic('_Settings');
   $settings_button->signal_connect(clicked => sub { grigs_settings::show_settings($cfg, $w_main) });
   $settings_button->set_tooltip_text("Settings editor");
   my $quit_button = Gtk3::Button->new_with_mnemonic('_Quit');
   $quit_button->signal_connect(clicked => \&close_main_win);
   $quit_button->set_tooltip_text("Exit the program");

   # Add widgets and insert the box in the window
   $box->pack_start($hide_button, FALSE, FALSE, 0);
   $box->pack_start($settings_button, FALSE, FALSE, 0);
   $box->pack_start($quit_button, FALSE, FALSE, 0);
   $w_main->add($box);


   # Draw it and hide the FM box
   w_main_show();

   # set the window visibility to saved state (from config) automaticly?
   if ($cfg->{'stay_hidden'}) {
      my $vis = $cfg->{'win_visible'};
      $log->Log("ui", "info", "stay hidden mode enabled: visible=$vis");
      $w_main->set_visible($vis);
   }
}

# Set the icon on settings window. This is called from grigs_settings::show_settings
sub set_settings_icon {
   my $win = shift;
   $win->set_icon($icon_settings_pix);
}

sub get_state_icon {
   my $state = shift;

   if ($state eq "idle") {
      return $icon_idle_pix;
   } elsif ($state eq "transmit") {
      return $icon_transmit_pix;
   } else {
      return $icon_error_pix;
   }
}

sub set_tray_tooltip {
   my $icon = shift;
   my $tooltip_text = shift;
   $icon->set_tooltip_text($tooltip_text);
}

# Set up the tray icon and set a label on it...
#############
sub set_tray_icon {
   my $status = shift;

   my $connected_txt = '';

   if ($status eq "idle") {
      $connected_txt = "Connected";
   } else {
      $connected_txt = "Connecting";
   }
   my $freq = '';
   my $rigctl_addr = $cfg->{'rigctl_addr'};
   my $status_txt = '';
   my $curr_vfo = $cfg->{'active_vfo'}; 
   if (defined($rig)) {
      if ($rig->get_ptt($Hamlib::RIG_VFO_A)) {
         $status_txt = "TRANSMIT";
      } else {
         $status_txt = "RECEIVE";
      }
   } else {
      $status_txt = "INITIALIZING";
   }
   my $freq_txt = $vfos->{$curr_vfo}{'freq'};
   my $mode_txt = $vfos->{$curr_vfo}{'mode'};
   my $width_text = $vfos->{$curr_vfo}{'width'};
   my $power_text = $vfos->{$curr_vfo}{'power'};
   my $swr_txt = "1";

   # create and apply the tooltip help for tray icon...
   my $tray_tooltip  = "$app_name: Click to toggle display or right click for menu.\n";
      $tray_tooltip .= "\t$connected_txt to $rigctl_addr\n";
      $tray_tooltip .= "\t$status_txt $freq_txt $mode_txt ${width_text} hz\n\n";
      $tray_tooltip .= "Meters:\n";
      $tray_tooltip .= "\t\tPower: ${power_text}W\n\t\tSWR: ${swr_txt}:1\n";
   set_tray_tooltip($tray_icon, $tray_tooltip);

   $tray_icon->set_from_pixbuf(get_state_icon($status));
}

sub set_icon {
   my $state = shift;
   my $state_txt = "unknown";

   if ($state eq "idle") {
      $state_txt = "Connected to ";
   } elsif ($state eq "connecting") {
      $state_txt = "Connecting to ";
   } elsif ($state eq "transmit") {
      $state_txt = "TRANSMIT - ";
   }
   $w_main->set_title("$app_name: $state_txt " . $cfg->{'rigctl_addr'});

   my $icon = get_state_icon($state);
   $w_main->set_icon($icon);
   set_tray_icon($state);
}

my $on_init = 0;

# Delay the hamlib
sub hamlib_init {
   return if $on_init;

   $rig = grigs_hamlib::setup_hamlib($cfg);
   if (defined($rig)) {
      set_icon("idle");
   } else {
      die "Wtf? setup_hamlib returned undefined\n";
   }
   $on_init = 1;
}
Glib::Timeout->add(1000, \&hamlib_init);

sub show_help {
   print "$app_name: $app_descr\n";
   print "==== General Options ====\n";
   print "\t-f <file>\t\tSpecify a configuration file for the rig\n";
   print "\t-h\t\t\tDisplay this help message\n";
   print "\t\t--help\n";
   print "\t-r\t\t\tTreat the configuration file as read-only\n";
   print "\n";
   print "==== Window Placement ====\n";
   print "\t-a\t\t\tAlways on top\n";
   print "\t-x\t\t\tX position of main window\n";
   print "\t-y\t\t\tY position of main window\n";
   exit 0;
}

###########################################################
# scratch space for cmdline arguments
my $cl_show_help = 0;
my $cl_ontop;		# always on top?
my $cl_x;		# cmdline X pos of main win
my $cl_y;		# cmdline Y pos of main win
my $cl_s_x;		# cmdline X pos of settings win
my $cl_s_y;		# cmdline Y pos of settings win

# Parse command line options
GetOptions(
   "a" => \$cl_ontop,		# -a for always on top
   "f=s" => \$cfg_file,    	# -f to specify the config file
   "r" => \$cfg_readonly, 	# -r for read-only config
   "h|help" => \$cl_show_help,     # -h or --help for help
   "x=i" => \$cl_x,		# X pos of main win
   "y=i" => \$cl_y,		# Y pos of main win
) or die "Invalid options - see --help\n";

# Show help if requested
if ($cl_show_help) { show_help(); }

# Load configuration
$log->Log("core", "info", "$app_name is starting");
$cfg_p = woodpile::Config->new($log, $cfg_file, $def_cfg);
$cfg = $cfg_p->{cfg};

# Merge commandline options, overriding config file
if ($cfg_readonly) {
   $log->Log("core", "info", "using configuration read-only");
   $cfg->{'read_only'} = 1;
}

if (defined($cl_ontop)) {
   $log->Log("ui", "info", "Forcing always on top due to -a cmdline option");
   $cfg->{'always_on_top'} = 1;
}

if (defined($cl_x) && defined($cl_y)) {
   $log->Log("ui", "info", "Placing main window at $cl_x, $cl_y at cmdline request");
   $cfg->{'win_x'} = $cl_x;
   $cfg->{'win_y'} = $cl_y;
} elsif (defined($cl_x) || defined($cl_y)) {
   $log->Log("ui", "error", "You must specify both -x and -y options to place the window at startup");
   exit 1;
}

# Setup the GUI
load_icons();
draw_main_win();
set_icon("connecting");
grigs_memory::init($cfg, $w_main);

# gtk main loop
Gtk3->main();

# And say goodbye...
$log->Log("core", "info", "$app_name is shutting down!");
