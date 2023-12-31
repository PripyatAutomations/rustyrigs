# woodpile.pm contains an assortment of junk i commonly use
package woodpile;
use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Gtk3 '-init';

sub hex_to_gdk_rgba {
    my ($hex_color) = @_;

    # Convert hex color value to RGBA components
    if (!defined $hex_color) {
       die "Invalid color (from: " . (caller(1))[3] . ")!\n";
    }
    my ($r, $g, $b) = map { hex($_) / 255 } $hex_color =~ m/[\da-f]{2}/ig;

    # Create a Gtk3::Gdk::RGBA object using the calculated RGBA components
    my $rgba_color = Gtk3::Gdk::RGBA->new($r, $g, $b, 1.0); # 1.0 is alpha (fully opaque)
    
    return $rgba_color;
}

sub find_offset {
    my $array_ref = shift;
    my @a = @$array_ref;
    my $val = shift;
    my $index = -1;

    if (!defined($val)) {
       return -1;
    }

    for my $i (0 .. $#a) {
        if (looks_like_number($a[$i]) && looks_like_number($val)) {
            # Compare as numbers if both values are numeric
            if ($a[$i] == $val) {
                $index = $i;
                last;
            }
        } else {
            # Compare as strings if either value is non-numeric
            if ("$a[$i]" eq "$val") {
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
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday tv_interval usleep);
my $app_name = 'grigs';

# Log levels for messages
our %log_levels = (
   'none' => 0,
   'fatal' => 1,
   'bug' => 2,
   'audit' => 3,
   'warn' => 4,
   'info' => 5,
   'debug' => 6,
   'noise' => 7,
);

sub Log {
   my ($self, $log_type, $log_level) = @_;
   my $filter_level = $self->{log_level};

   if ($log_levels{$filter_level} < $log_levels{$log_level}) {
      return 0;
   }

   my $datestamp = strftime("%Y/%m/%d %H:%M:%S", localtime);
   my $lvl = $log_levels{$log_level};
   if (!defined $lvl) {
      $lvl = "UNKNOWN";
   }
   ####
   print { $self->{log_fh} } $datestamp . " [$log_type/$lvl]";
   print $datestamp . " [$log_type/$log_level]";

   # skip first 3 arguments
   shift; shift; shift;
   foreach my $a(@_) {
      print { $self->{log_fh} } " " . $a;
      print " " . $a;
   }
   print { $self->{log_fh} } "\n";
   print "\n";
}

sub set_log_level {
   my ($class, $log_level);
}

sub new {
   my ($class, $log_file, $log_level) = @_;

   open my $log_fh, '>>', $log_file or die "Unable to open $log_file: $!\n";

   my $self = {
      log_file => $log_file,
      log_level => $log_level,
      log_fh => $log_fh
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

my $settings_open = 0;
my $cfg_readonly = 0;		# if 1, config won't be written out

sub load_config {
   my ($self, $cfg_file, $def_cfg) = @_;
   my $rv;

   # does $cfg_file exist? if so use it instead of default (this lets us have per-rig configurations)
   if (defined($cfg_file) && -f $cfg_file) {
      $cfg_file = $cfg_file;
   }

   # If a config file exists, load it
   if (-f $cfg_file) {
      open my $fh, '<', $cfg_file or die "Can't open config file $cfg_file for reading: $!";
      my $yaml_content = do { local $/; <$fh> };
      my $new_cfg = YAML::XS::Load($yaml_content);

      if (defined($def_cfg) && defined($new_cfg)) {
         print "[config/info] merging config\n";
         $rv = {%$def_cfg, %$new_cfg};
      } elsif (defined($new_cfg)) {
         print "[config/info] using only new config\n";
         $rv = $new_cfg;
      } else {
         print "[config/info] using only default config\n";
         $rv = $def_cfg;
      }
   } else {
      warn "[config/info] cant find config file $cfg_file, using defaults\n";
      $rv = $def_cfg;
   }
   return $rv;
}

sub save_config {
   my ($self, $cfg_file) = @_;

   if (!$cfg_readonly) {
      print "[core/debug] saving config to $cfg_file\n";
      my $cfg_out_txt = YAML::XS::Dump($self->{cfg});
      if (!defined($cfg_out_txt)) {
         die "Exporting YAML configuration failed\n";
      }
      open my $fh, '>', $cfg_file or die "Can't open config file $cfg_file for writing: $! ";
      print $fh $cfg_out_txt . "\n";
      close $fh;
   } else {
      $self->log->Log("core", "info", "not saving configuration as cfg_readonly is enabled...");
   }
}

sub new {
   my ($class, $log, $cfg_file, $def_cfg) = @_;

   my $self = {
      load_config => \&load_config,
      save_config => \&save_config,
      cfg_file => $cfg_file,
      def_cfg => $def_cfg,
      log => $log
   };

   $self->{cfg} = load_config($self, $cfg_file, $def_cfg);

   bless $self, $class;
   return $self;
}

# Destructor to close the file cfg_fh when the object is destroyed
sub DESTROY {
    my ($self) = @_;
}

1;
