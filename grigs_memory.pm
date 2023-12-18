# Here we deal with our memory add/edit window
package grigs_memory;
use strict;
use warnings;
use Carp;
use Glib qw(TRUE FALSE);
use Data::Dumper;

my $w_mem_edit;
my $mem_edit_box = Gtk3::Box->new('vertical', 5);
my $mem_edit_open = 0;
my $mem_edit_accel = Gtk3::AccelGroup->new();

# new() sets these up
my $cfg;
my $w_main;

sub save_memory {
   my $channel = shift;
   close_window(TRUE);
   $mem_edit_open = 0;
};

sub show_window {
   if ($mem_edit_open) {
      $w_mem_edit->present();
      $w_mem_edit->grab_focus();
      return TRUE;
   }
   my $button_box = Gtk3::Box->new('vertical', 5);
   $mem_edit_open = 1;
   $w_mem_edit = Gtk3::Window->new('toplevel',
      decorated => TRUE,
      destroy_with_parent => TRUE,
      position => "center"
   );
   $w_mem_edit->set_transient_for($w_main);
   $w_mem_edit->set_keep_above(1);
   $w_mem_edit->set_modal(1);
   $w_mem_edit->set_resizable(0);
   $w_mem_edit->set_title("Memory Editor");

   # set the icon to show it's a settings window
   main::set_settings_icon($w_mem_edit);

   # Place the window and size it
   $w_mem_edit->set_default_size($cfg->{'win_mem_edit_width'},
                                $cfg->{'win_mem_edit_height'});
   $w_mem_edit->move($cfg->{'win_mem_edit_x'}, $cfg->{'win_mem_edit_y'});

   my $save_button = Gtk3::Button->new_with_mnemonic('_Save Memory');
   $save_button->signal_connect(clicked => sub { save_memory(); });
   $save_button->set_tooltip_text("Save memory");
   my $quit_button = Gtk3::Button->new_with_mnemonic('_Quit');
   $quit_button->signal_connect(clicked => \&close_window);
   $quit_button->set_tooltip_text("Close the memory editor");

   $w_mem_edit->add_accel_group($mem_edit_accel);

   # add widgets into the button box at bottom
   $button_box->pack_start($save_button, FALSE, FALSE, 0);
   $button_box->pack_start($quit_button, FALSE, FALSE, 0);
   # add it to the END of the window
   $mem_edit_box->pack_end($button_box, FALSE, FALSE, 0);
   $w_mem_edit->add($mem_edit_box);


   #########
   # Signal handlers
   #########
   # Handle moves and resizes
   $w_mem_edit->signal_connect('configure-event' => sub {
      my ($widget, $event) = @_;
      my ($width, $height) = $widget->get_size();
      my ($x, $y) = $widget->get_position();
      $cfg->{'win_mem_edit_x'} = $x;
      $cfg->{'win_mem_edit_y'} = $y;
      $cfg->{'win_mem_edit_height'} = $height;
      $cfg->{'win_mem_edit_width'} = $width;
      return FALSE;
   });
   # Handle close button
   $w_mem_edit->signal_connect('delete-event' => sub {
      close_window();
      return TRUE;
   });

   $w_mem_edit->show_all();
}

sub close_window {
    my $quiet = shift;
    if (!$mem_edit_open || !defined($w_mem_edit)) {
       return;
    }

    my $response = 'yes';
    my $dialog;

    # skip this if quiet is passed
    if (!defined($quiet) || !$quiet) {
       my $s_modal = $w_mem_edit->get_modal();
       $w_mem_edit->set_keep_above(0);
       $w_mem_edit->set_modal(0);

       $dialog = Gtk3::MessageDialog->new(
           $w_mem_edit,
           'destroy-with-parent',
           'warning',
           'yes_no',
           "Close settings window? Unsaved changes will be lost."
       );
       $dialog->set_title('Confirm close memory editor?');
       $dialog->set_default_response('no');
       $dialog->set_transient_for($w_mem_edit);
       $dialog->set_modal(1);
       $dialog->set_keep_above(1);
       $dialog->present();
       $dialog->grab_focus();

       $response = $dialog->run();
    }

    if ($response eq 'yes') {
       if (defined($dialog)) {
          $dialog->destroy();
       }
       $w_mem_edit->destroy();
       $mem_edit_open = 0;
    } else {
       if (defined($dialog)) {
          $dialog->destroy();
       }
       $w_mem_edit->set_keep_above(1);
       $w_mem_edit->set_modal(1);
       $w_mem_edit->present();
       $w_mem_edit->grab_focus();
    }
}

sub init {
  $cfg = shift;
  $w_main = shift;
}

1;
