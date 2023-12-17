# Here we deal with our memory add/edit window
package grigs_memory;
use strict;
use warnings;
use Carp;
use Glib qw(TRUE FALSE);
use Data::Dumper;

my $w_mem_add;
my $w_mem_add_box = Gtk3::Box->new('vertical', 5);
my $w_mem_add_open = 0;
my $w_mem_add_accel = Gtk3::AccelGroup->new();
my $cfg;
my $w_main;

sub show_window {
   my $button_box = Gtk3::Box->new('vertical', 5);

   if (!defined($w_main)) {
      $w_main = shift;
   }

   if ($w_mem_add_open) {
      $w_mem_add->show();
      return TRUE;
   }
   $w_mem_add_open = 1;
   $w_mem_add = Gtk3::Window->new('toplevel',
      decorated => TRUE,
      destroy_with_parent => TRUE,
      title => "Add/Edit Memory",
      modal => TRUE,
      resizable => FALSE,
      bord_width => 5,
      position => "center"
   );
   $w_mem_add->set_transient_for($w_main);
   $w_mem_add->set_keep_above(1);
   # XXX: Set icon from main
   # Place the window and size it
   $w_mem_add->set_default_size($cfg->{'win_mem_add_width'},
                                $cfg->{'win_mem_add_height'});
   $w_mem_add->move($cfg->{'win_mem_add_x'}, $cfg->{'win_mem_add_y'});

   my $save_button = Gtk3::Button->new_with_mnemonic('_Save Memory');
   $save_button->signal_connect(clicked => sub { save_memory(); });
   $save_button->set_tooltip_text("Save memory");
   my $quit_button = Gtk3::Button->new_with_mnemonic('_Quit');
   $quit_button->signal_connect(clicked => \&close_window);
   $quit_button->set_tooltip_text("Close the memory editor");

   $w_mem_add->add_accel_group($w_mem_add_accel);

   # Add widgets and insert the box in the window
   $button_box->pack_start($save_button, FALSE, FALSE, 0);
   $button_box->pack_start($quit_button, FALSE, FALSE, 0);
   $w_mem_add_box->pack_end($button_box, FALSE, FALSE, 0);
   $w_mem_add->add($w_mem_add_box);

   # Handle moves and resizes
   $w_mem_add->signal_connect('configure-event' => sub {
      my ($widget, $event) = @_;
      my ($width, $height) = $widget->get_size();
      my ($x, $y) = $widget->get_position();
      $cfg->{'win_mem_add_x'} = $x;
      $cfg->{'win_mem_add_y'} = $y;
      $cfg->{'win_mem_add_height'} = $height;
      $cfg->{'win_mem_add_width'} = $width;
      return FALSE;
   });
   # Handle close button
   $w_mem_add->signal_connect('delete-event' => sub {
      close_window();
      return TRUE;
   });

   $w_mem_add->show_all();
}

sub close_window {
    my $s_modal = $w_mem_add->get_modal();
    $w_mem_add->set_keep_above(0);
    $w_mem_add->set_modal(0);

    my $dialog = Gtk3::MessageDialog->new(
        $w_mem_add,
        'destroy-with-parent',
        'warning',
	'yes_no',
        "Close settings window? Unsaved changes will be lost."
    );
    $dialog->set_title('Confirm close memory editor?');
    $dialog->set_default_response('no');
    $dialog->set_transient_for($w_mem_add);
    $dialog->set_modal(1);
    $dialog->set_keep_above(1);
    $dialog->present();
    $dialog->grab_focus();

    my $response = $dialog->run();

    if ($response eq 'yes') {
       $dialog->destroy();
       $w_mem_add->destroy();
       $w_mem_add_open = 0;
    } else {
       $dialog->destroy();
       $w_mem_add->set_keep_above(1);
       $w_mem_add->set_modal(1);
       $w_mem_add->present();
       $w_mem_add->grab_focus();
    }
}

sub init {
  $cfg = shift;
  $w_main = shift;
}

1;
