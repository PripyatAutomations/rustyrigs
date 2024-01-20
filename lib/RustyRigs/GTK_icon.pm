# This handles loading and caching icons for use in GTK
package RustyRigs::GTK_icon;
use strict;
use warnings;
use Data::Dumper;

our $icons;
our $log;
our $cfg;
our $tray_icon;
our $vfos;

sub get_icon {
    my ( $self, $name ) = @_;
    my $pixbuf;

    if (!defined $name) {
       die "Not enough arguments to get_icon!\n";
    }


    # point into our icon cache
    my $ico = $icons->{$name};

    if (defined $ico) {
#       print "returning cached icon $name\n";
       return $ico;
    }

    # Nope, lets try to resolve it via config file
    my $key = "icon_$name";
    my $cfg_ico = $$cfg->{$key};
#    print "caller: " . ( caller(1) )[3] . " name: " . Dumper($name);

    if (!defined $cfg_ico) {
       print "No icon specified for $name in config!\n";
       return;
    }

    my $res = $$cfg->{'res_dir'};
    my $icon_filename = $res . '/' . $cfg_ico;

    # does it exist?
    if ( -f $icon_filename ) {
        $log->Log( "ui", "debug", "loading icon $name from $icon_filename" );
        $pixbuf = Gtk3::Gdk::Pixbuf->new_from_file($icon_filename)
          or die "Failed loading icon $icon_filename\n";

        # save it
        $icons->{$name} = $pixbuf;
    }
    else {
        die "Missing icon file $icon_filename for icon $name, can't continue!\n";
    }
    return $pixbuf;
}

sub load_all {
    my ( $self ) = @_;

    for my $key (sort keys %$$cfg) {
       if ($key =~ /^icon_/) {
          my $icons = $self->{'icons'};
          my $ico_name = $key;
          $ico_name =~ s/icon_//;
          # Reference the font to cause it to be loaded
          $self->get_icon($ico_name);
       }
    }
    return;
}

sub get_state_icon {
    my ( $state ) = @_;

#    print "get_state_icon: " . Dumper($state) . "\n";
    # look up the icon, if it's available return it,
    my $ico = $main::icons->get_icon($state);
    if (!defined $ico) {
       # else, return the error icon
       $ico = $main::icons->get_icon("error");
    }
    return $ico;
}

sub set_tray_tooltip {
    my ( $self, $icon, $tooltip_text ) = @_;

    if (!defined $icon) {
       print "\$tray_icon undefined\n";
       return;
    }

    $$icon->set_tooltip_text($tooltip_text);
    return;
}

# Set up the tray icon and set a label on it...
#############
sub set_tray_icon {
    my ( $self, $status ) = @_;
#    print "set_tray_icon: status: " . Dumper($status) . "\n";

    my $tray_icon = $main::icons->{'tray_icon'};
    $$tray_icon->set_from_pixbuf(get_state_icon($status));
    return;
}

sub set_icon {
    ( my $self, my $state ) = @_;
    my $connected_txt = '';

    my $tray_icon = $main::icons->{'tray_icon'};

    if ( $state eq "idle" || $state eq "transmit" ) {
        $connected_txt = "Connected";
    }
    else {
        $connected_txt = "Connecting";
    }
    my $freq        = '';
    my $status_txt  = '';
    my $curr_vfo    = $$cfg->{'active_vfo'};
    my $act_vfo     = $vfos->{$curr_vfo};

#    $main::log->Log("gtkui", "debug", "act_vfo: " . Dumper($act_vfo));
    my $atten      = $act_vfo->{'stats'}{'atten'};
    my $freq_txt   = $act_vfo->{'freq'};
    my $mode_txt   = $act_vfo->{'mode'};
    my $width_text = $act_vfo->{'width'};
    my $power_text = $act_vfo->{'power'};
    my $rigctl_addr = $$cfg->{'rigctl_addr'};
    my $swr_txt    = $act_vfo->{'stats'}{'swr'};
    my $sig_txt    = $act_vfo->{'stats'}{'signal'};

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

    # create and apply the tooltip help for tray icon...
    my $tray_tooltip =
      $main::app_name . ": Click to toggle display or right click for menu.\n";
    $tray_tooltip .= "\t$connected_txt to $rigctl_addr\n";
    $tray_tooltip .= "\t$status_txt $freq_txt $mode_txt ${width_text} hz\n\n";
    $tray_tooltip .= "Meters:\n";
    $tray_tooltip .= "\t\tPower: ${power_text}W\n\t\tSWR: ${swr_txt}:1\n";
    # update the tooltip
    $self->set_tray_tooltip( $tray_icon, $tray_tooltip );

    # Update the main window title
    my $gtk_ui = $main::gtk_ui;
    my $w_main = $gtk_ui->{'w_main'};
    $$w_main->set_title(
        $main::app_name . ": $state_txt " . $$cfg->{'rigctl_addr'} );

    # Find the appropriate icon
#    print "set_icon: state: " . Dumper($state) . "\n";
    my $icon = get_state_icon($state);

    # Apply it to main window & system tray icon
    $$w_main->set_icon($icon);
    $self->set_tray_icon($state);
    return;
}

sub DESTROY {
    my ( $self ) = @_;
    return;
}

sub new {
    my ( $class ) = @_;
    $cfg = $main::cfg;
    $log = $main::log;
    $vfos = $RustyRigs::Hamlib::vfos;

    # initialize the tray icon
    if ( !defined($tray_icon) ) {
        $log->Log( "ui", "debug", "creating tray icon" );
        $tray_icon = Gtk3::StatusIcon->new();

       # Create a system tray icon with the loaded icon
        $tray_icon->signal_connect( 'activate'   => sub { $main::gtk_ui->w_main_toggle(); });
#        $tray_icon->signal_connect( 'popup-menu' => \&main_menu );
    }

    my $self = {
       icons => \$icons,
       tray_icon => \$tray_icon
    };
    bless $self, $class if (defined $self);
    return $self;
}

1;
