
package RustyRigs::Meter::Settings;
use Carp;
use Data::Dumper;
use Glib                  qw(TRUE FALSE);
use warnings;
use strict;

my $color_win;
our $tmp_cfg;

sub cancel {
    my ( $self ) = @_;
    undef $tmp_cfg;
    $color_win->destroy();
    return;
}

sub save {
    my ( $self, $us_tmp_cfg ) = @_;
    my $rv;

    if (defined $tmp_cfg) {
       print "Applying changes to meter config:\n" . Dumper($tmp_cfg) . "\n";
       # try to merge it...
       $us_tmp_cfg = { %$$us_tmp_cfg, %$tmp_cfg };
    } else {
       print "no changes to save (meters)\n";
    }

    $color_win->destroy();
    return $rv;
}

# Function to handle color selection
sub color_picker {
    my ($parent_window, $name, $default_color) = @_;

    my $color_dialog = Gtk3::ColorSelectionDialog->new("Choose Color: $name");
    $color_dialog->set_modal(1);
    $color_dialog->present();
    $color_dialog->set_transient_for($parent_window);
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
        return;
    }
    return;
}

sub font_chooser {
    my ($parent_window, $default_font) = @_;

    my $font_dialog = Gtk3::FontChooserDialog->new('Choose Font', $parent_window);
    
    if ($default_font) {
        # XXX: this is incorrect!
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
    return;
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

   my $icon = $main::icons->get_icon('meters');
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
            $tmp_cfg->{'ui_' . $m_name . '_bg'} = $self->get_text();
         }
      );
      $bg_input->signal_connect(
         button_press_event => sub {
            my ($self, $event) = @_;
            if ($event->type eq 'button-press') {
               my $def_color = Woodpile::Gtk::hex_to_gdk_rgba($m_bg);
               my $color = color_picker($color_win, "${m_name} background", $def_color);
               if ($color) {
                  $self->set_text($color->to_string());
                  $tmp_cfg->{'ui_' . $m_name . '_bg'} = Woodpile::Gtk::gdk_rgb_to_hex($color);
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
            $tmp_cfg->{'ui_' . $m_name . '_alarm_bg'} = $self->get_text();
         }
      );
      $alarm_bg_input->signal_connect(
         button_press_event => sub {
            my ($self, $event) = @_;
            if ($event->type eq 'button-press') {
               my $def_color = Woodpile::Gtk::hex_to_gdk_rgba($m_bg);
               my $color = color_picker($color_win, "${m_name} ALARM", $def_color);
               if ($color) {
                  $self->set_text($color->to_string());
                  $tmp_cfg->{'ui_' . $m_name . '_alarm_bg'} = Woodpile::Gtk::gdk_rgb_to_hex($color);;
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
            $tmp_cfg->{'ui_' . $m_name . '_fg'} = $self->get_text();
         }
      );
      $fg_input->signal_connect(
         button_press_event => sub {
            my ($self, $event) = @_;
            if ($event->type eq 'button-press') {
               my $def_color = Woodpile::Gtk::hex_to_gdk_rgba($m_bg);
               my $color = color_picker($color_win, "${m_name} foreground", $def_color);
               if ($color) {
                  $self->set_text($color->to_string());
                  $tmp_cfg->{'ui_' . $m_name . '_fg'} = Woodpile::Gtk::gdk_rgb_to_hex($color);
               }
            }
         }
      );
      $fg_box->pack_start($fg_input, TRUE, TRUE, 0);
      $m_box->pack_start($fg_box, TRUE, TRUE, 0);

      # text color
      my $text_box = Gtk3::Box->new('horizontal', 5);
      my $text_label = Gtk3::Label->new("Text");
      $text_box->pack_start($text_label, TRUE, TRUE, 0);

      my $text_input = Gtk3::Entry->new();
      $text_input->set_text($m_text);
      $text_input->set_tooltip_text("Text color color for $m_title widget");
      $text_input->set_can_focus(1);
      $text_input->signal_connect(
         changed => sub {
            my ($self) = @_;
            $tmp_cfg->{'ui_' . $m_name . '_text'} = $self->get_text();
         }
      );
      $text_input->signal_connect(
         button_press_event => sub {
            my ($self, $event) = @_;
            if ($event->type eq 'button-press') {
               my $def_color = Woodpile::Gtk::hex_to_gdk_rgba($m_bg);
               my $color = color_picker($color_win, "${m_name} text input", $def_color);
               if ($color) {
                  $self->set_text($color->to_string());
                  $tmp_cfg->{'ui_' . $m_name . '_text'} = Woodpile::Gtk::gdk_rgb_to_hex($color);
               }
            }
         }
      );
      $text_box->pack_start($text_input, TRUE, TRUE, 0);
      $m_box->pack_start($text_box, TRUE, TRUE, 0);

      my $font_button = Gtk3::Button->new_with_label("Font: $m_font");
      $font_button->signal_connect(clicked => sub {
          my $font = font_chooser($color_win, $m_font);

          if (defined $font) {
             $tmp_cfg->{'ui_' . $m_name . '_font'} = $font;
          }
      });

      # Add the font button to your container
      $m_box->pack_start($font_button, TRUE, TRUE, 0);

      # Add a toggle button
      my $toggle_button = Gtk3::CheckButton->new();
      $toggle_button->set_label("Enabled?");
      $toggle_button->set_active($m_enabled);
      $toggle_button->set_can_focus(1);
      $toggle_button->signal_connect(
          'toggled' => sub {
              my $button = shift;

              if ( $button->get_active() ) {
                  $tmp_cfg->{'use_' . $m_name} = 1;
              }
              else {
                  $tmp_cfg->{'use_' . $m_name} = 0;
              }
          }
      );
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
   $save_button->signal_connect( 'clicked'  => sub { (my $self) = @_; save($self, \$tmp_cfg); } );
   $accel->connect(ord('S'), $$cfg->{'shortcut_key'}, 'visible', sub { my ( $self ) = @_; save($self, \$tmp_cfg); });
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

   my $us_tmp_cfg = $RustyRigs::Settings::tmp_cfg;

   my $self = {
      us_tmp_cfg => \$us_tmp_cfg,
      accel => \$accel,
      box => \$box,
      window => \$color_win
   };

   bless $self, $class;
   return $self;
}

1;
