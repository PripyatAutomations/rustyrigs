# grids quare utilities dialog
# This provides a few simple utilities for measuring distances/bearings
package rustyrigs_gridtools;
use Carp;
use Data::Dumper;
use strict;
use Glib qw(TRUE FALSE);
use warnings;
use Hamlib;

my $log;
my $cfg;

sub DESTROY {
    ( my $self ) = @_;
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
    $use_metric = $$cfg->{'use_metric'};

    # labels to update
    my $b_l = $self->{'bear_label'};
    my $d_l = $self->{'dist_label'};
    my $l_l = $self->{'latlon_entry'};
    my $lp_l = $self->{'longpath_label'};

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

       if ($use_metric) {
          $s_az = sprintf("%.2f deg", $az);
          $s_dist = sprintf("%.2f km", $dist);
          $s_longpath = sprintf("%.2f mi", $longpath);
       } else {
          $s_az = sprintf("%.2f deg", $az);
          $s_dist = sprintf("%.2f mi", $dist / 1.60934);
          $s_longpath = sprintf("%.2f mi", $longpath / 1.60934);
       }
       $log->Log("user", "info", "Calculated [$mygrid] $s_my_lat, $s_my_lon => [$dxgrid] $s_dx_lat, $s_dx_lon - ${s_dist} ($s_longpath long path) at ${s_az}");
       $$b_l->set_text($s_az);
       $$d_l->set_text($s_dist);
       $$lp_l->set_text($s_longpath);
    } else {	# clear results until valid values present
       $$b_l->set_text('----');	# clear bearing label
       $$d_l->set_text('----');	# clear distance label
       $$l_l->set_text('');	# clear lat lon label
       $$lp_l->set_text('----');
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

    my $icon = $$gtk_ui->{'icon_gridtools_pix'};

    if (defined $icon) {
       $window->set_icon($$icon);
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

    my $rot_box = Gtk3::Box->new('vertical', 5);
    my $rotate_button = Gtk3::Button->new("Rotate _Antenna");
    $rotate_button->set_tooltip_text("Rotate antenna towards bearing");
    $rotate_button->set_can_focus(0);
    $rotate_button->signal_connect( 'clicked'  => sub { 
       (my $self) = @_;
       $main::log->Log("user", "info", "User requested antenna rotation, but that's not yet supported...");
    });
    $rot_box->pack_start($rotate_button, TRUE, TRUE, 0);

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
    $box->pack_start($rot_box, TRUE, TRUE, 0);
    $box->pack_end($button_box, FALSE, FALSE, 0);


    $window->add($box);
    $window->show_all();

    # set focus properly in the input box
    $mygrid_input->grab_focus();
    $mygrid_input->set_position(0);
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
            $$cfg->{'win_gridtools_x'}      = $x;
            $$cfg->{'win_gridtools_y'}      = $y;
            $$cfg->{'win_gridtools_height'} = $height;
            $$cfg->{'win_gridtools_width'}  = $width;

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
       longpath_label => \$o_longpath_label,
       latlon_entry => \$o_latlon_entry,
       dxgrid => $dxgrid_input,
       mygrid => $mygrid_input,
       window => \$window
    };

    bless $self, $class;
    return $self;
}

1;
