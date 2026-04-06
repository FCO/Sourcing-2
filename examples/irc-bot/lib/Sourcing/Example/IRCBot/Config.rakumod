use v6.e.PREVIEW;

=begin pod

=head1 NAME

Sourcing::Example::IRCBot::Config - Configuration for IRC bot

=head1 DESCRIPTION

Provides access to IRC bot configuration.

=end pod

unit class Sourcing::Example::IRCBot::Config;

has Str $.nickname;
has Str $.server;
has Int $.port;
has Str $.username;
has Str $.realname;
has Str @.channels;
has Bool $.auto-join = True;
has Bool $.verbose = False;

# Karma settings
has Int $.karma-min = -10;
has Int $.karma-max = 10;
has Bool $.karma-enabled = True;

# Alias settings
has Bool $.alias-enabled = True;

# Broadcast settings
has Int $.broadcast-timeout = 60;  # seconds
has Int $.max-channels-per-broadcast = 50;

=begin pod

=head2 Method new

Creates a new Config instance.

=head3 Parameters

=item C<:*%params> — Configuration parameters

If no parameters provided, returns default configuration.

=end pod

multi method new() {
    self.bless(
        :nickname("sourcing-bot"),
        :server("localhost"),
        :port(6667),
        :username("sourcing-bot"),
        :realname("Sourcing IRC Bot"),
        :channels(["#general", "#random"]),
        :auto-join(True),
        :verbose(False),
        :karma-min(-10),
        :karma-max(10),
        :karma-enabled(True),
        :alias-enabled(True),
        :broadcast-timeout(60),
        :max-channels-per-broadcast(50)
    );
}

multi method new(Str :$file) {
    self.load-file($file);
}

multi method new(*%params) {
    self.bless(
        :nickname(%params<nickname> // "sourcing-bot"),
        :server(%params<server> // "localhost"),
        :port(%params<port> // 6667),
        :username(%params<username> // "sourcing-bot"),
        :realname(%params<realname> // "Sourcing IRC Bot"),
        :channels(%params<channels> // ["#general", "#random"]),
        :auto-join(%params<auto-join> // True),
        :verbose(%params<verbose> // False),
        :karma-min(%params<karma-min> // -10),
        :karma-max(%params<karma-max> // 10),
        :karma-enabled(%params<karma-enabled> // True),
        :alias-enabled(%params<alias-enabled> // True),
        :broadcast-timeout(%params<broadcast-timeout> // 60),
        :max-channels-per-broadcast(%params<max-channels-per-broadcast> // 50)
    );
}

=begin pod

=head2 Method load-file

Loads configuration from a TOML-like file.

=head3 Parameters

=item C<Str $file> — Path to config file

=end pod

method load-file(Str $file) {
    my $path = $file.IO;
    unless $path.e {
        die "Config file not found: $file";
    }

    my %config;
    my $current-section = '';
    
    for $path.lines -> $line {
        my $trimmed = $line.trim;
        next unless $trimmed.chars;
        next if $trimmed.starts-with('#');
        
        if $trimmed.starts-with('[') && $trimmed.ends-with(']') {
            $current-section = $trimmed.substr(1, $trimmed.chars - 2);
            %config{$current-section} = {};
        }
        elsif $trimmed.contains('=') {
            my $eq-pos = $trimmed.index('=');
            my $key = $trimmed.substr(0, $eq-pos).trim;
            my $value = $trimmed.substr($eq-pos + 1).trim;
            
            # Remove quotes
            if $value.starts-with('"') && $value.ends-with('"') {
                $value = $value.substr(1, $value.chars - 2);
            }
            if $value.starts-with("'") && $value.ends-with("'") {
                $value = $value.substr(1, $value.chars - 2);
            }
            
            if $current-section {
                %config{$current-section}{$key} = $value;
            } else {
                %config{$key} = $value;
            }
        }
    }
    
    # Extract values with fallbacks
    my $nickname = %config<nickname> // "sourcing-bot";
    my $server = %config<server> // "localhost";
    my $port = (%config<port> // "6667").Int;
    my $username = %config<username> // "sourcing-bot";
    my $realname = %config<realname> // "Sourcing IRC Bot";
    
    my @channels = ["#general", "#random"];
    if %config<channels>:exists {
        my $ch = %config<channels>;
        if $ch.starts-with('[') && $ch.ends-with(']') {
            $ch = $ch.substr(1, $ch.chars - 2);
            @channels = $ch.split(',').map({ .trim });
        }
    }
    
    my $auto-join = (%config<auto-join> // "true") eq "true";
    my $verbose = (%config<verbose> // "false") eq "true";
    
    my $karma-min = -10;
    my $karma-max = 10;
    my $karma-enabled = True;
    if %config<karma>:exists {
        $karma-min = (%config<karma><min> // "-10").Int;
        $karma-max = (%config<karma><max> // "10").Int;
        $karma-enabled = (%config<karma><enabled> // "true") eq "true";
    }
    
    my $alias-enabled = True;
    if %config<alias>:exists {
        $alias-enabled = (%config<alias><enabled> // "true") eq "true";
    }
    
    my $broadcast-timeout = 60;
    my $max-channels = 50;
    if %config<broadcast>:exists {
        $broadcast-timeout = (%config<broadcast><timeout> // "60").Int;
        $max-channels = (%config<broadcast><max-channels> // "50").Int;
    }
    
    self.bless(
        :nickname($nickname),
        :server($server),
        :port($port),
        :username($username),
        :realname($realname),
        :channels(@channels),
        :auto-join($auto-join),
        :verbose($verbose),
        :karma-min($karma-min),
        :karma-max($karma-max),
        :karma-enabled($karma-enabled),
        :alias-enabled($alias-enabled),
        :broadcast-timeout($broadcast-timeout),
        :max-channels-per-broadcast($max-channels)
    );
}

=begin pod

=head2 Method channel-list

Returns the channel list as an array.

=end pod

method channel-list() {
    @.channels
}
