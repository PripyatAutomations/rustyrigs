package rustyrigs_set_colors;
use Carp;
use Data::Dumper;
use strict;
use Glib qw(TRUE FALSE);
use warnings;

sub DESTROY {
   my ( $self ) = @_;
}

sub new {
   my ( $class ) = @_;
   my $self = {
      # stuff
   };

   bless $self, $class;
   return $self;
}

1;
