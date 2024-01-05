#!/usr/bin/perl
# grigs.pl: GTK rigctld frontend for the system tray
# You need to run rigctld with -o such as in ./run-dummy-rigctld
# XXX: Move all GUI bits to grigs_gtk.pm - so we can later add CLI frontend
#     -- this is in progress, and a bit ugly ;)
use strict;
use warnings;
use Hamlib;
use Scalar::Util qw(looks_like_number);
use Sys::Hostname;
use Data::Dumper;
use Data::Structure::Util qw/unbless/;
use YAML::XS;
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday tv_interval usleep);
use Gtk3 '-init';
use Glib qw(TRUE FALSE);
use FindBin;
use lib $FindBin::Bin;

# project settings
my $app_name = 'grigs';
my $app_descr = "GTK frontend for rigctld";
my $default_cfg_file = $ENV{"HOME"} . "/.config/${app_name}.yaml";
my $cfg_file = $default_cfg_file;
my $log_file = $ENV{"HOME"} . "/${app_name}.log";

# override with local bits and pieces if in source directory...
if (-f 'grigs_defconfig.pm') {
   use lib './lib';
   print "* It seems we're running in a $app_name source directory, so we'll use the libraries from there. *\n";
} else {
   use lib '/usr/lib/grigs/';
}

use woodpile;
use grigs_defconfig;
#use grigs_ui;			# someday we'll have a cli interface here
use grigs_gtk_ui;
use grigs_cmdline;
use grigs_doc;
use grigs_hamlib;
use grigs_settings;
use grigs_fm;
use grigs_memory;
use grigs_meter;

# Start logging in debug mode until config is loaded and we quiet down...
our $log = woodpile::Log->new($log_file, "debug");

##################
# Run time state #
##################
my $cfg_readonly = FALSE;
my $connected = FALSE;
my $locked = FALSE;
my $vfos = $grigs_hamlib::vfos;
my $hamlib_riginfo;
my $rig;
my $channels;
my $gtk_ui;
my $rig_p;

#####################################################
# Set config to defconfig, until we load config...
my $def_cfg = $grigs_defconfig::def_cfg;
my $cfg = $def_cfg;
my $cfg_p;

# Set up logging...
$log->Log("core", "info", $app_name . " is starting");

sub toggle_locked {
   my $origin = shift;

   if ($locked == TRUE) {
      $locked = FALSE;
   } else {
      $locked = TRUE;
   }

   if (!$origin eq "button") {
      # XXX: We need to check here if using GTK
      $gtk_ui->lock_button->set_active($locked);
   }

   $log->Log("ui", "debug", "Toggling \$locked to $locked by $origin");
}

sub next_vfo {
    my $nval = grigs_hamlib::next_vfo($cfg->{'active_vfo'});
    switch_vfo($nval);
    $log->Log("ui", "debug", "nval: $nval, curr: " . $cfg->{'active_vfo'});
    return FALSE;
}

# Parse the command line
grigs_cmdline::parse_cmdline($cfg, $cfg_file);

# Load configuration
$cfg_p = woodpile::Config->new($log, $cfg_file, $def_cfg);
$cfg = $cfg_p->{cfg};

if ($cfg_readonly) {
   $log->Log("core", "info", "using configuration read-only");
   $cfg->{'read_only'} = 1;
}

# Initialize the GTK GUI
$gtk_ui = grigs_gtk_ui->new($cfg, $log);
$gtk_ui->load_icons();

# load channel memory
#$channels = grigs_memory->new($cfg, $gtk_ui->w_main);

#if (-f $cfg->{'mem_file'}) {
#   $channels->load_from_yaml();
#} else {
#   # Load default memories
#   $channels->load_defaults($grigs_defconfig::default_memories);
#
#   # Save default memories to memory file
#   # XXX: Save memories
##   $channels->save($cfg->{'mem_file'});
#}

$gtk_ui->draw_main_win();
$gtk_ui->set_icon("connecting");

# Delay the hamlib init at least a second, for reliability
my $hamlib_initialized = 0;
sub hamlib_init {
   return if $hamlib_initialized;

   my $rig_p = grigs_hamlib->new($cfg);
   $rig = $rig_p->{rig};

   if (defined($rig)) {
      set_icon("idle");
   } else {
      die "Wtf? setup_hamlib returned undefined\n";
   }
   $hamlib_initialized = 1;
}
Glib::Timeout->add(1000, \&hamlib_init);

# Andd.... go!
Gtk3->main();
$log->Log("core", "info", "$app_name is shutting down!");
