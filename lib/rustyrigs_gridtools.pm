# grids quare utilities dialog
# This provides a few simple utilities for measuring distances/bearings
package rustyrigs_gridtools;
use Carp;
use Data::Dumper;
use strict;
use Glib qw(TRUE FALSE);
use warnings;
use Hamlib;
use rustyrigs_set_colors;

my $log;

sub DESTROY {
    ( my $self ) = @_;
}

sub update {
    my ( $self ) = @_;
    my $mygrid = $self->{'mygrid'}->get_text;
    my $dxgrid = $self->{'dxgrid'}->get_text;
    my $my_len = length($mygrid);
    my $dx_len = length($dxgrid);
    my ( $dx_lat, $dx_lon, $my_lat, $my_lon, $dist, $az );

    # labels to update
    my $b_l = $self->{'bear_label'};
    my $d_l = $self->{'dist_label'};
    my $l_l = $self->{'latlon_entry'};

    # update lat/lon for the gridsquare if it appears valid length
    if ($dx_len >= 4 && ($dx_len % 2 == 0)) {
       (my $err, $dx_lon, $dx_lat, my $sw) = Hamlib::locator2longlat($dxgrid);
       print "err: $err\n";
       my $dx_lat_s = int($dx_lat * 100000) / 100000.0;
       my $dx_lon_s = int($dx_lon * 100000) / 100000.0;
       my $latlon = "$dx_lat_s, $dx_lon_s";
       $$l_l->set_text($latlon);
    }

    # calculate distance/bearing, only when both are correct
    if (($my_len == 4 || $my_len == 6) && ($dx_len == 4 || $dx_len == 6)) {
       (my $ll_err, $my_lon, $my_lat, my $sw) = Hamlib::locator2longlat($mygrid);
       print "ll_err: $ll_err\n";
       my $my_lat_s = int($my_lat * 100000) / 100000.0;
       my $my_lon_s = int($my_lon * 100000) / 100000.0;

       ( my $err, $dist, $az ) = Hamlib::qrb($my_lon, $my_lat, $dx_lon, $dx_lat);
       print "Hamlib::qrb - err: $err, dist: $dist, az: $az\n";
       my $longpath = Hamlib::distance_long_path($dist);

       my $s_dist = sprintf("%.2f", $dist);
       my $s_az = sprintf("%.2f", $az);
       my $out = sprintf("my qth ($mygrid) %.3f, %.3f", $my_lat, $my_lon);
       $out .=   sprintf("dx ($dxgrid) %.3f, %.3f distance: %.2f bearing: %.2f", $dx_lat, $dx_lon, $dist, $az);
       print "$out\n";
       my $log_msg = sprintf( "Dist: %.3f km, bearing %.2f, long path: %.3f km from $mygrid to $dxgrid\n",
           $dist, $az, $longpath);
       $log->Log("user", "info", "Calculated [$mygrid] => [$dxgrid]: ${s_dist} km ($longpath km long path) at ${s_az}) °");
    } else {	# clear results until valid values present
       $$b_l->set_text('----');	# clear bearing label
       $$d_l->set_text('----');	# clear distance label
       $$l_l->set_text('');	# clear lat lon label
    }
 }

sub latlon_entry_clicked {
#    my ($class, $entry) = @_;
#    die "class: " . Dumper($class) . "\nentry: " . Dumper($entry) . "\n";
    my ( $entry ) = @_;
    $entry->select_region(0, length($entry->get_text));
}
  
sub new {
    my ( $class ) = @_;

    my $cfg = $main::cfg;
    $log = $main::log;
    
    my $wp = $$cfg->{'win_gridtools_placement'};
    my $on_top = $$cfg->{'always_on_top_gridtools'};
    $wp = 'none' if (!defined $wp);
    my $box;

    # get the main window
    my $gtk_ui = $main::gtk_ui;
    my $w_main = ${$gtk_ui->{'w_main'}};

    my $window = Gtk3::Window->new(
        'toplevel',
        decorated => TRUE,
        destroy_with_parent => TRUE,
        position => $wp
    );
    $window->set_transient_for($w_main);
    $window->set_title("Grid tools");
    $window->set_border_width(5);
    $window->set_default_size(320, 320);
    $window->set_keep_above($on_top);
    $window->set_resizable(0);

    my $icon = ${$gtk_ui->{'icon_settings_pix'}};
    $window->set_icon($icon);

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
    $mygrid_input->set_text($$cfg->{'my_qth'});
    $mygrid_box->pack_start($mygrid_label, FALSE, FALSE, 0);
    $mygrid_box->pack_start($mygrid_input, FALSE, FALSE, 0);
    $mygrid_input->signal_connect('changed' => sub { my ( $self ) = $main::gridtools; $self->update(); });
    my $dxgrid_box = Gtk3::Box->new('vertical', 5);
    my $dxgrid_label = Gtk3::Label->new('DX QTH');
    my $dxgrid_input = Gtk3::Entry->new();
    $dxgrid_input->signal_connect('changed' => sub { my ( $self ) = $main::gridtools; $self->update(); });
    $dxgrid_box->pack_start($dxgrid_label, FALSE, FALSE, 0);
    $dxgrid_box->pack_start($dxgrid_input, FALSE, FALSE, 0);

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

    # Buttons
    my $button_box = Gtk3::Box->new('horizontal', 5);
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

#    my $cancel_button = Gtk3::Button->new("_Cancel");
#    $cancel_button->set_tooltip_text("Cancel");
#    $cancel_button->set_can_focus(1);
#    $cancel_button->signal_connect( 'clicked'  => sub { (my $self) = @_; cancel($self); } );
#    $accel->connect(ord('C'), $$cfg->{'shortcut_key'}, 'visible', sub { my ( $self ) = @_; cancel($self); });
#    $button_box->pack_start($cancel_button, TRUE, TRUE, 0);
    $box->pack_end($button_box, FALSE, FALSE, 0);

    $window->add($box);
    $window->show_all();

    # Focus the DX QTH input
    $dxgrid_input->grab_focus();

    # if configured as such, hide the window automatically
    if ($$cfg->{'hide_gridtools_at_start'}) {
       $window->iconify();
    }

    # Handle window placement
    my $wgp = $$cfg->{'win_gridtools_placement'};
    if (!defined $wgp) {
       $wgp = 'none';
    }


    # If placement type is none, we should manually place the window at x,y
    if ($wgp =~ m/none/) {
       # Place the window
       $window->move( $$cfg->{'win_gridtools_x'}, $$cfg->{'win_gridtools_y'} );
#       # Set width/height of teh window
#       $window->set_default_size( $$cfg->{'win_gridtools_width'},
#           $$cfg->{'win_gridtools_height'} );
    }

    # save resizes/moves
    $window->signal_connect(
        'configure-event' => sub {
            my ( $widget, $event ) = @_;

            # Retrieve the size and position information
            my ( $width, $height ) = $widget->get_size();
            my ( $x,     $y )      = $widget->get_position();

            # Save the data...
            $$cfg->{'win_gridtools_x'}      = $x;
            $$cfg->{'win_gridtools_y'}      = $y;
            $$cfg->{'win_gridtools_height'} = $height;
            $$cfg->{'win_gridtools_width'}  = $width;

            print "saving new position $x, $y ($width x $height)\n";
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
       # functions
       update => \&update,
       # variables
       accel => \$accel,
       box => \$box,
       bear_label => \$o_bear_label,
       dist_label => \$o_dist_label,
       latlon_entry => \$o_latlon_entry,
       dxgrid => $dxgrid_input,
       mygrid => $mygrid_input,
       window => \$window
    };

    bless $self, $class;
    return $self;
}

1;
