# Woodpile.pm contains an assortment of junk i commonly use
package Woodpile;
use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Gtk3 '-init';
use Woodpile::Config;
use Woodpile::Log;
use Woodpile::Gtk;

sub find_offset {
    # Wut?
    my $array_ref = shift;
    my @a         = @$array_ref;
    my $val       = shift;
    my $index     = -1;

    if ( !defined($val) ) {
        return -1;
    }

    for my $i ( 0 .. $#a ) {
        if ( looks_like_number( $a[$i] ) && looks_like_number($val) ) {

            # Compare as numbers if both values are numeric
            if ( $a[$i] == $val ) {
                $index = $i;
                last;
            }
        }
        else {
            # Compare as strings if either value is non-numeric
            if ( "$a[$i]" eq "$val" ) {
                $index = $i;
                last;
            }
        }
    }
    return $index;
}

# Function to resize window height based on visible boxes
# Call this when widgets in a window are hidden or shown, to calculate needed dimensions
sub autosize_height {
    my ( $window, $box ) = @_;
    my ( $width, $height ) = $window->get_size();

    # Get preferred height for the current width
    my ( $min_height, $nat_height ) =
       $box->get_preferred_height_for_width($width);

    # Set window height based on the preferred height of visible boxes
    $window->resize( $window->get_allocated_width(), $min_height );
    return;
}

1;
