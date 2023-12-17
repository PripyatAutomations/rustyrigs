# Here we deal with our memory add/edit window
package grigs_memory;
use strict;
use warnings;
use Carp;
use Glib qw(TRUE FALSE);
use Data::Dumper;

my $w_mem_edit;
my $w_mem_edit_box = Gtk3::Box->new('vertical', 5);
my $w_mem_edit_open = 0;
my $w_mem_edit_accel = Gtk3::AccelGroup->new();
my $cfg;
my $w_main;

sub show_window {
   if ($w_mem_edit_open) {
      $w_mem_edit->present();
      $w_mem_edit->grab_focus();
      return TRUE;
   }
   my $button_box = Gtk3::Box->new('vertical', 5);
   $w_mem_edit_open = 1;
   $w_mem_edit = Gtk3::Window->new('toplevel',
      decorated => TRUE,
      destroy_with_parent => TRUE,
      title => "Add/Edit Memory",
      resizable => FALSE,
      bord_width => 5,
      position => "center"
   );
   $w_mem_edit->set_transient_for($w_main);
   $w_mem_edit->set_keep_above(1);
   $w_mem_edit->set_modal(1);
   $w_mem_edit->set_resizable(0);

   # XXX: Set icon instead of using main

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

   $w_mem_edit->add_accel_group($w_mem_edit_accel);

   # add widgets into the button box at bottom
   $button_box->pack_start($save_button, FALSE, FALSE, 0);
   $button_box->pack_start($quit_button, FALSE, FALSE, 0);
   # add it to the END of the window
   $w_mem_edit_box->pack_end($button_box, FALSE, FALSE, 0);
   $w_mem_edit->add($w_mem_edit_box);

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
    if (!$w_mem_edit_open || !defined($w_mem_edit)) {
       return;
    }
    my $s_modal = $w_mem_edit->get_modal();
    $w_mem_edit->set_keep_above(0);
    $w_mem_edit->set_modal(0);

    my $dialog = Gtk3::MessageDialog->new(
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

    my $response = $dialog->run();

    if ($response eq 'yes') {
       $dialog->destroy();
       $w_mem_edit->destroy();
       $w_mem_edit_open = 0;
    } else {
       $dialog->destroy();
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
