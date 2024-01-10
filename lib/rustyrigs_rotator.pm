package rustyrigs_rotator;
use strict;
use warnings;
use Hamlib;

sub rotate {
   my ( $self, $azimuth ) = @_;

   my $rotator = $self->{'rotator'};
   $main::log->Log("rotate", "info", "Rotating to $azimuth");
   $rotator->set_postition($azimuth);
}
sub DESTROY {
   my ( $self ) = @_;
   $self->{'rotator'}->close;
}

sub new {
   my ( $class ) = @_;

   # Define the rotator's parameters
   # XXX: Put path and baudrate into config
   my $rotator = new $main::rigRotator(
#       rot_pathname => '/dev/ttyUSB0',
#       rot_baudrate => 38400,
       rot_model => $cfg->{'rotlctl_model'}
   );

   # Initialize the rotator connection
   $rotator->open || die "Failed to open rotator: $!\n";
   my $self = {
      rotator => $rotator
   };
   bless $self, $class;
   return $self;
}
