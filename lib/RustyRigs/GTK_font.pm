package RustyRigs::GTK_font;
use strict;
use warnings;
use Data::Dumper;
use Glib qw(TRUE FALSE);

our $fonts;

sub load {
    my ( $self, $font_name ) = @_;

    if ( !defined $font_name) {
       die "GTK_font::load: Invalid usage: No font name specified\n";
    }

    # Try to use the font if it exists already
    my $font = $fonts->{$font_name};

    if ( undef($font) ) {
        # Nope, load it
        $main::log->Log("core", "debug", "Loading new font $font_name");
        $font = Gtk3::Pango::FontDescription->new();
        $font->set_family($font_name);
        $fonts->{$font_name} = $font;
    } else {
        print "using cached font $font_name\n";
    }

    return $font;
}

sub DESTROY {
    my ( $self ) = @_;
}

sub new {
    my ( $class ) = @_;
    my $self = {
       fonts => \$fonts
    };
    bless $self, $class if (defined $self);
    return $self;
}

1;
