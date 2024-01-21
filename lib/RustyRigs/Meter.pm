# here we render a meter bar widget
package RustyRigs::Meter;
use warnings;
use strict;
use Carp;
use Data::Dumper;
use Glib                  qw(TRUE FALSE);
use RustyRigs::Meter::Settings;

#####
our $docked;
our $tmp_cfg;
my $cfg;
my $vfos;
my $w_main;

sub set_label {
    return;
}

sub set_value {
    ( my $class, my $value ) = @_;
    $class->{value} = $value;
    $class->{val_label}->set_label($value);
    return;
}

sub zero {
    return;
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
    return;
}

sub on_drag_end {
    my ( $widget, $context ) = @_;

    # Get the main window
    my $main_window = $widget->get_toplevel;

    # Reparent the widget back to the main window
    $widget->reparent($w_main);
    return;
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
    return;
}

sub new {
    ( my $class, $cfg, $vfos, $w_main, my $label, my $min_val, my $max_val ) = @_;
    my $lc_label = lc($label);
    my $s        = "ui_${lc_label}";
    my $l        = $main::meters->{$lc_label}{'title'};

    my $bg       = Woodpile::Gtk::hex_to_gdk_rgba( $$cfg->{"${s}_bg"} );
    my $alarm_bg = Woodpile::Gtk::hex_to_gdk_rgba( $$cfg->{"${s}_alarm_bg"} );
    my $fg       = Woodpile::Gtk::hex_to_gdk_rgba( $$cfg->{"${s}_fg"} );
    my $txt_fg   = Woodpile::Gtk::hex_to_gdk_rgba( $$cfg->{"${s}_text"} );
    my $txt_font = $$cfg->{"${s}_font"};
    my $value;

    # Look up the font from the cache
    my $fonts = \$main::fonts;
    my $font = $$fonts->load($txt_font);

    my $grid = Gtk3::Grid->new();
    $grid->set_column_homogeneous(FALSE);
    $grid->set_row_homogeneous(FALSE);

    my $bar_label = Gtk3::Label->new($l);
    my $val_label = Gtk3::Label->new($value);
    $bar_label->set_width_chars(6);
    $val_label->set_width_chars(6);
#    if (defined $font) {
#       $bar_label->override_font($font);
#       $val_label->override_font($font);
#    }
    $bar_label->set_alignment(1, 0.5);
    $val_label->set_alignment(1, 0.5);
    my $bar = Gtk3::Box->new( 'horizontal', 0 );
    my $bar_sep = Gtk3::Separator->new('horizontal');
    my $val_sep = Gtk3::Separator->new('horizontal');
    $val_sep->set_size_request( 30, 30 );
    $bar_sep->set_size_request( 30, 30 );
    $bar_sep->override_background_color( 'normal', $bg );
    $val_sep->override_background_color( 'normal', $fg );
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
    return;
}

sub dock_meterbars {
    my ( $self ) = @_;
    my $dock = $self->{'meter_dock'};
    my $gtk_ui = $main::gtk_ui;

    if (!$docked) {
       # XXX: Remove from it's own window
#       $dock->pack_start($meters, TRUE, TRUE, 0);
#       $docked = 1;
    } else {
       $main::log->Log("gtkui", "debug", "meters already docked!");
    }
    $main::log->Log("gtkui", "debug", "dock meters win");
    return;
}

sub hide_meterbars {
    my ( $self ) = @_;
    my $dock = $self->{'meter_dock'};
    my $gtk_ui = $main::gtk_ui;

    $main::log->Log("gtkui", "debug", "hide meters win");
    return;
}

sub show_meterbar_win {
    my ( $self ) = @_;
    my $dock = $self->{'meter_dock'};
    my $docked = $self->{'docked'};
    my $gtk_ui = $main::gtk_ui;

    if ($docked) {
       # XXX: Remove from dock first
    }
    $main::log->Log("gtkui", "debug", "show meters win");
    return;
}

# This will return an object containing all the meters and their properties
sub render_meterbars {
    ( my $class, my $meters_ref, my $cfg, my $vfos, my $w_main ) = @_;

    my $meters = ${$meters_ref};
    # Box for the meters
    my $meter_box   = Gtk3::Box->new( 'vertical', 5 );
#    my $meter_label = Gtk3::Label->new("Meters");
#    $meter_box->pack_start( $meter_label, FALSE, FALSE, 0 );

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

       if ($m_enabled) {
          my $widget = 
             RustyRigs::Meter->new( $cfg, $vfos, $w_main, $m_name, 0, 10 );

          $widget->set_threshold($m_thresh_min, $m_thresh_max);
          $meter_box->pack_start( $widget->{'grid'}, TRUE, TRUE, 0 );
       }
       else {
          $main::log->Log("gtkui", "debug", "skipping disabled meter: $m_name");
       }
    }

    my $self = {
        dock_meterbars => \&dock_meterbars,	# Dock in main window
        hide_meterbars => \&hide_meterbars,	# Hide the popup window
        show_meterbar_win => \&show_meterbar_win,	# Show in a popup window
        box => $meter_box,
        meters => \$meters,
        docked => \$docked
    };        
    return $self;
}
1;

