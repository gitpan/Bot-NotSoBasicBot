use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Bot::NotSoBasicBot',
    AUTHOR              => 'Michael Roberts <michael@vivtek.com>',
    VERSION_FROM        => 'lib/Bot/NotSoBasicBot.pm',
    ABSTRACT_FROM       => 'lib/Bot/NotSoBasicBot.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Bot::BasicBot' => 0,
	'Config::Auto' => 0,
	'Event::Schedule' => 0,
	'Data::Dumper' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Bot-NotSoBasicBot-*' },
);
