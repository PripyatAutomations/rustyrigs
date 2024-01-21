package Woodpile::Gtk;
use strict;
use warnings;
use Data::Dumper;

sub hex_to_gdk_rgba {
    my ($hex_color) = @_;

    # Convert hex color value to RGBA components
    if ( !defined $hex_color ) {
        die "Invalid color (from: " . ( caller(1) )[3] . ")!\n";
    }
    my ( $red, $green, $blue ) = map { hex($_) / 255 } $hex_color =~ m/[\da-f]{2}/ig;

    # Create a Gtk3::Gdk::RGBA object using the calculated RGBA components
    my $rgba_color =
      Gtk3::Gdk::RGBA->new( $red, $green, $blue, 1.0 );    # 1.0 is alpha (fully opaque)

    return $rgba_color;
}

sub gdk_rgba_to_hex {
    my ($rgba) = @_;
    
    my ($red, $green, $blue) = map { int($_ * 255 + 0.5) } ($rgba->red, $rgba->green, $rgba->blue);

    return sprintf("#%02X%02X%02X", $red, $green, $blue);
}

sub gdk_rgb_to_hex {
    my ($rgb) = @_;
    my ($red, $green, $blue) = map { sprintf("%02X", $_ / 256) } ($rgb->red, $rgb->green, $rgb->blue);
    return "#$red$green$blue";
}
1;
