# This handles loading and caching icons for use in GTK
package RustyRigs::GTK_icon;
use strict;
use warnings;
use Data::Dumper;
use Gtk3;
use Pango;
use Glib qw(TRUE FALSE);

our $icons;
our $log;
our $cfg;
our $tray_icon;

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
}

sub DESTROY {
    my ( $self ) = @_;
}

sub new {
    my ( $class ) = @_;
    $cfg = $main::cfg;
    $log = $main::log;

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
