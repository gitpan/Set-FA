###########################################################################
# $Id: Makefile.PL,v 1.1 2002/03/18 05:43:00 wendigo Exp $
###########################################################################
#
# Makefile.PL
#
# RCS Revision: $Revision: 1.1 $
# Date: $Date: 2002/03/18 05:43:00 $
#
# Copyright (c) 2002 Mark Rogaski, mrogaski@cpan.org; all rights reserved.
#
# See the README file included with the
# distribution for license information.
#
# $Log: Makefile.PL,v $
# Revision 1.1  2002/03/18 05:43:00  wendigo
# Initial revision
#
#
###########################################################################
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'Set::FA',
    'VERSION_FROM'	=> 'FA.pm',
    'PREREQ_PM'		=> {
        Set::Object => 1.02,
        Log::Agent  => 0.2
    },
    ($] >= 5.005 ?
        (
            ABSTRACT_FROM => 'FA.pm',
            AUTHOR     => 'Mark Rogaski <mrogaski@cpan.org>') : ()
        ),
);

