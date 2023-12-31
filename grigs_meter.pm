# here we render a meter widget
package grigs_meter;
use Carp;
use Data::Dumper;
use Glib qw(TRUE FALSE);
use Data::Structure::Util qw/unbless/;
use warnings;
use strict;

my $monospace_font;

my $cfg;
my $vfos;
my $w_main;

# XXX: Make methods for these
#	- SetValue
#	- Zero
sub set_label {
}

sub set_value {
   ( my $class, my $value ) = @_;
   $class->{value} = $value;
   $class->{val_label}->set_label($value);
}

sub zero {
}

sub on_drag_begin {
    my ($widget, $context) = @_;
    
    # Create a new window to hold the dragged widget
    my $new_window = Gtk3::Window->new('toplevel');
    $new_window->set_default_size(200, 200);

    # Remove the widget from its original parent (main window)
    $widget->reparent($new_window);
    
    # Show the new window
    $new_window->show_all();
}

sub on_drag_end {
    my ($widget, $context) = @_;
    
    # Get the main window
    my $main_window = $widget->get_toplevel;

    # Reparent the widget back to the main window
    $widget->reparent($w_main);
}

# This needs sorted out so it makes only one widget.
# The widget will need supplied the following parameters
#	- Name
#	- Height, Width
#	- Fill color
#	- Active fill color
#	- Label text

sub set_threshold {
   ( my $class, my $min, my $max ) = @_;

   if (!defined $class || !defined $min || !defined $max) {
      die "Improper call to set_threshold - please pass TWO options: min, max! Got ($min, $max)\n";
   }

   $class->{"threshold_min"} = $min;
   $class->{"threshold_max"} = $max;
}

sub new {
   ( my $class, $cfg, $vfos, $w_main, my $label, my $min_val, my $max_val ) = @_;
   my $l = lc($label);
   my $s = "ui_${l}";
   my $bg = woodpile::hex_to_gdk_rgba($cfg->{"${s}_bg"});
   my $alt_bg = woodpile::hex_to_gdk_rgba($cfg->{"${s}_alt_bg"});
   my $fg = woodpile::hex_to_gdk_rgba($cfg->{"${s}_fg"});
   my $txt_fg = woodpile::hex_to_gdk_rgba($cfg->{"${s}_text"});
   my $txt_font = $cfg->{"${s}_font"};
   my $value;

   if (undef($monospace_font)) {
      $monospace_font = Gtk3::Pango::FontDescription->new();;
      $monospace_font->set_family('Monospace');
   }

   my $grid = Gtk3::Grid->new();
   $grid->set_column_homogeneous(FALSE);
   $grid->set_row_homogeneous(FALSE);
   
   my $bar_label = Gtk3::Label->new($label);
   my $val_label = Gtk3::Label->new($value);
   $bar_label->set_width_chars(6);
   $val_label->set_width_chars(6);
   $bar_label->override_font($monospace_font);
   $val_label->override_font($monospace_font);

   my $bar_sep = Gtk3::Separator->new('horizontal');
   my $val_sep = Gtk3::Separator->new('horizontal');
   $bar_sep->set_size_request(30, 30);
   $val_sep->set_size_request(30, 30);
   $bar_sep->override_background_color('normal', $bg);
   $val_sep->override_background_color('normal', $fg);

   my $bar = Gtk3::Box->new('horizontal', 0);
   $bar_sep = Gtk3::Separator->new('horizontal');
   $val_sep = Gtk3::Separator->new('horizontal');
   $bar_label = Gtk3::Label->new($label);
   $val_label = Gtk3::Label->new($value);
   $bar_label->set_width_chars(6);
   $val_label->set_width_chars(6);
   $bar_label->override_font($monospace_font);
   $val_label->override_font($monospace_font);
   $bar_sep->set_size_request(-1, 30);
   $bar_sep->override_background_color('normal', $bg);
   $val_sep->override_background_color('normal', $fg);
   $bar_sep->set_size_request(30, 30);

   $grid->attach($bar_label, 0, 0, 1, 1);
   $grid->attach($bar_sep, 1, 0, 1, 1);
   $grid->attach($val_sep, 1, 0, 1, 1);
   $grid->attach($val_label, 2, 0, 1, 1);
   $grid->set_column_homogeneous(FALSE);
   $bar_sep->set_hexpand(TRUE);
   $val_sep->set_hexpand(FALSE);
   $grid->set_column_spacing(10);
 
   # XXX: We need to calculate min/max to get a percentage of fill
   # XXX: Then determine how many pixels that is and set width appropriately
   # XXX: on $act_sep
   $value = "1.0";
   $val_label->set_label($value);
   $val_sep->set_size_request(0, 30);

   my $self = {
       grid => $grid,
       bar_label => $bar_label,
       bar_sep => $bar_sep,
       min => $min_val,
       max => $max_val,
       min_threshold => -1,
       max_threshold => -1,
       set_label => \&set_label,
       set_threshold => \&set_threshold,
       set_value => \&set_value,
       value => $value,
       val_label => $val_label,
       val_sep => $val_sep,
       zero => \&zero
   };
   bless $self, $class;
   return $self;
}

sub DESTROY {
   my ( $class ) = @_;
}

1;
