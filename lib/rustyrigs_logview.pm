# Here we provide a window to display log messages
package rustyrigs_logview;
use Carp;
use Data::Dumper;
use strict;
use Glib qw(TRUE FALSE);
use warnings;

our $cfg;
our $window;		# our viewer window
our $box;
our $hidden;		# is the window hidden?
our $text_view;

my @log_buffer;

sub write {
    ( my $self, my $message ) = @_;
    my $buffer = $text_view->get_buffer();
#    die "tv: " . Dumper($self) . "\n";
    push @log_buffer, "$message";

    # Get rid of a line, if too long
    if (@log_buffer > 100) {
        shift @log_buffer; 
    }
    
    # Update the text area with the log buffer content
    $buffer->set_text(join("", @log_buffer));
    
    # Scroll the TextView to the bottom after updating the content
    my $end_iter = $buffer->get_end_iter();
    my $mark = $buffer->create_mark("end_mark", $end_iter, FALSE);
    $text_view->scroll_mark_onscreen($mark);
}

# This needs adapted to our use
#sub autosize_height {
#    my ($window) = @_;

#    # Get preferred height for the current width
#    my ( $min_height, $nat_height ) =
#      $box->get_preferred_height_for_width( $cfg->{'win_x'} );

    # Set window height based on the preferred height of visible boxes
#    $window->resize( $window->get_allocated_width(), $min_height );
#}

sub window_state {
    my ( $widget, $event ) = @_;
    my $on_top  = 0;
    my $focused = 0;

    if ( $event->new_window_state =~ m/\biconified\b/ ) {
        # Prevent the window from being iconified
        $widget->deiconify();

#        # and minimize it to the system tray icon
#        $widget->hide();
        return TRUE;
    }

    if ( $event->new_window_state =~ m/\babove\b/ ) {
        $on_top = 1;
    }

    if ( $event->new_window_state =~ m/\bfocused\b/ ) {
        $focused = 1;
    }

    # the window shouldn't ever be maximized...
    if ( $event->new_window_state =~ m/\bmaximized\b/ ) {
        $widget->unmaximize();
    }

    if ( defined( $event->new_window_state ) ) {
#        print "ui debug - WSE: "
#              . $widget->get_title()
#              . " // "
#              . $event->new_window_state
#              . " (ontop: $on_top, focused: $focused)\n";
    }
    return FALSE;
}

sub DESTROY {
   ( my $self ) = @_;
}

sub new {
   ( my $class, my $cfg_ref ) = @_;
   $cfg = ${$cfg_ref};

   my $lvp = $cfg->{'win_logview_placement'};

   if (!defined $lvp) {
      $lvp = 'none';
   }

   $window = Gtk3::Window->new(
      'toplevel',
      decorated => TRUE,
      destroy_with_parent => TRUE,
      position  => $lvp
   );

   my $keep_above = $cfg->{'always_on_top_logview'};
   # this makes the stacking order reasonable
   $window->set_transient_for($main::w_main);
   $window->set_title("Log Viewer");
   $window->set_border_width(5);
   $window->set_keep_above($keep_above);
   $window->set_modal(0);
   $window->set_resizable(1);

   # Set width/height of teh window
   $window->set_default_size( $cfg->{'win_logview_width'},
       $cfg->{'win_logview_height'} );

   # If placement type is none, we should manually place the window at x,y
   if ($lvp =~ m/none/) {
      # Place the window
      $window->move( $cfg->{'win_logview_x'}, $cfg->{'win_logview_y'} );
   }

   # Keyboard accelerators
   my $accel = Gtk3::AccelGroup->new();
   $window->add_accel_group($accel);

   $window->signal_connect(
       'configure-event' => sub {
           my ( $widget, $event ) = @_;

           # Retrieve the size and position information
           my ( $width, $height ) = $widget->get_size();
           my ( $x,     $y )      = $widget->get_position();

           # Save the data...
           $cfg->{'win_logview_x'}      = $x;
           $cfg->{'win_logview_y'}      = $y;
           $cfg->{'win_logview_height'} = $height;
           $cfg->{'win_logview_width'}  = $width;

           # Return FALSE to allow the event to propagate
           return FALSE;
       }
   );

   $window->signal_connect(
       delete_event => sub {
           ( my $class ) = @_;
           $class->close();
           return TRUE;    # Suppress default window destruction
       }
   );

   $window->signal_connect( window_state_event   => \&window_state );
   $window->signal_connect(
       'configure-event' => sub {
           my ( $widget, $event ) = @_;

           # Retrieve the size and position information
           my ( $width, $height ) = $widget->get_size();
           my ( $x,     $y )      = $widget->get_position();

           # Save the data...
           $cfg->{'win_logview_x'}      = $x;
           $cfg->{'win_logview_y'}      = $y;
           $cfg->{'win_logview_height'} = $height;
           $cfg->{'win_logview_width'}  = $width;

           # Return FALSE to allow the event to propagate
           return FALSE;
       }
   );

   $box = Gtk3::Box->new('vertical', 5);
 
   my $scrolled_window = Gtk3::ScrolledWindow->new();
   $scrolled_window->set_policy('automatic', 'automatic');
   $box->add($scrolled_window);

   $text_view = Gtk3::TextView->new();
   $text_view->set_editable(0);
   $text_view->set_hexpand(1);
   $text_view->set_vexpand(1);
   $text_view->set_wrap_mode('word');
   $scrolled_window->add($text_view);
 
   $window->add($box);
   $window->show_all();

   if ($cfg->{'always_on_logview'}) {
      $window->iconify();
   }

   my $self = {
      # functions
      write => \&write,
      # variables
      accel => \$accel,
      box => \$box,
      hidden => \$hidden,
      text_view => \$text_view,
      window => \$window
   };
   bless $self, $class;
   return $self;
}
1;
