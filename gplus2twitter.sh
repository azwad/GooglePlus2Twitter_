#!/bin/bash
cd /home/toshi/perl/github/GooglePlus2Twitter/
	while [ $? -eq 0 ]
		do 
			echo "wait 60 seconds"
			echo "sleep 60"
			sleep 60
			/home/toshi/perl/github/GooglePlus2Twitter/gplus2twitter.pl &
		done



