# Here we handle interaction with hamlib to talk to rigctld
#
# Try to stay frontend-agnostic here, if possible
package RustyRigs::hamlib;
use Carp;
use Glib qw(TRUE FALSE);
use strict;
use warnings;
use Data::Dumper;
my $cfg;
my $rig;

my $gtk_ui;

# This will become TRUE if read_rig() is running
# - Callbacks for UI widgets will be suppressed if this is TRUE
# - Use is_busy() to check
our $rigctld_applying_changes = FALSE;

# This will be come TRUE if user is changing the GUI
# - read_rig will be surprised in exec_read_rig while GUI changing
# - Use is_gui_busy() to check
our $gui_applying_changes = FALSE;

our @vfo_widths_fm  = ( 25000, 12500 );
our @vfo_widths_am  = ( 6000,  5000, 3800, 3200, 3000, 2800 );
our @vfo_widths_ssb = ( 3800,  3000, 3200, 2800, 2700, 2500 );
our @pl_tones       = (
    67.0,  71.9,  77.0,  88.5,  94.8,  100.0, 103.5, 107.2,
    110.9, 114.8, 118.8, 123.0, 127.3, 131.8, 136.5, 141.3,
    146.2, 151.4, 156.7, 162.2, 167.9, 173.8, 179.9, 186.2,
    192.8, 203.5, 210.7, 218.1, 225.7, 233.6, 241.8, 250.3
);

our %hamlib_debug_levels = (
    'none'    => $Hamlib::RIG_DEBUG_NONE,
    'bug'     => $Hamlib::RIG_DEBUG_BUG,
    'err'     => $Hamlib::RIG_DEBUG_ERR,
    'warn'    => $Hamlib::RIG_DEBUG_WARN,
    'verbose' => $Hamlib::RIG_DEBUG_VERBOSE,
    'trace'   => $Hamlib::RIG_DEBUG_TRACE,
    'cache'   => $Hamlib::RIG_DEBUG_CACHE
);

our @hamlib_modes = ( 'D-U', 'D-L', 'USB', 'LSB', 'FM', 'AM', 'C4FM', 'CW' );

our %vfo_mapping = (
    'A' => $Hamlib::RIG_VFO_A,
    'B' => $Hamlib::RIG_VFO_B,
    'C' => $Hamlib::RIG_VFO_C
);

our $vfos = {
    'A' => {
        freq       => 14074000,
        mode       => "LSB",
        power      => 40,
        width      => 3000,
        min_power  => 5,
        max_power  => 100,
        power_step => 5,
        min_freq   => 3000,
        max_freq   => 56000000,
        rf_gain    => 0,
        vfo_step   => 1000,
        stats      => {
            attn   => 0,
            signal => 0,
            swr    => 0
        },
        fm => {
            split_mode   => "-",
            split_offset => "600KHz",
            tone_mode    => "RT-PL",
            tone_freq_tx => "112.0",
            tone_freq_rx => "112.0"
        }
    },
    'B' => {
        freq       => 7074000,
        mode       => "LSB",
        power      => 40,
        width      => 3000,
        min_power  => 5,
        max_power  => 100,
        power_step => 5,
        min_freq   => 3000,
        max_freq   => 56000000,
        rf_gain    => 0,
        vfo_step   => 1000,
        stats      => {
            attn   => 0,
            signal => 0,
            swr    => 0
        },
        fm => {
            split_mode   => "-",
            split_offset => "600KHz",
            tone_mode    => "RT-PL",
            tone_freq_tx => "112.0",
            tone_freq_rx => "112.0"
        }
    }
};

my $pending_changes = {
    'A' => {
        freq  => 0,    # need to set freq
        mode  => 0,    # need to set mode/width
        power => 0
    },
    'B' => {
        freq  => 0,    # need to set freq
        mode  => 0,    # need to set mode/width
        power => 0
    }
};

our $volume;

########################################################################
sub hamlib_debug_level {
    ( my $self ) = @_;
    my $new_lvl = $_[0];

    if ( exists $hamlib_debug_levels{$new_lvl} ) {
        my $val = $hamlib_debug_levels{$new_lvl};
        return $val;
    }
    else {
        $main::log->Log( "hamlib", "warn",
"hamlib_debug_level: returning default Warnings: $new_lvl unrecognized!"
        );
        return $Hamlib::RIG_DEBUG_WARN;
    }
}

sub ptt_off {
    ( my $self, my $vfo ) = @_;
    my $curr_vfo = $$cfg->{active_vfo};

    $main::log->Log( "ptt", "info", "Clearing PTT..." );
    $rig->set_ptt( $vfo, $Hamlib::RIG_PTT_OFF );
}

sub ptt_on {
    ( my $self, my $vfo ) = @_;
    my $curr_vfo = $$cfg->{active_vfo};

    $main::log->Log( "ptt", "info", "Setting PTT..." );
    $rig->set_ptt( $vfo, $Hamlib::RIG_PTT_ON );
}

sub set_freq {
    ( my $self, my $freq ) = @_;
    my $curr_vfo = $$cfg->{'active_vfo'};
    $vfos->{$curr_vfo}{'freq'} = $freq;
#    $rig->set_freq( $curr_vfo, $freq );
}


sub vfo_name {
    my $vfo = shift;

    if ( $vfo == $Hamlib::RIG_VFO_A ) {
        return 'A';
    }
    elsif ( $vfo == $Hamlib::RIG_VFO_B ) {
        return 'B';
    }
    elsif ( $vfo == $Hamlib::RIG_VFO_C ) {
        return 'C';
    }
    return '';
}

sub vfo_from_name {
    my $vfo_name = shift;
    if ( $vfo_name eq 'A' ) {
        return $Hamlib::RIG_VFO_A;
    }
    elsif ( $vfo_name eq 'B' ) {
        return $Hamlib::RIG_VFO_B;
    }
    elsif ( $vfo_name eq 'C' ) {
        return $Hamlib::RIG_VFO_C;
    }
}

sub next_vfo {
    my $vfo;
    
    if (!defined $vfo) {
       $vfo = shift;
    }
    else {
       print "not enough arguments to next_vfo\n";
       return;
    }

    $gtk_ui->switch_vfo($vfo);
    $main::log->Log( "ui", "debug", "val: $vfo, curr: " . $$cfg->{'active_vfo'} );

    # XXX: this only supports 2 vfo
    if ( $vfo eq 'A' ) {
        return 'B';
    }
    elsif ( $vfo eq 'B' ) {
        return 'A';
    }
    else {
        die "No such VFO\n";
    }
}

# These let us only show messages when a state has changed, regardless
# of how many times we poll the rig... Don't export these...
my $last_ptt_status;
my $last_mode;
my $last_freq;

# Read the state of the rig and apply it to the appropriate $vfos entry
# XXX: This needs to read into $vfos then call $gtk_ui->update()
sub read_rig {
    ( my $self ) = @_;

    $rigctld_applying_changes = TRUE;
    my $curr_hlvfo = $rig->get_vfo();
    my $curr_vfo   = $$cfg->{active_vfo} = vfo_name($curr_hlvfo);

    # XXX: Update the VFO select button if needed


    # Get the frequency for current VFO
    my $freq = $rig->get_freq($curr_hlvfo);
    $vfos->{$curr_vfo}{'freq'} = $freq;
    if (!defined $last_freq || !($last_freq == $freq)) {
       $main::log->Log("hamlib", "info", "Freq change on VFO $curr_hlvfo to $freq");
    }
    $last_freq = $freq;

    my ($mode, $width) = $rig->get_mode();
    my $textmode = Hamlib::rig_strrmode($mode);
    $textmode =~ s/PKTUSB/D-U/g;
    $textmode =~ s/PKTLSB/D-L/g;
    if (!defined $last_mode || !($last_mode eq $textmode)) {
       $main::log->Log("hamlib", "info", "Mode of VFO $curr_hlvfo: $mode ($textmode) at width $width");
    }
    $last_mode = $textmode;

    my $vme = $$gtk_ui->{'mode_entry'};
    my $mode_index = 0;
    for my $i (0 .. $#RustyRigs::hamlib::hamlib_modes) {
        if ($RustyRigs::hamlib::hamlib_modes[$i] eq $textmode) {
            $mode_index = $i;
            last;
        }
    }

    # Get the RX volume
    $volume = $rig->get_level( $Hamlib::RIG_LEVEL_AF );
    print "vol: " . Dumper($volume) . "\n" if (defined $volume);
    if (defined $volume) {
       print "setting volume: $volume\n";
       $self->{'volume'} = $volume;
       my $rve = $main::gtk_ui->{'rig_vol_entry'};
       $rve->set_value($volume);
    }
    else {
#       print "no volume\n";
       $volume = 0;
    }

    # XXX: Figure out which width table applies and find the appropriate width index then select it...
    my ( $alc, $comp, $power, $sig, $swr, $temp, $vdd );
    $alc = $rig->get_level($Hamlib::RIG_LEVEL_ALC);
    $comp = $rig->get_level($Hamlib::RIG_LEVEL_COMP);
    # XXX: This needs to use MaxWatts instead of 100...
    $power = int($rig->get_level_f($Hamlib::RIG_LEVEL_RFPOWER) * 100 + 0.5);
    $sig = $rig->get_level_i($Hamlib::RIG_LEVEL_STRENGTH);
    $swr = $rig->get_level_f($Hamlib::RIG_LEVEL_SWR);
#    $temp = $rig->get_level($Hamlib::RIG_LEVEL_TEMP);
#    $vdd = $rig->get_level($Hamlib::RIG_LEVEL_VDD);
    $vfos->{$curr_vfo}{'power'} = $power;
    $vfos->{$curr_vfo}{'sig'} = $sig;
    $vfos->{$curr_vfo}{'swr'} = $swr;
#    $vfos->{$curr_vfo}{'temp'} = $temp;
#    $vfos->{$curr_vfo}{'vdd'} = $vdd;
    my $stats = $vfos->{$curr_vfo}{'stats'};
    $stats->{'signal'} = $rig->get_level_i( $curr_hlvfo, $Hamlib::RIG_LEVEL_STRENGTH );
#    $main::log->Log( "hamlib", "debug", "power:\t\t $power\n mode: \t\t$mode\nstrength:\t\t" . $stats->{'signal'} . "\tswr$swr");

    #    my $atten = $rig->{caps}->{attenuator};
    #    $stats->{'atten'} = $atten;
    #    $main::log->Log("hamlib", "debug", "Attenuators:\t\t@$atten");
    my $ptt_status = $rig->get_ptt($curr_hlvfo);

    ####################
    # Apply the values #
    ####################
#    my $rve = $$gtk_ui->{'rig_vol_entry'};
#    $$rve->set_value($volume);
    my $vfe = $$gtk_ui->{'vfo_freq_entry'};
    $$vfe->set_value( $vfos->{$curr_vfo}{'freq'} );
    $vfos->{$curr_vfo}{'mode'} = $textmode;
    $$vme->set_active( $mode_index );
    my $vpe = $$gtk_ui->{'vfo_power_entry'};
    $$vpe->set_value( $power );

    # Set the icons appropriately & update the tooltip
    if (!$ptt_status) {
       if (!defined $last_ptt_status || $last_ptt_status != $ptt_status) {
          $main::log->Log("hamlib", "info", "PTT off");
       }
       $main::gtk_ui->set_icon("idle");
    } else {
       if (!defined $last_ptt_status || $last_ptt_status != $ptt_status) {
          $main::log->Log("hamlib", "info", "PTT on");
       }
       $main::gtk_ui->set_icon("transmit");
    }
    $last_ptt_status = $ptt_status;
    $main::gtk_ui->update_widgets();
    $rigctld_applying_changes = FALSE;
}

# state for our tray mode polling slowdown, not exported
my $tray_iterations = 0;
my $update_needed   = 0;

# Determine if we need to read the rig this iteration...
sub exec_read_rig {
    ( my $self ) = @_;

    # Don't read the rig while GUI is applying changes...
    if ($gui_applying_changes) {
#       print "skipping read_rig as GUI update in progress\n";
       return TRUE;
    }

    my $tray_every = $$cfg->{'poll_tray_every'};

    if ( !$main::connected ) {
        $main::log->Log( "hamlib", "debug",
            "skipping rig read (not connected)" );
    }

    # Slow down status updates when not actively displayed
    if ( $$cfg->{'win_visible'} ) {
        $update_needed = 1;
    }
    else {
        $tray_iterations++;

        # are we due for an update?
        if ( $tray_iterations >= $tray_every ) {
            $update_needed = 1;
        }
    }

    if ($update_needed) {
        $tray_iterations = 0;
        read_rig();
        $update_needed = 0;
    }

    return TRUE;    # ensure we're called again
}

# Write vfo{}s
sub write_rig {
    my ( $self ) = @_;
}

sub is_busy {
   my ( $self ) = @_;
   return $rigctld_applying_changes;
}

sub is_gui_busy {
   my ( $self ) = @_;
   return $gui_applying_changes;
}

sub new {
    ( my $class, my $cfg_ref ) = @_;
    $cfg = $cfg_ref;
    $gtk_ui = \$main::gtk_ui;

    Hamlib::rig_set_debug( hamlib_debug_level( $$cfg->{'hamlib_loglevel'} ) );
    my $model = $$cfg->{'rigctl_model'};
    my $addr  = $$cfg->{'rigctl_addr'};

    # If no model set, use rigctld netrig
    if ( !defined $model || $model eq "" ) {
        $model = $Hamlib::RIG_MODEL_NETRIGCTL;
    }

    # If no addr set, use localhost
    if ( !defined $addr || $addr eq "" ) {
        $addr = "localhost:4532";
    }
    $rig = new Hamlib::Rig($model);

    $rig->set_conf( "retry",        "50" );
    $rig->set_conf( 'rig_pathname', $addr );

    $main::log->Log( "hamlib", "info", "connecting to $addr" );

#  XXX: hamlib seems to immediately return success, even before trying to connect...
#   if ($rig->open() != $Hamlib::RIG_OK) {
    #      $log->Log("hamlib", "fatal", "failed connecting to hamlib\n");
    #      die "No rig connection\n";
    #   }
    my $rv = $rig->open();

    # enable polling of the rig
    $main::connected = 1;
    my $riginfo = $rig->get_info();
    $main::log->Log( "hamlib", "info",
        "Backend copyright:\t$rig->{caps}->{copyright}" );
    $main::log->Log( "hamlib", "info", "Model:\t\t$rig->{caps}->{model_name}" );
    $main::log->Log( "hamlib", "info",
        "Manufacturer:\t\t$rig->{caps}->{mfg_name}" );
    $main::log->Log( "hamlib", "info",
        "Backend version:\t$rig->{caps}->{version}" );

    if ( defined $riginfo ) {
        $riginfo =~ s/\n$//;
        $main::log->Log( "hamlib", "info", "Connected Rig:\t$riginfo" );
    }

    my $poll_interval = $$cfg->{'poll_interval'};

    # Start a timer for it
    our $rig_timer =
      Glib::Timeout->add( $poll_interval, \&exec_read_rig );

    my $self = {
        # variables
        rig           => $rig,
        gui_applying_changes => \$gui_applying_changes,
        rigctld_applying_changes => \$rigctld_applying_changes,
        timer         => $rig_timer,
        update_needed => \$update_needed,
        vfos => \$vfos,
        volume => \$volume,
        %hamlib_debug_levels => \%hamlib_debug_levels,
        @pl_tones => \@pl_tones,
        %vfo_mapping => \%vfo_mapping,
        @vfo_widths_am => \@vfo_widths_am,
        @vfo_widths_fm => \@vfo_widths_fm,
        @vfo_widths_ssb => \@vfo_widths_ssb,

        # functions
        exec_read_rig => \&exec_read_rig,
        hamlib_debug_level => \&hamlib_debug_level,
        is_busy => \&is_busy,
        is_gui_busy => \&is_gui_busy,
        next_vfo => \&next_vfo,
        ptt_off => \&ptt_off,
        ptt_on => \&ptt_on,
        read_rig => \&read_rig,
        set_freq => \&set_freq,
        vfo_from_name => \&vfo_from_name,
        vfo_name => \&vfo_name,
        write_rig => \&write_rig
    };
    bless $self, $class;

    return $self;
}

sub DESTROY {
}

1;
