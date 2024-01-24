package RustyRigs::Baresip::Settings;
use strict;
use warnings;
use Gtk3;
use Glib qw(TRUE FALSE);

my $tmp_cfg;
our $w_sip_settings;

sub DESTROY {
   my ( $self ) = @_;
   return;
}

sub save {
   my ( $self ) = @_;
   
   $w_sip_settings->destroy();
   return;
}

sub close_dialog {
   my ( $self ) = @_;
   my $dialog =
     Gtk3::MessageDialog->new( $w_sip_settings, 'destroy-with-parent', 'warning',
       'yes_no', "Close settings window? Unsaved changes will be lost." );
   $dialog->set_title('Confirm Close');
   $dialog->set_default_response('no');
   $dialog->set_transient_for($w_sip_settings);
   $dialog->set_modal(1);
   $dialog->set_keep_above(1);
   $dialog->present();
   $dialog->grab_focus();

   my $response = $dialog->run();

   if ( $response eq 'yes' ) {
       undef $tmp_cfg;
       $dialog->destroy();
       $w_sip_settings->destroy();
       bless $self, 'undef';
   }
   else {
       $dialog->destroy();
       $w_sip_settings->present();
       $w_sip_settings->grab_focus();
   }
   return;
}

sub new {
   my ( $class ) = @_;
   my $cfg = $main::cfg;
   my $gtkui = $main::gtkui;
   my $w_main = $gtkui->{'w_main'};

   my $wsp = $$cfg->{'win_baresip_settings_placement'};
   if (!defined $wsp) {
      $wsp = 'none';
   }

   my $win = Gtk3::Window->new(
        'toplevel',
        decorated           => TRUE,
        destroy_with_parent => TRUE,
        position            => $wsp
   );

   $win->set_transient_for($w_main);
   $win->set_title("VoIP Settings");
   $win->set_border_width(5);
   $win->set_keep_above(1);
   $win->set_modal(1);
   $win->set_resizable(0);
   my $icon = $main::icons->get_icon('settings');
   $win->set_icon($icon);

   my $win_accel = Gtk3::AccelGroup->new();
   $win->add_accel_group($win_accel);
   my $config_box = Gtk3::Box->new( 'vertical', 5 );

   $win->signal_connect(
       'configure-event' => sub {
           my ( $widget, $event ) = @_;

           # Retrieve the size and position information
           my ( $x,     $y )      = $widget->get_position();

           # Save the data...
           $tmp_cfg->{'win_baresip_settings_x'}      = $x;
           $tmp_cfg->{'win_baresip_settings_y'}      = $y;

           # Return FALSE to allow the event to propagate
           return FALSE;
       }
   );

   $win->signal_connect(
       delete_event => sub {
           ( my $class ) = @_;
           $class->close();
           return TRUE;    # Suppress default window destruction
       }
   );

   my $sip_label = Gtk3::Label->new( 'SIP Server' );
   my $sip_label_box = Gtk3::Box->new( 'vertical', 5 );
   my $sip_ctrl_box = Gtk3::Box->new( 'vertical', 5 );
   my $sip_host_label = Gtk3::Label->new( 'SIP Host:port' );
   my $sip_host_entry = Gtk3::Entry->new();
   $sip_label_box->pack_start( $sip_host_label, FALSE, FALSE, 0 );
   $sip_ctrl_box->pack_start( $sip_host_entry, TRUE, TRUE, 0 );

   my $sip_user_label = Gtk3::Label->new( 'SIP user' );
   my $sip_user_entry = Gtk3::Entry->new();
   $sip_label_box->pack_start( $sip_user_label, FALSE, FALSE, 0 );
   $sip_ctrl_box->pack_start( $sip_user_entry, TRUE, TRUE, 0 );

   my $sip_pass_label = Gtk3::Label->new( 'SIP password' );
   my $sip_pass_entry = Gtk3::Entry->new();
   $sip_pass_entry->set_input_purpose( 'password' );
   $sip_pass_entry->set_visibility( 0 );
   $sip_label_box->pack_start( $sip_pass_label, FALSE, FALSE, 0 );
   $sip_ctrl_box->pack_start( $sip_pass_entry, TRUE, TRUE, 0 );

   my $sip_laddr_label = Gtk3::Label->new( 'Local IP:port' );
   my $sip_laddr_entry = Gtk3::Entry->new();
   $sip_label_box->pack_start( $sip_laddr_label, FALSE, FALSE, 0 );
   $sip_ctrl_box->pack_start( $sip_laddr_entry, TRUE, TRUE, 0 );

   my $sip_dest_label = Gtk3::Label->new( 'Call destination' );
   my $sip_dest_entry = Gtk3::Entry->new();
   $sip_label_box->pack_start( $sip_dest_label, FALSE, FALSE, 0 );
   $sip_ctrl_box->pack_start( $sip_dest_entry, TRUE, TRUE, 0 );

   my $debug_label = Gtk3::Label->new("Debugging Settings");
   my $debug_box = Gtk3::Box->new( 'horizontal', 5 );
   my $debug_label_box = Gtk3::Box->new( 'vertical', 5 );
   my $debug_ctrl_box = Gtk3::Box->new( 'vertical', 5 );
   $debug_box->pack_start( $debug_label_box, TRUE, TRUE, 0 );
   $debug_box->pack_start( $debug_ctrl_box, TRUE, TRUE, 0 );
   my $sip_exp_logfile_label = Gtk3::Label->new( 'Expect logfile' );
   my $sip_exp_logfile_entry = Gtk3::Entry->new();
   $debug_label_box->pack_start( $sip_exp_logfile_label, FALSE, FALSE, 0 );
   $debug_ctrl_box->pack_start( $sip_exp_logfile_entry, TRUE, TRUE, 0 );

   my $sip_box = Gtk3::Box->new( 'horizontal', 5 );

   my $audev_label = Gtk3::Label->new( 'Audio Devices' );
   my $audev_box = Gtk3::Box->new( 'horizontal', 5 );
   my $audev_label_box = Gtk3::Box->new( 'vertical', 5 );
   my $audev_ctrl_box = Gtk3::Box->new( 'vertical', 5 );
   my $sip_volume_entry = Gtk3::CheckButton->new();
   my $sip_volume_dummy = Gtk3::Label->new();
   $sip_volume_entry->set_label( 'Use SIP volume?' );
   $audev_label_box->pack_start( $sip_volume_entry, TRUE, TRUE, 0 );
   $audev_ctrl_box->pack_start( $sip_volume_dummy, TRUE, TRUE, 0 );
   $audev_box->pack_start( $audev_label_box, TRUE, TRUE, 0 );
   $audev_box->pack_start( $audev_ctrl_box, TRUE, TRUE, 0 );
   my $audev_in_label = Gtk3::Label->new( 'input device' );
   my $audev_in_entry = Gtk3::Entry->new();
   my $audev_out_label = Gtk3::Label->new( 'output device' );
   my $audev_out_entry = Gtk3::Entry->new();
   $audev_label_box->pack_start( $audev_in_label, FALSE, FALSE, 0);
   $audev_label_box->pack_start( $audev_out_label, FALSE, FALSE, 0);
   $audev_ctrl_box->pack_start( $audev_in_entry, TRUE, TRUE, 0 );
   $audev_ctrl_box->pack_start( $audev_out_entry, TRUE, TRUE, 0 );

   my $button_box = Gtk3::Box->new( 'horizontal', 5 );
   my $save_button = Gtk3::Button->new( '_Save' );
   $save_button->set_tooltip_text( "Save and apply changes" );
   $save_button->set_can_focus( 1 );
   $win_accel->connect(
       ord('S'),  $$cfg->{'shortcut_key'},
       'visible', sub { $$cfg, $class->save($tmp_cfg); }
   );
   my $cancel_button = Gtk3::Button->new( '_Cancel' );
   $cancel_button->set_tooltip_text( "Discard changes" );
   $save_button->signal_connect( 'activate' => sub { $class->save($tmp_cfg); } );
   $save_button->signal_connect( 'clicked'  => sub { $class->save($tmp_cfg); } );
   $cancel_button->signal_connect( 'activate' => \&close_dialog );
   $cancel_button->signal_connect( 'clicked'  => \&close_dialog );
   $cancel_button->set_can_focus( 1 );
   $win_accel->connect( ord('C'), 'mod1-mask', 'visible', \&close_dialog );
   $button_box->pack_start( $save_button,   TRUE, TRUE, 0 );
   $button_box->pack_start( $cancel_button, TRUE, TRUE, 0 );
   my $restart_note_label = Gtk3::Label->new( '* Will restart on save' );

   ##########
   $sip_box->pack_start( $sip_label_box, FALSE, FALSE, 0 );
   $sip_box->pack_start( $sip_ctrl_box, FALSE, FALSE, 0 );
   $config_box->pack_start( $sip_label, TRUE, TRUE, 0 );
   $config_box->pack_start( $sip_box, TRUE, TRUE, 0 );
   $config_box->pack_start( $audev_label, TRUE, TRUE, 0 );
   $config_box->pack_start( $audev_box, TRUE, TRUE, 0 );
   $config_box->pack_start( $debug_label, TRUE, TRUE, 0 );
   $config_box->pack_start( $debug_box, TRUE, TRUE, 0 );
   $config_box->pack_start( $button_box, FALSE, FALSE, 0 );
   $config_box->pack_start( $restart_note_label, FALSE, FALSE, 0 );

   # Add the config box, show the window, and focus first input
#   $win->signal_connect( key_release_event => \&combobox_keys );
   $win->add($config_box);
   $win->show_all();

   my $obj = {
      win => $win
   };
   $w_sip_settings = $win;
   bless $obj, $class if (defined $obj);
   return $obj;
}

1;
