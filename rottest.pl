#!/usr/bin/perl
use Hamlib;
use Data::Dumper;

my $rot_model = $Hamlib::ROT_MODEL_NETROTCTL;
my $rot_path = "rotctld:localhost:4533";
# Set the bearing to 71 degrees, 0 elev (unsupported);
my $target_bearing = 71;
my $target_elev = 0;

# Connect to rotctld on localhost at port 4533
my $rot = new Hamlib::Rot($rot_model);
print "rot: " . Dumper($rot) . "\n";
$rot->set_conf('rot_pathname', $rot_path);

# Initialize the rotator
#$rot->rot_init($rot_model);

# Query the current bearing
my $current_bearing = $rot->get_position();
print "Current Bearing: $current_bearing degrees\n";

$rot->set_position($target_bearing, $target_elev);
print "Setting Bearing to $target_bearing degrees\n";
