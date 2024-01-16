# Support for hamlib's ampctld
package rustyrigs_amp;
use strict;
use warnings;
use Hamlib;
use Data::Dumper;
use Glib qw(TRUE FALSE);

sub DESTROY {
   my ( $self ) = @_;
}

sub new {
   my ( $class ) = @_;

   my $self = {
   };
   bless $self, $class if (defined $self);
   return $self;
}

1;
