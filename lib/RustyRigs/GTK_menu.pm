package RustyRigs::GTK_menu;
use warnings;
use strict;
use Gtk3;
use Data::Dumper;
use Glib qw(TRUE FALSE);

our $w_main;
our $main_menu_open = 0;
our $main_menu;
our $lock_item;

sub main_menu_item_clicked {
    my ( $item, $window, $menu ) = @_;

    if ( $item->get_label() eq 'Toggle Window' ) {
        $window->set_visible( !$window->get_visible() );
    }
    elsif ( $item->get_label() eq 'Show Gridtools' ) {
        if (!defined $main::gridtools) {
           $main::gridtools = RustyRigs::Gridtools->new();
        }
        my $w = ${$main::gridtools->{'window'}};
        $w->present();
    }
    elsif ( $item->get_label() eq 'Quit' ) {
        close_main_win();
    }
    elsif ( $item->get_label() eq 'Settings' ) {
#        $settings = RustyRigs::Settings->new( $cfg, \$w_main );
    }

    $main_menu_open = 0;
    $menu->destroy();    # Hide the menu after the choice is made
}

sub main_menu_state {
    my ( $widget, $event ) = @_;
    my $on_top  = 0;
    my $focused = 0;

    # keep menu from being iconified/maximized
    if ( $event->new_window_state =~ m/\biconified\b/ ) {
        $w_main->deiconify();
    }

    if ( $event->new_window_state =~ m/\bmaximized\b/ ) {
        $w_main->unmaximize();
    }

    if ( $event->new_window_state =~ m/\babove\b/ ) {
        $on_top = 1;
    }

    if ( $event->new_window_state =~ m/\bfocused\b/ ) {
        $focused = 1;
    }

    # If menu becomes unfocused, destroy it...
    if ( !$focused ) {
        $widget->destroy();
    }
    return FALSE;
}

sub main_menu {
    my ( $status_icon, $button, $time ) = @_;

    # destroy old menu, if it exists
    if ($main_menu_open) {
        $main_menu->destroy();
    }

    $main_menu_open = 1;
    $main_menu      = Gtk3::Menu->new();
    my $sep1        = Gtk3::SeparatorMenuItem->new();
    my $sep2        = Gtk3::SeparatorMenuItem->new();
    my $sep3        = Gtk3::SeparatorMenuItem->new();
    my $toggle_item = Gtk3::MenuItem->new("Toggle Window");
    $toggle_item->signal_connect( activate =>
          sub { main_menu_item_clicked( $toggle_item, $w_main, $main_menu ) } );
    $main_menu->append($toggle_item);
    $main_menu->append($sep1);

    #   $main_menu->signal_connect(destroy => sub { undef $lock_item; });

    my $settings_item = Gtk3::MenuItem->new("Settings");
    $settings_item->signal_connect( activate =>
          sub { main_menu_item_clicked( $settings_item, $w_main, $main_menu ) }
    );
    $main_menu->append($settings_item);
    $main_menu->append($sep2);

    my $gridtools_item = Gtk3::MenuItem->new("Show Gridtools");
    $gridtools_item->signal_connect(
        activate =>
          sub { main_menu_item_clicked( $gridtools_item, $w_main, $main_menu ) }
    );
    $main_menu->append($gridtools_item);
    $main_menu->append($sep3);

    $lock_item = Gtk3::CheckMenuItem->new("Locked");
    $lock_item->signal_connect(
        toggled => sub {
            my $widget = shift;
            main::toggle_locked("menu");
            $main_menu_open = 0;
            $main_menu->destroy();    # Hide the menu after the choice is made
            return FALSE;
        }
    );
    $lock_item->set_active($main::locked);
    $main_menu->append($lock_item);

    my $quit_item = Gtk3::MenuItem->new("Quit");
    $quit_item->signal_connect( activate =>
          sub { main_menu_item_clicked( $quit_item, $w_main, $main_menu ) } );
    $main_menu->append($quit_item);

    $main_menu->show_all();
    $main_menu->popup( undef, undef, undef, undef, $button, $time );

    # XXX: We need to add an event to destroy the menu if it loses focus
    $main_menu->signal_connect( window_state_event => \&main_menu_state );
}

sub DESTROY {
    my ( $self ) = @_;
}

sub new {
    my ( $class ) = @_;

    $w_main = $main::gtk_ui->{'w_main'};
    my $self = {
    };
    bless $self, $class if ( defined $self );
    return $self;
}

1;
