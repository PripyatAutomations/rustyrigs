# Here we provide a window to display log messages
# This needs some improvements --
# * Fix autoscrolling bug
# * Add save to file (is there a point? we have logfile already...)
# * Add upload to termbin button

package RustyRigs::Logview;
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
our $end_mark;

my @log_buffer;

sub write {
    ( my $self, my $message ) = @_;
    my $scrollback_lines = 300; #$$cfg->{'scrollback_lines'};
    my $buffer = $text_view->get_buffer();

    push @log_buffer, "$message";

    # get rid of existing mark
    if (defined $end_mark) {
       $buffer->delete_mark($end_mark);
       undef $end_mark;
    }

    # Get rid of a line, if too long
    if (@log_buffer > $scrollback_lines) {
        shift @log_buffer;
        print "trimming logview buffer\n";
    }
    
    # Update the text area with the log buffer content
    $buffer->set_text(join("", @log_buffer));
    
    # Scroll the TextView to the bottom after updating the content
    my $end_iter = $buffer->get_end_iter();
    $end_mark = $buffer->create_mark("end_mark", $end_iter, FALSE);
    $text_view->scroll_to_iter($end_iter, 0, FALSE, 0, 0);
    $text_view->scroll_mark_onscreen($end_mark);
}

sub window_state {
    my ( $widget, $event ) = @_;
    my $on_top  = 0;
    my $focused = 0;

    # Only allow the window to be hidden with the main window
    if ( $event->new_window_state =~ m/\bwithdrawn\b/ ) {
       my $visible = $cfg->{'win_visible'};

       if ($visible) {
          # Instead, iconify it
          $widget->unhide();
          $widget->iconify();
       }
       return FALSE;
    }

    if ( $event->new_window_state =~ m/\babove\b/ ) {
        $on_top = 1;
    }

    if ( $event->new_window_state =~ m/\bfocused\b/ ) {
        $focused = 1;
    }

    return FALSE;
}

sub DESTROY {
   ( my $self ) = @_;
}

sub new {
   ( my $class, my $cfg ) = @_;

   my $lvp = $$cfg->{'win_logview_placement'};
   my $tmp_cfg;		# hold changed configuration values until apply()'d
   my $gtk_ui = \$main::gtk_ui;

   if (!defined $lvp) {
      $lvp = 'none';
   }

   $window = Gtk3::Window->new(
      'toplevel',
      decorated => TRUE,
      destroy_with_parent => TRUE,
      position  => $lvp
   );

   my $keep_above = $$cfg->{'always_on_top_logview'};
   # this makes the stacking order reasonable
   $window->set_transient_for($main::w_main);
   $window->set_title("Log Viewer");
   $window->set_border_width(5);
   $window->set_keep_above($keep_above);
   $window->set_modal(0);
   $window->set_resizable(1);
   my $icon = $$gtk_ui->{'icon_logview_pix'};

   if (defined $icon) {
      $window->set_icon($$icon);
   } else {
      $main::log->Log("core", "warn", "We appear to be missing logview icon!");
   }

   # Set width/height of teh window
   $window->set_default_size( $$cfg->{'win_logview_width'},
       $$cfg->{'win_logview_height'} );

   my $w_state = $$cfg->{'win_logview_state'};
   if (defined $w_state) {
      $window->set_state($w_state);
   }

   # If placement type is none, we should manually place the window at x,y
   if ($lvp =~ m/none/) {
      # Place the window
      $window->move( $$cfg->{'win_logview_x'}, $$cfg->{'win_logview_y'} );
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
           $tmp_cfg->{'win_logview_x'}      = $x;
           $tmp_cfg->{'win_logview_y'}      = $y;
           $tmp_cfg->{'win_logview_height'} = $height;
           $tmp_cfg->{'win_logview_width'}  = $width;
           $tmp_cfg->{'win_logview_state'} = $widget->get_state();
           $main::cfg_p->apply($tmp_cfg);
           undef $tmp_cfg;

           # Return FALSE to allow the event to propagate
           return FALSE;
       }
   );

   $window->signal_connect(
       delete_event => sub {
           ( my $class ) = @_;
           $window->iconify();
           return TRUE;    # Suppress default window destruction
       }
   );

   $window->signal_connect( window_state_event   => \&window_state );

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

   my $auto_hide = $$cfg->{'hide_logview_at_start'};
   if (defined $auto_hide && $auto_hide) {
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
