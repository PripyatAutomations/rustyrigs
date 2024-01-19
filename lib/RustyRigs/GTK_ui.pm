# This package presents a GTK3 user interface for rustyrigs
package RustyRigs::GTK_ui;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Glib qw(TRUE FALSE);
use Hamlib;
#use RustyRigs::Hamlib;
#use Woodpile;

# Try to make the tooltip's appear faster
#Gtk3::Settings->get_default->set_property('gtk-tooltip-timeout', 100);

# These will be initialized by new()
our $vfos;
our $cfg;
our $log;
our $cfg_file;

# gui widgets
our $w_main;
our $mem_edit_button;
our $mem_load_button;
our $mem_write_button;
our $mode_entry;
our $rf_gain_entry;
our $squelch_entry;
our $rig_vol_entry;
our $vfo_freq_entry;
our $vfo_power_entry;
our $vfo_sel_button;
our $width_entry;
our $box;
our $fm_box;
our $lock_button;
our $lock_item;

# objects
our $settings;
our $meters;
our $tmp_cfg;

sub close_main_win {
    my ( $widget, $event ) = @_;

    main::save_config();
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

    my $tray_icon = $main::icons->{'tray_icon'};

    # Right mouse click (display menu)
    if ( $event->type eq 'button-press' && $event->button == 3 ) {
#        main_menu( $tray_icon, 3, $event->time );
    }
}

sub w_main_fm_toggle {
    my $curr_vfo = $cfg->{'active_vfo'};
    my $vfo      = $vfos->{$curr_vfo};
    my $mode     = uc( $vfo->{'mode'} );

    # hide the FM box, unless in FM mode
    if ( $mode eq "FM" ) {
        $fm_box->show_all();
    }
    else {
        $fm_box->hide();
    }
    Woodpile::autosize_height($w_main, $box);
}

sub w_main_hide {
    my ( $self ) = @_;

    $cfg->{'win_visible'} = 0;
    $w_main->set_visible(0);

    my $hide_lv_too = $cfg->{'hide_logview_too'};

    if ($hide_lv_too) {
       my $lv = $main::logview;
       my $lw = $lv->{'window'};
       # If logview exists, hide it
       if (defined $lw) {
          $$lw->set_visible(0);
          $$lw->iconify();
       }
    }

    my $hide_gt_too = $cfg->{'hide_gridtools_too'};
    if ($hide_gt_too) {
       my $gt = $main::gridtools;
       my $gw = $gt->{'window'};
       print "gw: " . Dumper($gw) . "\n";
       $$gw->set_visible(0);
       $$gw->iconify();
    }
    return FALSE;
}

sub w_main_show {
    my ( $self ) = @_;

    $cfg->{'win_visible'} = 1;
    $w_main->deiconify();
    $w_main->set_visible(1);

    my $hide_lv_too = $cfg->{'hide_logview_too'};

    if ($hide_lv_too) {
       my $lv = $main::logview;

       print "showing logview too\n";
       # Raise logview with main window, if configured to do so
       if (defined $lv) {
          my $w = $lv->{'window'};
          if (defined $w) {
             $$w->set_visible(1);
             $$w->deiconify();
          } else {
             print "No logview window\n";
          }
       } else {
          print "No logview\n";
       }
    }
    $w_main->show_all();
    $w_main->move( $cfg->{'win_x'}, $cfg->{'win_y'} );
    w_main_fm_toggle();

    if ($cfg->{'hide_gridtools_too'}) {
       my $gt = $main::gridtools;
       my $gw = $gt->{'window'};
       if (defined $gw) {
          $$gw->deiconify();
          $$gw->set_visible(1);
       }
    }

    return FALSE;
}

sub w_main_toggle {
    my ( $self ) = @_;

    if ( $cfg->{'win_visible'} ) {
        $self->w_main_hide();
    }
    else {
        $self->w_main_show();
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

sub switch_vfo {
    my $vfo = shift;

    $log->Log( "vfo", "info", "Switching to VFO $vfo" );
    $vfo_sel_button->set_label( "VFO: "
          . RustyRigs::Hamlib::next_vfo($vfo) . " ("
          . $cfg->{'key_vfo'}
          . ")" );
    $cfg->{active_vfo} = $vfo;

    RustyRigs::Hamlib::read_rig();
}

sub w_main_ontop {
    my $val = shift;
    if ( !defined($val) ) {
        $val = 0;
    }

    $w_main->set_keep_above($val);
}

sub refresh_available_widths {
    my ( $self, $new_width ) = @_;
    my $curr_vfo = $cfg->{'active_vfo'};
    my $vfo      = $vfos->{$curr_vfo};
    my $val      = $vfo->{'width'};
    my $rv       = -1;

    # empty the list
    $width_entry->remove_all();

    if ( defined $new_width ) {
       $val = $new_width;
    } else {
       $val = $vfo->{'width'};
    }

    if ( $val == 0 ) {
       print "width == 0, caller: " . ( caller(1) )[3] . "\n";
    }

    if ( $vfo->{'mode'} eq "FM" ) {
        foreach my $value (@RustyRigs::Hamlib::vfo_widths_fm) {
            $width_entry->append_text($value);
        }
        $rv = Woodpile::find_offset( \@RustyRigs::Hamlib::vfo_widths_fm, $val );
    }
    elsif ( $vfo->{'mode'} =~ m/AM/ ) {
        foreach my $value (@RustyRigs::Hamlib::vfo_widths_am) {
            $width_entry->append_text($value);
        }
        $rv = Woodpile::find_offset( \@RustyRigs::Hamlib::vfo_widths_am, $val );
    }
    elsif ( $vfo->{'mode'} =~ qr/(D-[UL]|USB|LSB)/ ) {
        foreach my $value (@RustyRigs::Hamlib::vfo_widths_ssb) {
            $width_entry->append_text($value);
        }
        $rv = Woodpile::find_offset( \@RustyRigs::Hamlib::vfo_widths_ssb, $val );
    }
    elsif ( $vfo->{'mode'} =~ m/C4FM/ ) {
        $width_entry->append_text(12500);
        $rv = 0;
    }
    if ( $rv == -1 ) {
        $rv = 0;
    }
#    $log->Log( "ui", "debug", "refresh avail widths: VFO $curr_vfo, mode " . $vfo->{'mode'} . " val: $val (rv: $rv)" );
    $width_entry->set_active($rv);
}

sub open_gridtools {
    if (defined $main::gridtools) {
       my $gt_win = $main::gridtools->{'window'};
       $$gt_win->deiconify();
       $$gt_win->present();
    }
    else {
       $main::gridtools = RustyRigs::Gridtools->new();
       my $gt_win = $main::gridtools->{'window'};
       $$gt_win->present();
    }
}

sub draw_main_win {
    my ( $self ) = @_;

    $w_main = Gtk3::Window->new('toplevel');

    my $curr_vfo = $cfg->{active_vfo};
    if ( $curr_vfo eq '' ) {
        $curr_vfo = $cfg->{active_vfo} = 'A';
    }
    my $act_vfo = $vfos->{$curr_vfo};

    $w_main->set_title("rustyrigs: Not connected");
    $w_main->set_default_size( $cfg->{'win_width'}, $cfg->{'win_height'} );
    $w_main->set_border_width( $cfg->{'win_border'} );
    my $resizable = 0;

    $w_main->set_resizable(0);

    if ( $cfg->{'always_on_top'} ) {
        w_main_ontop(1);
    }

    $w_main->set_default_size( $cfg->{'win_width'}, $cfg->{'win_height'} );
    $w_main->move( $cfg->{'win_x'}, $cfg->{'win_y'} );

    my $w_state = $cfg->{'win_state'};
    if (defined $w_state) {
       $w_main->set_state($w_state);
    }

    ##############################
    # Capture the window signals #
    ##############################
    $w_main->signal_connect( 'button-press-event' => \&w_main_click );
    $w_main->signal_connect( delete_event         => \&close_main_win );
    $w_main->signal_connect( window_state_event   => \&w_main_state );
    $w_main->signal_connect( 'key-press-event'    => \&w_main_keypress );


    #####################
    # Layout the window #
    #####################
    my $w_main_accel = Gtk3::AccelGroup->new();
    $w_main->add_accel_group($w_main_accel);
    $box = Gtk3::Box->new( 'vertical', 5 );

    # add a placeholder box we can insert/edit easily
    my $meters_dock_box = Gtk3::Box->new('vertical', 5);
    $self->{'meter_dock'} = \$meters_dock_box;
    $box->pack_start( $meters_dock_box, TRUE, TRUE, 0);

    $meters = RustyRigs::Meterbar->render_meterbars( \$main::meters, \$cfg, $vfos, $w_main );
    # Do we render the meters in the main window?
    my $meters_in_main = $cfg->{'meters_in_main'};
    if ($meters_in_main) {
       my $meter_box = $meters->{'box'};
       $meters_dock_box->pack_start( $meter_box, TRUE, TRUE, 0 );
    } else {
       # Show the meters window
#       $meters->show();
       print "BUG!!! Undocked meters not yet implemented\n";
    }

    #################
    # Channel stuff #
    #################
    my $chan_box = Gtk3::Box->new( 'vertical', 5 );

    my $chan_label = Gtk3::Label->new( "Channel (" . $cfg->{'key_chan'} . ")" );
    $chan_box->pack_start( $chan_label, FALSE, FALSE, 0 );

    # Show the channel choser combobox
    my $chan_combo = Gtk3::ComboBox->new();
    $chan_combo->set_model( RustyRigs::Memory::get_list() );
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
            $chan_combo->popup();
        }
    );

    my $mem_btn_box = Gtk3::Box->new( 'horizontal', 5 );

    # Memory load button
    $mem_load_button =
      Gtk3::Button->new( "Load Chan (" . $cfg->{'key_mem_load'} . ")" );
    $mem_load_button->set_tooltip_text("(re)load the channel memory");

    $mem_load_button->signal_connect(
        clicked => sub {

            # XXX: Apply the settings from the memory entry into the active VFO
            # apply_mem_to_vfo();
        }
    );

    $mem_btn_box->pack_start( $mem_load_button, TRUE, TRUE, 0 );

    # Memory write button
    $mem_write_button =
      Gtk3::Button->new( "Save Chan (" . $cfg->{'key_mem_write'} . ")" );
    $mem_write_button->set_tooltip_text("write the channel memory");

    $mem_write_button->signal_connect(
        clicked => sub {
        }
    );
    $mem_btn_box->pack_start( $mem_write_button, TRUE, TRUE, 0 );

    # XXX: ACCEL-Replace these with a global function
    $w_main_accel->connect(
        ord( $cfg->{'key_mem_write'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $mem_write_button->grab_focus();

            # XXX: Apply the settings from the memory entry into active VFO
            # apply_mem_to_vfo();
        }
    );

    # Memory edit button
    $mem_edit_button =
      Gtk3::Button->new( "Edit Chan (" . $cfg->{'key_mem_edit'} . ")" );
    $mem_edit_button->set_tooltip_text("Add or Edit Memory slot");

    $mem_edit_button->signal_connect(
        clicked => sub {
            $main::channels->show();
        }
    );
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
            RustyRigs::Hamlib::next_vfo();
        }
    );
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
    $rig_vol_entry->set_digits(0);
    $rig_vol_entry->set_draw_value(TRUE);
    $rig_vol_entry->set_value_pos('right');
    $rig_vol_entry->set_value(0);	# default to 0 until hamlib loaded
    $rig_vol_entry->set_tooltip_text("Please click and drag to set RX volume");
    $rig_vol_entry->signal_connect(
        button_press_event => sub {
            my $rp = $main::rig_p->{'gui_applying_changes'};
            $$rp = TRUE;
            return FALSE;
        }
    );
    $rig_vol_entry->signal_connect(
        button_release_event => sub {
            my $rp = $main::rig_p->{'gui_applying_changes'};
            $$rp = FALSE;
            return FALSE;
        }
    );
    $rig_vol_entry->signal_connect(
        value_changed => sub {
            my ( $widget ) = @_;
            my $rig_p = $main::rig_p;
            my $rig = $rig_p->{'rig'};
            my $rp = $main::rig_p->{'gui_applying_changes'};
            $$rp = TRUE;
            my $vol = $widget->get_value();

            $rig_p->{'volume'} = $vol;
            $rig->set_level($Hamlib::RIG_LEVEL_AF, $vol / 100);
#            $main::rig->set_level($Hamlib::RIG_LEVEL_AF, $vol / 100);

            $$rp = FALSE;

            return FALSE;
        }
    );
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

    $vfo_freq_entry = Gtk3::SpinButton->new_with_range(
        $act_vfo->{'min_freq'},
        $act_vfo->{'max_freq'},
        $act_vfo->{'vfo_step'}
    );
    $vfo_freq_entry->set_numeric(TRUE);
    $vfo_freq_entry->set_wrap(FALSE);
    $vfo_freq_entry->set_tooltip_text("VFO frequency input");

    $vfo_freq_entry->signal_connect(
        changed => sub {
            my ( $widget, $event ) = @_;

            if (!$main::rig_p->is_busy()) {
               my $freq = $vfo_freq_entry->get_text();
               $log->Log( "vfo", "debug",
                   "Changing freq on VFO $curr_vfo to $freq" );
               RustyRigs::Hamlib->set_freq($freq);
            }
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
    foreach my $mode (@RustyRigs::Hamlib::hamlib_modes) {
        $mode_entry->append_text($mode);
    }

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

    # Callback function to handle selection change
    $mode_entry->signal_connect(
        changed => sub {
            my ( $class ) = @_;

            if (!$main::rig_p->is_busy()) {
               my $selected_item = $mode_entry->get_active_text();
               $log->Log( "ui", "debug", "Mode Selected: $selected_item" );
               my $curr_vfo = $cfg->{'active_vfo'};
               my $mode     = uc( $act_vfo->{'mode'} );
               $vfos->{$curr_vfo}{'mode'} = uc($selected_item);
   #            RustyRigs::Hamlib::set_mode($curr_vfo, $mode);
            }
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
            my ( $class ) = @_;
            if (!$main::rig_p->is_busy()) {
               my $selected_item = $width_entry->get_active_text();
               if ( defined($selected_item) ) {
                   $log->Log( "ui", "debug", "Width Selected: $selected_item\n" )
                     ;    # Print the selected item (for demonstration)
                   my $curr_vfo = $cfg->{'active_vfo'};
                   $act_vfo->{'width'} = $selected_item;
               }
            }
        }
    );
    my $rf_gain_label =
      Gtk3::Label->new( 'RF Gain / Atten. (' . $cfg->{'key_rf_gain'} . ')' );
    $rf_gain_entry = Gtk3::Scale->new_with_range( 'horizontal', -40, 40, 1 );
    $rf_gain_entry->set_digits(0);
    $rf_gain_entry->set_draw_value(TRUE);
    $rf_gain_entry->set_value_pos('right');
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
            my ( $class ) = @_;
            if (!$main::rig_p->is_busy()) {
               my $curr_vfo = $cfg->{'active_vfo'};
               my $value    = $rf_gain_entry->get_value();
               $act_vfo->{'rf_gain'} = $value;
            }
        }
    );

    my $squelch_label =
      Gtk3::Label->new( 'Squelch (' . $cfg->{'key_squelch'} . ')' );
    $squelch_entry = Gtk3::Scale->new_with_range( 'horizontal', 0, 20, 1 );
    $squelch_entry->set_digits(0);
    $squelch_entry->set_draw_value(TRUE);
    $squelch_entry->set_value_pos('right');
    $squelch_entry->set_value( $act_vfo->{'squelch'} );
    $squelch_entry->set_tooltip_text("Please Click and DRAG to change RF gain");

    # XXX: ACCEL-Replace these with a global function
    $w_main_accel->connect(
        ord( $cfg->{'key_squelch'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            $squelch_entry->grab_focus();
        }
    );
    $squelch_entry->signal_connect(
        value_changed => sub {
            my ( $class ) = @_;
            if (!$main::rig_p->is_busy()) {
               my $curr_vfo = $cfg->{'active_vfo'};
               my $value    = $squelch_entry->get_value();
               $act_vfo->{'squelch'} = $value;
            }
        }
    );

    # Variable to track if the scale is being dragged
    my $dragging = 0;

    my $vfo_power_label =
      Gtk3::Label->new( 'Power (Watts) (' . $cfg->{'key_power'} . ')' );
    $vfo_power_entry = Gtk3::Scale->new_with_range(
        'horizontal',            $act_vfo->{'min_power'},
        $act_vfo->{'max_power'}, $act_vfo->{'power_step'}
    );
    $vfo_power_entry->set_digits(0);
    $vfo_power_entry->set_draw_value(TRUE);
    $vfo_power_entry->set_value_pos('right');
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

    $vfo_power_entry->signal_connect(
        value_changed => sub {
            if (!$main::rig_p->is_busy()) {
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
               my $hlval = int( $value + 0.5 ) / 100;

               # calculate how much change occurred
               if ( $value > $oldval ) {
                   $change = $value - $oldval;
               }
               elsif ( $value < $oldval ) {
                   $change = $oldval - $value;
               }

               $main::log->Log("ui", "debug", "change power: dragging: $dragging - change: $change. val $value oldval: $oldval hlval: $hlval");

               if ( $dragging < 2 ) {
                   print "rig_power widget dragging: $dragging < 2, not changing value\n";
                   return FALSE;
               }

               # Ensure no abrupt changes occurred
               if ( $change <= $max_change ) {
                   my $rp = $main::rig_p->{'gui_applying_changes'};
                   $$rp = TRUE;
                   $act_vfo->{'power'} = $value;
                   print "applying power: $value (change: $change, hlval: $hlval)\n";
                   my $rig = $main::rig;
                   $rig->set_level($Hamlib::RIG_LEVEL_RFPOWER, $hlval);
                   $$rp = FALSE;
               }
               else {    # reject change otherwise
                   print "rig_power widget: rejecting power change $change in excess of limit $max_change\n";
                   return FALSE;
               }
               return TRUE;
           }
        }
    );

    $vfo_power_entry->signal_connect(
        'motion-notify-event' => sub {
            my $rig_p = $main::rig_p;
            if (defined $rig_p && !$rig_p->is_busy()) {
               my ( $widget, $event ) = @_;
               $dragging = 2;
               return FALSE;
            } else {
               return TRUE;
            }
        }
    );

    # XXX: This will change soon as _accel will be wrapped in window object
    my $fm_p = RustyRigs::FM->new( $cfg, $w_main, $w_main_accel );
    $fm_box = $fm_p->{box};

    # Create a toggle button to represent the lock state
    my $key_lock = $cfg->{'key_lock'};
    $lock_button = Gtk3::ToggleButton->new_with_label("Lock ($key_lock)");
    # lock things
    my $auto_lock = $cfg->{'start_locked'};
    if ($auto_lock) {
        $lock_button->set_active($main::locked);
        main::toggle_locked("startup", TRUE);
    }
    $lock_button->signal_connect(
        toggled => sub {
            main::toggle_locked("button", $lock_button->get_active());
        }
    );

    $w_main_accel->connect(
        ord( $cfg->{'key_lock'} ),
        $cfg->{'shortcut_key'},
        'visible',
        sub {
            main::toggle_locked("hotkey", $lock_button->get_active());
        }
    );

    #########
    $box->pack_start( $vfo_freq_label,  FALSE, FALSE, 0 );
    $box->pack_start( $vfo_freq_entry,  FALSE, FALSE, 0 );
    $box->pack_start( $rig_vol_label,   FALSE, FALSE, 0 );
    $box->pack_start( $rig_vol_entry,   FALSE, FALSE, 0 );
    $box->pack_start( $squelch_label,   FALSE, FALSE, 0 );
    $box->pack_start( $squelch_entry,   FALSE, FALSE, 0 );
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
            $settings = RustyRigs::Settings->new( $cfg, \$w_main );
        }
    );
    $settings_button->set_tooltip_text("Settings editor");

    my $gridtools_button = Gtk3::Button->new_with_mnemonic('_Gridsquare Tools');
    $gridtools_button->signal_connect(
        clicked => sub {
            open_gridtools();
        }
    );
    $gridtools_button->set_tooltip_text("Show gridsquare tools");

    my $quit_button = Gtk3::Button->new_with_mnemonic('_Quit');
    $quit_button->signal_connect( clicked => \&close_main_win );
    $quit_button->set_tooltip_text("Exit the program");

    # Add widgets and insert the box in the window
    $box->pack_start( $hide_button,     FALSE, FALSE, 0 );
    $box->pack_start( $settings_button, FALSE, FALSE, 0 );
    $box->pack_start( $gridtools_button, FALSE, FALSE, 0 );
    $box->pack_start( $quit_button,     FALSE, FALSE, 0 );
    $w_main->add($box);

    $w_main->signal_connect(
        'configure-event' => sub {
            my ( $widget, $event ) = @_;

            # Retrieve the size and position information
            my ( $width, $height ) = $widget->get_size();
            my ( $x,     $y )      = $widget->get_position();

            # Save the data...
            $tmp_cfg->{'win_x'}      = $x;
            $tmp_cfg->{'win_y'}      = $y;
            $tmp_cfg->{'win_state'}  = $widget->get_state();
            $tmp_cfg->{'win_height'} = $height;
            $tmp_cfg->{'win_width'}  = $width;

            $main::cfg_p->apply($tmp_cfg, FALSE);
            # Return FALSE to allow the event to propagate
            return FALSE;
        }
    );

    # Draw it and hide the FM box
    w_main_show();

    # set the window visibility to saved state (from config) automaticly?
    if ( $cfg->{'stay_hidden'} ) {
        my $vis = $cfg->{'win_visible'};
        $log->Log( "ui", "info", "stay hidden mode enabled: visible=$vis" );
        $w_main->set_visible($vis);
    }
}

######################################

sub update_widgets {
    my ( $self ) = @_;

    if (!$main::rig_p->is_busy) {
        my $curr_vfo = $cfg->{active_vfo};
        if ( $curr_vfo eq '' ) {
            $curr_vfo = $cfg->{active_vfo} = 'A';
        }
        my $act_vfo = $vfos->{$curr_vfo};
        my $rig_p = $main::rig_p;
        my $rig = $rig_p->{'rig'};
        my $vol = $rig_p->{'volume'};

        $rig_vol_entry->set_value($$vol);
        $vfo_freq_entry->set_value( $act_vfo->{'freq'} );
        # XXX: set $mode_entry to $act_vfo->{'mode'} (indexed)
        # XXX: set $width_entry to $act_vfo->{'width'} (indexed)
        $rf_gain_entry->set_value($act_vfo->{'rf_gain'});
        $vfo_power_entry->set_value( $act_vfo->{'power'} );
    } else {
#        print "skipping GUI update as read_rig() is running!\n";
    }
}

######################################

sub new {
    ( my $class, my $cfg_ref, my $log_ref, my $vfos_ref ) = @_;
    $vfos     = $RustyRigs::Hamlib::vfos;
    $cfg      = ${$cfg_ref};
    $cfg_file = $main::cfg_file;
    $log      = $log_ref;
    $vfos     = ${vfos_ref};

    my $self = {
        # GUI widgets
        box               => \$box,
        fm_box            => \$fm_box,
        lock_button       => \$lock_button,
        lock_item         => \$lock_item,
        mem_add_button    => \$mem_load_button,
        mem_edit_button   => \$mem_edit_button,
        mem_load_button   => \$mem_load_button,
        mode_entry        => \$mode_entry,
        rf_gain_entry     => \$rf_gain_entry,
        rig_vol_entry     => \$rig_vol_entry,
        squelch_entry     => \$squelch_entry,
        vfo_freq_entry    => \$vfo_freq_entry,
        vfo_power_entry   => \$vfo_power_entry,
        vfo_sel_button    => \$vfo_sel_button,
        width_entry       => \$width_entry,

        # Windows
        w_main            => \$w_main,
    };
    bless $self, $class;

    return $self;
}

sub DESTROY {
    ( my $class ) = @_;
}

1;
