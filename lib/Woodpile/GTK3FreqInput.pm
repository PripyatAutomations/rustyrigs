# this will draw a GTK3 widget suitable for frequency entry
package Woodpile::GTK3FreqInput;
use Gtk3;
use Glib qw(TRUE FALSE);
use strict;
use warnings;
use Data::Dumper;

# Set the value to display
sub set_value {
    my ($self, $value) = @_;

    # Split the value into integer and decimal parts
    my ($integer_part, $decimal_part) = split /\./, $value, 2;

    # Check for overflow...
    my $limit = $self->{'places'};
    my $i_len = length($integer_part);
    if ($i_len > $limit) {
       die "FreqInput widget can't handle numbers longer than $limit long. Input |$integer_part| is $i_len long! Either increase the size when creating widget or truncate input! Called by " . ( caller(1) )[3] . "\n";
    }

    # Calculate the number of leading zeros needed
    my $leading_zeros = $limit - $i_len;
    $integer_part = '0' x $leading_zeros . $integer_part;

    # Deal with the whole part
    while ($limit > 0) {
        my $digits = $self->{'digits'};
        my $digit_item = $digits->{$limit};
        my $digit_entry = $digit_item->{'entry'};
        my $digit = substr($integer_part, 0, 1);
        $digit = 0 if (!defined $digit || $digit !~ /^\d$/);
        $digit_entry->set_text($digit);
        $integer_part = substr($integer_part, 1);
        $limit--;
    }

    # Update the decimal part if applicable
    if (defined $decimal_part && $self->{'decimals'} > 0) {
        $limit = -$self->{'decimals'};
        while ($limit > 0) {
            my $digits = $self->{'digits'};
            my $digit_item = $digits->{$limit};
            my $digit_entry = $digit_item->{'entry'};
            my $digit = chop $decimal_part;
            $digit = 0 if (!defined $digit || $digit !~ /^\d$/);
            $digit_entry->set_text($digit);
            $limit--;
        }
    } elsif ($self->{'decimals'} > 0) {
        # XXX: Zero them all out
    }
    return;
}

# Get a single digit: Positive for whole, negative for decimal
sub get_digit {
    my ( $self, $scale ) = @_;
    if (!defined $scale) {
       return;
    }

    my $digits = $self->{'digits'};
#    print "get_digit: scale=$scale: " . Dumper($digits) . "\n";
    return;
}

# Set a single digit: Positive for whole, negative for decimal
sub set_digit {
    return;
}

sub dec_digit {
    my ( $widget, $scale ) = @_;
    my $cfg      = $main::cfg;
    my $curr_vfo = $$cfg->{'active_vfo'};
    my $vfos     = $RustyRigs::Hamlib::vfos;
    my $vfo      = $vfos->{$curr_vfo};
    my $freq     = $vfo->{'freq'};
    my $mult     = (10**$scale)/10;
#    my $new_val  = $widget->get_digit($scale) - $mult;
    my $new_val = $freq - $mult;
#    print "dec: scale=$scale, mult=$mult, newval=$new_val, widget=" . Dumper($widget) . "\n";
    $main::rig->set_freq($main::rig->get_vfo(), $new_val);
    return;
}

sub inc_digit {
    my ( $widget, $scale ) = @_;
    my $cfg      = $main::cfg;
    my $curr_vfo = $$cfg->{'active_vfo'};
    my $vfos     = $RustyRigs::Hamlib::vfos;
    my $vfo      = $vfos->{$curr_vfo};
    my $freq     = $vfo->{'freq'};
    my $mult     = (10**$scale)/10;
#    my $new_val  = $widget->get_digit($scale) + $mult;
    my $new_val = $freq + $mult;
#    print "inc: scale=$scale, mult=$mult, newval=$new_val, widget=" . Dumper($widget) . "\n";
    $main::rig->set_freq($main::rig->get_vfo(), $new_val);
    return;
}

# Draw a single digit
sub draw_digit {
   my ( $self, $scale, $default ) = @_;
#   print "scale: $scale, default: $default, self: " . Dumper($self);
   my $box = Gtk3::Box->new('vertical', 0);
   my $up_btn = Gtk3::Button->new('+');
   my $digit = Gtk3::Entry->new();
   my $dwn_btn = Gtk3::Button->new('-');
   $digit->set_max_length(1);
   $digit->set_text($default);
   $digit->set_alignment(0.5); 

   # Filter to only numeric values
   $digit->signal_connect(
      # XXX: Divine how to figure out which digit we are and modify the freq appropriately
      changed => sub {
         my ( $widget ) = @_;
         my $text = $widget->get_text;

         if ($main::locked) {
            return TRUE;
         }
         # Remove non-numeric characters
         $text =~ s/\D//g;
         $widget->set_text($text);
      }
   );

   # Handle DOWN button clicks
   $dwn_btn->signal_connect(
       activate => sub {
           my ( $widget ) = @_;
           if ($main::locked) {
              return TRUE;
           }
#           print "activate down\n";
           $self->dec_digit($scale);
       }
   );

   $dwn_btn->signal_connect(
       clicked => sub {
           my ( $widget ) = @_;
           if ($main::locked) {
              return TRUE;
           }
#           print "clicked down\n";
           $self->dec_digit($scale);
       }
   );

   # Handle UP button clicks
   $up_btn->signal_connect(
       activate => sub {
           my ( $widget ) = @_;
           if ($main::locked) {
              return TRUE;
           }
#           print "activate up\n";
           $self->inc_digit($scale);
       }
   );
   $up_btn->signal_connect(
       clicked => sub {
           my ( $widget ) = @_;
           if ($main::locked) {
              return TRUE;
           }
#           print "clicked up\n";
           $self->inc_digit($scale);
       }
   );

   $box->pack_start( $up_btn, FALSE, FALSE, 0 );
   $box->pack_start( $digit, FALSE, FALSE, 0 );
   $box->pack_start( $dwn_btn, FALSE, FALSE, 0 );

   my $obj = {
      box => $box,
      entry => $digit,
      scale => $scale
   };
   return $obj;
}

#sub set_sensitive {
#   my ( $widget, $val) = @_;
#   print "freq input: set_sensitive($val)\n";
#}

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
       # Pass scale and a default value of 0 to draw_digit
       my $new_digit = $class->draw_digit($digit, 0);
       my $digitbox = $new_digit->{'box'};
       if (defined $digitbox) {
          $box->pack_start($digitbox, FALSE, FALSE, 0);
       }
       
       # XXX: Decide if we need to place a comma here?
#       if ($digit % 3) {
#       }

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

sub DESTROY {
   my ( $self ) = @_;
   return;
}

1;
