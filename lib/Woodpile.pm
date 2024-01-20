# Woodpile.pm contains an assortment of junk i commonly use
package Woodpile;
use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Gtk3 '-init';
use Woodpile::Config;

sub hex_to_gdk_rgba {
    my ($hex_color) = @_;

    # Convert hex color value to RGBA components
    if ( !defined $hex_color ) {
        die "Invalid color (from: " . ( caller(1) )[3] . ")!\n";
    }
    my ( $r, $g, $b ) = map { hex($_) / 255 } $hex_color =~ m/[\da-f]{2}/ig;

    # Create a Gtk3::Gdk::RGBA object using the calculated RGBA components
    my $rgba_color =
      Gtk3::Gdk::RGBA->new( $r, $g, $b, 1.0 );    # 1.0 is alpha (fully opaque)

    return $rgba_color;
}

sub gdk_rgba_to_hex {
    my ($rgba) = @_;
    
    my ($r, $g, $b) = map { int($_ * 255 + 0.5) } ($rgba->red, $rgba->green, $rgba->blue);

    return sprintf("#%02X%02X%02X", $r, $g, $b);
}

sub gdk_rgb_to_hex {
    my ($rgb) = @_;
    my ($r, $g, $b) = map { sprintf("%02X", $_ / 256) } ($rgb->red, $rgb->green, $rgb->blue);
    return "#$r$g$b";
}

sub find_offset {
    # Wut?
    my $array_ref = shift;
    my @a         = @$array_ref;
    my $val       = shift;
    my $index     = -1;

    if ( !defined($val) ) {
        return -1;
    }

    for my $i ( 0 .. $#a ) {
        if ( looks_like_number( $a[$i] ) && looks_like_number($val) ) {

            # Compare as numbers if both values are numeric
            if ( $a[$i] == $val ) {
                $index = $i;
                last;
            }
        }
        else {
            # Compare as strings if either value is non-numeric
            if ( "$a[$i]" eq "$val" ) {
                $index = $i;
                last;
            }
        }
    }
    return $index;
}

# Function to resize window height based on visible boxes
# Call this when widgets in a window are hidden or shown, to calculate needed dimensions
sub autosize_height {
    my ( $window, $box ) = @_;
    my ( $width, $height ) = $window->get_size();

    # Get preferred height for the current width
    my ( $min_height, $nat_height ) =
       $box->get_preferred_height_for_width($width);

    # Set window height based on the preferred height of visible boxes
    $window->resize( $window->get_allocated_width(), $min_height );
    return;
}

package Woodpile::Log;
use strict;
use warnings;
use Sys::Hostname;
use Data::Dumper;
use POSIX       qw(strftime);
use Time::HiRes qw(gettimeofday tv_interval usleep);
my $app_name = 'rustyrigs';

our $cfg;

# Log levels for messages
our %log_levels = (
    'none'  => 0,		# show no errors
    'fatal' => 1,		# show only fatal errors
    'bug'   => 2,		# show only bugs + fatal errors
    'audit' => 3,		# show important events for auditing
    'warn'  => 4,		# show warnings and more urgent only
    'notice' => 5,		# show notices and more urgent only
    'info'  => 6,		# show informational messages too
    'noise' => 7,		# show even more noise
    'debug' => 8,		# show debugging spew
);

sub Log {
    my ( $self, $log_type, $log_level ) = @_;
    my $filter_level = $self->{log_level};

    my $buf;

    # XXX: We should do log levels per destination: logview, logfile, stdout
    if ( $log_levels{$filter_level} < $log_levels{$log_level} ) {
        return 0;
    }

    my $datestamp = strftime( "%Y/%m/%d %H:%M:%S", localtime );
    my $lvl       = $log_levels{$log_level};
    if ( !defined $lvl ) {
        $lvl = "UNKNOWN";
    }
    ####
    $buf = $datestamp . " [$log_type/$log_level]";

    # skip first 3 arguments
    shift;
    shift;
    shift;
    foreach my $a (@_) {
       $buf .= " " . $a;
    }
    $buf .= "\n";

    # send to the log file, always
    print { $self->{log_fh} } $buf;

    # If we've established a log output handler, send it there
    if (defined $self->{'handler'}) {
       my $i = $self->{'handler'};
       $i->write($buf);
    }

    # if we're debugging, or no handler send it to stdout
    if (!defined $self->{'handler'} || $lvl eq 'debug') {
       print $buf;
    }
    return;
}

sub set_log_level {
    my ( $class, $log_level ) = @_;
    my $ll = $class->{'log_level'};
    if (!defined $ll) {
       $ll = 'debug';
    }
    print "[core/notice] Changing log level from $ll to $log_level\n";
    $class->{'log_level'} = $log_level;
    return;
}

sub add_handler {
   ( my $self, my $handler ) = @_;

    $self->Log("core", "notice", "Switching logging to external handler, tty will go silent except runtime errors/debugging info... Logfile is at " . $self->{'log_file'});
    $self->{'handler'} = $handler;
    return;
}

sub new {
    my ( $class, $log_file, $log_level ) = @_;

    open my $log_fh, '>>', $log_file or die "Unable to open $log_file: $!\n";

    my $self = {
        # functions
        add_handler => \&add_handler,
        set_log_level => \&set_level,
        # variables
        log_file  => $log_file,
        log_level => $log_level,
        log_fh    => $log_fh
    };
    bless $self, $class;

    $self->set_log_level($log_level);
    return $self;
}

sub DESTROY {
    my ($self) = @_;
    close $self->{log_fh} if $self->{log_fh};
    return;
}

1;
