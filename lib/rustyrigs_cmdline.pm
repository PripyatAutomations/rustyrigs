package rustyrigs_cmdline;
use strict;
use warnings;
use Carp;
use Glib qw(TRUE FALSE);
use Data::Dumper;
use Getopt::Long;

# scratch space for cmdline arguments
my $cfg_file;
my $mem_file;
my $cl_show_help = 0;
my $cl_ontop;		# always on top?
my $cl_x;		# cmdline X pos of main win
my $cl_y;		# cmdline Y pos of main win
my $cl_s_x;		# cmdline X pos of settings win
my $cl_s_y;		# cmdline Y pos of settings win
my $cfg;

sub parse {
   ( my $cfg_ref, my $cfg_file_ref ) = @_;

   $cfg = ${$cfg_ref};
   $cfg_file = ${$cfg_file_ref};

   # Parse command line options
   GetOptions(
#      "a" => \$cl_ontop,		# -a for always on top
      "f=s" => \$cfg_file,	    	# -f to specify the config file
      "m=s" => \$mem_file,		# -m for memory file
      "r" => \$main::cfg_readonly, 	# -r for read-only config
      "h|help" => \$cl_show_help,     # -h or --help for help
#      "x=i" => \$cl_x,		# X pos of main win
#      "y=i" => \$cl_y,		# Y pos of main win
   ) or die "Invalid options - see --help\n";

   $main::cfg_file = $cfg_file;
   if (defined $mem_file) {
      # use cmdline memory file
      $main::mem_file = $mem_file;
   } elsif (defined $main::cfg->{'mem_file'}) {
      # use file specified in config file
      $mem_file = $main::mem_file = $main::cfg->{'mem_file'};
   } else {
      # derive it from config file name
      $mem_file = $main::cfg_file;
      $mem_file =~ s/\.yaml$/.mem.yaml/;
   }
   $cfg->{'mem_file'} = $mem_file;

   # Show help if requested
   if ($cl_show_help) {
      rustyrigs_doc::show_help($main::app_name, $main::app_descr);
   }

   # XXX: Make this work

   if (defined($cl_ontop)) {
      $main::log->Log("ui", "info", "Forcing always on top due to -a cmdline option");
      $main::cfg->{'always_on_top'} = 1;
   }

   if (defined($cl_x) && defined($cl_y)) {
      $main::log->Log("ui", "info", "Placing main window at $cl_x, $cl_y at cmdline request");
      $main::cfg->{'win_x'} = $cl_x;
      $main::cfg->{'win_y'} = $cl_y;
   } elsif (defined($cl_x) || defined($cl_y)) {
      $main::log->Log("ui", "error", "You must specify both -x and -y options to place the window at startup");
      exit 1;
   }
}

1;
