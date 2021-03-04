#!perl
use strict;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';
use Getopt::Long;
use Pod::Usage;

# Adaption of https://github.com/dudik/twitch-m3u8/blob/master/index.js

use StreamFinder::Twitch;

GetOptions(
    'stream=s' => \my $channelId,
    'vod=s' => \my $videoId,
    'format=s' => \my $output_format,
) or pod2usage(2);

$output_format //= 'm3u8';

my @res;

if( $output_format eq 'url' ) {
    if( $channelId ) {
        @res = StreamFinder::Twitch::getStreamPlaylistUrl($channelId);
    } elsif( $videoId ) {
        @res = StreamFinder::Twitch::getVodPlaylistUrl($videoId);
    }

} else {
    my $raw = $output_format eq 'm3u8';
    if( $channelId ) {
        @res = getStream($channelId, $raw);
    } elsif( $videoId ) {
        @res = getVod($videoId, $raw);
    }
};
print join "", @res;
