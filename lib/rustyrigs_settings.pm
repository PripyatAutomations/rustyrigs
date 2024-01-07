# Here we handle the settings window
package rustyrigs_settings;
use Carp;
use Data::Dumper;
use strict;
use Glib qw(TRUE FALSE);
use warnings;

my $config_box;
my $address_entry;
my $poll_interval_entry;
my $poll_tray_entry;
my $core_debug;
my $hamlib_debug;
my $tmp_cfg;
my $w_main;
my $changes = 0;
my $cfg;
my $w_settings;

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

######################
# Exported Functions #
######################
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
    ( my $self, my $tc ) = @_;

    if ( $changes && defined $tc ) {
        $main::log->Log( "config", "info",
            "Merging settings into in-memory config" );
        my $tmp = { %$cfg, %$tc };
        $main::cfg = $cfg = $tmp;
    }
    else {
        $main::log->Log( "config", "info", "no changes to save" );
    }

    apply();
    main::save_config();
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
    print "destroying settings obj\n";
}

sub new {
    ( my $class, my $cfg_ref, my $w_main_ref ) = @_;
    $cfg    = $cfg_ref;
    $w_main = ${$w_main_ref};

    $w_settings = Gtk3::Window->new(
        'toplevel',
        decorated           => TRUE,
        destroy_with_parent => TRUE,
        position            => 'center'
    );

    # this makes the stacking order reasonable
    $w_settings->set_transient_for($w_main);
    $w_settings->set_title("Settings");
    $w_settings->set_border_width(5);
    $w_settings->set_default_size( 300, 200 );
    $w_settings->set_keep_above(1);
    $w_settings->set_modal(1);
    $w_settings->set_resizable(0);
    rustyrigs_gtk_ui::set_settings_icon($w_settings);

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

    # Place the window
    $w_settings->move( $cfg->{'win_settings_x'}, $cfg->{'win_settings_y'} );

    $w_settings->signal_connect(
        'configure-event' => sub {
            my ( $widget, $event ) = @_;

            # Retrieve the size and position information
            my ( $width, $height ) = $widget->get_size();
            my ( $x,     $y )      = $widget->get_position();

            # Save the data...
            $cfg->{'win_settings_x'}      = $x;
            $cfg->{'win_settings_y'}      = $y;
            $cfg->{'win_settings_height'} = $height;
            $cfg->{'win_settings_width'}  = $width;

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

    # Rigctl address
    my $address_label = Gtk3::Label->new('Rigctld Address:Port');
    $address_entry = Gtk3::Entry->new();
    $address_entry->set_text( $cfg->{'rigctl_addr'} );    # Default value
    $address_entry->set_tooltip_text(
        "Address of rigctld server (default localhost:4532)");
    $address_entry->set_can_focus(1);
    $address_entry->signal_connect(
        changed => sub {
            my $val = $address_entry->get_text();
        }
    );

    # poll interval: window visible
    my $poll_interval_label = Gtk3::Label->new('Hamlib poll interval (ms)');
    $poll_interval_entry =
      Gtk3::Scale->new_with_range( 'horizontal', 250, 60000, 250 );
    $poll_interval_entry->set_digits(0);
    $poll_interval_entry->set_draw_value(TRUE);
    $poll_interval_entry->set_has_origin(FALSE);
    $poll_interval_entry->set_value_pos('right');
    $poll_interval_entry->set_value( $cfg->{'poll_interval'} );
    $poll_interval_entry->set_tooltip_text(
        "Hamlib polling interval when window is active (in millisconds)");
    $poll_interval_entry->set_can_focus(1);
    $poll_interval_entry->signal_connect(
        value_changed => sub {
            my $val = $poll_interval_entry->get_value();
            $tmp_cfg->{'poll_interval'} = $val;
            $changes++;
        }
    );

    # poll interval: in tray
    my $poll_tray_label =
      Gtk3::Label->new('Inactive (tray), poll interval (1/x)');
    $poll_tray_entry = Gtk3::Scale->new_with_range( 'horizontal', 1, 120, 1 );
    $poll_tray_entry->set_digits(0);
    $poll_tray_entry->set_draw_value(TRUE);
    $poll_tray_entry->set_has_origin(FALSE);
    $poll_tray_entry->set_value_pos('right');
    $poll_tray_entry->set_value( $cfg->{'poll_tray_every'} );
    $poll_tray_entry->set_tooltip_text(
        "When inactive (in the tray), we poll at 1/x the normal rate above");
    $poll_tray_entry->set_can_focus(1);
    $poll_tray_entry->signal_connect(
        value_changed => sub {
            my $val = $poll_tray_entry->get_value();
            $tmp_cfg->{'poll_tray_every'} = $val;
            $changes++;
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
    for our $hl_dbg_opt ( keys %rustyrigs_hamlib::hamlib_debug_levels ) {
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
            $changes++;
        }
    );
    $autohide_toggle->set_can_focus(1);

    my $ontop_button = Gtk3::CheckButton->new();
    $ontop_button->set_label('Keep window above others?');
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
            $changes++;
        }
    );
    $window_options_box->pack_start( $autohide_toggle, FALSE, FALSE, 0 );
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
            $changes++;
        }
    );
    $window_options_box->pack_start( $meter_ontop_button, FALSE, FALSE, 0 );

    ###########
    my $meter_choices_box = Gtk3::Box->new( 'vertical', 5 );
    my $meters_label      = Gtk3::Label->new('Displayed Meters');

    # XXX: Make this 2 checkboxes per row: main dialog & meter popup

    $meter_choices_box->pack_start( $meters_label, FALSE, FALSE, 0 );

    my $alc_toggle = Gtk3::CheckButton->new();
    $alc_toggle->set_label('Show ALC meter?');
    $alc_toggle->set_active( $cfg->{'show_alc'} );
    $alc_toggle->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'show_alc'} = 1;
            }
            else {
                $tmp_cfg->{'show_alc'} = 0;
            }
            $changes++;
        }
    );
    $alc_toggle->set_can_focus(1);
    $meter_choices_box->pack_start( $alc_toggle, FALSE, FALSE, 0 );

    my $comp_toggle = Gtk3::CheckButton->new();
    $comp_toggle->set_label('Show ALC meter?');
    $comp_toggle->set_active( $cfg->{'show_comp'} );
    $comp_toggle->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'show_comp'} = 1;
            }
            else {
                $tmp_cfg->{'show_comp'} = 0;
            }
            $changes++;
        }
    );
    $comp_toggle->set_can_focus(1);
    $meter_choices_box->pack_start( $comp_toggle, FALSE, FALSE, 0 );

    my $pow_toggle = Gtk3::CheckButton->new();
    $pow_toggle->set_label('Show power meter?');
    $pow_toggle->set_active( $cfg->{'show_pow'} );
    $pow_toggle->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'show_pow'} = 1;
            }
            else {
                $tmp_cfg->{'show_pow'} = 0;
            }
            $changes++;
        }
    );
    $pow_toggle->set_can_focus(1);
    $meter_choices_box->pack_start( $pow_toggle, FALSE, FALSE, 0 );

    my $swr_toggle = Gtk3::CheckButton->new();
    $swr_toggle->set_label('Show SWR meter?');
    $swr_toggle->set_active( $cfg->{'show_swr'} );
    $swr_toggle->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'show_swr'} = 1;
            }
            else {
                $tmp_cfg->{'show_swr'} = 0;
            }
            $changes++;
        }
    );
    $swr_toggle->set_can_focus(1);
    $meter_choices_box->pack_start( $swr_toggle, FALSE, FALSE, 0 );

    my $temp_toggle = Gtk3::CheckButton->new();
    $temp_toggle->set_label('Show temp meter?');
    $temp_toggle->set_active( $cfg->{'show_temp'} );
    $temp_toggle->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'show_temp'} = 1;
            }
            else {
                $tmp_cfg->{'show_temp'} = 0;
            }
            $changes++;
        }
    );
    $temp_toggle->set_can_focus(1);
    $meter_choices_box->pack_start( $temp_toggle, FALSE, FALSE, 0 );

    my $vdd_toggle = Gtk3::CheckButton->new();
    $vdd_toggle->set_label('Show VDD meter?');
    $vdd_toggle->set_active( $cfg->{'show_vdd'} );
    $vdd_toggle->signal_connect(
        'toggled' => sub {
            my $button = shift;

            if ( $button->get_active() ) {
                $tmp_cfg->{'show_vdd'} = 1;
            }
            else {
                $tmp_cfg->{'show_vdd'} = 0;
            }
            $changes++;
        }
    );
    $vdd_toggle->set_can_focus(1);
    $meter_choices_box->pack_start( $vdd_toggle, FALSE, FALSE, 0 );

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
    $config_box->pack_start( $address_label,       FALSE, FALSE, 0 );
    $config_box->pack_start( $address_entry,       FALSE, FALSE, 0 );
    $config_box->pack_start( $poll_interval_label, FALSE, FALSE, 0 );
    $config_box->pack_start( $poll_interval_entry, FALSE, FALSE, 0 );
    $config_box->pack_start( $poll_tray_label,     FALSE, FALSE, 0 );
    $config_box->pack_start( $poll_tray_entry,     FALSE, FALSE, 0 );
    $config_box->pack_start( $core_debug_label,    FALSE, FALSE, 0 );
    $config_box->pack_start( $core_debug,          FALSE, FALSE, 0 );
    $config_box->pack_start( $hamlib_debug_label,  FALSE, FALSE, 0 );
    $config_box->pack_start( $hamlib_debug,        FALSE, FALSE, 0 );
    $config_box->pack_start( $window_options_box,  FALSE, FALSE, 0 );
    $config_box->pack_start( $meter_choices_box,   FALSE, FALSE, 0 );
    $config_box->pack_end( $button_box, FALSE, FALSE, 0 );

    # Add the config box, show the window, and focus first input
    $w_settings->signal_connect( key_release_event => \&combobox_keys );
    $w_settings->add($config_box);
    $w_settings->show_all();
    $address_entry->grab_focus();

    my $self = {
        close      => \&close,
        save       => \&save,
        w_settings => \$w_settings
    };
    bless $self, $class;
    return $self;
}

1;
