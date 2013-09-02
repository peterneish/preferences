#! /usr/bin/perl -w

# processes raw data for preferences from the AEC website
# http://www.aec.gov.au/election/downloads.htm

use TEXT::CSV;
use Data::Dumper;

$csv = Text::CSV->new();


my @files = glob( './raw_data/*' );

foreach $file (@files){

	# load into an array for easier processing
	my @prefs;	# tracks a preference from another ticket
	my %tickets;	# tracks the party or independent group the ticket is from	
	my $candidates = {};	# tracks which ticket a candiate is from


	open (CSV, "<", $file) or die $!;
	while(<CSV>){

		next if ($. == 1); 

		$status = $csv->parse($_);

		if($status){
			@fields = $csv->fields();

			# we are going to use this as our key for a candidate
			my $candidate_key = join(":", ($fields[3], $fields[4], $fields[5]));
			my $preference = $fields[6];
			my $ticket = $fields[1];

			# first collapse lib and national into coalition
			$fields[5] =~ s/^Liberal$/Coalition/;
			$fields[5] =~ s/^The Nationals$/Coalition/;

			# now load the ticket into our array
			# we are assuming that each ticket will preference their own party first
			if($fields[6] == 1){
				$ticketname = $fields[5] . "";
				if($ticketname eq ""){
					# if there is no party then we use the candidate name and add group to the end
					$ticketname = $fields[4] . " " . $fields[3] . " Group";	
				}
				
				$tickets{$fields[1]} = $ticketname;
			}


			
			# create or update our candidate 
			# keeping track of best preference 
			# (we'll assume this is the ticket they belong to)
			if( exists $candidates->{$candidate_key}){
				# update if we have a better preference
				if($candidates->{$candidate_key}->{ 'preference' }  > $preference){
					$candidates->{$candidate_key}->{ 'ticket' } 	= $ticket;
					$candidates->{$candidate_key}->{ 'preference' } = $preference;
				}
			} 	
			else {
				$candidates->{$candidate_key}->{'ticket'} = $ticket;
				$candidates->{$candidate_key}->{'preference'} = $preference;
	
			}

			# now store our simple preference array
			push @prefs, [$ticket, $candidate_key, $preference];

		}


	}
 	close CSV;

	#print Dumper(%tickets);

	# now we have our data we can generate the average preference given between tickets
	# and associate with a party
	
	my $party_preferences = {};

	for my $pref (@prefs){

		# we now add the data to our new final hashref of party tickets and their preferences

		my $directing_party 	= $tickets{$pref->[0]};
		my $receiving_ticket 	= $candidates->{$pref->[1]}->{'ticket'};
		my $receiving_party  	= $tickets{$receiving_ticket};
		my $preference 		= $pref->[2];

		$party_preferences->{$directing_party}->{$receiving_party}->{'count'}++;
		$party_preferences->{$directing_party}->{$receiving_party}->{'total'} += $preference;
		$party_preferences->{$directing_party}->{$receiving_party}->{'average'} = 
			$party_preferences->{$directing_party}->{$receiving_party}->{'total'} /
			$party_preferences->{$directing_party}->{$receiving_party}->{'count'}++;
			


	}		

	# now we have all our data we can output a csv file and a matrix.json file

	$outputfile = $file;
	$outputfile =~ s/raw_data/processed_data/;
	$outputfile =~ s/\.csv//;

	$matrix_file = $outputfile."_processed.json";
	$csv_file = $outputfile."_processed.csv";


	open MATRIX, ">$matrix_file" or die $!;
	open CSV_PROC, ">$csv_file" or die $!;

	print MATRIX "[";

	my @lines;

	foreach my $dir_party (sort keys ($party_preferences)){
		print CSV_PROC $dir_party."\n";

		my @averages;
		
		foreach my $rec_party (sort keys ($party_preferences->{$dir_party})){
			
			$avg = sprintf("%.1f", $party_preferences->{$dir_party}->{$rec_party}->{'average'});
			push @averages, $avg;
			


		}
		print MATRIX "[";
		print MATRIX join ",", @averages;
		print MATRIX "],";
	}

	print MATRIX "]";

	close MATRIX;
	close CSV_PROC;






}

1;
