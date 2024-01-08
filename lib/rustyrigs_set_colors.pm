package rustyrigs_set_colors;
use Carp;
use Data::Dumper;
use strict;
use Glib qw(TRUE FALSE);
use warnings;

my $window;

sub DESTROY {
   my ( $self ) = @_;
}

sub new {
   my ( $class, $w_set_ref ) = @_;
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
   $box = Gtk3::Box->new('vertical', 5);
   $window->add($box);

   # Add the widgets here...

   $window->show_all();

   my $self = {
      # functions
      # variables
      window => \$window
   };

   bless $self, $class;
   return $self;
}

1;
