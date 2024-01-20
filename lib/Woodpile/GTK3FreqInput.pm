# this will draw a GTK3 widget suitable for frequency entry
package Woodpile::GTK3FreqInput;
use Gtk3;
use Glib qw(TRUE FALSE);
use strict;
use warnings;

# Draw a single digit
sub draw_digit {
   my ( $self, $scale, $default ) = @_;
   my $box = Gtk3::Box->new('vertical', 0);
   my $up_btn = Gtk3::Button->new('+');
   my $digit = Gtk3::Entry->new();
   my $dwn_btn = Gtk3::Button->new('-');
   $digit->set_max_length(1);
   $digit->set_text($default);
   $digit->set_alignment(0.5); 
   $digit->signal_connect(
      changed => sub {
         my ( $self ) = @_;
         my $entry = shift;
         my $text = $entry->get_text;

         # Remove non-numeric characters
         $text =~ s/\D//g;
         $self->set_text($text);
      }
   );
   $box->pack_start( $up_btn, FALSE, FALSE, 0 );
   $box->pack_start( $digit, FALSE, FALSE, 0 );
   $box->pack_start( $dwn_btn, FALSE, FALSE, 0 );

   my $obj = {
      box => $box,
      entry => $digit
   };
   return $obj;
}

sub set_value {
    my ($self, $value) = @_;

    # Split the value into integer and decimal parts
    my ($integer_part, $decimal_part) = split /\./, $value, 2;

    # Update the integer part
#    my $i = $self->{'places'};
#    while ($i > 0) {
#        my $digits = $self->{'digits'};
#        my $digit = $digits->{$i};
#        my $digit_entry = $digit->{'entry'};
#        my $d = chop $integer_part;
#
#        # Set to 0 if not a digit..
#        $d = 0 if (!defined $d || $d !~ /^\d$/);
#        $digit_entry->set_text($d);
#        $i--;
#    }

    my $integer_digit = $self->{'places'};
    while ($integer_digit > 0) {
        my $digits = $self->{'digits'};
        my $digit = $digits->{$integer_digit};
        my $digit_entry = $digit->{'entry'};
#        my $digit_entry = $self->{'digits'}{$integer_digit}->get_children->[1]; # The Entry widget
        my $digit = substr($integer_part, -1, 1); # Get the last character
        $digit = 0 if (!defined $digit || $digit !~ /^\d$/); # Set to 0 if not a digit
        $digit_entry->set_text($digit);
        $integer_part = substr($integer_part, 0, -1); # Remove the last character
        $integer_digit--;
    }
    # Update the decimal part if applicable
#    if (defined $decimal_part && $self->{'decimals'} > 0) {
#        my $decimal_digit = -$self->{'decimals'};
#        my $dot_index = $self->{'places'} + 1;
#        # The Label widget for the dot
#        my $dot_entry = $self->{'box'}->get_children->[$dot_index]; 
#        while ($decimal_digit > 0) {
#            my $digit_entry = $self->{'digits'}{$decimal_digit}->get_children->[1]; # The Entry widget
#            my $digit = chop $decimal_part;
#            $digit = 0 if (!defined $digit || $digit !~ /^\d$/); # Set to 0 if not a digit
#            $digit_entry->set_text($digit);
#            $decimal_digit--;
#        }
#    }
}

sub DESTROY {
   my ( $self ) = @_;
}

sub new {
   my ( $class, $places, $decimals, $default ) = @_;

   # set some defaults
   if (!defined $decimals) {
      $decimals = 0;
   }

   if (!defined $places) {
      $places = 4;
   }

   # We work left to right here, adding each digit...
   my $box = Gtk3::Box->new('horizontal', 0);
   
   my $obj = {
      # Our GTK3 box
      box => \$box,
      # decimal places to keep
      decimals => $decimals,
      # whole places to keep
      places   => $places,
      # store the digits to display
      digits   => { }
   };

   # Place one digit widget per desired place
   my $digit = $places;
   while ($digit > 0) {
       my $new_digit = $class->draw_digit($digit, 0);
       my $digitbox = $new_digit->{'box'};
       if (defined $digitbox) {
          $box->pack_start($digitbox, FALSE, FALSE, 0);
       }
       
       # XXX: Can we add a digit seperator such as ','?
       $obj->{'digits'}{$digit} = $new_digit;
       $digit--;
   }

   # Add decimal digits, if desired
   if ($decimals > 0) {
      # Place a DOT between the digits
      my $dot = Gtk3::Label->new(".");
      $box->pack_start($dot, FALSE, FALSE, 0);
      my $limit = -$decimals;
      while ( $digit > $limit ) {
         my $new_digit = $class->draw_digit($digit, 0);
         my $digitbox = $new_digit->{'box'};
         $box->pack_start($digitbox, FALSE, FALSE, 0);
         $obj->{'digits'}{$digit} = $new_digit;
         $digit--;
      }
   }

   # If a default value exists, set it on the widget
   if (defined $default) {
      $class->set_value($default);
   }

   bless $obj, $class if (defined $obj);
   return $obj;
}

1;
