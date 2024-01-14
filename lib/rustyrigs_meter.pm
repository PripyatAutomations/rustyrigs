# here we render a meter bar widget
package rustyrigs_meterbar;
use Carp;
use Data::Dumper;
use Glib                  qw(TRUE FALSE);
use Data::Structure::Util qw/unbless/;
use warnings;
use strict;

our $monospace_font;

my $cfg;
my $vfos;
my $w_main;

sub set_label {
}

sub set_value {
    ( my $class, my $value ) = @_;
    $class->{value} = $value;
    $class->{val_label}->set_label($value);
}

sub zero {
}

sub on_drag_begin {
    my ( $widget, $context ) = @_;

    # Create a new window to hold the dragged widget
    my $new_window = Gtk3::Window->new('toplevel');
    $new_window->set_default_size( 200, 200 );

    # Remove the widget from its original parent (main window)
    $widget->reparent($new_window);

    # Show the new window
    $new_window->show_all();
}

sub on_drag_end {
    my ( $widget, $context ) = @_;

    # Get the main window
    my $main_window = $widget->get_toplevel;

    # Reparent the widget back to the main window
    $widget->reparent($w_main);
}

# The widget will need supplied the following parameters
#	- Name
#	- Height, Width
#	- Fill color
#	- Active fill color
#	- Label text
sub set_threshold {
    ( my $class, my $min, my $max ) = @_;

    if ( !defined $class || !defined $min || !defined $max ) {
        die "Improper call to set_threshold - please pass TWO options: min, max! Got ($min, $max)\n";
    }

    $class->{"threshold_min"} = $min;
    $class->{"threshold_max"} = $max;
}

sub new {
    ( my $class, $cfg, $vfos, $w_main, my $label, my $min_val, my $max_val ) = @_;
    my $lc_label = lc($label);
    my $s        = "ui_${lc_label}";
    my $l        = $main::meters->{$lc_label}{'title'};

    my $bg       = woodpile::hex_to_gdk_rgba( $$cfg->{"${s}_bg"} );
    my $alarm_bg = woodpile::hex_to_gdk_rgba( $$cfg->{"${s}_alarm_bg"} );
    my $fg       = woodpile::hex_to_gdk_rgba( $$cfg->{"${s}_fg"} );
    my $txt_fg   = woodpile::hex_to_gdk_rgba( $$cfg->{"${s}_text"} );
    my $txt_font = $$cfg->{"${s}_font"};
    my $value;

    if ( undef($monospace_font) ) {
        $monospace_font = Gtk3::Pango::FontDescription->new();
        $monospace_font->set_family('Monospace');
    }

    my $grid = Gtk3::Grid->new();
    $grid->set_column_homogeneous(FALSE);
    $grid->set_row_homogeneous(FALSE);

    my $bar_label = Gtk3::Label->new($l);
    my $val_label = Gtk3::Label->new($value);
    $bar_label->set_width_chars(6);
    $val_label->set_width_chars(6);
    $bar_label->override_font($monospace_font);
    $val_label->override_font($monospace_font);

    my $bar_sep = Gtk3::Separator->new('horizontal');
    my $val_sep = Gtk3::Separator->new('horizontal');
    $bar_sep->set_size_request( 30, 30 );
    $val_sep->set_size_request( 30, 30 );
    $bar_sep->override_background_color( 'normal', $bg );
    $val_sep->override_background_color( 'normal', $fg );

    my $bar = Gtk3::Box->new( 'horizontal', 0 );
    $bar_sep   = Gtk3::Separator->new('horizontal');
    $val_sep   = Gtk3::Separator->new('horizontal');
    $bar_label = Gtk3::Label->new($l);
    $val_label = Gtk3::Label->new($value);
    $bar_label->set_width_chars(6);
    $val_label->set_width_chars(6);
    $bar_label->override_font($monospace_font);
    $val_label->override_font($monospace_font);
    $bar_sep->set_size_request( -1, 30 );
    $bar_sep->override_background_color( 'normal', $bg );
    $val_sep->override_background_color( 'normal', $fg );
    $bar_sep->set_size_request( 30, 30 );

    $grid->attach( $bar_label, 0, 0, 1, 1 );
    $grid->attach( $bar_sep,   1, 0, 1, 1 );
    $grid->attach( $val_sep,   1, 0, 1, 1 );
    $grid->attach( $val_label, 2, 0, 1, 1 );
    $grid->set_column_homogeneous(FALSE);
    $bar_sep->set_hexpand(TRUE);
    $val_sep->set_hexpand(FALSE);
    $grid->set_column_spacing(10);

    # XXX: We need to calculate min/max to get a percentage of fill
    # XXX: Then determine how many pixels that is and set width appropriately
    # XXX: on $act_sep
    $value = "1.0";
    $val_label->set_label($value);
    $val_sep->set_size_request( 0, 30 );

    my $self = {
        grid          => $grid,
        bar_label     => $bar_label,
        bar_sep       => $bar_sep,
        min           => $min_val,
        max           => $max_val,
        min_threshold => -1,
        max_threshold => -1,
        set_label     => \&set_label,
        set_threshold => \&set_threshold,
        set_value     => \&set_value,
        value         => $value,
        val_label     => $val_label,
        val_sep       => $val_sep,
        zero          => \&zero
    };
    bless $self, $class;
    return $self;
}

sub DESTROY {
    my ($class) = @_;
}

# This will return an object containing all the meters and their properties
sub render_meterbars {
    ( my $class, my $meters_ref, my $cfg, my $vfos, my $w_main ) = @_;

    my $meters = ${$meters_ref};
    # Box for the meters
    my $meter_box   = Gtk3::Box->new( 'vertical', 5 );
    my $meter_label = Gtk3::Label->new("Meters");
    $meter_box->pack_start( $meter_label, FALSE, FALSE, 0 );

    my @meter_names = sort keys %$meters;
    my $sorted_meters = { map { $_ => $meters->{$_} } sort keys %$meters };
    foreach my $index (0 .. $#meter_names) {
       my $m_name = $meter_names[$index];
       my $meter = $meters->{$m_name};
       my $m_title = $meter->{'title'};
       my $m_enabled = $meter->{'enabled'};
       my $m_alarm_bg = $meter->{'alarm_bg'};
       my $m_bg = $meter->{'bg'};
       my $m_fg = $meter->{'fg'};
       my $m_font = $meter->{'font'};
       my $m_text = $meter->{'text'};
       my $m_box = Gtk3::Box->new('vertical', 5);
       my $m_thresh_min = $meter->{'thresh_min'};
       my $m_thresh_max = $meter->{'thresh_max'};

       my $widget = 
          rustyrigs_meterbar->new( $cfg, $vfos, $w_main, $m_name, 0, 10 );

       $widget->set_threshold($m_thresh_min, $m_thresh_max);
       $meter_box->pack_start( $widget->{'grid'}, TRUE, TRUE, 0 );
    }

    my $self = {
        box => $meter_box,
        meters => \$meters
    };        
    return $self;
}

package rustyrigs_meterbar::Settings;
use Carp;
use Data::Dumper;
use Glib                  qw(TRUE FALSE);
use Data::Structure::Util qw/unbless/;
use warnings;
use strict;

my $color_win;

sub cancel {
   my ( $self ) = @_;
   $color_win->destroy();
}

sub save {
   my ( $self ) = @_;
   $color_win->destroy();
}

# Function to handle color selection
sub color_picker {
    my ($parent_window, $default_color) = @_;

    my $color_dialog = Gtk3::ColorSelectionDialog->new('Choose Color');
    my $color_selection = $color_dialog->get_color_selection();

    if ($default_color) {
        $color_selection->set_current_rgba($default_color);
    }

    my $response = $color_dialog->run();
    $color_dialog->destroy();

    if ($response eq 'ok') {
        my $selected_color = $color_selection->get_current_rgba();
        return $selected_color;
    } else {
        return undef;  # User canceled the dialog
    }
}

sub font_chooser {
    my ($parent_window, $default_font) = @_;

    my $font_dialog = Gtk3::FontChooserDialog->new('Choose Font', $parent_window);
    
    if ($default_font) {
        $font_dialog->set_font($default_font);
    }

    my $response = $font_dialog->run();

    my $selected_font;
    if ($response eq 'ok') {
        $selected_font = $font_dialog->get_font();
    }

    $font_dialog->destroy();
    return $selected_font;
}

sub DESTROY {
   my ( $self ) = @_;
}

# XXX: Make this store settings in a temp variable so we can discard if cancel clicked
sub new {
   my ( $class, $w_set_ref ) = @_;

   my $cfg = $main::cfg;

   # settings window
   my $w_set = ${$w_set_ref};
   my $box;

   # get the main window
   my $gtk_ui = $main::gtk_ui;
   my $w_main = $gtk_ui->{'w_main'};

   $color_win = Gtk3::Window->new(
      'toplevel',
      decorated => TRUE,
      destroy_with_parent => TRUE,
      position => 'center_on_parent'
   );
   $color_win->set_transient_for($w_set);
   $color_win->set_title("Meter Settings");
   $color_win->set_border_width(5);
   $color_win->set_keep_above(1);
   $color_win->set_default_size(300, 200);
   $color_win->set_modal(1);
   $color_win->set_resizable(0);

   my $icon = ${$gtk_ui->{'icon_settings_pix'}};
   $color_win->set_icon($icon);

   my $accel = Gtk3::AccelGroup->new();
   $color_win->add_accel_group($accel);
   $box = Gtk3::Box->new('vertical', 5);

   my $box_label = Gtk3::Label->new("Meters");
   $box->pack_start($box_label, FALSE, FALSE, 0);

   my $box_label_sep = Gtk3::Separator->new('horizontal');
   $box->pack_start($box_label_sep, FALSE, FALSE, 0);

   # Iterate over the available meters and render them into the box
   my $wrap_box = Gtk3::Box->new('horizontal', 5);
   my $meters = $main::meters;
   my @meter_names = sort keys %$meters;

   foreach my $index (0 .. $#meter_names) {
      my $m_name = $meter_names[$index];
      my $meter = $meters->{$m_name};
      my $m_title = $meter->{'title'};
      my $m_enabled = $meter->{'enabled'};
      my $m_alarm_bg = $meter->{'alarm_bg'} ? $meter->{'alarm_bg'} : "#f0c0c0";
      my $m_bg = $meter->{'bg'} ? $meter->{'bg'} : "#000000";
      my $m_fg = $meter->{'fg'} ? $meter->{'fg'} : "#ffffff";
      my $m_font = $meter->{'font'} ? $meter->{'font'} : "Monospace";
      my $m_text = $meter->{'text'} ? $meter->{'text'} : "#ffffff";

      # wrap everything in a box
      my $m_box = Gtk3::Box->new('vertical', 5);
      
      # Meter name
      my $m_label = Gtk3::Label->new(uc($m_name));
      $m_box->pack_start($m_label, TRUE, TRUE, 0);

      # background color
      my $bg_box = Gtk3::Box->new('horizontal', 5);
      my $bg_label = Gtk3::Label->new("Bgnd");
      $bg_box->pack_start($bg_label, TRUE, TRUE, 0);

      my $bg_input = Gtk3::Entry->new();
      $bg_input->set_text($m_bg);
      $bg_input->set_tooltip_text("Background color for $m_title widget");
      $bg_input->set_can_focus(1);
      $bg_input->signal_connect(
         changed => sub {
            my ($self) = @_;
            $m_bg = $meter->{$m_name}{'bg'} = $$cfg->{'ui_' . $m_name . '_bg'} = $self->get_text();
         }
      );
      $bg_input->signal_connect(
         button_press_event => sub {
            my ($self, $event) = @_;
            if ($event->type eq 'button-press') {
               my $def_color = woodpile::hex_to_gdk_rgba($m_bg);
               my $color = color_picker($color_win, $def_color);
               if ($color) {
                  $self->set_text($color->to_string());
                  $m_bg = $meter->{$m_name} = $$cfg->{'ui_' . $m_name . '_bg'} = woodpile::gdk_rgb_to_hex($color);
               }
            }
         }
      );
      $bg_box->pack_start($bg_input, TRUE, TRUE, 0);
      $m_box->pack_start($bg_box, FALSE, FALSE, 0);

      # alarm background color
      my $alarm_bg_box = Gtk3::Box->new('horizontal', 5);
      my $alarm_bg_label = Gtk3::Label->new("Alarm");
      $alarm_bg_box->pack_start($alarm_bg_label, TRUE, TRUE, 0);

      my $alarm_bg_input = Gtk3::Entry->new();
      $alarm_bg_input->set_text($m_alarm_bg);
      $alarm_bg_input->set_tooltip_text("Alarm background color for $m_title widget");
      $alarm_bg_input->set_can_focus(1);
      $alarm_bg_input->signal_connect(
         changed => sub {
            my ($self) = @_;
            $m_bg = $meter->{$m_name}{'alarm_bg'} = $$cfg->{'ui_' . $m_name . '_alarm_bg'} = $self->get_text();
         }
      );
      $alarm_bg_input->signal_connect(
         button_press_event => sub {
            my ($self, $event) = @_;
            if ($event->type eq 'button-press') {
               my $def_color = woodpile::hex_to_gdk_rgba($m_bg);
               my $color = color_picker($color_win, $def_color);
               if ($color) {
                  $self->set_text($color->to_string());
                  $m_bg = $$cfg->{'ui_' . $m_name . '_alarm_bg'} = $meter->{$m_name} = woodpile::gdk_rgb_to_hex($color);;
               }
            }
         }
      );
      $alarm_bg_box->pack_start($alarm_bg_input, TRUE, TRUE, 0);
      $m_box->pack_start($alarm_bg_box, TRUE, TRUE, 0);

      # foreground color
      my $fg_box = Gtk3::Box->new('horizontal', 5);
      my $fg_label = Gtk3::Label->new("Fgnd");
      $fg_box->pack_start($fg_label, TRUE, TRUE, 0);

      my $fg_input = Gtk3::Entry->new();
      $fg_input->set_text($m_fg);
      $fg_input->set_tooltip_text("Foreground color for $m_title widget");
      $fg_input->set_can_focus(1);
      $fg_input->signal_connect(
         changed => sub {
            my ($self) = @_;
            $m_bg = $$cfg->{'ui_' . $m_name . '_fg'} = $meter->{$m_name}{'fg'} = $self->get_text();
         }
      );
      $fg_input->signal_connect(
         button_press_event => sub {
            my ($self, $event) = @_;
            if ($event->type eq 'button-press') {
               my $def_color = woodpile::hex_to_gdk_rgba($m_bg);
               my $color = color_picker($color_win, $def_color);
               if ($color) {
                  $self->set_text($color->to_string());
                  $m_bg = $meter->{$m_name} = $$cfg->{'ui_' . $m_name . '_fg'} = woodpile::gdk_rgb_to_hex($color);
               }
            }
         }
      );
      $fg_box->pack_start($fg_input, TRUE, TRUE, 0);
      $m_box->pack_start($fg_box, TRUE, TRUE, 0);

      # text color
      my $text_box = Gtk3::Box->new('horizontal', 5);
      my $text_label = Gtk3::Label->new("Text:");
      $text_box->pack_start($text_label, TRUE, TRUE, 0);

      my $text_input = Gtk3::Entry->new();
      $text_input->set_text($m_text);
      $text_input->set_tooltip_text("Text color color for $m_title widget");
      $text_input->set_can_focus(1);
      $text_input->signal_connect(
         changed => sub {
            my ($self) = @_;
            $m_bg = $$cfg->{'ui_' . $m_name . '_text'} = $meter->{$m_name}{'text'} = $self->get_text();
         }
      );
      $text_input->signal_connect(
         button_press_event => sub {
            my ($self, $event) = @_;
            if ($event->type eq 'button-press') {
               my $def_color = woodpile::hex_to_gdk_rgba($m_bg);
               my $color = color_picker($color_win, $def_color);
               if ($color) {
                  $self->set_text($color->to_string());
                  $m_bg = $meter->{$m_name} = $$cfg->{'ui_' . $m_name . '_text'} = woodpile::gdk_rgb_to_hex($color);
               }
            }
         }
      );
      $text_box->pack_start($text_input, TRUE, TRUE, 0);
      $m_box->pack_start($text_box, TRUE, TRUE, 0);

      my $font_button = Gtk3::Button->new_with_label("Font: $m_font");
      $font_button->signal_connect(clicked => sub {
          my $font = font_chooser($color_win, $m_font);
          if ($font) {
              $m_font = $meter->{'font'} = $$cfg->{'ui_' . $m_name . '_font'} = $font;
          }
      });

      # Add the font button to your container
      $m_box->pack_start($font_button, TRUE, TRUE, 0);

      # Add a toggle button
      my $toggle_button = Gtk3::CheckButton->new();
      $toggle_button->set_label("Enabled?");
      $toggle_button->set_active($m_enabled);
      $toggle_button->set_can_focus(1);
      # XXX: add signal handler
      $m_box->pack_start($toggle_button, TRUE, TRUE, 0);

      # add it to our outer box
      $wrap_box->pack_start($m_box, TRUE, TRUE, 0);

      # add a separator, only if it's not the last one
      $wrap_box->pack_start(Gtk3::Separator->new('vertical'), TRUE, TRUE, 0) unless $index == $#meter_names;
   }
   $box->pack_start($wrap_box, FALSE, FALSE, 0);

   my $after_sep = Gtk3::Separator->new('horizontal');
   $box->pack_start($after_sep, TRUE, TRUE, 0);
   my $button_box = Gtk3::Box->new('horizontal', 5);
   my $save_button = Gtk3::Button->new("_Save");
   $save_button->set_tooltip_text("Save settings");
   $save_button->set_can_focus(1);
   $save_button->signal_connect( 'clicked'  => sub { (my $self) = @_; save($self); } );
   $accel->connect(ord('S'), $$cfg->{'shortcut_key'}, 'visible', sub { my ( $self ) = @_; save($self); });
   $button_box->pack_start($save_button, TRUE, TRUE, 0);

   my $cancel_button = Gtk3::Button->new("_Cancel");
   $cancel_button->set_tooltip_text("Cancel");
   $cancel_button->set_can_focus(1);
   $cancel_button->signal_connect( 'clicked'  => sub { (my $self) = @_; cancel($self); } );
   $accel->connect(ord('C'), $$cfg->{'shortcut_key'}, 'visible', sub { my ( $self ) = @_; cancel($self); });
   $button_box->pack_start($cancel_button, TRUE, TRUE, 0);
   $box->pack_end($button_box, TRUE, TRUE, 0);

   $color_win->add($box);
   $color_win->show_all();

   my $self = {
      # functions
      # variables
      accel => \$accel,
      box => \$box,
      window => \$color_win
   };

   bless $self, $class;
   return $self;
}

1;
