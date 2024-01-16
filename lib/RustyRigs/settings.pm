# Here we handle the settings window
# XXX: De-duplicate widget creation by moving them out to functions
#      which will return exactly 1 object, with the desired properties applied
# XXX: Make this possible using a list with title, properties, etc for each

package RustyRigs::settings;
use Carp;
use Data::Dumper;
use strict;
use Glib qw(TRUE FALSE);
use warnings;

our $config_box;
our $amp_addr_entry;
our $rig_addr_entry;
our $rot_addr_entry;
our $qth_entry;
our $elev_entry;
our $poll_interval_entry;
our $poll_tray_entry;
our $core_debug;
our $hamlib_debug;
my $tmp_cfg;
my $w_main;
my $cfg;
our $w_settings;

######################
# Exported Functions #
######################
sub set_colors() {
   my ( $class ) = @_;
   my $dialog = RustyRigs::meterbar::Settings->new(\$w_settings);
}

##############################
# Internal use, not exported #
##############################
sub combobox_keys {
    my ( $widget, $event ) = @_;

    if ( $event->keyval == 65289 ) {
        $main::log->Log( "ui", "debug", "settings next!" );
        $w_settings->child_focus('down');
        return TRUE;    # Stop further handling
    }
    else {
        $main::log->Log( "ui", "debug", "xxx: keyval - " . $event->keyval );
        return FALSE;    # Continue default handling
    }
}

sub print_signal_info {
    my ( $widget, $signal_name ) = @_;
    $main::log->Log( "ui", "debug", "Signal emitted by $widget: $signal_name" );
}

# XXX: We need to make a list of cfg val => function
# XXX: Then we can call this at startup, after woodpile::Config is loaded, instead of dealing with settings scattered
# XXX: about the initialization code. This should be a lot more compact...
sub apply {
    ( my $class ) = @_;

    if ( defined $cfg ) {
        if ( $cfg->{'always_on_top'} ) {
            $main::gtk_ui->w_main_ontop(1);
        }
        else {
            $main::gtk_ui->w_main_ontop(0);
        }
    }
}

sub save {
   my ( $tc ) = @_;
   if (defined $tc) {
        $main::log->Log( "config", "info",
            "Merging settings into in-memory config" );
        my $tc_dump = Dumper($tc);
        print "Changes to be applied:\n$tc_dump\n";
        $main::log->Log( "config", "debug", "Applying config changes:\n\t$tc_dump");
        $main::cfg_p->apply($tc);
        apply();
#        undef $tc;
    }
    else {
        print "No changes to apply.\n";
        $main::log->Log( "config", "info", "no changes to save" );
    }
    $w_settings->close();
    $w_settings->destroy();
}

sub close {
    ( my $self ) = @_;
    my $dialog =
      Gtk3::MessageDialog->new( $w_settings, 'destroy-with-parent', 'warning',
        'yes_no', "Close settings window? Unsaved changes may be lost." );
    $dialog->set_title('Confirm Close');
    $dialog->set_default_response('no');
    $dialog->set_transient_for($w_settings);
    $dialog->set_modal(1);
    $dialog->set_keep_above(1);
    $dialog->present();
    $dialog->grab_focus();

    my $response = $dialog->run();

    if ( $response eq 'yes' ) {
        undef $tmp_cfg;
        $dialog->destroy();
        $w_settings->destroy();
        bless $self, 'undef';
    }
    else {
        $dialog->destroy();
        $w_settings->present();
        $w_settings->grab_focus();
    }
}

sub DESTROY {
    ( my $self ) = @_;
}

sub new {
    ( my $class, my $cfg_ref, my $w_main_ref ) = @_;
    $cfg    = $cfg_ref;
    $w_main = ${$w_main_ref};

    # window placement style
    my $wsp = $cfg->{'win_settings_placement'};
    if (!defined $wsp) {
       $wsp = 'none';
    }

    $w_settings = Gtk3::Window->new(
        'toplevel',
        decorated           => TRUE,
        destroy_with_parent => TRUE,
        position            => $wsp
    );

    # this makes the stacking order reasonable
    $w_settings->set_transient_for($w_main);
    $w_settings->set_title("Settings");
    $w_settings->set_border_width(5);
    $w_settings->set_keep_above(1);
    $w_settings->set_modal(1);
    $w_settings->set_resizable(0);
    RustyRigs::gtk_ui::set_settings_icon($w_settings);

# Bind 'Escape' key press to close the settings window with confirmation
# XXX: Figure out why fallthrough events do not work regardless of returning TRUE or FALSE :\
#   $w_settings->signal_connect(key_press_event => sub {
#       my ($widget, $event) = @_;
#
#       if ($event->keyval == 65307) {  # ASCII value for 'Escape' key
#           $class->close($w_settings);
#           return TRUE; # Suppress further handling
#       }
#       return FALSE;
#   });

    my $w_settings_accel = Gtk3::AccelGroup->new();
    $w_settings->add_accel_group($w_settings_accel);
    $config_box = Gtk3::Box->new( 'vertical', 5 );

    # Set width/height of teh window
    $w_settings->set_default_size( $cfg->{'win_settings_width'},
        $cfg->{'win_settings_height'} );

    # If placement type is none, we should manually place the window at x,y
    if ($wsp =~ m/none/) {
       # Place the window
       $w_settings->move( $cfg->{'win_settings_x'}, $cfg->{'win_settings_y'} );
    }

    $w_settings->signal_connect(
        'configure-event' => sub {
            my ( $widget, $event ) = @_;

            # Retrieve the size and position information
            my ( $width, $height ) = $widget->get_size();
            my ( $x,     $y )      = $widget->get_position();

            # Save the data...
            $tmp_cfg->{'win_settings_x'}      = $x;
            $tmp_cfg->{'win_settings_y'}      = $y;
            $tmp_cfg->{'win_settings_height'} = $height;
            $tmp_cfg->{'win_settings_width'}  = $width;

            # Return FALSE to allow the event to propagate
            return FALSE;
        }
    );

    $w_settings->signal_connect(
        delete_event => sub {
            ( my $class ) = @_;
            $class->close();
            return TRUE;    # Suppress default window destruction
        }
    );

    # ampctld address
    my $ampctl_box = Gtk3::Box->new('vertical', 5);
    my $amp_addr_label = Gtk3::Label->new('ampctld Address:Port');
    $amp_addr_entry = Gtk3::Entry->new();
    $amp_addr_entry->set_text( $cfg->{'ampctl_addr'} );
    $amp_addr_entry->set_tooltip_text(
        "Address of ampctld server (default localhost:4531)");
    $amp_addr_entry->set_can_focus(1);
    $amp_addr_entry->signal_connect(
        changed => sub {
            my $val = $amp_addr_entry->get_text();
            $tmp_cfg->{'ampctl_addr'} = $val;
        }
    );
    $ampctl_box->pack_start( $amp_addr_label,       FALSE, FALSE, 0 );
    $ampctl_box->pack_start( $amp_addr_entry,       FALSE, FALSE, 0 );

    # rigctld address
    my $rigctl_box = Gtk3::Box->new('vertical', 5);
    my $rig_addr_label = Gtk3::Label->new('rigctld Address:Port');
    $rig_addr_entry = Gtk3::Entry->new();
    $rig_addr_entry->set_text( $cfg->{'rigctl_addr'} );
    $rig_addr_entry->set_tooltip_text(
        "Address of rigctld server (default localhost:4532)");
    $rig_addr_entry->set_can_focus(1);
    $rig_addr_entry->signal_connect(
        changed => sub {
            my $val = $rig_addr_entry->get_text();
            $tmp_cfg->{'rigctl_addr'} = $val;
        }
    );
    $rigctl_box->pack_start( $rig_addr_label,       FALSE, FALSE, 0 );
    $rigctl_box->pack_start( $rig_addr_entry,       FALSE, FALSE, 0 );


    # rotatctld address
    my $rotctl_box = Gtk3::Box->new('vertical', 5);
    my $rot_addr_label = Gtk3::Label->new('rotctld Address:Port');
    $rot_addr_entry = Gtk3::Entry->new();
    $rot_addr_entry->set_text( $cfg->{'rotctl_addr'} );
    $rot_addr_entry->set_tooltip_text(
        "Address of rotctld server (default localhost:4532)");
    $rot_addr_entry->set_can_focus(1);
    $rot_addr_entry->signal_connect(
        changed => sub {
            my $val = $rot_addr_entry->get_text();
            $tmp_cfg->{'rotctl_addr'} = $val;
        }
    );
    $rotctl_box->pack_start( $rot_addr_label,       FALSE, FALSE, 0 );
    $rotctl_box->pack_start( $rot_addr_entry,       FALSE, FALSE, 0 );

    # my qth box
    my $qth_box = Gtk3::Box->new('horizontal', 5);
    # My gridsquare
    my $qth_label = Gtk3::Label->new('My QTH');
    $qth_entry = Gtk3::Entry->new();
    $qth_entry->set_text( uc($cfg->{'my_qth'}) );
    $qth_entry->set_tooltip_text("Maidenhead gridsquare of the rig");
    $qth_entry->set_can_focus(1);
    $qth_entry->signal_connect(
        changed => sub {
            my $val = $qth_entry->get_text();
            $tmp_cfg->{'my_qth'} = $val;
        }
    );
    $qth_box->pack_start($qth_label, FALSE, FALSE, 0);
    $qth_box->pack_start($qth_entry, TRUE, TRUE, 0);

    # my elevation
    my $elev_box = Gtk3::Box->new('horizontal', 5);
    my $elev_label = Gtk3::Label->new('QTH Elev');
    my $elev_unit_label = Gtk3::Label->new('M ASL');
    $elev_entry = Gtk3::Entry->new();
    $elev_entry->set_text( $cfg->{'my_qth_elev'} );
    $elev_entry->set_tooltip_text("Elevation of antenna");
    $elev_entry->set_can_focus(1);
    $elev_entry->signal_connect(
        changed => sub {
            my $val = $elev_entry->get_text();
            $tmp_cfg->{'my_qth_elev'} = $val;
        }
    );
    $elev_box->pack_start($elev_label, FALSE, FALSE, 0);
    $elev_box->pack_start($elev_entry, TRUE, TRUE, 0);
    $elev_box->pack_start($elev_unit_label, FALSE, FALSE, 0);

    # poll interval: window visible
    my $poll_interval_label = Gtk3::Label->new('Hamlib poll interval (ms)');
    $poll_interval_entry =
      Gtk3::Scale->new_with_range( 'horizontal', 250, 60000, 250 );
    $poll_interval_entry->set_digits(0);
    $poll_interval_entry->set_draw_value(TRUE);
#    $poll_interval_entry->set_has_origin(FALSE);
    $poll_interval_entry->set_value_pos('right');
    $poll_interval_entry->set_value( $cfg->{'poll_interval'} );
    $poll_interval_entry->set_tooltip_text(
        "Hamlib polling interval when window is active (in millisconds)");
    $poll_interval_entry->set_can_focus(1);
    $poll_interval_entry->signal_connect(
        value_changed => sub {
            my $val = $poll_interval_entry->get_value();
            $tmp_cfg->{'poll_interval'} = $val;
        }
    );

    # poll interval: in tray
    my $poll_tray_label =
      Gtk3::Label->new('Inactive (tray), poll interval (1/x)');
    $poll_tray_entry = Gtk3::Scale->new_with_range( 'horizontal', 1, 120, 1 );
    $poll_tray_entry->set_digits(0);
    $poll_tray_entry->set_draw_value(TRUE);
#    $poll_tray_entry->set_has_origin(FALSE);
    $poll_tray_entry->set_value_pos('right');
    $poll_tray_entry->set_value( $cfg->{'poll_tray_every'} );
    $poll_tray_entry->set_tooltip_text(
        "When inactive (in the tray), we poll at 1/x the normal rate above");
    $poll_tray_entry->set_can_focus(1);
    $poll_tray_entry->signal_connect(
        value_changed => sub {
            my $val = $poll_tray_entry->get_value();
            $tmp_cfg->{'poll_tray_every'} = $val;
        }
    );

    # system log level
    my $core_debug_label = Gtk3::Label->new('Core log level');
    $core_debug = Gtk3::ComboBoxText->new();
    $core_debug->set_tooltip_text("Select the core log level");
    my $curr_cl_dbg = -1;
    my $i           = 0;
    for our $cl_dbg_opt ( keys %woodpile::Log::log_levels ) {
        if ( $cl_dbg_opt eq $cfg->{'log_level'} ) {
            $curr_cl_dbg = $i;
        }

        $core_debug->append_text($cl_dbg_opt);
        $i++;
    }

    # did we find current debug level?
    if ( $curr_cl_dbg > -1 ) {
        $core_debug->set_active($curr_cl_dbg);
    }
    else {
        $core_debug->set_active(0);
    }
    $core_debug->set_can_focus(1);

    # create hamlib debug level entry
    my $hamlib_debug_label = Gtk3::Label->new('Hamlib log level');
    $hamlib_debug = Gtk3::ComboBoxText->new();
    $hamlib_debug->set_tooltip_text("Select the logging level of hamlib");
    $i = 0;
    my $cur_hl_dbg = -1;
    for our $hl_dbg_opt ( keys %RustyRigs::hamlib::hamlib_debug_levels ) {
        if ( $hl_dbg_opt eq $cfg->{'hamlib_loglevel'} ) {
            $cur_hl_dbg = $i;
        }

        $hamlib_debug->append_text($hl_dbg_opt);
        $i++;
    }

    if ( $cur_hl_dbg > -1 ) {
        $hamlib_debug->set_active($cur_hl_dbg);
    }
    else {
        $hamlib_debug->set_active(0);
    }
    $hamlib_debug->set_can_focus(1);
    $hamlib_debug->signal_connect( key_release_event => \&combobox_keys );

    my $amp_toggle = Gtk3::CheckButton->new();
    $amp_toggle->set_label('Use amp?');
    $amp_toggle->set_active( $cfg->{'use_amp'} );
    $amp_toggle->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'use_amp'} = 1;
            }
            else {
                $tmp_cfg->{'use_amp'} = 0;
            }
        }
    );
    $amp_toggle->set_can_focus(1);

    my $rotator_toggle = Gtk3::CheckButton->new();
    $rotator_toggle->set_label('Use rotator?');
    $rotator_toggle->set_active( $cfg->{'use_rotator'} );
    $rotator_toggle->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'use_rotator'} = 1;
            }
            else {
                $tmp_cfg->{'use_rotator'} = 0;
            }
        }
    );
    $rotator_toggle->set_can_focus(1);

    my $metric_toggle = Gtk3::CheckButton->new();
    $metric_toggle->set_label('Use metric?');
    $metric_toggle->set_active( $cfg->{'use_metric'} );
    $metric_toggle->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'use_metric'} = 1;
            }
            else {
                $tmp_cfg->{'use_metric'} = 0;
            }
        }
    );
    $metric_toggle->set_can_focus(1);

    my $start_locked_toggle = Gtk3::CheckButton->new();
    $start_locked_toggle->set_label('Start locked?');
    $start_locked_toggle->set_active( $cfg->{'start_locked'} );
    $start_locked_toggle->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'start_locked'} = 1;
            }
            else {
                $tmp_cfg->{'start_locked'} = 0;
            }
        }
    );
    $start_locked_toggle->set_can_focus(1);

    my $window_options_box   = Gtk3::Box->new( 'vertical', 5 );
    my $window_options_label = Gtk3::Label->new('Window Behaviour');
    $window_options_box->pack_start( $window_options_label, FALSE, FALSE, 0 );

    my $autohide_toggle = Gtk3::CheckButton->new();
    $autohide_toggle->set_label('Restore minimized state?');
    $autohide_toggle->set_active( $cfg->{'stay_hidden'} );
    $autohide_toggle->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'stay_hidden'} = 1;
            }
            else {
                $tmp_cfg->{'stay_hidden'} = 0;
            }
        }
    );
    $autohide_toggle->set_can_focus(1);
    $window_options_box->pack_start( $autohide_toggle, FALSE, FALSE, 0 );

    my $hide_gridtools_button = Gtk3::CheckButton->new();
    $hide_gridtools_button->set_label('Hide gridtools with main window?');
    $hide_gridtools_button->set_active( $cfg->{'hide_gridtools_too'} );
    $hide_gridtools_button->set_can_focus(1);
    $hide_gridtools_button->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'hide_gridtools_too'} = 1;
            }
            else {
                $tmp_cfg->{'hide_gridtools_too'} = 0;
            }
        }
    );
    $window_options_box->pack_start( $hide_gridtools_button,    FALSE, FALSE, 0 );

    my $hide_gridtools_def_button = Gtk3::CheckButton->new();
    $hide_gridtools_def_button->set_label('Hide gridtools by default?');
    $hide_gridtools_def_button->set_active( $cfg->{'hide_gridtools_at_start'} );
    $hide_gridtools_def_button->set_can_focus(1);
    $hide_gridtools_def_button->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'hide_gridtools_at_start'} = 1;
            }
            else {
                $tmp_cfg->{'hide_gridtools_at_start'} = 0;
            }
        }
    );
    $window_options_box->pack_start( $hide_gridtools_def_button,    FALSE, FALSE, 0 );

    my $hide_logview_button = Gtk3::CheckButton->new();
    $hide_logview_button->set_label('Hide log viewer by default?');
    $hide_logview_button->set_active( $cfg->{'hide_logview_at_start'} );
    $hide_logview_button->set_can_focus(1);
    $hide_logview_button->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'hide_logview_at_start'} = 1;
            }
            else {
                $tmp_cfg->{'hide_logview_at_start'} = 0;
            }
        }
    );
    $window_options_box->pack_start( $hide_logview_button,    FALSE, FALSE, 0 );

    my $logview_ontop_button = Gtk3::CheckButton->new();
    $logview_ontop_button->set_label('Keep log window above others?');
    $logview_ontop_button->set_active( $cfg->{'always_on_top_logview'} );
    $logview_ontop_button->set_can_focus(1);
    $logview_ontop_button->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'always_on_top_logview'} = 1;
            }
            else {
                $tmp_cfg->{'always_on_top_logview'} = 0;
            }
        }
    );
    $window_options_box->pack_start( $logview_ontop_button, FALSE, FALSE, 0 );

    my $gridtools_ontop_button = Gtk3::CheckButton->new();
    $gridtools_ontop_button->set_label('Keep grid tools above others?');
    $gridtools_ontop_button->set_active( $cfg->{'always_on_top_gridtools'} );
    $gridtools_ontop_button->set_can_focus(1);
    $gridtools_ontop_button->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'always_on_top_gridtools'} = 1;
            }
            else {
                $tmp_cfg->{'always_on_top_gridtools'} = 0;
            }
        }
    );
    $window_options_box->pack_start( $gridtools_ontop_button, FALSE, FALSE, 0 );

    my $ontop_button = Gtk3::CheckButton->new();
    $ontop_button->set_label('Keep main window above others?');
    $ontop_button->set_active( $cfg->{'always_on_top'} );
    $ontop_button->set_can_focus(1);
    $ontop_button->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'always_on_top'} = 1;
            }
            else {
                $tmp_cfg->{'always_on_top'} = 0;
            }
        }
    );
    $window_options_box->pack_start( $ontop_button,    FALSE, FALSE, 0 );

    my $meter_ontop_button = Gtk3::CheckButton->new();
    $meter_ontop_button->set_label('Keep meters window above others?');
    $meter_ontop_button->set_active( $cfg->{'always_on_top_meters'} );
    $meter_ontop_button->set_can_focus(1);
    $meter_ontop_button->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'always_on_top_meters'} = 1;
            }
            else {
                $tmp_cfg->{'always_on_top_meters'} = 0;
            }
        }
    );
    $window_options_box->pack_start( $meter_ontop_button, FALSE, FALSE, 0 );


    # Create an OK button to apply settings
    my $colors_button = Gtk3::Button->new('_Meters');
    $colors_button->set_tooltip_text("Change Meter settings");
    $colors_button->set_can_focus(1);
    $colors_button->signal_connect( 'activate' => sub { (my $self) = @_; $class->set_colors(); } );
    $colors_button->signal_connect( 'clicked'  => sub { (my $self) = @_; $class->set_colors(); } );
    $w_settings_accel->connect(
        ord('U'),  $cfg->{'shortcut_key'},
        'visible', sub { $colors_button->grab_focus(); }
    );

    ###########
    # We want Save and Cancel next to each other, so use a box to wrap
    my $button_box = Gtk3::Box->new( 'horizontal', 5 );

    # Create an OK button to apply settings
    my $save_button = Gtk3::Button->new('_Save');
    $save_button->set_tooltip_text("Save and apply changes");
    $save_button->set_can_focus(1);
    $w_settings_accel->connect(
        ord('S'),  $cfg->{'shortcut_key'},
        'visible', sub { save($tmp_cfg); }
    );

    # Create a Cancel button to discard changes
    my $cancel_button = Gtk3::Button->new('_Cancel');
    $cancel_button->set_tooltip_text("Discard changes");
    $save_button->signal_connect( 'activate' => sub { save($tmp_cfg); } );
    $save_button->signal_connect( 'clicked'  => sub { save($tmp_cfg); } );
    $cancel_button->signal_connect( 'activate' => \&close );
    $cancel_button->signal_connect( 'clicked'  => \&close );
    $cancel_button->set_can_focus(1);
    $w_settings_accel->connect( ord('C'), 'mod1-mask', 'visible', \&close );
    $button_box->pack_start( $save_button,   TRUE, TRUE, 0 );
    $button_box->pack_start( $cancel_button, TRUE, TRUE, 0 );

    # place the widgets
    my $main_box = Gtk3::Box->new('vertical', 5);
    my $box_label = Gtk3::Label->new('General');
    $main_box->pack_start( $box_label, FALSE, FALSE, 0);
    $main_box->pack_start( $ampctl_box, FALSE, FALSE, 0);
    $main_box->pack_start( $rigctl_box, FALSE, FALSE, 0);
    $main_box->pack_start( $rotctl_box, FALSE, FALSE, 0);
    $main_box->pack_start( $qth_box,             FALSE, FALSE, 0 );
    $main_box->pack_start( $elev_box,           FALSE, FALSE, 0 );
    $main_box->pack_start( $poll_interval_label, FALSE, FALSE, 0 );
    $main_box->pack_start( $poll_interval_entry, FALSE, FALSE, 0 );
    $main_box->pack_start( $poll_tray_label,     FALSE, FALSE, 0 );
    $main_box->pack_start( $poll_tray_entry,     FALSE, FALSE, 0 );
    $main_box->pack_start( $core_debug_label,    FALSE, FALSE, 0 );
    $main_box->pack_start( $core_debug,          FALSE, FALSE, 0 );
    $main_box->pack_start( $hamlib_debug_label,  FALSE, FALSE, 0 );
    $main_box->pack_start( $hamlib_debug,        FALSE, FALSE, 0 );
    $main_box->pack_start( $amp_toggle, FALSE, FALSE, 0 );
    $main_box->pack_start( $rotator_toggle, FALSE, FALSE, 0 );
    $main_box->pack_start( $metric_toggle, FALSE, FALSE, 0 );
    $main_box->pack_start( $start_locked_toggle, FALSE, FALSE, 0 );
    $config_box->pack_start( $main_box, FALSE, FALSE, 0 );
    $config_box->pack_start( $window_options_box,  FALSE, FALSE, 0 );
    $config_box->pack_start( $colors_button,   FALSE, FALSE, 0 );
    $config_box->pack_end( $button_box, FALSE, FALSE, 0 );

    # Add the config box, show the window, and focus first input
    $w_settings->signal_connect( key_release_event => \&combobox_keys );
    $w_settings->add($config_box);
    $w_settings->show_all();
    $rig_addr_entry->grab_focus();

    my $self = {
        close      => \&close,
        save       => \&save,
        w_settings => \$w_settings
    };
    bless $self, $class;
    return $self;
}

1;
