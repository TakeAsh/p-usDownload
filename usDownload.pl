#!/usr/bin/perl
# Ustream archive ダウンローダ

use strict;
use warnings;
use utf8;
use XML::RSS;
use LWP::UserAgent;
use HTTP::Request;
use YAML::Syck;
use Log::Dispatch;
use String::Util qw(trim);

$YAML::Syck::ImplicitUnicode = 1;
$YAML::Syck::ImplicitTyping  = 1;

my $charsetConsole = 'UTF-8';
my $charsetFile    = 'UTF-8';

binmode( STDIN,  ":encoding($charsetConsole)" );
binmode( STDOUT, ":encoding($charsetConsole)" );
binmode( STDERR, ":encoding($charsetConsole)" );

my $configFile = $ARGV[0] || 'config.yml';
my $authUrl1   = 'https://www.ustream.tv/channel/';
my $authUrl2   = '/0/video/download.rss';
my $rssExt     = 'rss';
my $logExt     = 'log';

my $config = YAML::Syck::LoadFile($configFile) or die("$configFile: $!");

my $ua = LWP::UserAgent->new( keep_alive => 4, timeout => 300, );
$ua->cookie_jar( {} );

foreach my $channel ( @{ $config->{'channels'} } ) {
    getChannel($channel);
}

sub getChannel {
    my $channel = shift or return;

    my $req = HTTP::Request->new( GET => $authUrl1 . $channel . $authUrl2, );
    $req->authorization_basic( $config->{'username'}, $config->{'password'} );

    my $res = $ua->request($req);
    if ( !$res->is_success ) {
        die( $res->status_line );
    } else {
        print "Channel:$channel\tStatus:$res->status_line\n";
    }

    if ( !( -d $channel ) ) {
        mkdir($channel) or die("$channel: $!\n");
    }

    my $rssXml = $res->decoded_content;
    open( my $fhRss, '>:utf8', "$channel/$channel.$rssExt" )
        or die("$channel.$rssExt: $!\n");
    print $fhRss $rssXml;
    close($fhRss);

    my $log = Log::Dispatch->new(
        outputs => [
            [   'File',
                min_level   => 'debug',
                filename    => "$channel/$channel.$logExt",
                binmode     => ":utf8",
                permissions => 0666,
                newline     => 1,
            ],
        ],
    );

    my $rss = XML::RSS->new;
    $rss->parse($rssXml);
    my @items = @{ $rss->{'items'} };
    for ( my $i = 0; $i < @items; ++$i ) {
        my $item  = $items[$i];
        my $guid  = $item->{'guid'};
        my $title = trim( $item->{'title'} );
        my $type  = $item->{'enclosure'}{'type'};
        my $url   = $item->{'enclosure'}{'url'};
        $guid =~ s/^.+\/(\w+)$/$1/;
        $type =~ s/^.+?([A-Za-z0-9]+)$/$1/;
        my $fileName = "${guid}_$title.$type";
        my $req = HTTP::Request->new( GET => $url );
        my ( $status, $size, $total )
            = saveFile( $req, "$channel/$fileName" );
        my $percent
            = $total != 0
            ? sprintf( "%.1f", $size / $total * 100 )
            : '-';
        $log->info(
            "No:" . ( $i + 1 ) . "\tItems:" . scalar(@items),
            "\tguid:$guid\tTitle:$title\tType:$type\tURL:$url\t",
            "Status:$status\tSize:$size\tTotal:$total\tPercent:$percent"
        );
    }
}

sub saveFile {
    my ( $req, $filename ) = @_;
    my $retry = 0;
    my $res;
    my $size  = 0;
    my $total = 0;
    while (1) {
        $res = $ua->request( $req, $filename );
        $size = -s $filename || 0;
        $total = $res->header('Content-Length') || 0;
        if ( ++$retry <= 10 && $size < $total ) {
            sleep(30);
        } else {
            last;
        }
    }
    return ( $res->status_line, $size, $total );
}

# EOF
