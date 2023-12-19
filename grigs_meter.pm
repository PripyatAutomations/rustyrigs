# here we render a meter widget
package grigs_meter;
use Carp;
use Data::Dumper;
use Glib qw(TRUE FALSE);
use warnings;
use strict;

my $cfg;
my $vfos;
my $w_main;

sub new {
   ( $cfg, $vfos, $w_main ) = @_;
   my $status_box = Gtk3::Box->new('vertical', 5);
   $status_box->set_hexpand(TRUE);
   $status_box->set_halign('fill');
   my $pow_ovl = Gtk3::Overlay->new();
   my $swr_ovl = Gtk3::Overlay->new();
   my $pow_bar = Gtk3::Box->new('horizontal', 0);
   my $swr_bar = Gtk3::Box->new('horizontal', 0);
   my $pow_bar_sep = Gtk3::Separator->new('horizontal');
   my $swr_bar_sep = Gtk3::Separator->new('horizontal');
   my $pow_act_sep = Gtk3::Separator->new('horizontal');
   my $swr_act_sep = Gtk3::Separator->new('horizontal');
   my $swr_bar_label = Gtk3::Label->new('1.4:1');
   my $pow_bar_label = Gtk3::Label->new(' 30W');
   $pow_bar_sep->set_size_request(-1, 30);
   $swr_bar_sep->set_size_request(-1, 30);
   $pow_bar_sep->override_background_color('normal', woodpile::hex_to_gdk_rgba($cfg->{'ui_pow_bg'}));
   $swr_bar_sep->override_background_color('normal', woodpile::hex_to_gdk_rgba($cfg->{'ui_swr_bg'}));
   $pow_act_sep->override_background_color('normal', woodpile::hex_to_gdk_rgba($cfg->{'ui_pow_fg'}));
   $swr_act_sep->override_background_color('normal', woodpile::hex_to_gdk_rgba($cfg->{'ui_swr_fg'}));
   $pow_bar_sep->set_size_request(30, 30);
   $swr_bar_sep->set_size_request(120, 30);
   $pow_bar->pack_start($pow_bar_sep, TRUE, TRUE, 10);
   $swr_bar->pack_start($swr_bar_sep, TRUE, TRUE, 10);
   $pow_bar->pack_start($pow_bar_label, FALSE, FALSE, 0);
   $swr_bar->pack_start($swr_bar_label, FALSE, FALSE, 0);
#   $pow_ovl->add_overlay($pow_bar_sep);
#   $pow_ovl->add_overlay($pow_act_sep);
#   $pow_ovl->set_halign('start');
#   $pow_ovl->set_valign('start');
#   $pow_ovl->set_margin_start(10);
#   $pow_ovl->set_margin_top(10);

   # add the power and swr widgets to a box
   $status_box->pack_start($pow_bar, TRUE, FALSE, 0);
#   $status_box->pack_start($pow_ovl, TRUE, TRUE, 0);
   $status_box->pack_start($swr_bar, TRUE, FALSE, 0);

   my $rv = {
      box => $status_box,
      set_swr => \&set_swr,
      set_pwr => \&set_pwr
   };
}

1;
