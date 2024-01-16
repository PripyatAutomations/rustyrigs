# documentation
package RustyRigs::doc;
use warnings;
use strict;

# XXX: We need to make this message
my $help_msg = "==== General Options ====\n"
             . "\t-f <file>\t\tSpecify a configuration file for the rig\n"
             . "\t-m <file>\t\tSpecify the channel memory file\n"
             . "\t-h\t\t\tDisplay this help message\n"
             . "\t\t--help\n"
             . "\t-r\t\t\tTreat the configuration file as read-only\n"
             . "\n"
             . "==== Window Placement ====\n"
             . "\t-a\t\t\tAlways on top\n"
             . "\t-x\t\t\tX position of main window\n"
             . "\t-y\t\t\tY position of main window\n";

# Send help to tty
sub show_help_tty {
    my ( $app_name, $app_descr ) = @_;

    print "$app_name: $app_descr\n";
    print $help_msg;

    exit 0;
}

1;
