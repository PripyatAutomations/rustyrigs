# Here we talk to rotctld to rotate the antenna as needed...
# XXX: This is a work in progress and likely is buggy...
package RustyRigs::Rotator;
use strict;
use warnings;
use Hamlib;
use Data::Dumper;
use Glib qw(TRUE FALSE);

sub query {
   my ( $self, $azimuth, $elevation ) = @_;
   my $rot = $self->{'rot'};

   my $current_bearing = $rot->get_position();
   $main::log->Log("rotate", "info", "Curent rotator bearing is $current_bearing");
   return;
}

# Call me with azimuth and elevation as arguments
sub rotate {
   my ( $self, $azimuth, $elevation ) = @_;
   my $rot = $self->{'rot'};

   $main::log->Log("rotate", "info", "Rotating to bearing $azimuth at elevation $elevation");
   $$rot->set_position($azimuth, $elevation);
   return;
}

sub DESTROY {
   my ( $self ) = @_;
   return;
}

sub new {
   my ( $class ) = @_;
   # Connect to rotctld on localhost at port 4533
   my $rot_model = $$main::cfg->{'rotctl_model'};

#   XXX:  we need to work this out
#   Hamlib::rig_set_debug( hamlib_debug_level( $$cfg->{'hamlib_loglevel'} ) );

   if (!defined $rot_model) {
      $rot_model = $Hamlib::ROT_MODEL_NETROTCTL;
   }

   my $rot_path = $$main::cfg->{'rotctl_addr'};
   if (!defined $rot_path) {
      $rot_path = "localhost:4533";
   }

   my $rot = Hamlib::Rot->new($rot_model);
   $rot->set_conf('rot_pathname', $rot_path);

   # Initialize the rotator connection
   my $rv = $rot->open;
   if (undef $rv) {
      $main::log->Log("rotate", "crit", "Failed to open rotator: $!");
   }
   my $self = {
      rot => \$rot,
   };
   bless $self, $class;
   return $self;
}

1;
