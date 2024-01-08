package rustyrigs_set_colors;
use Carp;
use Data::Dumper;
use strict;
use Glib qw(TRUE FALSE);
use warnings;

my $window;

sub cancel {
   my ( $self ) = @_;
   $window->destroy();
}

sub save {
   my ( $self ) = @_;
   $window->destroy();
}

sub DESTROY {
   my ( $self ) = @_;
}

sub new {
   my ( $class, $w_set_ref ) = @_;

   my $cfg = $main::cfg;

   # settings window
   my $w_set = ${$w_set_ref};
   my $box;

   # get the main window
   my $gtk_ui = $main::gtk_ui;
   my $w_main = $gtk_ui->{'w_main'};

   $window = Gtk3::Window->new(
      'toplevel',
      decorated => TRUE,
      destroy_with_parent => TRUE,
      position => 'center_on_parent'
   );
   $window->set_transient_for($w_set);
   $window->set_title("Colour settings");
   $window->set_border_width(5);
   $window->set_keep_above(1);
   $window->set_default_size(300, 200);
   $window->set_modal(1);
   $window->set_resizable(0);

   my $icon = ${$gtk_ui->{'icon_settings_pix'}};
   $window->set_icon($icon);

   my $accel = Gtk3::AccelGroup->new();
   $window->add_accel_group($accel);
   $box = Gtk3::Box->new('vertical', 5);

   my $button_box = Gtk3::Box->new('horizontal', 5);
   my $save_button = Gtk3::Button->new("_Save");
   $save_button->set_tooltip_text("Save settings");
   $save_button->set_can_focus(1);
   $save_button->signal_connect( 'clicked'  => sub { (my $self) = @_; save($self); } );
   $accel->connect(ord('S'), $$cfg->{'shortcut_key'}, 'visible', sub { my ( $self ) = @_; save($self); });
   $button_box->pack_start($save_button, TRUE, TRUE, 0);

   my $cancel_button = Gtk3::Button->new("_Cancel");
   $cancel_button->set_tooltip_text("Cancel");
   $cancel_button->set_can_focus(1);
   $cancel_button->signal_connect( 'clicked'  => sub { (my $self) = @_; cancel($self); } );
   $accel->connect(ord('C'), $$cfg->{'shortcut_key'}, 'visible', sub { my ( $self ) = @_; cancel($self); });
   $button_box->pack_start($cancel_button, TRUE, TRUE, 0);
   $box->pack_end($button_box, FALSE, FALSE, 0);

   $window->add($box);
   $window->show_all();

   my $self = {
      # functions
      # variables
      accel => \$accel,
      box => \$box,
      window => \$window
   };

   bless $self, $class;
   return $self;
}

1;
