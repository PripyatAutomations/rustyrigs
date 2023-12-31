# Here we generate a box packed with the FM mode settings
# which can be inserted/removed on the main window as needed

package grigs_fm;
use Carp;
use Data::Dumper;
use Data::Structure::Util qw/unbless/;
use woodpile;
#use strict;
use warnings;
use Glib qw(TRUE FALSE);
my $cfg;
my $fm_box;
my $vfos = $grigs_hamlib::vfos;
my $curr_vfo;
my $vfo;

sub refresh_tone_freqs {
   my $curr_vfo = $cfg->{'active_vfo'};
   if (defined($curr_vfo)) {
      $vfo = $vfos->{$curr_vfo};
   } else {
      print "refresh_tone_freqs: no active VFO\n";
      $vfo = $Hamlib::RIG_VFO_A;
   }
   my $rv = -1;

   # empty the lists
   $tone_freq_rx_entry->remove_all();
   $tone_freq_tx_entry->remove_all();

   foreach my $val (@pl_tones) {
      $tone_freq_rx_entry->append_text($val);
      $tone_freq_tx_entry->append_text($val);
   }

   if (defined($vfo->{'fm'}{'tone_freq_rx'})) {
      my $rx_tone = woodpile::find_offset(\@pl_tones, $vfo->{'fm'}{'tone_freq_rx'});
      $tone_freq_rx_entry->set_active($rx_tone);
   }

   if (defined($vfo->{'fm'}{'tone_freq_tx'})) {
      my $tx_tone = woodpile::find_offset(\@pl_tones, $vfo->{'fm'}{'tone_freq_tx'});
      $tone_freq_tx_entry->set_active($tx_tone);
   }
}

sub new {
   ( my $class, $cfg, my $w_main, my $w_main_accel ) = @_;

   $curr_vfo = $cfg->{'active_vfo'};
   $vfo = $vfos->{$curr_vfo};

   # Create the FM settings box and hide it
   ########################################
   my $fm_label = Gtk3::Label->new("---- FM ----");
   my $split_mode_label = Gtk3::Label->new("Split Mode (" . $cfg->{'key_split'} . ")");
   my $split_mode_entry = Gtk3::ComboBoxText->new();
   $split_mode_entry->append_text("+");
   $split_mode_entry->append_text("-");
   $split_mode_entry->append_text("OFF");
   $split_mode_entry->append_text("RX");
   $split_mode_entry->set_active(2);

   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_split'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $split_mode_entry->grab_focus();
      $split_mode_entry->popup();
   });
   $split_mode_entry->signal_connect(changed => sub {
      my $curr_vfo = $cfg->{'active_vfo'};
      my $vfo = $vfos->{$curr_vfo};
      my $value = $split_mode_entry->get_active_text();
      $vfo->{'fm'}{'split_mode'} = $value;
   });

   my $offset_label = Gtk3::Label->new("Offset kHz (" . $cfg->{'key_offset'} . ")");
   my $offset_entry = Gtk3::ComboBoxText->new();
   $offset_entry->append_text("0");
   $offset_entry->append_text("100KHz");
   $offset_entry->append_text("500KHz");
   $offset_entry->append_text("600KHz");
   $offset_entry->append_text("1.0MHz");
   $offset_entry->append_text("1.6MHz");
   $offset_entry->append_text("5.0MHz");
   $offset_entry->append_text("12.0MHz");
   $offset_entry->append_text("12.5MHz");
   $offset_entry->append_text("20.0MHz");
   $offset_entry->append_text("25.0MHz");
   $offset_entry->set_active(0);
   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_offset'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $offset_entry->grab_focus();
      $offset_entry->popup();
   });
   $offset_entry->signal_connect(changed => sub {
      my $curr_vfo = $cfg->{'active_vfo'};
      my $vfo = $vfos->{$curr_vfo};
      my $value = $offset_entry->get_active_text();
      $vfo->{'fm'}{'split_offset'} = $value;
   });

   my $tone_mode_label = Gtk3::Label->new("Tone Mode (" . $cfg->{'key_tone_mode'} . ")");
   my $tone_mode_entry = Gtk3::ComboBoxText->new();
   $tone_mode_entry->append_text("OPEN");
   $tone_mode_entry->append_text("R-PL");
   $tone_mode_entry->append_text("T-PL");
   $tone_mode_entry->append_text("RT-PL");
   $tone_mode_entry->append_text("R-DCS");
   $tone_mode_entry->append_text("T-DCS");
   $tone_mode_entry->append_text("RT-DCS");
   $tone_mode_entry->append_text("Carrier");
   $tone_mode_entry->set_active(0);
   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_tone_mode'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $tone_mode_entry->grab_focus();
      $tone_mode_entry->popup();
   });
   $tone_mode_entry->signal_connect(changed => sub {
      my $curr_vfo = $cfg->{'active_vfo'};
      my $vfo = $vfos->{$curr_vfo};
      my $value = $tone_mode_entry->get_active_text();
      $vfo->{'fm'}{'tone_mode'} = $value;
      refresh_tone_freqs();
   });

   my $tone_freq_rx_label = Gtk3::Label->new("Tone Freq RX (" . $cfg->{'key_tone_freq_rx'} . ")");
   $tone_freq_rx_entry = Gtk3::ComboBoxText->new();
   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_tone_freq_rx'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $tone_freq_rx_entry->grab_focus();
      $tone_freq_rx_entry->popup();
   });
   $tone_freq_rx_entry->signal_connect(changed => sub {
      my $curr_vfo = $cfg->{'active_vfo'};
      my $vfo = $vfos->{$curr_vfo};
      my $rrv = $tone_freq_rx_entry->get_active_text();
      $vfo->{'fm'}{'tone_freq_rx'} = $rrv;

      # If the TX PL is empty, set it to the RX tone
      my $rro = woodpile::find_offset(\@pl_tones, $rrv);
      my $trv = $tone_freq_tx_entry->get_active_text();
      my $tro = woodpile::find_offset(\@pl_tones, $trv);

      # If PL is empty or both boxes are the same, change it along
      if (!defined($trv) || ($rro - 1) == $tro || ($tro - 1) == $rro) {
         $tone_freq_tx_entry->set_active(woodpile::find_offset(\@pl_tones, $rrv));
      }
   });

   my $tone_freq_tx_label = Gtk3::Label->new("Tone Freq TX (" . $cfg->{'key_tone_freq_tx'} . ")");
   $tone_freq_tx_entry = Gtk3::ComboBoxText->new();
   # XXX: ACCEL-Replace these with a global function
   $w_main_accel->connect(ord($cfg->{'key_tone_freq_tx'}), $cfg->{'shortcut_key'}, 'visible', sub {
      $tone_freq_tx_entry->grab_focus();
      $tone_freq_tx_entry->popup();
   });
   $tone_freq_tx_entry->signal_connect(changed => sub {
      my $curr_vfo = $cfg->{'active_vfo'};
      my $vfo = $vfos->{$curr_vfo};
      my $value = $tone_freq_tx_entry->get_active_text();
      $vfo->{'fm'}{'tone_freq_tx'} = $value;
   });

   refresh_tone_freqs();

   $fm_box = Gtk3::Box->new('vertical', 5);
   $fm_box->pack_start($fm_label, FALSE, FALSE, 0);
   $fm_box->pack_start($split_mode_label, FALSE, FALSE, 0);
   $fm_box->pack_start($split_mode_entry, FALSE, FALSE, 0);
   $fm_box->pack_start($offset_label, FALSE, FALSE, 0);
   $fm_box->pack_start($offset_entry, FALSE, FALSE, 0);
   $fm_box->pack_start($tone_mode_label, FALSE, FALSE, 0);
   $fm_box->pack_start($tone_mode_entry, FALSE, FALSE, 0);
   $fm_box->pack_start($tone_freq_rx_label, FALSE, FALSE, 0);
   $fm_box->pack_start($tone_freq_rx_entry, FALSE, FALSE, 0);
   $fm_box->pack_start($tone_freq_tx_label, FALSE, FALSE, 0);
   $fm_box->pack_start($tone_freq_tx_entry, FALSE, FALSE, 0);
   my $self = {
      box => $fm_box
   };
   bless $self, $class;
   return $self;
}

1;
