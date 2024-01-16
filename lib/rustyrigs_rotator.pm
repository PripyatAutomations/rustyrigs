# Here we talk to rotctld to rotate the antenna as needed...
# XXX: This is a work in progress and likely is buggy...
package rustyrigs_rotator;
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
}

# Call me with azimuth and elevation as arguments
sub rotate {
   my ( $self, $azimuth, $elevation ) = @_;
   my $rot = $self->{'rot'};

   $main::log->Log("rotate", "info", "Rotating to bearing $azimuth at elevation $elevation");
   $$rot->set_position($azimuth, $elevation);
}

sub DESTROY {
   my ( $self ) = @_;
}

sub new {
   my ( $class ) = @_;
   # Connect to rotctld on localhost at port 4533
   my $rot_model = $$main::cfg->{'rotctl_model'};
   if (!defined $rot_model) {
      $rot_model = $Hamlib::ROT_MODEL_NETROTCTL;
   }

   my $rot_path = $$main::cfg->{'rotctl_addr'};
   if (!defined $rot_path) {
      $rot_path = "rotctld:localhost:4533";
   }

   my $rot = new Hamlib::Rot($rot_model);
   print "rot: " . Dumper($rot) . "\n";
   $rot->set_conf('rot_pathname', $rot_path);

   # Initialize the rotator connection
   my $rv = $rot->open;
   if (undef $rv) {
      $main::log->Log("rotate", "crit", "Failed to open rotator: $!");
   }
   my $self = {
      # functions
      query => \&query,
      rotate => \&rotate,
      # variables
      rot => \$rot,
   };
   bless $self, $class;
   return $self;
}

1;
