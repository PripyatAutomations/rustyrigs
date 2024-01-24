# this will draw a GTK3 widget suitable for frequency entry
package Woodpile::GTK3FreqInput;
use Gtk3;
use Glib qw(TRUE FALSE);
use strict;
use warnings;
use Data::Dumper;

# XXX: These mustn't be a global.. but im tired of fighting this today...
my $master_digits;
my $last_value;
my $widget_box;

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

    if (!defined $last_value || $last_value != $value) {
       print "set_value: $value\n";

       if ( $val_len > $vfo_digits ) {
          die "FreqInput widget can't handle numbers longer than $vfo_digits long. Input |$val_str| is $val_len long! Either increase the size when creating widget or truncate input! Called by " . ( caller(1) )[3] . "\n";
       }

       # add leading zeros as needed
       my $leading_zeros = $vfo_digits - $val_len;
       my $pad = '0' x $leading_zeros;
       my $int_str = $pad . $val_str;

       # Update the display
       my $i = $vfo_digits;
       while ( $i > 0 ) {
           my $digits = $master_digits;
           my $digit_item = $digits->{$i};
           my $digit_entry = $digit_item->{'entry'};
           my $curr_digit = substr($int_str, 0, 1);				   # extract left most digit
           $curr_digit = 0 if ( !defined $curr_digit || $curr_digit !~ /^\d$/) ;   # if no value, set to 0
           $digit_entry->set_text( $curr_digit );                                  # set the digit
           $int_str = substr( $int_str, 1 );                                       # trim first character off
           $i--;
       }
       $last_value = $value;
    }
    return;
}

# Get a single digit: Positive for whole, negative for decimal (NYI)
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

    my $offset = ($places_i - $digit);
    my $new_freq = replace_nth_digit( $curr_freq, $offset, $newval );
    $widget->set_value( $new_freq );
    $main::rig->set_freq( $main::rig->get_vfo(), $new_freq );
    print "Setting $digit digit (offset: $offset) to $newval, resulting in new freq of $new_freq\n";

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
    print "digit: " . Dumper($digit) . ", widget: " . Dumper($widget) . "\n";
    my $mult     = (10**$digit)/10;
    my $new_val = $freq - $mult;

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

    $widget->set_value( $new_val );
    $main::rig->set_freq($main::rig->get_vfo(), $new_val);
    return;
}

sub shift_focus {
    my ($target, $direction) = @_;

    if ($direction eq 'forward') {
        $target->child_focus('tab-forward');
    } elsif ($direction eq 'backward') {
        $target->child_focus('tab-backward');
    }
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

#         print "digit[$digit]: got keyval=" . $event->keyval . "\n";

         if ($event->keyval >= 48 && $event->keyval <= 57) {	  # 0 to 9
            my $digit_pressed = chr( $event->keyval );		  # Convert keyval to the corresponding character
            my $cfg      = $main::cfg;
            my $curr_vfo = $$cfg->{'active_vfo'};
            my $vfos     = $RustyRigs::Hamlib::vfos;
            my $vfo      = $vfos->{$curr_vfo};
            my $freq     = $vfo->{'freq'};
            my $new_freq = replace_nth_digit( $freq, $digit, $digit_pressed );
            print "digit[${digit}]: $digit_pressed entered, new_freq: $new_freq\n";
#            $self->set_value( $new_freq );
            $self->set_digit( $digit, $digit_pressed, $places );
            # shift focus to the next widget
            shift_focus( $widget_box, 'forward' );
            return TRUE;
         }
         elsif ($event->keyval == 65362) {  # 65362 is the GDK keyval for UP key
            $self->inc_digit( $digit );
            $widget->grab_focus();
            return TRUE;
         }
         elsif ($event->keyval == 65364) {  # 65364 is the GDK keyval for DOWN key
            $self->dec_digit( $digit );
            $widget->grab_focus();
            return TRUE;
         }
         elsif ($event->keyval == 65361) {  # 65361 is the GDK keyval for LEFT key
            # Handle moving left between digits
            shift_focus( $widget_box, 'backward' );
            return TRUE;
         }
         elsif ($event->keyval == 65363) {  # 65363 is the GDK keyval for RIGHT key
            # Handle moving right between digits
            shift_focus( $widget_box, 'forward' );
            return TRUE;
         }
         elsif ($event->keyval == 65288) {  # 65288 is the GDK keyval for BKSPC key
            # XXX: Instead of clearing current widget, clear the last one
            shift_focus( $widget_box, 'backward' );
            return TRUE;
         }
         elsif ($event->keyval == 65289) { # TAB key
           my $top_level = $widget->get_toplevel;
           $top_level->child_focus( 'tab-forward' );
           return TRUE;
         }

         # Propagate the event
         return FALSE;
      }
   );

   $dwn_btn->signal_connect( activate => sub {
     my ( $widget ) = @_;
     if ( $main::locked ) {
        return TRUE;
     }
     $self->dec_digit( $digit );
   });
   $dwn_btn->signal_connect( clicked => sub {
     my ( $widget ) = @_;
     if ( $main::locked ) {
        return TRUE;
     }
     $self->dec_digit( $digit );
   });
   $up_btn->signal_connect( activate => sub {
     my ( $widget ) = @_;
     if ( $main::locked ) {
        return TRUE;
     }
     $self->inc_digit( $digit );
   });
   $up_btn->signal_connect( clicked => sub {
     my ( $widget ) = @_;
     if ( $main::locked ) {
        return TRUE;
     }
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

   my $outer_box = Gtk3::Box->new ( 'vertical', 0 );
   $widget_box = Gtk3::Box->new( 'horizontal', 0 );
   $outer_box->pack_start( $widget_box, TRUE, TRUE, 5 );

   my $obj = {
      box      => \$outer_box,	        # The outer box we return
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
          $widget_box->pack_start( $digitbox, FALSE, FALSE, 0 );
       }
       
       # XXX: Every 3 digits, we should slightly change the background color to group digits

       $master_digits->{$i} = $obj->{'digits'}{$i} = $new_digit;
       $i--;
   }

   my $label_box = Gtk3::Box->new( 'vertical', 0 );
   my $widget_label = Gtk3::Label->new( $label );
   $widget_label->set_hexpand( TRUE );                  # Allow horizontal expansion
   $widget_label->set_vexpand( TRUE );                  # Allow vertical expansion
   $widget_label->set_valign( 'center' );               # Vertically center the label
   $label_box->pack_start( $widget_label, TRUE, TRUE, 0 );
   $widget_box->pack_start( $label_box, TRUE, TRUE, 0 );

   return $obj;
}

sub DESTROY {
   my ( $self ) = @_;
   return;
}

1;
