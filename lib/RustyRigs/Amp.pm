# Support for hamlib's ampctld
package RustyRigs::Amp;
use strict;
use warnings;
use Hamlib;
use Data::Dumper;
use Glib qw(TRUE FALSE);

sub DESTROY {
   my ( $self ) = @_;
   return;
}

sub new {
   my ( $class ) = @_;

#   Hamlib::rig_set_debug( hamlib_debug_level( $$cfg->{'hamlib_loglevel'} ) );

   my $amp;
   my $self = {
      amp => \$amp
   };
   bless $self, $class if (defined $self);
   return $self;
}

1;
