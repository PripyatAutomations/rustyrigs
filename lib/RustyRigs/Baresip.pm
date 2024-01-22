# This wraps up the baresip UA and allows us to control it enough to keep a call going
package RustyRigs::Baresip;
use strict;
use warnings;
use Expect;
use File::Path qw(make_path remove_tree);
use RustyRigs::Baresip::Settings;

sub settings {
    my ( $self ) = @_;
    my $win = RustyRigs::Baresip::Settings->new();
    return $win;
}

sub genconf {
    my ( $self, $ua_dir ) = @_;

    # Remove stale baresip ua configuration
    remove_tree($ua_dir);

    # Create the directory
    mkdir($ua_dir) or $!{EEXIST} or warn("can't create baresip ua_dir $ua_dir");;

    # Setup some shortcuts
    my $account_file = "$ua_dir/accounts";
    my $config_file = "$ua_dir/config";

    # Get config from main
    my $cfg        = $main::cfg;
    my $au_indev   = $$cfg->{'sip_au_indev'};
    my $au_outdev  = $$cfg->{'sip_au_outdev'};
    my $sip_host   = $$cfg->{'sip_host'};
    my $sip_user   = $$cfg->{'sip_user'};
    my $sip_pass   = $$cfg->{'sip_pass'};
    my $sip_laddr  = $$cfg->{'sip_laddr'};
    my $sip_lport  = $$cfg->{'sip_lport'};
    my $sip_ctrl_port = $$cfg->{'sip_ctrl_port'};

    # Create teh accounts file
    open (my $account_fh, '>', $account_file) or die("Can't open $account_file for writing");
    my $ua_str = '<sip:' . $sip_user . '@' . $sip_host . ';transport=udp>;outbound="sip:' . $sip_host . ';transport=udp";auth_pass=' . $sip_pass . ';answermode=early' . "\n";
    print $account_fh "# This file is auto-generated! Your changes will be clobbered by rustyrigs!\n";
    print $account_fh "# Edit " . $main::cfg_file . " instead!\n";
    print $account_fh $ua_str;
    close $account_fh;

    # create the main config file
    open (my $config_fh, '>', $config_file) or die("Can't open $config_file for writing");
    print $config_fh "# This file is auto-generated! Your changes will be clobbered by rustyrigs!\n";
    print $config_fh "# Edit " . $main::cfg_file . " instead!\n";
    print $config_fh <<EOF;
poll_method             epoll           # poll, select, epoll ..
#sip_listen              $sip_laddr:$sip_lport
call_local_timeout      20
call_max_calls          1
audio_buffer            200             # ms
audio_player            $au_outdev
audio_source            $au_indev
ausrc_srate             48000
auplay_srate            48000
ausrc_channels          1
auplay_channels         1
#audio_txmode           poll            # poll, thread
audio_level             no
ausrc_format            s16             # s16, float, ..
auplay_format           s16             # s16, float, ..
auenc_format            s16             # s16, float, ..
audec_format            s16             # s16, float, ..
rtp_tos                 184
#rtp_ports              10000-20000
#rtp_bandwidth          512-1024 # [kbit/s]
rtcp_mux                no
jitter_buffer_delay     5-10            # frames
rtp_stats               no
#rtp_timeout            60
dns_server 1.1.1.1:53
net_interface 127.0.0.1

module_path             /usr/lib/baresip/modules
module                  stdio.so
module                  cons.so
module                  evdev.so
module                  httpd.so
module                  telnet.so
module                  opus.so
#module                 amr.so
#module                 g7221.so
module                  g722.so
#module                 g726.so
#module                 g711.so
#module                 gsm.so
#module                 l16.so
#module                 vumeter.so
#module                 sndfile.so
#module                 speex_pp.so
#module                 plc.so
#module                 webrtc_aec.so
module                  alsa.so
module_tmp              uuid.so
module_tmp              account.so

module_app              auloop.so
module_app              contact.so
module_app              debug_cmd.so
module_app              menu.so
module_app              syslog.so

#cons_listen             127.0.0.1:\$sip_cons_port # cons - Console UI UDP/TCP sockets
#http_listen             127.0.0.1:\$sip_http_port # httpd - HTTP Server
ctrl_tcp_listen         127.0.0.1:$sip_ctrl_port  # ctrl_tcp - TCP interface JSON
evdev_device            /dev/input/event0
opus_bitrate            28000 # 6000-510000
opus_stereo             no
opus_sprop_stereo       no
opus_inbandfec          no
#opus_complexity        10
opus_application        audio   # {voip,audio}
#opus_samplerate        48000
#opus_packet_loss       10      # 0-100 percent (expected packet loss)
#jack_connect_ports     yes
config
contacts
current_contact
uuid
EOF
    close($config_fh);
    return;
}

sub new {
    my ( $class ) = @_;

    # Generate configuration
#    my $expect_log;
    my $baresip_cmd = "baresip";
    my $ua_dir = "tmp/baresip-ua/";
    my $expect_log = "$ua_dir/expect.log";
    my @params = ( "-f", $ua_dir );
    my $baresip_conf = $class->genconf($ua_dir);
    # create an Expect object by spawning another process
    my $exp = Expect->spawn($baresip_cmd, @params) or die "Cannot spawn $baresip_cmd: $!\n";

    # set up logging, if desired
    if (defined $expect_log) {
       $exp->log_file($expect_log);
    }
    # For now, we want some debugging...
    $exp->debug(1);

    # XXX: Add glib timer to poll the baresip client
    my $obj = {
       # stuff and things
       baresip_conf => \$baresip_conf,
       expect => \$exp
    };

    bless $obj, $class if (defined $obj);
    return $obj;
}

1;
