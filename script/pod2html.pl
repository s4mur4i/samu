#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use Pod::Simple::HTMLBatch;
use Pod::Simple::XHTML;

unless (-e "$Bin/../pod_html") {
    mkdir "$Bin/../pod_html" or die "could not create directory: $!";
}

my $convert = Pod::Simple::HTMLBatch->new;
$convert->html_render_class('Pod::Simple::XHTML');
$convert->add_css('http://search.cpan.org/s/style.css');
$convert->css_flurry(0);
$convert->javascript_flurry(0);
$convert->contents_file(0);
$convert->batch_convert("$Bin/../lib", "$Bin/../pod_html");

1;