package grigs_settings;
use Carp;
use Data::Dumper;
#use strict;
use Glib qw(TRUE FALSE);
use warnings;

my $config_box;
my $address_entry;
my $poll_interval_entry;
my $poll_tray_entry;
my $core_debug;
my $hamlib_debug;
my $temp_cfg;
my $w_main;

sub print_signal_info {
   my ($widget, $signal_name) = @_;
   print "Signal emitted by $widget: $signal_name\n";
}

sub apply_settings {
   main::w_main_ontop($cfg->{'always_on_top'});
}

sub save_settings {
   if (defined($temp_cfg)) {
      print "Merging settings into in-memory config\n";
      my $tmp = {%$cfg, %$tmp_cfg};
      $cfg = $tmp;
      print "settings: " . Dumper($tmp) . "\n";
   } else {
      print "no tmpconfig\n";
   }
   print "Apply settings\n";
   apply_settings();
   main::save_config();
   $settings_open = 0;
   $w_settings->destroy();
}

sub combobox_keys {
   my ($widget, $event) = @_;
   if ($event->keyval == 65289) {
      print "[ui/debug]: next!\n";
      $w_settings->child_focus('down');
      return TRUE; 	# Stop further handling
   } else {
      print "xxx: keyval - " . $event->keyval . "\n";
      return FALSE; 	# Continue default handling
   }
}

sub show_settings {
   my $cfg = shift;
   my $mainwin = shift;
   $w_main = $mainwin;

   # if settings window is already open raise it instead
   if ($settings_open) {
      $w_settings->present();
      $w_settings->grab_focus();
      return TRUE;
   }

   # Nope, we'll create the window...
   $settings_open = 1;
   $w_settings = Gtk3::Window->new('toplevel',
      decorated => TRUE,
      destroy_with_parent => TRUE,
      title => "Settings",
      border_width => 10,
      position => 'center'
   );
   # this makes the stacking order reasonable
   $w_settings->set_transient_for($w_main);
   $w_settings->set_default_size(300, 200);
   $w_settings->set_keep_above(1);
   $w_settings->set_modal(1);
   $w_settings->set_resizable(0);
   main::set_settings_icon($w_settings);

   # Bind 'Escape' key press to close the settings window with confirmation
   # XXX: Figure out why fallthrough events do not work regardless of returning TRUE or FALSE :\
#   $w_settings->signal_connect(key_press_event => sub {
#       my ($widget, $event) = @_;
#
#       if ($event->keyval == 65307) {  # ASCII value for 'Escape' key
#           close_settings($w_settings);
#           return TRUE; # Suppress further handling
#       }
#       return FALSE;
#   });

   my $w_settings_accel = Gtk3::AccelGroup->new();
   $w_settings->add_accel_group($w_settings_accel);
   $config_box = Gtk3::Box->new('vertical', 5);

   # Set width/height of teh window
   $w_settings->set_default_size($cfg->{'win_settings_width'}, $cfg->{'win_settings_height'});

   # Place the window
   $w_settings->move($cfg->{'win_settings_x'}, $cfg->{'win_settings_y'});

   $w_settings->signal_connect('configure-event' => sub {
       my ($widget, $event) = @_;
       
       # Retrieve the size and position information
       my ($width, $height) = $widget->get_size();
       my ($x, $y) = $widget->get_position();

       # Save the data...
       $cfg->{'win_settings_x'} = $x;
       $cfg->{'win_settings_y'} = $y;
       $cfg->{'win_settings_height'} = $height;
       $cfg->{'win_settings_width'} = $width;

       # Return FALSE to allow the event to propagate
       return FALSE;
   });

   $w_settings->signal_connect(delete_event => sub {
       close_settings();
       return TRUE;      # Suppress default window destruction
   });

   # Rigctl address
   my $address_label = Gtk3::Label->new('Rigctld Address:Port');
   $address_entry = Gtk3::Entry->new();
   $address_entry->set_text($cfg->{'rigctl_addr'}); # Default value
   $address_entry->set_tooltip_text("Address of rigctld server (default localhost:4532)");
   $address_entry->set_can_focus(1);
   $address_entry->signal_connect(changed => sub {
       my $val = $address_entry->get_text();
   });

   # poll interval: window visible
   my $poll_interval_label = Gtk3::Label->new('Hamlib poll interval (ms)');
   $poll_interval_entry = Gtk3::Scale->new_with_range('horizontal', 250, 60000, 250);
   $poll_interval_entry->set_digits(0);
   $poll_interval_entry->set_draw_value(TRUE);
   $poll_interval_entry->set_has_origin(FALSE);
   $poll_interval_entry->set_value_pos('right');
   $poll_interval_entry->set_value($cfg->{'poll_interval'});
   $poll_interval_entry->set_tooltip_text("Hamlib polling interval when window is active (in millisconds)");
   $poll_interval_entry->set_can_focus(1);
   $poll_interval_entry->signal_connect(value_changed => sub {
       my $val = $poll_interval_entry->get_value();
       $tmp_cfg->{'poll_interval'} = $val;
   });

   # poll interval: in tray
   my $poll_tray_label = Gtk3::Label->new('Inactive (tray), poll interval (1/x)');
   $poll_tray_entry = Gtk3::Scale->new_with_range('horizontal', 1, 120, 1);
   $poll_tray_entry->set_digits(0);
   $poll_tray_entry->set_draw_value(TRUE);
   $poll_tray_entry->set_has_origin(FALSE);
   $poll_tray_entry->set_value_pos('right');
   $poll_tray_entry->set_value($cfg->{'poll_tray_every'});
   $poll_tray_entry->set_tooltip_text("When inactive (in the tray), we poll at 1/x the normal rate above");
   $poll_tray_entry->set_can_focus(1);
   $poll_tray_entry->signal_connect(value_changed => sub {
       my $val = $poll_tray_entry->get_value();
       $tmp_cfg->{'poll_tray_every'} = $val;
   });

   # system log level
   my $core_debug_label = Gtk3::Label->new('Core log level');
   $core_debug = Gtk3::ComboBoxText->new();
   $core_debug->set_tooltip_text("Select the core log level");
   my $curr_cl_dbg = -1;
   my $i = 0;
   for our $cl_dbg_opt (keys %woodpile::Log::log_levels) {
      if ($cl_dbg_opt eq $cfg->{'log_level'}) {
         $curr_cl_dbg = $i;
      }

      $core_debug->append_text($cl_dbg_opt);
      $i++;
   }

   # did we find current debug level?
   if ($curr_cl_dbg > -1) {
      $core_debug->set_active($curr_cl_dbg);
   } else {
      $core_debug->set_active(0);
   }
   $core_debug->set_can_focus(1);

   # create hamlib debug level entry
   my $hamlib_debug_label = Gtk3::Label->new('Hamlib log level');
   $hamlib_debug = Gtk3::ComboBoxText->new();
   $hamlib_debug->set_tooltip_text("Select the logging level of hamlib");
   $i = 0;
   my $cur_hl_dbg = -1;
   for our $hl_dbg_opt (keys %grigs_hamlib::hamlib_debug_levels) {
      if ($hl_dbg_opt eq $cfg->{'hamlib_loglevel'}) {
         $cur_hl_dbg = $i;
      }

      $hamlib_debug->append_text($hl_dbg_opt);
      $i++;
   }

   if ($cur_hl_dbg > -1) {
      $hamlib_debug->set_active($cur_hl_dbg);
   } else {
      $hamlib_debug->set_active(0);
   }
   $hamlib_debug->set_can_focus(1);
   $hamlib_debug->signal_connect(key_release_event => \&combobox_keys);

   my $autohide_toggle = Gtk3::CheckButton->new();
   $autohide_toggle->set_label('Restore minimized state?');
   $autohide_toggle->set_active($cfg->{'stay_hidden'});
   $autohide_toggle->signal_connect('toggled' => sub {
      my $button = shift;
      if ($button->get_active()) {
         $tmp_cfg->{'stay_hidden'} = 1;
      } else {
         $tmp_cfg->{'stay_hidden'} = 0;
      }
   });
   $autohide_toggle->set_can_focus(1);

   my $ontop_button = Gtk3::CheckButton->new();
   $ontop_button->set_label('Keep window above others?');
   $ontop_button->set_active($cfg->{'always_on_top'});
   $ontop_button->set_can_focus(1);
   $ontop_button->signal_connect('toggled' => sub {
      my $button = shift;
      if ($button->get_active()) {
         $tmp_cfg->{'always_on_top'} = 1;
      } else {
         $tmp_cfg->{'always_on_top'} = 0;
      }
   });

   # We want Save and Cancel next to each other, so use a box to wrap
   my $button_box = Gtk3::Box->new('horizontal', 5);

   # Create an OK button to apply settings
   my $save_button = Gtk3::Button->new('_Save');
   $save_button->set_tooltip_text("Save and apply changes");
   $save_button->set_can_focus(1);
   $w_settings_accel->connect(ord('S'), $cfg->{'shortcut_key'}, 'visible', \&save_settings);

   # Create a Cancel button to discard changes
   my $cancel_button = Gtk3::Button->new('_Cancel');
   $cancel_button->set_tooltip_text("Discard changes");
   $save_button->signal_connect('activate' => \&save_settings);
   $save_button->signal_connect('clicked' => \&save_settings );
   $cancel_button->signal_connect('activate' => \&close_settings); 
   $cancel_button->signal_connect('clicked' => \&close_settings );
   $cancel_button->set_can_focus(1);
   $w_settings_accel->connect(ord('C'), 'mod1-mask', 'visible', \&close_settings);
   $button_box->pack_start($save_button, FALSE, FALSE, 0);
   $button_box->pack_start($cancel_button, FALSE, FALSE, 0);

   # place the widgets
   $config_box->pack_start($address_label, FALSE, FALSE, 0);
   $config_box->pack_start($address_entry, FALSE, FALSE, 0);
   $config_box->pack_start($poll_interval_label, FALSE, FALSE, 0);
   $config_box->pack_start($poll_interval_entry, FALSE, FALSE, 0);
   $config_box->pack_start($poll_tray_label, FALSE, FALSE, 0);
   $config_box->pack_start($poll_tray_entry, FALSE, FALSE, 0);
   $config_box->pack_start($core_debug_label, FALSE, FALSE, 0);
   $config_box->pack_start($core_debug, FALSE, FALSE, 0);
   $config_box->pack_start($hamlib_debug_label, FALSE, FALSE, 0);
   $config_box->pack_start($hamlib_debug, FALSE, FALSE, 0);
   $config_box->pack_start($autohide_toggle, FALSE, FALSE, 0);
   $config_box->pack_start($ontop_button, FALSE, FALSE, 0);
   $config_box->pack_end($button_box, FALSE, FALSE, 0);

   # Add the config box, show the window, and focus first input
   $w_settings->signal_connect(key_release_event => \&combobox_keys);
   $w_settings->add($config_box);
   $w_settings->show_all();
   $address_entry->grab_focus();
}

# Function to close the settings window
sub close_settings {
    my $dialog = Gtk3::MessageDialog->new(
        $w_settings,
        'destroy-with-parent',
        'warning',
	'yes_no',
        "Close settings window? Unsaved changes may be lost."
    );
    $dialog->set_title('Confirm Close');
    $dialog->set_default_response('no');
    $dialog->set_transient_for($w_settings);
    $dialog->set_modal(1);
    $dialog->set_keep_above(1);
    $dialog->present();
    $dialog->grab_focus();

    my $response = $dialog->run();

    if ($response eq 'yes') {
       $dialog->destroy();
       $w_settings->destroy();
       $settings_open = 0;
    } else {
       $dialog->destroy();
       $w_settings->present();
       $w_settings->grab_focus();
    }
}

1;
