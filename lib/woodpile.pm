# woodpile.pm contains an assortment of junk i commonly use
package woodpile;
use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Gtk3 '-init';

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

package woodpile::Log;
use strict;
use warnings;
use Sys::Hostname;
use Data::Dumper;
use POSIX       qw(strftime);
use Time::HiRes qw(gettimeofday tv_interval usleep);
my $app_name = 'rustyrigs';

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
    # If we've established a log output handler, send it there
    if (defined $self->{'handler'}) {
       my $i = $self->{'handler'};
       $i->write($buf);
    } else { # else, to the tty
       print $buf;
    }
    # send to the log file, always
    print { $self->{log_fh} } $buf;
}

sub set_log_level {
    my ( $class, $log_level );
}

sub add_handler {
   ( my $self, my $handler ) = @_;

    $self->Log("core", "notice", "Switching logging to external handler, tty will go silent except runtime errors... Logfile is at " . $self->{'log_file'});
    $self->{'handler'} = $handler;
}

sub new {
    my ( $class, $log_file, $log_level ) = @_;

    open my $log_fh, '>>', $log_file or die "Unable to open $log_file: $!\n";

    my $self = {
        add_handler => \&add_handler,
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
}

package woodpile::Config;
use strict;
use warnings;
use YAML::XS;
use Data::Dumper;
use Data::Structure::Util qw/unbless/;
my $cfg_readonly = 0;    # if 1, config won't be written out
my $cfg_file;

sub load {
    my ( $self, $cfg_file, $def_cfg ) = @_;
    my $rv;

    # If a config file exists, load it
    if ( -f $$cfg_file ) {
        open my $fh, '<', $$cfg_file
          or die "Can't open config file $$cfg_file for reading: $!";
        $main::log->Log( "config", "info",
            "loading configuration from $$cfg_file" );
        my $yaml_content = do { local $/; <$fh> };
        my $new_cfg      = YAML::XS::Load($yaml_content);

        if ( defined($def_cfg) && defined($new_cfg) ) {
            $main::log->Log( "config", "info", "merging config" );
            $rv = { %$$def_cfg, %$new_cfg };
        }
        elsif ( defined($new_cfg) ) {
            $main::log->Log( "config", "info", "using only new config" );
            $rv = $new_cfg;
        }
        else {
            $main::log->Log( "config", "info", "using only default config" );
            $rv = $$def_cfg;
        }
    }
    else {
        warn "[config/info] cant find config file $$cfg_file, using defaults\n";
        $rv = $$def_cfg;
    }
    return $rv;
}

sub save {
    my ( $self, $cfg_file ) = @_;

    if ( !$cfg_readonly ) {
        print "[core/debug] saving config to $cfg_file\n";
        my $cfg_out_txt = YAML::XS::Dump( $self->{cfg} );
        if ( !defined($cfg_out_txt) ) {
            die "Exporting YAML configuration failed\n";
        }
        open my $fh, '>', $cfg_file
          or die "Can't open config file $cfg_file for writing: $! ";
        print $fh $cfg_out_txt . "\n";
        close $fh;
    }
    else {
        $self->log->Log( "core", "info",
            "not saving configuration as cfg_readonly is enabled..." );
    }
}


sub new {
    my ( $class, $log, $cfg_file, $def_cfg ) = @_;

    my $self = {
        # Functions we export
        load => \&load,
        save => \&save,

        # Data
        cfg_file => $cfg_file,
        def_cfg  => $def_cfg,
        log      => $log
    };

    $self->{cfg} = load( $self, $cfg_file, $def_cfg );

    bless $self, $class;
    return $self;
}

# Destructor to close the file cfg_fh when the object is destroyed
sub DESTROY {
    my ($self) = @_;
}

1;
