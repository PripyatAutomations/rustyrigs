# Here we handle interaction with hamlib to talk to rigctld
#
# Try to stay frontend-agnostic here, if possible
#
package rustyrigs_hamlib;
use Carp;
use Glib qw(TRUE FALSE);
use strict;
use warnings;

my $cfg;
my $rig;

our @vfo_widths_fm = ( 25000, 12500 );
our @vfo_widths_am = ( 6000, 5000, 3800, 3200, 3000, 2800 );
our @vfo_widths_ssb = ( 3800, 3000, 3200, 2800, 2700, 2500 );
our @pl_tones = (
    67.0, 71.9, 77.0, 88.5, 94.8, 100.0, 103.5, 107.2, 110.9, 114.8,
    118.8, 123.0, 127.3, 131.8, 136.5, 141.3, 146.2, 151.4, 156.7, 162.2,
    167.9, 173.8, 179.9, 186.2, 192.8, 203.5, 210.7, 218.1, 225.7, 233.6,
    241.8, 250.3
);

our %hamlib_debug_levels = (
   'none' => $Hamlib::RIG_DEBUG_NONE,
   'bug' => $Hamlib::RIG_DEBUG_BUG,
   'err' => $Hamlib::RIG_DEBUG_ERR,
   'warn' => $Hamlib::RIG_DEBUG_WARN,
   'verbose' => $Hamlib::RIG_DEBUG_VERBOSE,
   'trace' => $Hamlib::RIG_DEBUG_TRACE,
   'cache' => $Hamlib::RIG_DEBUG_CACHE
);

our %vfo_mapping = (
   'A' => $Hamlib::RIG_VFO_A,
   'B' => $Hamlib::RIG_VFO_B,
   'C' => $Hamlib::RIG_VFO_C
);

our $vfos = {
   'A' => {
     freq => 14074000,
     mode => "D-U",
     power => 40,
     width => 3000,
     min_power => 5,
     max_power => 100,
     power_step => 5,
     min_freq => 3000,
     max_freq => 56000000,
     rf_gain => 0,
     vfo_step => 1000,
     stats => {
        attn => 0,
        signal => 0,
     },
     fm => {
        split_mode => "-",
        split_offset => "600KHz",
        tone_mode => "RT-PL",
        tone_freq_tx => "112.0",
        tone_freq_rx => "112.0"
     }
   },
   'B' => {
     freq => 7074000,
     mode => "D-U",
     power => 40,
     width => 3000,
     min_power => 5,
     max_power => 100,
     power_step => 5,
     min_freq => 3000,
     max_freq => 56000000,
     rf_gain => 0,
     vfo_step => 1000,
     stats => {
        attn => 0,
        signal => 0,
     },
     fm => {
        split_mode => "-",
        split_offset => "600KHz",
        tone_mode => "RT-PL",
        tone_freq_tx => "112.0",
        tone_freq_rx => "112.0"
     }
   }
};

my $pending_changes = {
   'A' => {
      freq => 0,			# need to set freq
      mode => 0,			# need to set mode/width
      power => 0
   },
   'B' => {
      freq => 0,			# need to set freq
      mode => 0,			# need to set mode/width
      power => 0
   }
};

########################################################################
########################################################################

sub hamlib_debug_level {
   ( my $class ) = @_;
   my $new_lvl = $_[0];

   if (exists $hamlib_debug_levels{$new_lvl}) {
      my $val = $hamlib_debug_levels{$new_lvl};
      return $val;
   } else {
      $main::log->Log("hamlib", "warn", "hamlib_debug_level: returning default Warnings: $new_lvl unrecognized!");
      return $Hamlib::RIG_DEBUG_WARN;
   }
}

sub ptt_off {
   ( my $class, my $vfo ) = @_;
   my $curr_vfo = $$cfg->{active_vfo};

   $main::log->Log("ptt", "info", "Clearing PTT...");
   $rig->set_ptt($vfo, $Hamlib::RIG_PTT_OFF);
}

sub ptt_on {
   ( my $class, my $vfo ) = @_;
   my $curr_vfo = $$cfg->{active_vfo};

   $main::log->Log("ptt", "info", "Setting PTT...");
   $rig->set_ptt($vfo, $Hamlib::RIG_PTT_ON);
}

sub set_freq {
   ( my $class, my $freq ) = @_;
   my $curr_vfo = $$cfg->{'active_vfo'};
   $vfos->{$curr_vfo}{'freq'} = $freq;
   $rig->set_freq($curr_vfo, $freq);
}

sub update_display {
   ( my $class ) = @_;
   my $curr_vfo = $$cfg->{'active_vfo'};

   $main::vfo_freq_entry->set_value($vfos->{$curr_vfo}{'freq'});
}

sub vfo_name {
   my $vfo = shift;

   if ($vfo == $Hamlib::RIG_VFO_A) {
      return 'A';
   } elsif ($vfo == $Hamlib::RIG_VFO_B) {
      return 'B';
   } elsif ($vfo == $Hamlib::RIG_VFO_C) {
      return 'C';
   }
   return '';
}

sub vfo_from_name {
   my $vfo_name = shift;
   if ($vfo_name eq 'A') {
      return $Hamlib::RIG_VFO_A;
   } elsif ($vfo_name eq 'B') {
      return $Hamlib::RIG_VFO_B;
   } elsif ($vfo_name eq 'C') {
      return $Hamlib::RIG_VFO_C;
   }
}

sub next_vfo {
   my $vfo = shift;

   # XXX: this only supports 2 vfo
   if ($vfo eq 'A') {
      return 'B';
   } elsif ($vfo eq 'B') {
      return 'A';
   } else {
      die "No such VFO\n";
   }
}

sub read_rig {
   ( my $class ) = @_;

   my $curr_hlvfo = $rig->get_vfo();
   my $curr_vfo = $$cfg->{active_vfo} = vfo_name($curr_hlvfo);

   # XXX: Update the VFO select button if needed
   # Get the RX volume
   $$cfg->{'rx_volume'} = $rig->get_level($Hamlib::RIG_LEVEL_AF, $curr_hlvfo);
#   $rig_vol_entry->set_value($$cfg->{'rx_volume'});

   # Get the frequency for current VFO
   $vfos->{$curr_vfo}{'freq'} = $rig->get_freq($curr_hlvfo);
   $main::vfo_freq_entry->set_value($vfos->{$curr_vfo}{'freq'});
   $main::log->Log("hamlib", "debug", "freq: " . $vfos->{$curr_vfo}{'freq'});

#   my $mode;
#   $vfos->{$curr_vfo}{'mode'] = $mode;
#   my $power;
#   $vfos->{$curr_vfo}{'power'} = $power;
    my $stats = $vfos->{$curr_vfo}{'stats'};
    $stats->{'signal'} = $rig->get_level_i($curr_hlvfo, $Hamlib::RIG_LEVEL_STRENGTH);
    $main::log->Log("hamlib", "debug", "strength:\t\t" . $stats->{'signal'});

#    my $atten = $rig->{caps}->{attenuator};
#    $stats->{'atten'} = $atten;
#    $main::log->Log("hamlib", "debug", "Attenuators:\t\t@$atten");
}

# state for our tray mode polling slowdown
my $tray_iterations = 0;
my $update_needed = 0;

sub exec_read_rig {
   ( my $class ) = @_;

   my $tray_every = $$cfg->{'poll_tray_every'};

   if (!$main::connected) {
      $main::log->Log("hamlib", "debug", "skipping rig read (not connected)");
   }

   # Slow down status updates when not actively displayed
   if ($$cfg->{'win_visible'}) {
      $update_needed = 1;
   } else {
      $tray_iterations++;

      # are we due for an update?
      if (!$tray_iterations >= $tray_every) {
         $update_needed = 1;
      }
   }

   if ($update_needed) {
      $tray_iterations = 0;
      read_rig();
      update_display();
      $update_needed = 0;
   }

   print ".\n";
   return TRUE;			# ensure we're called again
}

sub new {
   ( my $class, my $cfg_ref ) = @_;
   $cfg = ${$cfg_ref};

   Hamlib::rig_set_debug(hamlib_debug_level($$cfg->{'hamlib_loglevel'}));
   my $model = $$cfg->{'rigctl_model'};
   my $host = $$cfg->{'rigctl_addr'};
   if (!defined($model) || $model eq "") {
      $model = 'RIG_MODEL_RIGCTLD';
   }
   $rig = new Hamlib::Rig($model);

   $rig->set_conf("retry", "50");
   $rig->set_conf('rig_pathname', $host);

   $main::log->Log("hamlib", "info", "connecting to $host");

#  XXX: hamlib seems to immediately return success, even before trying to connect...
#   $w_main->set_title("rustyrigs: Connecting to $host");
#   if ($rig->open() != $Hamlib::RIG_OK) {
   my $rv = $rig->open();
#      $log->Log("hamlib", "fatal", "failed connecting to hamlib\n");
#      die "No rig connection\n";
#   }

   # enable polling of the rig
   $main::connected = 1;
   my $riginfo = $rig->get_info();
   $main::log->Log("hamlib", "info", "Backend copyright:\t$rig->{caps}->{copyright}");
   $main::log->Log("hamlib", "info", "Model:\t\t$rig->{caps}->{model_name}");
   $main::log->Log("hamlib", "info", "Manufacturer:\t\t$rig->{caps}->{mfg_name}");
   $main::log->Log("hamlib", "info", "Backend version:\t$rig->{caps}->{version}");

   if (defined $riginfo) {
      $riginfo =~ s/\n$//;
      $main::log->Log("hamlib", "info", "Connected Rig:\t$riginfo");
   }

   my $poll_interval = $$cfg->{'poll_interval'};

   # Start a timer for it
   my $rig_timer = Glib::Timeout->add_seconds($poll_interval, \&exec_read_rig);
   my $self = {
      rig => $rig,
      exec_read_rig => \&exec_read_rig,
      set_freq => \&set_freq,
      timer => $rig_timer
   };
   bless $self, $class;

   return $self;
}

sub DESTROY {
}

1;
