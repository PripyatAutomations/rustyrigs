# This package presents a GTK3 user interface for rustyrigs
#
# It's a bit ugly for now...
package rustyrigs_gtk_ui;
use Carp;
use Data::Dumper;
use strict;
use Glib qw(TRUE FALSE);
use warnings;

# These will be initialized by new()
our $vfos;
our $cfg;
our $log;
our $cfg_file;

# shared resources
our $icon_error_pix;
our $icon_idle_pix;
our $icon_main_pix;
our $icon_settings_pix;
our $icon_transmit_pix;

# gui widgets
our $tray_icon;    # systray icon
our $w_main;       # main window
our $main_menu;
our $mode_entry;
our $rig_vol_entry;
our $vfo_freq_entry;
our $vfo_sel_button;
our $width_entry;
our $box;
our $fm_box;
our $lock_button;
our $lock_item;

# objects
our $settings;

# status flags
our $main_menu_open = 0;

# Function to resize window height based on visible boxes
# Call this when widgets in a window are hidden or shown, to calculate needed dimensions
sub autosize_height {
    my ($window) = @_;

    # Get preferred height for the current width
    my ( $min_height, $nat_height ) =
      $box->get_preferred_height_for_width( $cfg->{'win_x'} );

    # Set window height based on the preferred height of visible boxes
    $window->resize( $window->get_allocated_width(), $min_height );
}

# main menu
sub main_menu_item_clicked {
    my ( $item, $window, $menu ) = @_;

    if ( $item->get_label() eq 'Toggle Window' ) {
        $window->set_visible( !$window->get_visible() );
    }
    elsif ( $item->get_label() eq 'Quit' ) {
        close_main_win();
    }
    elsif ( $item->get_label() eq 'Settings' ) {
        $settings = rustyrigs_settings->new( $cfg, \$w_main );
    }

    $main_menu_open = 0;
    $menu->destroy();    # Hide the menu after the choice is made
}

sub main_menu_state {
    my ( $widget, $event ) = @_;
    my $on_top  = 0;
    my $focused = 0;

    if ( $event->new_window_state =~ m/\biconified\b/ ) {
        $w_main->deiconify();
    }

    if ( $event->new_window_state =~ m/\bmaximized\b/ ) {
        $w_main->unmaximize();
    }

    if ( $event->new_window_state =~ m/\babove\b/ ) {
        $on_top = 1;
    }

    if ( $event->new_window_state =~ m/\bfocused\b/ ) {
        $focused = 1;
    }

    # If menu becomes unfocused, destroy it...
    if ( !$focused ) {
        $widget->destroy();
    }
    return FALSE;
}

sub main_menu {
    my ( $status_icon, $button, $time ) = @_;

    if ($main_menu_open) {
        $main_menu->destroy();
    }

    $main_menu_open = 1;
    $main_menu      = Gtk3::Menu->new();
    my $sep1        = Gtk3::SeparatorMenuItem->new();
    my $sep2        = Gtk3::SeparatorMenuItem->new();
    my $toggle_item = Gtk3::MenuItem->new("Toggle Window");
    $toggle_item->signal_connect( activate =>
          sub { main_menu_item_clicked( $toggle_item, $w_main, $main_menu ) } );
    $main_menu->append($toggle_item);
    $main_menu->append($sep1);

    #   $main_menu->signal_connect(destroy => sub { undef $lock_item; });

    my $settings_item = Gtk3::MenuItem->new("Settings");
    $settings_item->signal_connect( activate =>
          sub { main_menu_item_clicked( $settings_item, $w_main, $main_menu ) }
    );
    $main_menu->append($settings_item);
    $main_menu->append($sep2);

    $lock_item = Gtk3::CheckMenuItem->new("Locked");
    $lock_item->signal_connect(
        toggled => sub {
            my $widget = shift;
            toggle_locked("menu");
            $main_menu_open = 0;
            $main_menu->destroy();    # Hide the menu after the choice is made
            return FALSE;
        }
    );
    $lock_item->set_active($main::locked);
    $main_menu->append($lock_item);

    my $quit_item = Gtk3::MenuItem->new("Quit");
    $quit_item->signal_connect( activate =>
          sub { main_menu_item_clicked( $quit_item, $w_main, $main_menu ) } );
    $main_menu->append($quit_item);

    $main_menu->show_all();
    $main_menu->popup( undef, undef, undef, undef, $button, $time );

    # XXX: We need to add an event to destroy the menu if it loses focus
    $main_menu->signal_connect( window_state_event => \&main_menu_state );
}

sub close_main_win {
    my ( $widget, $event ) = @_;

    #   main::save_config();
    Gtk3->main_quit();
    return TRUE;
}

sub w_main_state {
    my ( $widget, $event ) = @_;
    my $on_top  = 0;
    my $focused = 0;

  # instead of minimizing, hide the window to tray so it doesnt clutter app tray
    if ( $event->new_window_state =~ m/\biconified\b/ ) {

        # Prevent the window from being iconified
        $widget->deiconify();

        # and minimize it to the system tray icon
        w_main_hide();
        return TRUE;
    }

    if ( $event->new_window_state =~ m/\babove\b/ ) {
        $on_top = 1;
    }

    if ( $event->new_window_state =~ m/\bfocused\b/ ) {
        $focused = 1;
    }

    # the window shouldn't ever be maximized...
    if ( $event->new_window_state =~ m/\bmaximized\b/ ) {
        $widget->unmaximize();
    }

    return FALSE;
}

sub w_main_click {
    my ( $widget, $event ) = @_;

    # Right mouse click (display menu)
    if ( $event->type eq 'button-press' && $event->button == 3 ) {
        main_menu( $tray_icon, 3, $event->time );
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
    my $vfo      = $vfos->{$curr_vfo};
    my $mode     = uc( $vfo->{'mode'} );

    if ( $mode eq "FM" ) {
        $fm_box->show_all();
        autosize_height($w_main);
    }
    else {
        $fm_box->hide();
        autosize_height($w_main);
    }
}

sub w_main_show {
    $cfg->{'win_visible'} = 1;
    $w_main->deiconify();
    $w_main->set_visible(1);
    $w_main->show_all();
    $w_main->move( $cfg->{'win_x'}, $cfg->{'win_y'} );
    w_main_fm_toggle();

    return FALSE;
}

sub w_main_toggle {
    if ( $cfg->{'win_visible'} ) {
        w_main_hide();
    }
    else {
        w_main_show();
    }
    return FALSE;
}

sub w_main_keypress {
    my ( $widget, $event ) = @_;

    # if ESCape, minimize to the tray
    if ( $event->keyval == 65307 ) {
        w_main_hide();
    }
    return;
}

sub load_icon {
    my ($icon_filename) = @_;
    my $pixbuf;

    if ( -f $icon_filename ) {
        $log->Log( "ui", "debug", "loading icon $icon_filename" );
        $pixbuf = Gtk3::Gdk::Pixbuf->new_from_file($icon_filename)
          or die "Failed loading icon $icon_filename\n";
    }
    else {
        die "Missing icon file $icon_filename - can't continue!\n";
    }
    return $pixbuf;
}

# XXX: make this
sub unload_icons {
}

sub load_icons {
    my ($state) = @_;

    my $res           = $cfg->{'res_dir'};
    my $icon_error    = $res . "/" . $cfg->{'icon_error'};
    my $icon_idle     = $res . "/" . $cfg->{'icon_idle'};
    my $icon_settings = $res . "/" . $cfg->{'icon_settings'};
    my $icon_transmit = $res . "/" . $cfg->{'icon_transmit'};

    # Load images, if not already loaded
    if ( !defined($icon_error_pix) ) {
        $icon_error_pix = load_icon($icon_error);
    }
    if ( !defined($icon_idle_pix) ) {
        $icon_idle_pix = load_icon($icon_idle);
    }
    if ( !defined($icon_settings_pix) ) {
        $icon_settings_pix = load_icon($icon_settings);
    }
    if ( !defined($icon_transmit_pix) ) {
        $icon_transmit_pix = load_icon($icon_transmit);
    }

    # initialize the tray icon
    if ( !defined($tray_icon) ) {
        $log->Log( "ui", "debug", "creating tray icon" );
        $tray_icon = Gtk3::StatusIcon->new();

        # Create a system tray icon with the loaded icon
        $tray_icon->signal_connect( 'activate'   => \&w_main_toggle );
        $tray_icon->signal_connect( 'popup-menu' => \&main_menu );
    }
}

sub switch_vfo {
    my $vfo = shift;

    $log->Log( "vfo", "info", "Switching to VFO $vfo" );
    $vfo_sel_button->set_label( "VFO: "
          . rustyrigs_hamlib::next_vfo($vfo) . " ("
          . $cfg->{'key_vfo'}
          . ")" );
    $cfg->{active_vfo} = $vfo;

    rustyrigs_hamlib::read_rig();
}

sub w_main_ontop {
    my $val = shift;
    if ( !defined($val) ) {
        $val = 0;
    }

    $w_main->set_keep_above($val);
}

sub refresh_available_widths {
    my $curr_vfo = $cfg->{'active_vfo'};
    my $vfo      = $vfos->{$curr_vfo};
    my $val      = $vfo->{'width'};
    my $rv       = -1;

    # empty the list
    $width_entry->remove_all();

    if ( !defined($val) ) {
        $vfo->{'width'} = $val = 3000;
    }

    if ( $vfo->{'mode'} eq "FM" ) {
        foreach my $value (@rustyrigs_hamlib::vfo_widths_fm) {
            $width_entry->append_text($value);
        }
        $rv = woodpile::find_offset( \@rustyrigs_hamlib::vfo_widths_fm, $val );
    }
    elsif ( $vfo->{'mode'} =~ m/AM/ ) {
        foreach my $value (@rustyrigs_hamlib::vfo_widths_am) {
            $width_entry->append_text($value);
        }
        $rv = woodpile::find_offset( \@rustyrigs_hamlib::vfo_widths_am, $val );
    }
    elsif ( $vfo->{'mode'} =~ qr/(D-[UL]|USB|LSB)/ ) {
        foreach my $value (@rustyrigs_hamlib::vfo_widths_ssb) {
            $width_entry->append_text($value);
        }
        $rv = woodpile::find_offset( \@rustyrigs_hamlib::vfo_widths_ssb, $val );
    }
    elsif ( $vfo->{'mode'} =~ m/C4FM/ ) {
        $width_entry->append_text(12500);
        $rv = 0;
    }
    if ( $rv == -1 ) {
        $rv = 0;
    }
    $log->Log( "ui", "debug",
          "refresh avail widths: VFO $curr_vfo, mode "
          . $vfo->{'mode'}
          . " val: $val (rv: $rv)" );
    $width_entry->set_active($rv);
}

# XXX: Move this to ${profile}.mem.yaml where $profile is the $cfg_file minus the .yaml ;)
sub channel_list {
    my $store =
      Gtk3::ListStore->new( 'Glib::String', 'Glib::String', 'Glib::String' );

    my $iter = $store->append();
    $store->set( $iter, 0, '1', 1, ' WWV 5MHz', 2, ' 5,000.000 KHz AM' );

    $iter = $store->append();
    $store->set( $iter, 0, '2', 1, ' WWV 10MHz', 2, ' 10,000.000 KHz AM' );

    $iter = $store->append();
    $store->set( $iter, 0, '3', 1, ' WWV 15MHz', 2, ' 15,000.000 KHz AM' );

    $iter = $store->append();
    $store->set( $iter, 0, '4', 1, ' WWV 20MHz', 2, ' 20,000.000 KHz AM' );

    $iter = $store->append();
    $store->set( $iter, 0, '5', 1, ' WWV 25MHz', 2, ' 25,000.000 KHz AM' );

    #$combo->set_active(1);
    return $store;
}

sub draw_main_win {
    $w_main = Gtk3::Window->new('toplevel');

    my $curr_vfo = $cfg->{active_vfo};
    if ( $curr_vfo eq '' ) {
        $curr_vfo = $cfg->{active_vfo} = 'A';
    }
    my $act_vfo = $vfos->{$curr_vfo};

    # XXX: We need to set the window icon
    $w_main->set_title("rustyrigs: Not connected");
    $w_main->set_default_size( $cfg->{'win_width'}, $cfg->{'win_height'} );
    $w_main->set_border_width( $cfg->{'win_border'} );
    my $resizable = 0;

    if ( defined( $cfg->{'win_resizable'} ) ) {
        $resizable = $cfg->{'win_resizable'};
    }

    $w_main->set_resizable($resizable);

    if ( $cfg->{'always_on_top'} ) {
        w_main_ontop(1);
    }

    $w_main->set_default_size( $cfg->{'win_width'}, $cfg->{'win_height'} )
      ;    # Replace $width and $height with desired values
    $w_main->move( $cfg->{'win_x'}, $cfg->{'win_y'} )
      ;    # Replace $x and $y with desired coordinates

    ##############################
    # Capture the window signals #
    ##############################
    $w_main->signal_connect( 'button-press-event' => \&w_main_click );
    $w_main->signal_connect( delete_event         => \&close_main_win );
    $w_main->signal_connect( window_state_event   => \&w_main_state );
    $w_main->signal_connect( 'key-press-event'    => \&w_main_keypress );

    $w_main->signal_connect(
        'configure-event' => sub {
            my ( $widget, $event ) = @_;

            # Retrieve the size and position information
            my ( $width, $height ) = $widget->get_size();
            my ( $x,     $y )      = $widget->get_position();

            # Save the data...
            $cfg->{'win_x'}      = $x;
            $cfg->{'win_y'}      = $y;
            $cfg->{'win_height'} = $height;
            $cfg->{'win_width'}  = $width;

            # Return FALSE to allow the event to propagate
            return FALSE;
        }
    );

    #####################
    # Layout the window #
    #####################
    my $w_main_accel = Gtk3::AccelGroup->new();
    $w_main->add_accel_group($w_main_accel);
    $box = Gtk3::Box->new( 'vertical', 5 );

    my $meter_box =
      rustyrigs_meterbar::render_meterbars( $cfg, $vfos, $w_main );
    $box->pack_start( $meter_box, TRUE, TRUE, 0 );

    #################
    # Channel stuff #
    #################
    my $chan_box = Gtk3::Box->new( 'vertical', 5 );

    my $chan_label = Gtk3::Label->new( "Channel (" . $cfg->{'key_chan'} . ")" );
    $chan_box->pack_start( $chan_label, FALSE, FALSE, 0 );

    # Show the channel choser combobox
    my $chan_combo = Gtk3::ComboBox->new_with_model( channel_list() );
    $chan_combo->set_active(1);
    $chan_combo->set_entry_text_column(1);
    my $render1 = Gtk3::CellRendererText->new();
    $chan_combo->pack_start( $render1, FALSE );
    $chan_combo->add_attribute( $render1, text => 0 );
    my $render2 = Gtk3::CellRendererText->new();
    $chan_combo->pack_start( $render2, FALSE );
    $chan_combo->add_attribute( $render2, text => 1 );
    my $render3 = Gtk3::CellRendererText->new();
    $chan_combo->pack_start( $render3, FALSE );
    $chan_combo->add_attribute( $render3, text => 2 );

    $chan_box->pack_start( $chan_combo, FALSE, FALSE, 0 );

    $w_main_accel->connect(
        ord( $cfg->{'key_chan'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $chan_combo->grab_focus();
            $chan_combo->popup();
        }
    );

    my $mem_btn_box = Gtk3::Box->new( 'horizontal', 5 );

    # Memory load button
    my $mem_load_button =
      Gtk3::Button->new( "Load Chan (" . $cfg->{'key_mem_load'} . ")" );
    $mem_load_button->set_tooltip_text("(re)load the channel memory");

    $mem_load_button->signal_connect(
        clicked => sub {

            # XXX: Apply the settings from the memory entry into the active VFO
            # apply_mem_to_vfo();
        }
    );

    $mem_load_button->grab_focus();
    $mem_btn_box->pack_start( $mem_load_button, TRUE, TRUE, 0 );

    # XXX: ACCEL-Replace these with a global function
    $w_main_accel->connect(
        ord( $cfg->{'key_mem_load'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $mem_load_button->grab_focus();

            # XXX: Apply the settings from the memory entry into active VFO
            # apply_mem_to_vfo();
        }
    );

    # Memory edit button
    my $mem_edit_button =
      Gtk3::Button->new( "Edit Chan (" . $cfg->{'key_mem_edit'} . ")" );
    $mem_edit_button->set_tooltip_text("Add or Edit Memory slot");

    $mem_edit_button->signal_connect(
        clicked => sub {
            $main::channels->show();
        }
    );
    $mem_edit_button->grab_focus();
    $mem_btn_box->pack_start( $mem_edit_button, TRUE, TRUE, 0 );

    # XXX: ACCEL-Replace these with a global function
    $w_main_accel->connect(
        ord( $cfg->{'key_mem_edit'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $mem_edit_button->grab_focus();
            $main::channels->show();
        }
    );
    $chan_box->pack_start( $mem_btn_box, FALSE, FALSE, 0 );

    # add to the main window
    $box->pack_start( $chan_box, FALSE, FALSE, 0 );

    # VFO choser:
    $vfo_sel_button =
      Gtk3::Button->new( "VFO: " . $curr_vfo . " (" . $cfg->{'key_vfo'} . ")" );
    $vfo_sel_button->set_tooltip_text("Toggle active VFO");

    $vfo_sel_button->signal_connect(
        clicked => sub {
            rustyrigs_hamlib::next_vfo();
        }
    );
    $vfo_sel_button->grab_focus();
    $box->pack_start( $vfo_sel_button, FALSE, FALSE, 0 );

    # XXX: ACCEL-Replace these with a global function
    $w_main_accel->connect(
        ord( $cfg->{'key_vfo'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $vfo_sel_button->grab_focus();
            next_vfo();
        }
    );

    # rig volume
    my $rig_vol_label =
      Gtk3::Label->new( "Volume % (" . $cfg->{'key_volume'} . ")" );
    $rig_vol_entry = Gtk3::Scale->new_with_range( 'horizontal', 0, 100, 1 );
    $rig_vol_entry->set_digits(0);    # Disable decimal places
    $rig_vol_entry->set_draw_value(TRUE)
      ;                               # Display the current value on the slider
    $rig_vol_entry->set_has_origin(FALSE);    # Disable origin value
    $rig_vol_entry->set_value_pos('right')
      ;    # Set the position of the value indicator
    $rig_vol_entry->set_value( $cfg->{'rig_volume'} );
    $rig_vol_entry->set_tooltip_text("Please click and drag to set RX volume");

    # XXX: ACCEL-Replace these with a global function
    $w_main_accel->connect(
        ord( $cfg->{'key_volume'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $rig_vol_entry->grab_focus();
        }
    );

    # Active VFO settings
    my $vfo_freq_label =
      Gtk3::Label->new( 'Frequency (Hz) (' . $cfg->{'key_freq'} . ')' );
    #   die "curr_vfo: $curr_vfo || vfos: " . Dumper($act_vfo) . "\n";

    $vfo_freq_entry = Gtk3::SpinButton->new_with_range(
        $act_vfo->{'min_freq'},
        $act_vfo->{'max_freq'},
        $act_vfo->{'vfo_step'}
    );
    $vfo_freq_entry->set_numeric(TRUE);    # Display only numeric input
    $vfo_freq_entry->set_wrap(FALSE)
      ;    # Do not wrap around on reaching min/max values
    $vfo_freq_entry->set_value( $act_vfo->{'freq'} );
    $vfo_freq_entry->set_tooltip_text("VFO frequency input");

    $vfo_freq_entry->signal_connect(
        changed => sub {
            my ( $widget, $event ) = @_;

            my $freq = $vfo_freq_entry->get_text();
            $log->Log( "vfo", "debug",
                "Changing freq on VFO $curr_vfo to $freq" );
            rustyrigs_hamlib->set_freq($freq);
            return FALSE;
        }
    );

    # XXX: ACCEL-Replace these with a global function
    $w_main_accel->connect(
        ord( $cfg->{'key_freq'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $vfo_freq_entry->grab_focus();
        }
    );

    $vfo_freq_entry->signal_connect(
        'button-press-event' => sub {
            my ( $widget, $event ) = @_;

            $log->Log( "vfo btn", "debug", Dumper($event) . "\n" );

            if ( $event->button() == 3 ) {    # Right-click
                my $menu = Gtk3::Menu->new();

                #           my $clipboard = Gtk3::Clipboard->get();
                my $menu_item_copy = Gtk3::MenuItem->new_with_label('Copy');

#           $menu_item_copy->signal_connect('activate' => sub {
#              $log->Log("ui", "debug", "Copy to clipboard");
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
                $menu_item_step->signal_connect(
                    'activate' => sub {
                        $log->Log( "ui", "debug", "show freq step menu!" );
                    }
                );
                $menu->append($menu_item_step);

                # Show the menu
                $menu->show_all();
                $menu->popup( undef, undef, undef, undef, $event->button(),
                    $event->time() );
                return TRUE;
            }
            return FALSE;
        }
    );

  # XXX: we need to TAB key presses in the drop downs and move to next widget...
    my $mode_label = Gtk3::Label->new( 'Mode (' . $cfg->{'key_mode'} . ')' );
    $mode_entry = Gtk3::ComboBoxText->new();
    $mode_entry->set_tooltip_text(
        "Modulation Mode. Some options my not be supported by your rig.");
    foreach my $mode (@rustyrigs_hamlib::hamlib_modes) {
        $mode_entry->append_text($mode);
    }
    $mode_entry->set_active(0);

    # XXX: ACCEL-Replace these with a global function
    $w_main_accel->connect(
        ord( $cfg->{'key_mode'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $mode_entry->grab_focus();
            $mode_entry->popup();
        }
    );
#    $mode_entry->set_active(0);

    # Callback function to handle selection change
    $mode_entry->signal_connect(
        changed => sub {
            my $selected_item = $mode_entry->get_active_text();
            $log->Log( "ui", "debug", "Mode Selected: $selected_item" );
            my $curr_vfo = $cfg->{'active_vfo'};
            my $mode     = uc( $act_vfo->{'mode'} );
            $vfos->{$curr_vfo}{'mode'} = uc($selected_item);
#            rustyrigs_hamlib::set_mode($curr_vfo, $mode);
            w_main_fm_toggle();
            refresh_available_widths();
        }
    );

    my $width_label =
      Gtk3::Label->new( 'Width (hz) (' . $cfg->{'key_width'} . ')' );
    $width_entry = Gtk3::ComboBoxText->new();
    $width_entry->set_tooltip_text("Modulation bandwidth");

    # XXX: ACCEL-Replace these with a global function
    $w_main_accel->connect(
        ord( $cfg->{'key_width'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $width_entry->grab_focus();
            $width_entry->popup();
        }
    );
    refresh_available_widths();

    # Callback function to handle selection change
    $width_entry->signal_connect(
        changed => sub {
            my $selected_item = $width_entry->get_active_text();
            if ( defined($selected_item) ) {
                $log->Log( "ui", "debug", "Width Selected: $selected_item\n" )
                  ;    # Print the selected item (for demonstration)
                my $curr_vfo = $cfg->{'active_vfo'};
                $act_vfo->{'width'} = $selected_item;
            }
        }
    );

    my $rf_gain_label =
      Gtk3::Label->new( 'RF Gain / Atten. (' . $cfg->{'key_rf_gain'} . ')' );
    my $rf_gain_entry = Gtk3::Scale->new_with_range( 'horizontal', -40, 40, 1 );
    $rf_gain_entry->set_digits(0);    # Disable decimal places
    $rf_gain_entry->set_draw_value(TRUE)
      ;                               # Display the current value on the slider
    $rf_gain_entry->set_has_origin(FALSE);    # Disable origin value
    $rf_gain_entry->set_value_pos('right')
      ;    # Set the position of the value indicator
    $rf_gain_entry->set_value( $act_vfo->{'rf_gain'} );
    $rf_gain_entry->set_tooltip_text("Please Click and DRAG to change RF gain");

    # XXX: ACCEL-Replace these with a global function
    $w_main_accel->connect(
        ord( $cfg->{'key_rf_gain'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $rf_gain_entry->grab_focus();
        }
    );
    $rf_gain_entry->signal_connect(
        value_changed => sub {
            my $curr_vfo = $cfg->{'active_vfo'};
            my $value    = $rf_gain_entry->get_value();
            $act_vfo->{'rf_gain'} = $value;
        }
    );

    # Variable to track if the scale is being dragged
    my $dragging = 0;

    my $vfo_power_label =
      Gtk3::Label->new( 'Power (Watts) (' . $cfg->{'key_power'} . ')' );
    my $vfo_power_entry = Gtk3::Scale->new_with_range(
        'horizontal',            $act_vfo->{'min_power'},
        $act_vfo->{'max_power'}, $act_vfo->{'power_step'}
    );
    $vfo_power_entry->set_digits(0);    # Disable decimal places
    $vfo_power_entry->set_draw_value(TRUE)
      ;    # Display the current value on the slider
    $vfo_power_entry->set_has_origin(FALSE);    # Disable origin value
    $vfo_power_entry->set_value_pos('right')
      ;    # Set the position of the value indicator
    $vfo_power_entry->set_value( $act_vfo->{'power'} );
    $vfo_power_entry->set_tooltip_text(
        "Please Click and DRAG to change TX power");

    # XXX: ACCEL-Replace these with a global function
    $w_main_accel->connect(
        ord( $cfg->{'key_power'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $vfo_power_entry->grab_focus();
        }
    );

    #### Here we do some ugly stuff to try and prevent sudden jumps in power ####
    # Connect a signal to track button press
    $vfo_power_entry->signal_connect(
        'button-press-event' => sub {
            my ( $widget, $event ) = @_;
            $dragging = 1;    # Set dragging flag when the slider is clicked

            # reset the value to our stored state to discard this change
            return FALSE;     # Prevent the default behavior
        }
    );

    # Connect a signal to track button release
    $vfo_power_entry->signal_connect(
        'button-release-event' => sub {
            $dragging = 0;    # Reset dragging flag on button release
            if ( !defined( $act_vfo->{'power'} ) || $act_vfo->{'power'} eq "" )
            {
                $act_vfo->{'power'} = $main::rig->get_vfo();
            }

            # reset it
            $vfo_power_entry->set_value( $act_vfo->{'power'} );
            return FALSE;
        }
    );

    $vfo_power_entry->signal_connect(
        value_changed => sub {
            my $value  = $vfo_power_entry->get_value();
            my $oldval = $act_vfo->{'power'};
            my $change = 0;
            my $step   = $act_vfo->{'power_step'};

            if ( !defined($oldval) || !defined($step) ) {
                $oldval = 0;
                $step   = 2;
            }

            my $max_change = $step * 5;

            # round it
            $value = int( $value + 0.5 );

            # calculate how much change occurred
            if ( $value > $oldval ) {
                $change = $value - $oldval;
            }
            elsif ( $value < $oldval ) {
                $change = $oldval - $value;
            }

#      $log->Log("ui", "debug", "change power: dragging: $dragging - change: $change. val $value oldval: $oldval");

            if ( $dragging < 2 ) {
                return FALSE;
            }

            # Ensure no abrupt changes occurred
            if ( $change <= $max_change ) {
                $act_vfo->{'power'} = $value;

                # XXX: Send hamlib command for power
                # rustyrigs_hamlib::set_power($curr_vfo);
            }
            else {    # reject change otherwise
                return FALSE;
            }
            return TRUE;
        }
    );

    $vfo_power_entry->signal_connect(
        'motion-notify-event' => sub {
            my ( $widget, $event ) = @_;
            $dragging = 2;
            return FALSE;    # Propagate the event further
        }
    );

    # XXX: This will change soon as _accel will be wrapped in window object
    my $fm_p = rustyrigs_fm->new( $cfg, $w_main, $w_main_accel );
    $fm_box = $fm_p->{box};

    # Create a toggle button to represent the lock state
    my $key_lock = $cfg->{'key_lock'};
    $lock_button = Gtk3::ToggleButton->new_with_label("Lock ($key_lock)");
    $lock_button->signal_connect(
        toggled => sub {
            if ($main::locked) {
                $main::locked = FALSE;
            }
            else {
                $main::locked = TRUE;
            }
        }
    );

    $w_main_accel->connect(
        ord( $cfg->{'key_lock'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            if ( $lock_button->get_active() ) {
                $log->Log( "ui", "info", "UNLOCKing controls" );
                main::toggle_locked("hotkey");
                $lock_button->set_active(0);
            }
            else {
                $log->Log( "ui", "info", "LOCKing controls" );
                main::toggle_locked("hotkey");
                $lock_button->set_active(1);
            }
        }
    );

    #########
    $box->pack_start( $vfo_freq_label,  FALSE, FALSE, 0 );
    $box->pack_start( $vfo_freq_entry,  FALSE, FALSE, 0 );
    $box->pack_start( $rig_vol_label,   FALSE, FALSE, 0 );
    $box->pack_start( $rig_vol_entry,   FALSE, FALSE, 0 );
    $box->pack_start( $rf_gain_label,   FALSE, FALSE, 0 );
    $box->pack_start( $rf_gain_entry,   FALSE, FALSE, 0 );
    $box->pack_start( $vfo_power_label, FALSE, FALSE, 0 );
    $box->pack_start( $vfo_power_entry, FALSE, FALSE, 0 );
    $box->pack_start( $mode_label,      FALSE, FALSE, 0 );
    $box->pack_start( $mode_entry,      FALSE, FALSE, 0 );
    $box->pack_start( $width_label,     FALSE, FALSE, 0 );
    $box->pack_start( $width_entry,     FALSE, FALSE, 0 );
    $box->pack_start( $fm_box,          FALSE, FALSE, 0 );
    $box->pack_start( $lock_button,     FALSE, FALSE, 0 );

    # Add the Buttons
    ##################
    my $hide_button = Gtk3::Button->new_with_mnemonic('_Hide');
    $hide_button->signal_connect( clicked => \&w_main_hide );
    $hide_button->set_tooltip_text("Minimize to the system try");

    my $settings_button = Gtk3::Button->new_with_mnemonic('_Settings');
    $settings_button->signal_connect(
        clicked => sub {
            $settings = rustyrigs_settings->new( $cfg, \$w_main );
        }
    );
    $settings_button->set_tooltip_text("Settings editor");
    my $quit_button = Gtk3::Button->new_with_mnemonic('_Quit');
    $quit_button->signal_connect( clicked => \&close_main_win );
    $quit_button->set_tooltip_text("Exit the program");

    # Add widgets and insert the box in the window
    $box->pack_start( $hide_button,     FALSE, FALSE, 0 );
    $box->pack_start( $settings_button, FALSE, FALSE, 0 );
    $box->pack_start( $quit_button,     FALSE, FALSE, 0 );
    $w_main->add($box);

    # Draw it and hide the FM box
    w_main_show();

    # set the window visibility to saved state (from config) automaticly?
    if ( $cfg->{'stay_hidden'} ) {
        my $vis = $cfg->{'win_visible'};
        $log->Log( "ui", "info", "stay hidden mode enabled: visible=$vis" );
        $w_main->set_visible($vis);
    }
}

# Set the icon on settings window. This is called from rustyrigs_settings::show_settings
sub set_settings_icon {
    my $win = shift;
    $win->set_icon($icon_settings_pix);
}

sub get_state_icon {
    ( my $state ) = @_;

    if ( $state eq "idle" ) {
        return $icon_idle_pix;
    }
    elsif ( $state eq "transmit" ) {
        return $icon_transmit_pix;
    }
    else {
        return $icon_error_pix;
    }
}

sub set_tray_tooltip {
    my ( $self, $icon, $tooltip_text ) = @_;
    $icon->set_tooltip_text($tooltip_text);
}

# Set up the tray icon and set a label on it...
#############
sub set_tray_icon {
    my ( $self, $status ) = @_;
    my $connected_txt = '';

    if ( $status eq "idle" ) {
        $connected_txt = "Connected";
    }
    else {
        $connected_txt = "Connecting";
    }
    my $freq        = '';
    my $rigctl_addr = $cfg->{'rigctl_addr'};
    my $status_txt  = '';
    my $curr_vfo    = $cfg->{'active_vfo'};
    my $act_vfo     = $vfos->{$curr_vfo};

    if ( defined($main::rig) ) {
        if ( $main::rig->get_ptt($Hamlib::RIG_VFO_A) ) {
            $status_txt = "TRANSMIT";
        }
        else {
            $status_txt = "RECEIVE";
        }
    }
    else {
        $status_txt = "INITIALIZING";
    }
    my $freq_txt   = $act_vfo->{'freq'};
    my $mode_txt   = $act_vfo->{'mode'};
    my $width_text = $act_vfo->{'width'};
    my $power_text = $act_vfo->{'power'};
    my $swr_txt    = "1";

    # create and apply the tooltip help for tray icon...
    my $tray_tooltip =
      $main::app_name . ": Click to toggle display or right click for menu.\n";
    $tray_tooltip .= "\t$connected_txt to $rigctl_addr\n";
    $tray_tooltip .= "\t$status_txt $freq_txt $mode_txt ${width_text} hz\n\n";
    $tray_tooltip .= "Meters:\n";
    $tray_tooltip .= "\t\tPower: ${power_text}W\n\t\tSWR: ${swr_txt}:1\n";
    $self->set_tray_tooltip( $tray_icon, $tray_tooltip );
#    print "tooltip: " . Dumper($tray_tooltip) . "\n";

    $tray_icon->set_from_pixbuf( get_state_icon($status) );
}

sub set_icon {
    ( my $class, my $state ) = @_;
    my $state_txt = "unknown";

    if ( $state eq "idle" ) {
        $state_txt = "Connected to";
    }
    elsif ( $state eq "connecting" ) {
        $state_txt = "Connecting to";
    }
    elsif ( $state eq "transmit" ) {
        $state_txt = "TRANSMIT -";
    }
    $w_main->set_title(
        $main::app_name . ": $state_txt " . $cfg->{'rigctl_addr'} );
    my $icon = get_state_icon($state);
    $w_main->set_icon($icon);
    $class->set_tray_icon($state);
}

sub new {
    ( my $class, my $cfg_ref, my $log_ref, my $vfos_ref ) = @_;
    $vfos     = $rustyrigs_hamlib::vfos;
    $cfg      = ${$cfg_ref};
    $cfg_file = $main::cfg_file;
    $log      = $log_ref;
    $vfos     = ${vfos_ref};

    my $self = {
        # Variables
        icon_error_pix    => \$icon_error_pix,
        icon_idle_pix     => \$icon_idle_pix,
        icon_main_pix     => \$icon_main_pix,
        icon_settings_pix => \$icon_settings_pix,
        icon_transmit_pix => \$icon_transmit_pix,
        tray_icon         => \$tray_icon,
        vfo_freq_entry    => \$vfo_freq_entry,
        vfo_sel_button    => \$vfo_sel_button,
        width_entry       => \$width_entry,

        # GUI widgets
        box            => \$box,
        fm_box         => \$fm_box,
        lock_button    => \$lock_button,
        lock_item      => \$lock_item,
        main_menu      => \$main_menu,
        main_menu_open => \$main_menu_open,
        mode_entry     => \$mode_entry,
        rig_vol_entry  => \$rig_vol_entry,

        # Windows
        w_main     => \$w_main,

        # Functions
        autosize_height          => \&autosize_height,
        channel_list             => \&channel_list,
        close_main_win           => \&close_main_win,
        draw_main_win            => \&draw_main_win,
        get_state_icon           => \&get_state_icon,
        load_icon                => \&load_icon,
        load_icons               => \&load_icons,
        main_menu                => \&main_menu,
        main_menu_item_clicked   => \&main_menu_item_clicked,
        main_menu_state          => \&main_menu_state,
        refresh_available_widths => \&refresh_available_widths,
        save_config              => \&save_config,
        set_icon                 => \&set_icon,
        set_settings_icon        => \&set_settings_icon,
        set_tray_icon            => \&set_tray_icon,
        set_tray_tooltip         => \&set_tray_tooltip,
        switch_vfo               => \&switch_vfo,
        unload_icons             => \&unload_icons,
        w_main_click             => \&w_main_click,
        w_main_fm_toggle         => \&w_main_fm_toggle,
        w_main_hide              => \&w_main_hide,
        w_main_keypress          => \&w_main_keypress,
        w_main_ontop             => \&w_main_ontop,
        w_main_show              => \&w_main_show,
        w_main_state             => \&w_main_state,
        w_main_toggle            => \&w_main_toggle
    };
    bless $self, $class;

    return $self;
}

sub DESTROY {
    ( my $class ) = @_;
}

1;
