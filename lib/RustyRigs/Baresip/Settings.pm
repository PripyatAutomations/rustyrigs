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

   my $button_box = Gtk3::Box->new( 'horizontal', 5 );
   # Create an OK button to apply settings
   my $save_button = Gtk3::Button->new('_Save');
   $save_button->set_tooltip_text("Save and apply changes");
   $save_button->set_can_focus(1);
   $win_accel->connect(
       ord('S'),  $$cfg->{'shortcut_key'},
       'visible', sub { $class->save($tmp_cfg); }
   );

   # Create a Cancel button to discard changes
   my $cancel_button = Gtk3::Button->new('_Cancel');
   $cancel_button->set_tooltip_text("Discard changes");
   $save_button->signal_connect( 'activate' => sub { $class->save($tmp_cfg); } );
   $save_button->signal_connect( 'clicked'  => sub { $class->save($tmp_cfg); } );
   $cancel_button->signal_connect( 'activate' => \&close_dialog );
   $cancel_button->signal_connect( 'clicked'  => \&close_dialog );
   $cancel_button->set_can_focus(1);
   $win_accel->connect( ord('C'), 'mod1-mask', 'visible', \&close_dialog );
   $button_box->pack_start( $save_button,   TRUE, TRUE, 0 );
   $button_box->pack_start( $cancel_button, TRUE, TRUE, 0 );

   my $restart_note_label = Gtk3::Label->new('* Will restart on save');

   $config_box->pack_start( $button_box, FALSE, FALSE, 0 );
   $config_box->pack_start( $restart_note_label, FALSE, FALSE, 0);

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
