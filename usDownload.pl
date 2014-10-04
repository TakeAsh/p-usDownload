#!/usr/bin/perl
# Ustream archive ダウンローダ

use strict;
use warnings;
use utf8;
use XML::RSS;
use LWP::UserAgent;
use HTTP::Request;
use YAML::Syck;

$YAML::Syck::ImplicitUnicode = 1;
$YAML::Syck::ImplicitTyping = 1;

my $configFile = $ARGV[0] or die($ARGV[0]);#|| 'config.yml';
my $authUrl1 = 'https://www.ustream.tv/channel/';
my $authUrl2 = '/0/video/download.rss';
my $rssExt = 'rss';

my $config = YAML::Syck::LoadFile($configFile) or die("$configFile: $!");
my $path = $config->{'channel'};

if (!(-d $path)){
	mkdir($path) or die("$path: $!\n");
}

my $ua = LWP::UserAgent->new( keep_alive => 4, timeout => 300, );
$ua->cookie_jar({});

my $req = HTTP::Request->new(
	GET => $authUrl1 . $config->{'channel'} . $authUrl2,
);
$req->authorization_basic($config->{'username'}, $config->{'password'});

my $res = $ua->request($req);
if (!$res->is_success){
	die($res->status_line);
} else {
	print $config->{'channel'} . "\t" . $res->status_line. "\n";
}

my $rssXml = $res->decoded_content;
open(my $fhRss, '>:utf8', "$path/$path.$rssExt") or die("$path.$rssExt: $!\n");
print $fhRss $rssXml;
close($fhRss);

printf("No\tItems\tguid\tTitle\tType\tURL\tStatus\tSize\tTotal\t%%\n");

my $rss = XML::RSS->new;
$rss->parse($rssXml);
my @items = @{$rss->{'items'}};
for(my $i=0; $i<@items; ++$i){
	my $item = $items[$i];
	my $guid = $item->{'guid'};
	my $title = $item->{'title'};
	my $type = $item->{'enclosure'}{'type'};
	my $url = $item->{'enclosure'}{'url'};
	$guid =~ s/^.+\/(\w+)$/$1/;
	$type =~ s/^.+?([A-Za-z0-9]+)$/$1/;
	my $fileName = "${guid}_$title.$type";
	my $req = HTTP::Request->new(GET => $url);
	my($status, $size, $total) = saveFile($req, "$path/$title.$type");
	printf(
		"%d\t%d\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%.1f\n",
		$i+1, scalar(@items), $guid, $title, $type, $url, $status, $size, $total, $size / $total * 100
	);
}

sub saveFile {
	my($req, $filename) = @_;
	my $retry = 0;
	my $size = 0;
	my $total = 0;
	while(1){
		my $res = $ua->request($req, $filename);
		$size = -s $filename || 0;
		$total = $res->header('Content-Length') || 0;
		if (++$retry <= 5 && $size < $total){
			sleep(30);
		} else {
			last;
		}
	}
	return ($res->status_line, $size, $total);
}

# EOF
