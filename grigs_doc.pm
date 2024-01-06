# documentation
package rustyrigs_doc;
use Carp;
use warnings;
use strict;

sub show_help {
   ( my $app_name, my $app_descr ) = @_;

   print "$app_name: $app_descr\n";
   print "==== General Options ====\n";
   print "\t-f <file>\t\tSpecify a configuration file for the rig\n";
   print "\t-m <file>\t\tSpecify the channel memory file\n";
   print "\t-h\t\t\tDisplay this help message\n";
   print "\t\t--help\n";
   print "\t-r\t\t\tTreat the configuration file as read-only\n";
   print "\n";
#   print "==== Window Placement ====\n";
#   print "\t-a\t\t\tAlways on top\n";
#   print "\t-x\t\t\tX position of main window\n";
#   print "\t-y\t\t\tY position of main window\n";
   exit 0;
}

1;
