# Here we provide a window to display log messages
# This needs some improvements --
# * Fix autoscrolling bug
# * Add button save to file (is there a point? we have logfile already...)
# * Add upload to termbin button
package RustyRigs::Logview;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Glib qw(TRUE FALSE);
use IO::Socket::INET;
use POSIX       qw(strftime);

# XXX: move this into the Logview object
my @log_buffer;
my $window;

sub save_log {
    my ( $self ) = @_;

    # Create a new Gtk3::FileChooserDialog
    my $file_chooser = Gtk3::FileChooserDialog->new(
        'Save log...',
        undef,
        'save',
        'gtk-cancel' => 'cancel',
        'gtk-save'   => 'accept'
    );

    # Add a filter for "*.txt" files
    my $filter = Gtk3::FileFilter->new();
    $filter->set_name("Text files (*.txt)");
    $filter->add_pattern("*.txt");
    $file_chooser->add_filter($filter);

    # Run the dialog and get the response
    my $response = $file_chooser->run();

    # Check if the user clicked the "Save" button
    if ($response eq 'accept') {
        # Get the selected file path
        my $save_file = $file_chooser->get_filename();
        
        # Append ".txt" if not already present
        $save_file .= ".txt" unless $save_file =~ /\.txt$/i;

        # Perform your save operation with $selected_file
        print "Saving to: $save_file\n";
        my $fh;
        open $fh, '>', $save_file;

        if ( defined $fh ) {
           my $buffer = join( "", @log_buffer );
           my $app_name = $main::app_name;
           my $datestamp = strftime( "%Y/%m/%d %H:%M:%S", localtime );

           print $fh "Log exported by $app_name at $datestamp\n";
           print $fh $buffer . "\n";
        } else {
           print "unable to open log file $save_file: $!\n";
           # XXX: Display an error dialog
        }
    }

    # Destroy the file chooser dialog
    $file_chooser->destroy();
    return;
}

sub upload_to_termbin {
    my ( $self, $log_buffer ) = @_;
    my $timeout = 10;
    my $url;	# result URL

    if ( !defined( $log_buffer ) ) {
       print "upload_to_termbin requires a log_buffer\n";
       return;
    }

    my $win = $self->{'window'};
    my $dialog = Gtk3::MessageDialog->new(
        $win,
        'destroy-with-parent',
        'info',
        'ok',
        "Upload may take a minute..."
    );

    # Connect the response signal to close the dialog
    $dialog->signal_connect(response => sub {
        my ($dialog, $response_id) = @_;
        $dialog->destroy();
        eval {
            # Set a 30 second timeout on the socket operations
            local $SIG{ALRM} = sub { die "Timeout\n" };
            alarm $timeout;

            my $socket = IO::Socket::INET->new(
                PeerAddr => 'termbin.com',
                PeerPort => 9999,
                Proto    => 'tcp',
            );
            die "Could not create socket: $!" unless $socket;

            # Upload the log     
            my $buffer = join( "", @log_buffer );
            my $app_name = $main::app_name;
            my $datestamp = strftime( "%Y/%m/%d %H:%M:%S", localtime );
            print $socket "Log exported by $app_name at $datestamp\n";
            print $socket $buffer;
            print $socket "\r\n\r\n";

            # Get the server's response
            my $response = <$socket>;

            # Extract the URL from the response
            if ( $response =~ m/^(https?:\/\/\S+)/ ) {
                $url = $1;
                print "Termbin URL: $url\n";
            } else {
                print "Failed to get Termbin URL\n";
            }

            alarm 0;	# clear alarm
        };

        if ( $@ ) {
            if ( $@ eq "Timeout\n" ) {
                print "Timed out after $timeout seconds\n";
            } else {
                $main::log->Log( "core", "err", "Unknown error in Logview::upload_to_termin -- $@" );
            }
        }
    });

    $main::log->Log( "core", "notice", "Uploaded log successfully to $url" );
    # Show the dialog
    $dialog->show_all();
    return $url;
}

sub append {
    ( my $self, my $message ) = @_;
    my $cfg = $main::cfg;
    my $sb = $$cfg->{'scrollback_lines'};
    my $end_mark;
    my $text_view = $self->{'text_view'};

    if ( !defined $sb ) {
       # XXX: we should try to estimate the available lines
       # XXX: using dpi/font size/window size but that's for another
       # XXX: day in the distant future...
       $sb = 50;
       print "Defaulting to $sb lines of scrollback - to override set scrollback_lines in cfg\n";
    }

    my $scrollback_lines = $sb;
    my $buffer = $text_view->get_buffer();

    # Get rid of a line, if needed
    if ( @log_buffer > $scrollback_lines ) {
        shift @log_buffer;
    }

    # push it onto the tail of the message stack
    push @log_buffer, "$message";
    
    # Update the text area with the log buffer content
    $buffer->set_text( join( "", @log_buffer ) );
    
    # Scroll the TextView to the bottom after updating the content
    my $end_iter = $buffer->get_end_iter();
    $text_view->scroll_to_iter( $end_iter, 0, FALSE, 0, 0 );
    $end_mark = $buffer->create_mark( "end_mark", $end_iter, FALSE );
    if ( defined $end_mark ) {
       $text_view->scroll_mark_onscreen( $end_mark );
       $buffer->delete_mark( $end_mark );
       undef $end_mark;
    }
    return;
}

sub window_state {
    my ( $widget, $event ) = @_;
    my $cfg = $main::cfg;
    my $on_top  = 0;
    my $focused = 0;

    # Only allow the window to be hidden with the main window
    if ( $event->new_window_state =~ m/\bwithdrawn\b/ ) {
       my $visible = $$cfg->{'win_visible'};

       if ( $visible ) {
          $widget->set_visible( 1 );
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
   return;
}

sub close_logview {
    ( my $class ) = @_;
    # Don't forget to tell Woodpile::Log we no longer are around...
    $main::log->clear_handler();
    $window->destroy();
    return TRUE;
}

sub new {
   my ( $class, $log ) = @_;
   my $cfg = $main::cfg;
   my $lvp = $$cfg->{'win_logview_placement'};
   my $tmp_cfg;		# hold changed configuration values until apply()'d
   my $gtk_ui = \$main::gtk_ui;
   my $text_view;

   if ( !defined $lvp ) {
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
   $window->set_transient_for( $main::w_main );
   $window->set_title( "Log Viewer" );
   $window->set_border_width( 5 );
   $window->set_keep_above( $keep_above );
   $window->set_modal( 0 );
   $window->set_resizable( 1 );
   my $icon = $main::icons->get_icon( 'logview' );

   if ( defined $icon ) {
      $window->set_icon( $icon );
   } else {
      $main::log->Log( "core", "warn", "We appear to be missing logview icon!" );
   }

   # Set width/height of teh window
   $window->set_default_size( $$cfg->{'win_logview_width'},  $$cfg->{'win_logview_height'} );

   # If placement type is none, we should manually place the window at x,y
   if ( $lvp =~ m/none/ ) {
      # Place the window
      $window->move( $$cfg->{'win_logview_x'}, $$cfg->{'win_logview_y'} );
   }

   # Keyboard accelerators
   my $accel = Gtk3::AccelGroup->new();
   $window->add_accel_group( $accel );

   $window->signal_connect(
       'configure-event' => sub {
           my ( $widget, $event ) = @_;

           # Retrieve the size and position information
           my ( $width, $height ) = $widget->get_size();
           my ( $x,     $y )      = $widget->get_position();

           # Save the data...
           $tmp_cfg->{'win_logview_x'}      = $x;
           $tmp_cfg->{'win_logview_y'}      = $y;
           $tmp_cfg->{'win_logview_height'}      = $height;
           $tmp_cfg->{'win_logview_width'}      = $width;
           $main::cfg_p->apply( $tmp_cfg, FALSE );
           undef $tmp_cfg;

           # Return FALSE to allow the event to propagate
           return FALSE;
       }
   );

   $window->signal_connect( delete_event => \&close_logview );
   $window->signal_connect( window_state_event   => \&window_state );

   # Outer box
   my $box = Gtk3::Box->new( 'vertical', 5 );

   # Here's our scrolling text area... 
   my $text_box = Gtk3::Box->new( 'vertical', 5 );
   my $scrolled_window = Gtk3::ScrolledWindow->new();
   $scrolled_window->set_policy( 'automatic', 'automatic' );
   $text_box->add( $scrolled_window );

   $text_view = Gtk3::TextView->new();
   $text_view->set_editable( 0 );
   $text_view->set_hexpand( 1 );
   $text_view->set_vexpand( 1 );
   $text_view->set_wrap_mode( 'word' );
   $scrolled_window->add( $text_view );
 
   # buttons
   my $button_box = Gtk3::Box->new( 'horizontal', 5 );
   my $clear_button = Gtk3::Button->new( 'C_lear' );
   my $save_button = Gtk3::Button->new( '_Save' );
   my $upload_button = Gtk3::Button->new( '_Upload' );
   my $hide_button = Gtk3::Button->new( '_Hide' );
   my $close_button = Gtk3::Button->new( '_Close' );
   $button_box->pack_start( $clear_button, TRUE, TRUE, 5 );
   $button_box->pack_start( $save_button, TRUE, TRUE, 5 );
   $button_box->pack_start( $upload_button, TRUE, TRUE, 5 );
   $button_box->pack_start( $hide_button, TRUE, TRUE, 5 );
   $button_box->pack_start( $close_button, TRUE, TRUE, 5 );

   $clear_button->signal_connect( 'clicked' => sub {
      my ( $widget ) = @_;

      # clear the log buffer
      splice(@log_buffer, 0, scalar(@log_buffer));

      # clear the log text area
      my $buffer = $text_view->get_buffer();
      $buffer->set_text('');
      return;
   });

   $close_button->signal_connect( 'clicked' => \&close_logview );

   $hide_button->signal_connect( 'clicked' => sub {
      my ( $widget ) = @_;
      $window->iconify();
      return;
   });

   $save_button->signal_connect( 'clicked' => sub {
      my ( $widget ) = @_;
      save_log();
      return;
   });

   $upload_button->signal_connect( 'clicked' => sub {
      my ( $widget ) = @_;
      my $log_url = upload_to_termbin( $widget, @log_buffer );
      return;
   });

   # Add it all to the window
   $box->pack_start( $text_box, TRUE, TRUE, 0 );
   $box->pack_start( $button_box, FALSE, FALSE, 0 );
   $window->add( $box );
   $window->show_all();

   my $auto_hide = $$cfg->{'hide_logview_at_start'};
   if ( $auto_hide ) {
      $window->set_visible( 0 );
      $window->iconify();
   }

   my $self = {
      accel => \$accel,
      box => \$box,
      log => $log,
      text_view => $text_view,
      window => \$window
   };

   # Register with Woodpile::Log
   $log->add_handler( $self );

   bless $self, $class;
   return $self;
}
1;
