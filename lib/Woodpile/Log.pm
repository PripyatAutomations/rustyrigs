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
    foreach my $arg (@_) {
       $buf .= " " . $arg;
    }
    $buf .= "\n";

    # send to the log file, always
    print { $self->{log_fh} } $buf;

    # If we've established a log output handler, send it there
    if (defined $self->{'handler'}) {
       my $i = $self->{'handler'};
       $i->append($buf);
    }

    # if we're debugging, or no handler send it to stdout
#    if (!defined $self->{'handler'} || $lvl eq 'debug') {
       print $buf;
#    }
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

#    $self->Log("core", "notice", "Switching logging to external handler, tty will go silent except runtime errors/debugging info... Logfile is at " . $self->{'log_file'});
    $self->{'handler'} = $handler;
    return;
}

sub new {
    my ( $class, $log_file, $log_level ) = @_;

    open my $log_fh, '>>', $log_file or die "Unable to open $log_file: $!\n";

    my $self = {
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