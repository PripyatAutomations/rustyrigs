# grids quare utilities dialog
# This provides a few simple utilities for measuring distances/bearings
package RustyRigs::Gridtools;
use Carp;
use Data::Dumper;
use strict;
use Glib qw(TRUE FALSE);
use warnings;
use Hamlib;

my $log;
my $cfg;
our $tmp_cfg;
our $state;

sub DESTROY {
    my ( $self ) = @_;
    return;
}

sub update {
    my ( $self ) = @_;
    my $mygrid = uc($self->{'mygrid'}->get_text);
    my $dxgrid = uc($self->{'dxgrid'}->get_text);

    # re-apply it the text field, so it's captialized
    $self->{'mygrid'}->set_text($mygrid);
    $self->{'mygrid'}->set_position(-1);
    $self->{'dxgrid'}->set_text($dxgrid);
    $self->{'dxgrid'}->set_position(-1);
    my $my_len = length($mygrid);
    my $dx_len = length($dxgrid);
    my ( $dx_lat, $dx_lon, $my_lat, $my_lon, $dist, $az );
    my ( $s_az, $s_dx_lat, $s_dx_lon, $s_my_lat, $s_my_lon );
    my ( $longpath, $s_longpath, $s_dist, $s_ax, $use_metric );
    my ( $use_rotator );
    $use_metric = $$cfg->{'use_metric'};
    $use_rotator = $$cfg->{'use_rotator'};

    # labels to update
    my $b_l = $self->{'bear_label'};
    my $d_l = $self->{'dist_label'};
    my $l_l = $self->{'latlon_entry'};
    my $lp_l = $self->{'longpath_label'};
    my $rb = $self->{'rot_button'};
    my $lprb = $self->{'rot_lp_button'};

    # update lat/lon for the gridsquare if it appears valid length
    if ($dx_len >= 4 && ($dx_len % 2 == 0)) {
       (my $err, $dx_lon, $dx_lat, my $sw) = Hamlib::locator2longlat($dxgrid);
       $s_dx_lat = int($dx_lat * 100000) / 100000.0;
       $s_dx_lon = int($dx_lon * 100000) / 100000.0;
       my $latlon = "$s_dx_lat, $s_dx_lon";
       $$l_l->set_text($latlon);
    }

    # calculate distance/bearing, only when both are correct
    if (($my_len == 4 || $my_len == 6) && ($dx_len == 4 || $dx_len == 6)) {
       (my $ll_err, $my_lon, $my_lat, my $sw) = Hamlib::locator2longlat($mygrid);
       $s_my_lat = int($my_lat * 100000) / 100000.0;
       $s_my_lon = int($my_lon * 100000) / 100000.0;

       ( my $err, $dist, $az ) = Hamlib::qrb($my_lon, $my_lat, $dx_lon, $dx_lat);
       $longpath = Hamlib::distance_long_path($dist);

       my $dist_mi = $dist / 1.60934;
       my $longpath_mi = $longpath / 1.60934;
       my $longpath_az;
       if ($az > 180) {
          $longpath_az = $az - 180;
       } else {
          $longpath_az = $az + 180;
       }
       $s_az = sprintf("%.0f deg", $az);
       my $s_dist_km = sprintf("%.0f km", $dist);
       my $s_dist_mi = sprintf("%.0f mi", $dist_mi );
       my $s_longpath_km = sprintf("%.0f km", $longpath);
       my $s_longpath_mi = sprintf("%.0f mi", $longpath_mi);
       my $s_longpath_az = sprintf("%.0f deg", $longpath_az);

       $state->{'bearing'} = $az;
       $state->{'bearing_lp'} = $longpath_az;
       $state->{'dist_km'} = $dist;
       $state->{'dist_mi'} = $dist_mi;
       $state->{'dist_lp_km'} = $longpath;
       $state->{'dist_lp_mi'} = $longpath_mi;

       if ($use_metric) {
          $s_dist = $s_dist_km;
          $s_longpath = $s_longpath_km;
       } else {
          $s_dist = $s_dist_mi; 
          $s_longpath = $s_longpath_mi;
       }
       $log->Log("user", "info", "Calculated [$mygrid] $s_my_lat, $s_my_lon to [$dxgrid] $s_dx_lat, $s_dx_lon is ${s_dist_mi} (${s_dist_km}) at ${s_az}, longpath: $s_longpath at ${s_longpath_az}");
       $$b_l->set_text($s_az);
       $$d_l->set_text($s_dist);
       $$lp_l->set_text($s_longpath . " @ " . $s_longpath_az);

       # if rotator is enabled, enable the rotate buttons
       if ($use_rotator) {
          $$rb->set_sensitive(1);
          $$lprb->set_sensitive(1);
       }
    } else {	# clear results until valid values present
       $$b_l->set_text('----');	# clear bearing label
       $$d_l->set_text('----');	# clear distance label
       $$l_l->set_text('');	# clear lat lon label
       $$lp_l->set_text('----');

       # if rotator is enabled, disable the rotate buttons
       if ($use_rotator) {
          $$rb->set_sensitive(0);
          $$lprb->set_sensitive(0);
       }
       undef $state;
    }
    return;
}

# Function to filter non-numeric characters
sub on_insert_text {
    my ($entry, $new_text, $new_text_length, $position) = @_;

    # Allow only numeric characters (0-9) and optionally a decimal point
    if ($new_text =~ /^[0-9.]*$/) {
        return 0;  # Allow the insertion of the new text
    } else {
        return 1;  # Block the insertion of non-numeric text
    }
    return;
}

sub latlon_entry_clicked {
#    my ($class, $entry) = @_;
#    die "class: " . Dumper($class) . "\nentry: " . Dumper($entry) . "\n";
    my ( $entry ) = @_;
    $entry->select_region(0, length($entry->get_text));
    return;
}
  
sub new {
    my ( $class ) = @_;

    $cfg = $main::cfg;
    $log = $main::log;
    
    my $wp = $$cfg->{'win_gridtools_placement'};
    my $on_top = $$cfg->{'always_on_top_gridtools'};
    $wp = 'none' if (!defined $wp);
    my $box;

    # get the main window
    my $gtk_ui = \$main::gtk_ui;
    my $w_main = $$gtk_ui->{'w_main'};

    my $window = Gtk3::Window->new(
        'toplevel',
        decorated => TRUE,
        destroy_with_parent => TRUE,
        position => $wp
    );
    $window->set_transient_for($$w_main);
    $window->set_title("Grid tools");
    $window->set_border_width(5);
    $window->set_default_size(320, 320);
    $window->set_keep_above($on_top);
    $window->set_resizable(0);

    my $w_state = $$cfg->{'win_gridtools_state'};
    if (defined $w_state) {
       $window->set_state($w_state);
    }

    my $icon = $main::icons->get_icon('gridtools');

    if (defined $icon) {
       $window->set_icon($icon);
    } else {
       $main::log->Log("core", "warn", "We appear to be missing gridtools icon!");
    }

    my $accel = Gtk3::AccelGroup->new();
    $window->add_accel_group($accel);
    $box = Gtk3::Box->new('vertical', 5);

    # calculator box
    my $cbox = Gtk3::Box->new('vertical', 5);

    # Inputs
    my $in_box = Gtk3::Box->new('horizontal', 5);
    my $mygrid_box = Gtk3::Box->new('vertical', 5);
    my $mygrid_label = Gtk3::Label->new('My QTH');
    my $mygrid_input = Gtk3::Entry->new();
    # fill the input box
    $mygrid_input->set_text(uc($$cfg->{'my_qth'}));

    $mygrid_box->pack_start($mygrid_label, FALSE, FALSE, 0);
    $mygrid_box->pack_start($mygrid_input, FALSE, FALSE, 0);
    $mygrid_input->signal_connect('changed' => sub { my ( $self ) = $main::gridtools; $self->update(); });
    my $dxgrid_box = Gtk3::Box->new('vertical', 5);
    my $dxgrid_label = Gtk3::Label->new('DX QTH');
    my $dxgrid_input = Gtk3::Entry->new();
    $dxgrid_input->signal_connect('changed' => sub { my ( $self ) = $main::gridtools; $self->update(); });
    $dxgrid_box->pack_start($dxgrid_label, FALSE, FALSE, 0);
    $dxgrid_box->pack_start($dxgrid_input, FALSE, FALSE, 0);

    # Add the grid square input boxes to the inbox box
    $in_box->pack_start($mygrid_box, FALSE, TRUE, 0);
    $in_box->pack_start($dxgrid_box, FALSE, TRUE, 0); 

    # Results output box
    my $out_box = Gtk3::Box->new('vertical', 5);

    # Distance and bearing output
    my $db_box = Gtk3::Box->new('horizontal', 5);
    my $dist_box = Gtk3::Box->new('vertical', 5);
    my $bear_box = Gtk3::Box->new('vertical', 5);
    my $dist_label = Gtk3::Label->new('Distance:');
    my $o_dist_label = Gtk3::Label->new('----');
    my $bear_label = Gtk3::Label->new('Bearing:');
    my $o_bear_label = Gtk3::Label->new('----');
    $dist_box->pack_start($dist_label, TRUE, TRUE, 0);
    $dist_box->pack_start($o_dist_label, TRUE, TRUE, 0);
    $bear_box->pack_start($bear_label, TRUE, TRUE, 0);
    $bear_box->pack_start($o_bear_label, TRUE, TRUE, 0);
    $db_box->pack_start($dist_box, TRUE, TRUE, 0);
    $db_box->pack_start($bear_box, TRUE, TRUE, 0);
    $out_box->pack_start($db_box, FALSE, FALSE, 0);

    my $lp_box = Gtk3::Box->new('vertical', 5);
    my $longpath_label = Gtk3::Label->new('Long path');
    my $o_longpath_label = Gtk3::Label->new('----');
    $lp_box->pack_start($longpath_label, FALSE, FALSE, 0);
    $lp_box->pack_start($o_longpath_label, FALSE, FALSE, 0);
    $out_box->pack_start($lp_box, FALSE, FALSE, 0);

    # lat/lon conversion
    my $latlon_box = Gtk3::Box->new('vertical', 5);
    my $latlon_label = Gtk3::Label->new("WGS-84 Lat/Lon:");
    my $o_latlon_entry = Gtk3::Entry->new();
    my $o_latlon_entry_edited = 0;
    $o_latlon_entry->set_editable(0);
    $o_latlon_entry->set_text('');
    $o_latlon_entry->signal_connect('button-press-event' => \&latlon_entry_clicked);
    $latlon_box->pack_start($latlon_label, TRUE, TRUE, 0);
    $latlon_box->pack_start($o_latlon_entry, TRUE, TRUE, 0);
    $out_box->pack_start($latlon_box, TRUE, TRUE, 0);

    # Assemble the outer box
    $box->pack_start($cbox, TRUE, TRUE, 0);
    $box->pack_start($in_box, FALSE, FALSE, 0);
    $box->pack_start($out_box, FALSE, FALSE, 0);

    my $elev_box = Gtk3::Box->new('horizontal', 5);
    my $elev_label = Gtk3::Label->new("Elev:");
    our $elev_input = Gtk3::Entry->new();
    $elev_input->set_editable(1);
    $elev_input->set_max_length(3);
    $elev_input->set_text(0);
    $elev_input->signal_connect(insert_text => \&on_insert_text);
    $elev_box->pack_start($elev_label, TRUE, TRUE, 0);
    $elev_box->pack_start($elev_input, TRUE, TRUE, 0);
    $box->pack_start($elev_box, TRUE, TRUE, 0);

    my ( $rot_button, $rot_lp_button );
    if ($$cfg->{'use_rotator'}) {
        my $rot_box = Gtk3::Box->new('horizontal', 5);
        $rot_button = Gtk3::Button->new("Rotate _Ant");
        $rot_button->set_tooltip_text("Rotate antenna towards bearing");
        $rot_button->set_can_focus(1);
        $rot_button->set_sensitive(0);
        $rot_button->signal_connect( 'clicked'  => sub { 
           (my $self) = @_;
           my $az = $state->{'bearing'};
           my $elev = $elev_input->get_text();
           if (!defined $elev) {
              $elev = 0;
           }
           $main::log->Log("user", "info", "User requested antenna rotation to $az deg / $elev elev...");
           $main::rot->rotate($az, $elev);
        });
        $rot_box->pack_start($rot_button, TRUE, TRUE, 0);

        $rot_lp_button = Gtk3::Button->new("Rotate (_LP)");
        $rot_lp_button->set_tooltip_text("Rotate antenna towards longpath bearing");
        $rot_lp_button->set_can_focus(1);
        $rot_lp_button->set_sensitive(0);
        $rot_lp_button->signal_connect( 'clicked'  => sub { 
           (my $self) = @_;
           my $az  = $state->{'bearing_lp'};
           my $elev = $elev_input->get_text();
           if (!defined $elev) {
              $elev = 0;
           }
           $main::log->Log("user", "info", "User requested antenna rotation (longpath) to $az deg / $elev elev...");
           $main::rot->rotate($az, $elev);
        });
        $rot_box->pack_start($rot_lp_button, TRUE, TRUE, 0);
        $box->pack_start($rot_box, TRUE, TRUE, 0);
    }

    # Buttons
    my $button_box = Gtk3::Box->new('horizontal', 5);

    my $hide_button = Gtk3::Button->new("_Hide");
    $hide_button->set_tooltip_text("Hide Dialog");
    $hide_button->set_can_focus(1);
    $hide_button->signal_connect( 'clicked'  => sub { 
       (my $self) = @_;
       $window->iconify();
    });
    $accel->connect(ord('H'), $$cfg->{'shortcut_key'}, 'visible', sub { my ( $self ) = @_; });
    $button_box->pack_start($hide_button, TRUE, TRUE, 0);

    my $reset_button = Gtk3::Button->new("_Reset");
    $reset_button->set_tooltip_text("Reset dialog");
    $reset_button->set_can_focus(1);
    $reset_button->signal_connect( 'clicked'  => sub { 
       (my $self) = @_;
       $mygrid_input->set_text($$cfg->{'my_qth'});
       $dxgrid_input->set_text('');
    });
    $accel->connect(ord('R'), $$cfg->{'shortcut_key'}, 'visible', sub { my ( $self ) = @_; });
    $button_box->pack_start($reset_button, TRUE, TRUE, 0);
    $box->pack_end($button_box, FALSE, FALSE, 0);
    $window->add($box);
    $window->show_all();

    # set focus properly in the input box
    $mygrid_input->grab_focus();
    $mygrid_input->set_position(0);
    $dxgrid_input->grab_focus();

    # if configured as such, hide the window automatically
    my $gt_autohide = $$cfg->{'hide_gridtools_at_start'};

    my $gt_win_state = $$cfg->{'win_gridtools_state'};

    if (defined $gt_win_state) {
       $window->set_state($gt_win_state);
    } elsif ($gt_autohide) {
       $window->iconify();
    }

    # Handle window placement
    my $wgp = $$cfg->{'win_gridtools_placement'};
    if (!defined $wgp) {
       $wgp = 'none';
    }

    # If placement type is none, we should manually place the window at x,y
    if ($wgp =~ m/none/) {
       $window->move( $$cfg->{'win_gridtools_x'}, $$cfg->{'win_gridtools_y'} );
    }

    # save resizes/moves
    $window->signal_connect(
        'configure-event' => sub {
            my ( $widget, $event ) = @_;

            # Retrieve the size and position information
            my ( $width, $height ) = $widget->get_size();
            my ( $x,     $y )      = $widget->get_position();

            # Save the data...
            $tmp_cfg->{'win_gridtools_x'}      = $x;
            $tmp_cfg->{'win_gridtools_y'}      = $y;
            $tmp_cfg->{'win_gridtools_state'} = $widget->get_state();
            $main::cfg_p->apply($tmp_cfg, FALSE);
            undef $tmp_cfg;

            # Return FALSE to allow the event to propagate
            return FALSE;
        }
    );

    # make the close button iconify instead
    $window->signal_connect(delete_event => sub {
        my ($widget, $event) = @_;
        $widget->iconify();
        return TRUE;  			# Prevent default window destruction
    });

    my $self = {
       # variables
       accel => \$accel,
       box => \$box,
       bear_label => \$o_bear_label,
       dist_label => \$o_dist_label,
       dxgrid => $dxgrid_input,
       elev_entry => \$elev_input,
       longpath_label => \$o_longpath_label,
       latlon_entry => \$o_latlon_entry,
       mygrid => $mygrid_input,
       rot_button => \$rot_button,
       rot_lp_button => \$rot_lp_button,
       window => \$window
    };

    my $gw_ref = $self->{'window'};
    my $gw = $$gw_ref;
    my $gt_ah = $$cfg->{'hide_gridtools_at_start'};

    if ($gt_ah) {
        if (defined $gw) {
           $gw->iconify();
        }
    } else {
        if (defined $gw) {
           $gw->deiconify();
        }
    }

    bless $self, $class;
    return $self;
}

1;
