# here we render a meter widget
package grigs_meter;
use Carp;
use Data::Dumper;
use Glib qw(TRUE FALSE);
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
   ( my $self, my $value ) = @_;
   die "self: " . Dump($self) . "\n";
   $self->value = $value;
   $self->val_label->set_label($value);
}

sub zero {
}

# This needs sorted out so it makes only one widget.
# The widget will need supplied the following parameters
#	- Name
#	- Height, Width
#	- Fill color
#	- Active fill color
#	- Label text

sub new {
   ( $cfg, $vfos, $w_main, my $label, my $min_val, my $max_val ) = @_;
   my $l = lc($label);
   my $s = "ui_${l}";
   my $bg = woodpile::hex_to_gdk_rgba($cfg->{"${s}_bg"});
   my $fg = woodpile::hex_to_gdk_rgba($cfg->{"${s}_fg"});
   my $txt_fg = woodpile::hex_to_gdk_rgba($cfg->{"${s}_text"});
   my $txt_font = $cfg->{"${s}_font"};
   my $value;

   if (undef($monospace_font)) {
      $monospace_font = Gtk3::Pango::FontDescription->new();;
      $monospace_font->set_family('Monospace');
   }

   my $box = Gtk3::Box->new('vertical', 0);
   my $bar = Gtk3::Box->new('horizontal', 0);
   my $bar_sep = Gtk3::Separator->new('horizontal');
   my $val_sep = Gtk3::Separator->new('horizontal');
   my $bar_label = Gtk3::Label->new($label);
   my $val_label = Gtk3::Label->new($value);
   $bar_label->set_width_chars(6);
   $val_label->set_width_chars(6);
   $bar_label->override_font($monospace_font);
   $val_label->override_font($monospace_font);
   $bar_sep->set_size_request(-1, 30);
   $bar_sep->override_background_color('normal', $bg);
   $val_sep->override_background_color('normal', $fg);
   $bar_sep->set_size_request(30, 30);
   $bar->pack_start($bar_label, FALSE, FALSE, 0);
   $bar->pack_start($bar_sep, TRUE, TRUE, 10);
   $bar->pack_start($val_sep, FALSE, FALSE, 10);
   $bar->pack_start($val_label, FALSE, FALSE, 0);
   $box->pack_start($bar, TRUE, TRUE, 0);

   $value = "1.0";
   $val_label->set_label($value);
   $bar_sep->set_size_request(10, 30);

   my $rv = {
      bar => $bar,
      bar_label => $bar_label,
      bar_sep => $bar_sep,
      box => $box,
      min => $min_val,
      max => $max_val,
      set_label => \&set_label,
      set_value => \&set_value,
      value => $value,
      val_sep => $val_sep
   };
   return $rv;
}

1;
