package Woodpile::Config;
use strict;
use warnings;
use YAML::XS;
use Data::Dumper;
my $cfg_readonly = 0;    # if 1, config won't be written out
my $cfg_file;

sub apply {
    my ( $self, $tmp_cfg, $save ) = @_;
    my $x = \$self->{'cfg'};
    my $rv = { %$$x, %$tmp_cfg };

    # Apply globally
    $self->{'cfg'} = $rv;

    if ($save) {
       # Save to the configuration file
       my $cfg_file = $self->{'cfg_file'};
       $self->save($$cfg_file);
    }
    return;
}

sub load {
    my ( $self, $cfg_file, $def_cfg ) = @_;
    my $rv;

    # If a config file exists, load it
    if ( -f $$cfg_file ) {
        open my $fh, '<', $$cfg_file
          or die "Can't open config file $$cfg_file for reading: $!";
        $main::log->Log( "config", "info",
            "loading configuration from $$cfg_file" );
        my $yaml_content = do { local $/; <$fh> };
        my $new_cfg      = YAML::XS::Load($yaml_content);

        if ( defined($def_cfg) && defined($new_cfg) ) {
            $main::log->Log( "config", "info", "merging config" );
            $rv = { %$$def_cfg, %$new_cfg };
        }
        elsif ( defined($new_cfg) ) {
            $main::log->Log( "config", "info", "using only new config" );
            $rv = $new_cfg;
        }
        else {
            $main::log->Log( "config", "info", "using only default config" );
            $rv = $$def_cfg;
        }
    }
    else {
        warn "[config/info] cant find config file $$cfg_file, using defaults\n";
        $rv = $$def_cfg;
    }
    return $rv;
}

sub save {
    my ( $self, $cfg_file ) = @_;

    if ( !$cfg_readonly ) {
        print "[core/debug] saving config to $cfg_file\n";
        my $cfg_out_txt = YAML::XS::Dump( $self->{cfg} );
        if ( !defined($cfg_out_txt) ) {
            die "Exporting YAML configuration failed\n";
        }
        open my $fh, '>', $cfg_file
          or die "Can't open config file $cfg_file for writing: $! ";
        print $fh $cfg_out_txt . "\n";
        close $fh;
    }
    else {
        $self->log->Log( "core", "info",
            "not saving configuration $cfg_file as cfg_readonly is enabled..." );
    }
    return;
}


sub new {
    my ( $class, $log, $cfg_file, $def_cfg ) = @_;

    my $self = {
        # Data
        cfg_file => $cfg_file,
        def_cfg  => $def_cfg,
        log      => $log
    };

    $self->{cfg} = load( $self, $cfg_file, $def_cfg );

    bless $self, $class;
    return $self;
}

# Destructor to close the file cfg_fh when the object is destroyed
sub DESTROY {
    my ($self) = @_;
    return;
}

1;