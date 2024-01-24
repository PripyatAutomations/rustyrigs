# this will draw a GTK3 widget suitable for frequency entry
package Woodpile::GTK3FreqInput;
use Gtk3;
use Glib qw(TRUE FALSE);
use strict;
use warnings;
use Data::Dumper;

# Replace a single digit in a whole number
sub replace_nth_digit {
    my ( $number, $position, $new_digit ) = @_;
    my $number_str = sprintf( "%.0f", $number );
    substr( $number_str, $position - 1, 1, $new_digit );
    my $result = int( $number_str );

    return $result;
}

# get a pointer to the previous digit widget
sub prev_digit {
    my ( $self, $value ) = @_;
    return;
}

# get a pointer to the next digit widget
sub next_digit {
    my ( $self, $value ) = @_;
    return;
}

# Set the value to display
sub set_value {
    my ( $self, $value ) = @_;

    my $cfg = $main::cfg;
    my $vfo_digits = $$cfg->{'vfo_digits'};
    my $val_str = sprintf( "%.0f", $value );
    my $val_len = length( $val_str );

    if ( $val_len > $vfo_digits ) {
       die "FreqInput widget can't handle numbers longer than $vfo_digits long. Input |$val_str| is $val_len long! Either increase the size when creating widget or truncate input! Called by " . ( caller(1) )[3] . "\n";
    }

    # add leading zeros as needed
    my $leading_zeros = $vfo_digits - $val_len;
    my $pad = '0' x $leading_zeros;
    my $int_str = $pad . $val_str;

    my $i = $vfo_digits;
    while ( $i > 0 ) {
        my $digits = $self->{'digits'};
        my $digit_item = $digits->{$i};
        my $digit_entry = $digit_item->{'entry'};
        my $curr_digit = substr($int_str, 0, 1);				# extra left most digit
        $curr_digit = 0 if ( !defined $curr_digit || $curr_digit !~ /^\d$/) ;   # if no value, set to 0
        $digit_entry->set_text( $curr_digit );                                  # set the digit
        $int_str = substr( $int_str, 1 );                                       # trim first character off
        $i--;
    }
    return;
}

# Get a single digit: Positive for whole, negative for decimal
sub get_digit {
    my ( $self, $digit ) = @_;
    if ( !defined $digit ) {
       return;
    }

    my $digits = $self->{'digits'};
    return;
}

# Set a single digit:
sub set_digit {
    my ( $widget, $digit, $newval, $places ) = @_;
    my $cfg      = $main::cfg;
    my $curr_vfo = $$cfg->{'active_vfo'};
    my $vfos     = $RustyRigs::Hamlib::vfos;
    my $vfo      = $vfos->{$curr_vfo};
    my $curr_freq = $vfo->{'freq'};
    my $places_i = int($places);

    if ( $digit > 0 ) {
       my $new_freq = replace_nth_digit( $curr_freq, ($places_i - $digit), $newval );
       print "set_digit: widget = " . Dumper( $widget ) . "\n";
       $widget->set_value( $new_freq );
       $main::rig->set_freq( $main::rig->get_vfo(), $new_freq );
       print "Setting $digit digit to $newval, resulting in new freq of $new_freq\n";
    }
    return;
}

# decrement a single digit
sub dec_digit {
    my ( $widget, $digit ) = @_;
    my $cfg      = $main::cfg;
    my $curr_vfo = $$cfg->{'active_vfo'};
    my $vfos     = $RustyRigs::Hamlib::vfos;
    my $vfo      = $vfos->{$curr_vfo};
    my $freq     = $vfo->{'freq'};
    my $mult     = (10**$digit)/10;
    my $new_val = $freq - $mult;

    print "dec_digit: widget = " . Dumper( $widget ) . "\n";
    $widget->set_value( $new_val );
    $main::rig->set_freq($main::rig->get_vfo(), $new_val);
    return;
}

# increment a single digit
sub inc_digit {
    my ( $widget, $digit ) = @_;
    my $cfg      = $main::cfg;
    my $curr_vfo = $$cfg->{'active_vfo'};
    my $vfos     = $RustyRigs::Hamlib::vfos;
    my $vfo      = $vfos->{$curr_vfo};
    my $freq     = $vfo->{'freq'};
    my $mult     = (10**$digit)/10;
    my $new_val = $freq + $mult;

    print "inc_digit: widget = " . Dumper( $widget ) . "\n";
    $widget->set_value( $new_val );
    $main::rig->set_freq($main::rig->get_vfo(), $new_val);
    return;
}

# Draw a single digit widget
sub draw_digit {
   my ( $self, $digit, $places, $default ) = @_;
   my $box = Gtk3::Box->new('vertical', 0);
   my $up_btn = Gtk3::Button->new('+');
   my $dwn_btn = Gtk3::Button->new('-');
   $up_btn->set_can_focus(FALSE);
   $dwn_btn->set_can_focus(FALSE);
   my $digit_entry = Gtk3::Entry->new();
   $digit_entry->set_max_length(1);
   $digit_entry->set_text($default);
   $digit_entry->set_alignment(0.5); 

   $digit_entry->signal_connect(
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

   $digit_entry->signal_connect(
      'key-press-event' => sub {
         my ($widget, $event) = @_;

         print "my digit: $digit\n";
         print "digit[$digit]: got keyval=" . $event->keyval . "\n";

         if ($event->keyval >= 48 && $event->keyval <= 57) {	  # 0 to 9
            my $digit_pressed = chr($event->keyval);		  # Convert keyval to the corresponding character
            print "digit[${digit}]: $digit_pressed entered\n";
            $self->set_digit($digit, $digit_pressed, $places);
            return TRUE;
         }
         elsif ($event->keyval == 65362) {  # 65362 is the GDK keyval for UP key
            $self->inc_digit($self, $digit);
            $widget->grab_focus();
            return TRUE;
         }
         elsif ($event->keyval == 65364) {  # 65364 is the GDK keyval for DOWN key
            $self->dec_digit($self, $digit);
            $widget->grab_focus();
            return TRUE;
         }
         elsif ($event->keyval == 65361) {  # 65361 is the GDK keyval for LEFT key
            # Handle moving left between digits
            return TRUE;
         }
         elsif ($event->keyval == 65363) {  # 65363 is the GDK keyval for RIGHT key
            # Handle moving right between digits
            return TRUE;
         }

         # Propagate the event
         return FALSE;
      }
   );

   $dwn_btn->signal_connect( activate => sub {
     my ( $widget, $digit ) = @_;
     if ( $main::locked ) {
        return TRUE;
     }
     print "down button: widget = " . Dumper( $widget ) . "\n";
     print "self: ". Dumper($self) . "\n";
     $self->dec_digit( $digit );
   });
   $dwn_btn->signal_connect( clicked => sub {
     my ( $widget, $digit ) = @_;
     if ( $main::locked ) {
        return TRUE;
     }
     print "down button: widget = " . Dumper( $widget ) . "\n";
     print "self: ". Dumper($self) . "\n";
     $self->dec_digit( $digit );
   });
   $up_btn->signal_connect( activate => sub {
     my ( $widget, $digit ) = @_;
     if ( $main::locked ) {
        return TRUE;
     }
     print "up button: widget = " . Dumper( $widget ) . "\n";
     $self->inc_digit( $digit );
   });
   $up_btn->signal_connect( clicked => sub {
     my ( $widget, $digit ) = @_;
     if ( $main::locked ) {
        return TRUE;
     }
     print "up button: widget = " . Dumper( $widget ) . "\n";
     $self->inc_digit( $digit );
   });

   $box->pack_start( $up_btn, FALSE, FALSE, 0 );
   $box->pack_start( $digit_entry, FALSE, FALSE, 0 );
   $box->pack_start( $dwn_btn, FALSE, FALSE, 0 );

   my $obj = {
      box => $box,
      down => $dwn_btn,
      entry => $digit_entry,
      digit => $digit,
      up => $up_btn
   };
   return $obj;
}

# Create a FreqInput widget consisting of multiple digit entries and a label
sub new {
   my ( $class, $label, $places, $default ) = @_;

   $places = 9 if (!defined $places);	# set a default

   my $box = Gtk3::Box->new( 'horizontal', 0 );

   my $obj = {
      box => \$box,			# The outer box we return
      places   => $places,		# Whole # places
      digits   => { }			# Individual digits
   };
   bless $obj, $class if ( defined $obj );

   # Place one digit widget per desired place
   my $i = $places;
   while ($i > 0) {
       my $new_digit = $class->draw_digit( $i, $places, 0 );
       my $digitbox = $new_digit->{'box'};
       if (defined $digitbox) {
          $box->pack_start( $digitbox, FALSE, FALSE, 0 );
       }
       
       # XXX: Every 3 digits, we should slightly change the background color to group digits

       $obj->{'digits'}{$i} = $new_digit;
       $i--;
   }

   my $label_box = Gtk3::Box->new( 'vertical', 0 );
   my $widget_label = Gtk3::Label->new( $label );
   $widget_label->set_hexpand( TRUE );                  # Allow horizontal expansion
   $widget_label->set_vexpand( TRUE );                  # Allow vertical expansion
   $widget_label->set_valign( 'center' );               # Vertically center the label
   $label_box->pack_start( $widget_label, TRUE, TRUE, 0 );
   $box->pack_start( $label_box, TRUE, TRUE, 0 );

   return $obj;
}

sub DESTROY {
   my ( $self ) = @_;
   return;
}

1;
