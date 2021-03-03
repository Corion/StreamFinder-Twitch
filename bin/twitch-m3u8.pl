#!perl
use strict;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

# Adaption of https://github.com/dudik/twitch-m3u8/blob/master/index.js

# Simple version, suitable for StreamFinder
use LWP::UserAgent;
use HTTP::Request;
use JSON 'encode_json', 'decode_json';
use Carp 'croak';
use Getopt::Long;
use Pod::Usage;

our $clientId = "kimne78kx3ncx6brgo4mv6wki5h1ko";

sub _getAccessToken($id, $isVod) {

    my $data = encode_json({
        operationName =>  "PlaybackAccessToken",
        extensions => {
            persistedQuery => {
                    version => 1,
                    sha256Hash => "0828119ded1c13477966434e15800ff57ddacf13ba1911c129dc2200705b0712"
            }
        },
        variables => {
            isLive => ($isVod ? $JSON::false : $JSON::true),
            login => ($isVod ? "" : $id),
            isVod => ($isVod ? $JSON::true : $JSON::false),
            vodID => ($isVod ? $id : ""),
            playerType => "embed"
        }
    });

    my $req = HTTP::Request->new(
        'POST' => 'https://gql.twitch.tv/gql',
        [
            'Client-id' => $clientId,
        ],
        $data
    );

    return $req, sub( $resp ) {
        my $resp_body = decode_json( $resp->decoded_content );
       if( $resp->code != 200 ) {
            croak $resp_body->{message};
        } elsif( $isVod ) {
            return $resp_body->{data}->{videoPlaybackAccessToken};
        } else {
            return $resp_body->{data}->{streamPlaybackAccessToken};
        };
    };
}

sub _getPlaylist($id, $accessToken, $vod) {
    my $vodPath = $vod ? 'vod' : 'api/channel/hls';
    my $aValue = $accessToken->{value};
    my $aSignature = $accessToken->{signature};
    my $url = "https://usher.ttvnw.net/$vodPath/${id}.m3u8?client_id=${clientId}&token=${aValue}&sig=${aSignature}&allow_source=true&allow_audio_only=true";
    my $req = HTTP::Request->new(
        'GET' => $url,
    );

    return $req, sub($resp) {
        return $resp->decoded_content
    };
}

sub parsePlaylist($playlist) {
    my @parsedPlaylist;
    my @lines = split /\n/, $playlist;
    my $i = 4;
    while($i < @lines ) {
        #use Data::Dumper; warn Dumper @lines[$i-2..$i];
        my %info;
        ($info{quality}) = ( $lines[$i-2] =~ /NAME="([^"]*)"/);
        ($info{resolution}) = ( $lines[$i-1] =~ /RESOLUTION=([^",]+)/);
        $info{url} = $lines[$i];
        $i += 3;

        push @parsedPlaylist, \%info;
    }
    return @parsedPlaylist;
}

sub getStream($channelId, $raw=undef) {
    my $ua = LWP::UserAgent->new();
    my( $req, $then ) = _getAccessToken($channelId,undef);
    my $accessToken = $then->($ua->request( $req ));
    ( $req, $then ) = _getPlaylist($channelId,$accessToken,undef);
    my $playlist = $then->($ua->request( $req ));
    my @res = $raw ? $playlist : parsePlaylist($playlist);
    return @res
}

sub getVod($videoId, $raw=undef) {
    my $ua = LWP::UserAgent->new();
    my( $req, $then ) = _getAccessToken($videoId,1);
    my $accessToken = $then->($ua->request( $req ));

    ( $req, $then ) = _getPlaylist($videoId,$accessToken,1);
    my $playlist = $then->($ua->request( $req ));
    my @res = $raw ? $playlist : parsePlaylist($playlist);
    return @res
}

GetOptions(
    'stream=s' => \my $channelId,
    'vod=s' => \my $videoId,
    'format=s' => \my $output_format,
) or pod2usage(2);

$output_format //= 'm3u8';

my @res;
my $raw = $output_format eq 'm3u8';
if( $channelId ) {
    @res = getStream($channelId, $raw);
} elsif( $videoId ) {
    @res = getVod($videoId, $raw);
}
print join "", @res;
