package RustyRigs::GTK_font;
use strict;
use warnings;
use Data::Dumper;
use Gtk3;
use Glib qw(TRUE FALSE);
use Glib::Object::Introspection;
use Glib::Object::Subclass;
Glib::Object::Introspection->setup( basename => 'Pango', version => '1.0', package => 'Pango' );

our $fonts;

sub load {
    my ( $self, $font_name ) = @_;

    if ( !defined $font_name) {
       die "GTK_font::load: Invalid usage: No font name specified\n";
    }

    # Try to use the font if it exists already
    my $font = $fonts->{$font_name};

    if ( !defined $font ) {
        # Nope, load it
        $main::log->Log("core", "debug", "Loading new font $font_name");
        my $font = Pango::FontDescription->new ();
        $font->set_family($font_name);
#        $font->set_family($font_name);
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
