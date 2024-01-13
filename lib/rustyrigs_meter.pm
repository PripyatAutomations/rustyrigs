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

# XXX: Make methods for these
#	- SetValue
#	- Zero
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

# This needs sorted out so it makes only one widget.
# The widget will need supplied the following parameters
#	- Name
#	- Height, Width
#	- Fill color
#	- Active fill color
#	- Label text

sub set_threshold {
    ( my $class, my $min, my $max ) = @_;

    if ( !defined $class || !defined $min || !defined $max ) {
        die
"Improper call to set_threshold - please pass TWO options: min, max! Got ($min, $max)\n";
    }

    $class->{"threshold_min"} = $min;
    $class->{"threshold_max"} = $max;
}

sub new {
    ( my $class, $cfg, $vfos, $w_main, my $label, my $min_val, my $max_val ) =
      @_;
    my $l        = lc($label);
    my $s        = "ui_${l}";
    my $bg       = woodpile::hex_to_gdk_rgba( $cfg->{"${s}_bg"} );
    my $alarm_bg   = woodpile::hex_to_gdk_rgba( $cfg->{"${s}_alarm_bg"} );
    my $fg       = woodpile::hex_to_gdk_rgba( $cfg->{"${s}_fg"} );
    my $txt_fg   = woodpile::hex_to_gdk_rgba( $cfg->{"${s}_text"} );
    my $txt_font = $cfg->{"${s}_font"};
    my $value;

    if ( undef($monospace_font) ) {
        $monospace_font = Gtk3::Pango::FontDescription->new();
        $monospace_font->set_family('Monospace');
    }

    my $grid = Gtk3::Grid->new();
    $grid->set_column_homogeneous(FALSE);
    $grid->set_row_homogeneous(FALSE);

    my $bar_label = Gtk3::Label->new($label);
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
    $bar_label = Gtk3::Label->new($label);
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
    ( my $cfg, my $vfos, my $w_main ) = @_;

    our $meters = {
       'alc' => {
          'title' => 'ALC',
          'enabled' => TRUE,
          'alarm_bg' => $cfg->{'ui_alc_alarm_bg'},
          'bg' => $cfg->{'ui_alc_bg'},
          'fg' => $cfg->{'ui_alc_fg'},
          'font' => $cfg->{'ui_alc_font'},
          'text' => $cfg->{'ui_alc_font'}
       },
       'comp' => {
          'title' => 'Comp',
          'enabled' => TRUE,
          'alarm_bg' => $cfg->{'ui_comp_alarm_bg'},
          'bg' => $cfg->{'ui_comp_bg'},
          'fg' => $cfg->{'ui_comp_fg'},
          'font' => $cfg->{'ui_comp_font'},
          'text' => $cfg->{'ui_comp_font'}
       },
       'pow' => {
          'title' => 'Power',
          'enabled' => TRUE,
          'alarm_bg' => $cfg->{'ui_pow_alarm_bg'},
          'bg' => $cfg->{'ui_pow_bg'},
          'fg' => $cfg->{'ui_pow_fg'},
          'font' => $cfg->{'ui_pow_font'},
          'text' => $cfg->{'ui_pow_font'}
       },
       'swr' => {
          'title' => 'SWR',
          'enabled' => TRUE,
          'alarm_bg' => $cfg->{'ui_swr_alarm_bg'},
          'bg' => $cfg->{'ui_swr_bg'},
          'fg' => $cfg->{'ui_swr_fg'},
          'font' => $cfg->{'ui_swr_font'},
          'text' => $cfg->{'ui_swr_font'}
       },
       'temp' => {
          'title' => 'Temp',
          'enabled' => TRUE,
          'alarm_bg' => $cfg->{'ui_temp_alarm_bg'},
          'bg' => $cfg->{'ui_temp_bg'},
          'fg' => $cfg->{'ui_temp_fg'},
          'font' => $cfg->{'ui_temp_font'},
          'text' => $cfg->{'ui_temp_font'}
       },
       'vdd' => {
          'title' => 'Volt',
          'enabled' => TRUE,
          'alarm_bg' => $cfg->{'ui_vdd_alarm_bg'},
          'bg' => $cfg->{'ui_vdd_bg'},
          'fg' => $cfg->{'ui_vdd_fg'},
          'font' => $cfg->{'ui_vdd_font'},
          'text' => $cfg->{'ui_vdd_font'}
       }
    };

    # Add the meters
    my $meter_box   = Gtk3::Box->new( 'vertical', 5 );
    my $meter_label = Gtk3::Label->new("Meters");
    $meter_box->pack_start( $meter_label, FALSE, FALSE, 0 );

    my $stat_alc = $meters->{'alc'}{'widget'} =
      rustyrigs_meterbar->new( $cfg, $vfos, $w_main, "ALC", 0, 10 );
    $stat_alc->set_threshold( $cfg->{'thresh_alc_min'},
        $cfg->{'thresh_alc_max'} );
    $meter_box->pack_start( $stat_alc->{'grid'}, TRUE, TRUE, 0 );

    my $stat_comp = $meters->{'comp'}{'widget'} =
      rustyrigs_meterbar->new( $cfg, $vfos, $w_main, "COMP", 0, 10 );
    $stat_comp->set_threshold( $cfg->{'thresh_comp_min'},
        $cfg->{'thresh_comp_max'} );
    $meter_box->pack_start( $stat_comp->{'grid'}, TRUE, TRUE, 0 );

    my $stat_pow = $meters->{'pow'}{'widget'} =
      rustyrigs_meterbar->new( $cfg, $vfos, $w_main, "POW", 0, 100 );
    $stat_pow->set_threshold( $cfg->{'thresh_pow_min'},
        $cfg->{'thresh_pow_max'} );
    $meter_box->pack_start( $stat_pow->{'grid'}, TRUE, TRUE, 0 );

    my $stat_swr = $meters->{'swr'}{'widget'} =
      rustyrigs_meterbar->new( $cfg, $vfos, $w_main, "SWR", 0, 50 );
    $stat_swr->set_threshold( $cfg->{'thresh_swr_min'},
        $cfg->{'thresh_swr_max'} );
    $meter_box->pack_start( $stat_swr->{'grid'}, TRUE, TRUE, 0 );

    my $stat_temp = $meters->{'temp'}{'widget'} =
      rustyrigs_meterbar->new( $cfg, $vfos, $w_main, "TEMP", 0, 200 );
    $stat_temp->set_threshold( $cfg->{'thresh_temp_min'},
        $cfg->{'thresh_temp_max'} );
    $meter_box->pack_start( $stat_temp->{'grid'}, TRUE, TRUE, 0 );

    my $stat_vdd = $meters->{'vdd'}{'widget'} =
      rustyrigs_meterbar->new( $cfg, $vfos, $w_main, "VDD", 0, 50 );
    $stat_vdd->set_threshold( $cfg->{'thresh_vdd_min'},
        $cfg->{'thresh_vdd_max'} );
    $meter_box->pack_start( $stat_vdd->{'grid'}, TRUE, TRUE, 0 );

    my $self = {
        box => $meter_box,
        # these will go away soon...
        meters => \$meters,
        alc => \$stat_alc,
        comp => \$stat_comp,
        pow => \$stat_pow,
        swr => \$stat_swr,
        temp => \$stat_temp,
        vdd => \$stat_vdd,        
    };        
    return $self;
}

package rustyrigs_meterbar::Colors;
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

sub DESTROY {
   my ( $self ) = @_;
}

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
   $color_win->set_title("Colour settings");
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
   $box->pack_end($button_box, FALSE, FALSE, 0);

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
