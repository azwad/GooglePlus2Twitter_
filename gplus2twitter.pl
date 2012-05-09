#!/usr/bin/perl 
use lib qw(/home/toshi/perl/lib);
use strict;
use warnings;
use URI;
use Web::Scraper;
use WWW::Mechanize;
#use YAML;
use Encode;
use Config::Pit;
use feature qw( say );
#use HashDump;
use GooglePlusAPI;
use utf8;
use Encode;
use Net::Twitter;
use LWP::UserAgent;
use HTTP::Request;
use HTML::Scrubber;
use Config::Pit;
use WebService::Bitly;

#require G+ Twitter and  bit.ly API key and preset Config::Pit's yaml file in your ~/.pit directory

my $gplus_pit_account = 'GooglePlus';
my $twitter_pit_account = 'twitter';
my $bitly_pit_account = 'bit.ly';
my $sleep_time = 10;

my %tweet_history;
dbmopen(%tweet_history,'tweet.his',0644);

my @post_id = get_gplus_update($gplus_pit_account);
my @newer_post_id = ();

foreach my $post_id (@post_id){
#	say $post_id;
  unless ( exists $tweet_history{$post_id}){
		push (@newer_post_id, $post_id);
	}
}

unless (@newer_post_id) {
	say "no update";
	exit;
}

foreach my $post_id (@newer_post_id){
	say $post_id;
	say "get post detail";
	sleep 3;
	my $post_detail = get_post_detail($gplus_pit_account,$post_id);
	my $post_tweet = compose_entry($post_detail);
print encode_utf8($post_tweet) ."\n";

## run at the first time

#$tweet_history{$post_id} = localtime;	#<----- second time commentout
#next;																	#<----- second time commentout

	my $nettwitter = initialize($twitter_pit_account);
	sleep 10;
	eval  {$nettwitter->update( $post_tweet )};
	if ($@) {
		say "update failed because: $@\n" ;
	}else{
		say "update suceesful";
		$tweet_history{$post_id} = localtime;
		sleep( $sleep_time );
	}
}
dbmclose(%tweet_history);



sub get_gplus_update {
	my $pit_account = shift;
	my $my_account = Config::Pit::pit_get( $pit_account, require => {
			'user_id' => "Google Plus user ID",
		}
	);

	my $my_id  = $my_account->{user_id};

	my $uri = URI->new("http://plus.google.com/u/0/$my_id/posts");
	my $mech = new WWW::Mechanize;
	my $res = $mech->get($uri);
	my $scraper = scraper {
				process '//div[@class="Cg Gb"]', 'post[]'   => ['@id',sub{
				s/update-//;
				return $_;
			}]
	};

	my $scr = $scraper->scrape($res);
	return  @post_id = @{$scr->{post}};
}


sub get_post_detail{
	my ($pit_account, $post_id) = @_;
	my $gplus = GooglePlusAPI->new;
	$gplus->pit_account($pit_account);

	my %option = (
  	      'get_type'  => 'post_detail', 
    	    'post_id'   => $post_id,
	);

	$gplus->set_option(%option);
	return my $post_detail = $gplus->get;
}


sub initialize {
		my $pit_account = shift;
		my  $config =	Config::Pit::pit_get($pit_account, require => {
				'access_token'				=>	'your twitter access token',
				'access_token_secret'	=>	'your access token secert',
				'consumer_key'				=>  'your consumer ley',
				'consumer_secret'			=>	'your consumer seceret',
			}
		);

    my %opt = (
			'traits'								=> ['API::REST', 'OAuth'],
			'access_token'					=> $config->{access_token},
			'access_token_secret'		=> $config->{access_token_secret},
			'consumer_key'					=> $config->{consumer_key},
			'consumer_secret'				=> $config->{consumer_secret},
		);
    my $nettwitter = Net::Twitter->new(%opt);
    return  $nettwitter;
}


sub compose_entry {
	my $post_detail = shift;

	my $post_verv							 = $post_detail->{verb} || undef;																							# 'post' or 'share'
	my $post_type							 = $post_detail->{object}->{objectType} || undef;															# 'note' or 'activity'

	my $post_title						 = $post_detail->{title} || undef;																						# post summary 
	my $post_content					 = $post_detail->{object}->{content} || undef;																# content's text 

	my $post_url							 = $post_detail->{url} || undef;																							# post permalink
	my $post_org_url					 = $post_detail->{object}->{url} || undef;																		# if shared this is original post link

#	my $publishe_time					 = $post_detail->{published} || undef; 																				# post published time no use
#	my $updata_time						 = $post_detail->{updated} || undef; 																					# post updated time no use

	my $original_publisher		 = $post_detail->{object}->{actor}->{displayName} || undef;										# original publisher name 
	my $original_publisher_url = $post_detail->{object}->{actor}->{url} || undef;														# original publisher url
	my $annotation						 = $post_detail->{annotation} || undef;																				# if shared this is my comment text 

	my $attachmentDisplayName	 = $post_detail->{object}->{attachments}->[0]->{displayName} || undef;					# attachment title text
	my $attachmentContent			 = $post_detail->{object}->{attachments}->[0]->{content} || undef; 						# attachement content text

	my $attachmentUrl0				 = $post_detail->{object}->{attachments}->[0]->{url} || undef; 								# attachment link if shared original post link
	my $attachmentType0				 = $post_detail->{object}->{attachments}->[0]->{objectType} || undef; 				# 'photo' or 'article'
	my $attachmentImageUrl0		 = $post_detail->{object}->{attachments}->[0]->{fullIvmage}->{url} || undef;	# attachement photo link 

#	my $attachmentUrl1				 = $post_detail->{object}->{attachments}->[1]->{url} || undef; 								# attachmenmt link  no use
#	my $attachmentType1				 = $post_detail->{object}->{attachments}->[1]->{objectType} || undef;	 				# 'photo' or 'article' no use 
#	my $attachmentImageUrl1		 = $post_detail->{object}->{attachments}->[1]->{fullImage}->{url} || undef;		# attachment photo link no use


# $post_detail->{object}->{originalContent}; 																											# unknown
# $post_detail->{object}->{id};																																		# no use 
# $post_detail->{access}->{items}->[0]->{type}																										# no use  maybe post is public or hidden
# $post_detail->{kind};																																						# unknown plus activity 

		my $myposttype = '';
	  my $body = '';
		my $quote = '';
		my $link = '';
		my $post_tweet = '';
		my $footer = ' ..[G+]';
		my $anc = '\.';

	if (
### quote
		   $post_verv									eq 'post'			&&									# 'post' or 'share'
			 $post_type									eq 'note'			&&									# 'note' or 'activity'
#			 $post_title															&&									# post summary 
#			 $post_content														&&									# content's text 
			 $post_url																&&									# post permalink
			 $post_org_url														&&									# if shared this is original post link
#			 $publishe_time																								# post published time
#			 $original_publisher				eq undef			&&									# original publisher name 
#			 $original_publisher_url		eq undef			&&									# original publisher url
#			 $annotation								eq undef			&&									# if shared this is my comment text 
			 $attachmentDisplayName										&&									# attachment title text
			 $attachmentContent												&&									# attachement content text
			 $attachmentUrl0													&&									# attachment link if shared original post link
			 $attachmentType0						eq	'article'											# 'photo' or 'article'
#			 $attachmentImageUrl0																					# attachement photo link 
		){
				$myposttype = 'quote';
	}elsif(
### photo
			 $post_verv									eq 'post'			&&									# 'post' or 'share'
			 $post_type									eq 'note'			&&									# 'note' or 'activity'
			 $post_title															&&									# post summary 
			 $post_content														&&									# content's text 
			 $post_url																&&									# post permalink
			 $post_org_url														&&									# if shared this is original post link
#			 $publishe_time																								# post published time
#			 $original_publisher				eq undef			&&									# original publisher name 
#			 $original_publisher_url		eq undef			&&									# original publisher url
#			 $annotation 								eq undef			&&									# if shared this is my comment text 
#			 $attachmentDisplayName																				# attachment title text
#			 $attachmentContent																						# attachement content text
			 $attachmentUrl0													&&									# attachment link if shared original post link
			 $attachmentType0						eq 'photo'												# 'photo' or 'article'
#			 $attachmentImageUrl0 																				# attachement photo link 
		){
				$myposttype = 'photo';
	}elsif(
### reshare
			 $post_verv									eq 'share'												# 'post' or 'share'
#			 $post_type																										# 'note' or 'activity'
#			 $post_title																									# post summary 
#			 $post_content																								# content's text 
#			 $post_url																										# post permalink
#			 $post_org_url																								# if shared this is original post link
#			 $publishe_time																								# post published time
#			 $original_publisher																					# original publisher name 
#			 $original_publisher_url																			# original publisher url
#			 $annotation																									# if shared this is my comment text 
#			 $attachmentDisplayName																				# attachment title text
#			 $attachmentContent																						# attachement content text
#			 $attachmentUrl0																							# attachment link if shared original post link
#			 $attachmentType0																							# 'photo' or 'article'
#			 $attachmentImageUrl0 																				# attachement photo link 
	){
				$myposttype = 'reshare';
	}elsif(
### single post
			 $post_verv								eq 'post'				&&									# 'post' or 'share'
			 $post_type								eq 'note'				&& 									# 'note' or 'activity'
			 $post_title															&&									# post summary 
			 $post_content 														&&									# content's text 
			 $post_url																&&									# post permalink
			 $post_org_url																								# if shared this is original post link
#			 $publishe_time 																							# post published time
#			 $original_publisher			eq undef				&&									# original publisher name 
#			 $original_publisher_url	eq undef				&&									# original publisher url
#			 $annotation							eq undef				&&									# if shared this is my comment text 
#			 $attachmentDisplayName		eq undef				&&									# attachment title text
#			 $attachmentContent				eq undef				&&									# attachement content text
#			 $attachmentUrl0					eq undef				&&									# attachment link if shared original post link
#			 $attachmentType0					eq undef				&&									# 'photo' or 'article'
#			 $attachmentImageUrl0			eq undef														# attachement photo link 
	){
				$myposttype = 'single';
	}else{
				$myposttype = 'unknown';
	}

#say 'my post type ' . $myposttype;

	if ($myposttype eq 'single'){
		$body			= $post_content;
		$quote			= '';
		$link			= $post_url;
	}elsif($myposttype eq 'quote'){
		$body			= $post_content;
		$quote			= '"' . $attachmentDisplayName . ' ' . $attachmentContent . '"';
		$link			= $attachmentUrl0;
	}elsif($myposttype eq 'reshare'){
	  $body			= $annotation;
		$quote			= '"' . $attachmentDisplayName . ' via ' . $original_publisher . '"';
		$link			= $post_org_url;
	}elsif($myposttype eq 'photo'){
		$body			= $post_title || $post_content;
		$quote			= '';
		$link			= $attachmentImageUrl0 || $attachmentUrl0;
	}elsif($myposttype eq 'unknown'){
		$body			= $post_title || $post_content || $attachmentDisplayName || $attachmentContent;
		$quote			= '';
		$link			= $attachmentUrl0 || $post_url;
	}else{
		warn "unknown content";
	}



		my $body_text		= HTML::Scrubber->new();
		$body						= $body_text->scrub($body);

		my $quote_text	= HTML::Scrubber->new();
		$quote					= $quote_text->scrub($quote);

		$post_tweet = $body . ' ' . $quote;

		if ($body =~ /\s($anc)$/m){
			$link = '';
		}elsif ($body =~ /\s($anc){2}$/m){
			$link = $post_url;
		}else{
			$link = $link;
		}

		$link = url_shorten($link) if $link;	
		
		my $length_footer =length($footer);
		my $length_link = length($link);
		my $length_post_tweet = length($post_tweet);
    my $maxlength = 133;

		if (($length_post_tweet + $length_footer + $length_link) > $maxlength) {
			$post_tweet = substr($post_tweet, 0, ($maxlength - $length_footer - $length_link -3) );
   	}
	 	return $post_tweet = decode_utf8($post_tweet) . $footer . ' ' . $link;
}


sub url_shorten {
	my $url = shift;

	my $pit_account = $bitly_pit_account;
	my $config = Config::Pit::pit_get($pit_account, require => {
			'user_name'			=> 'your bit.ly account name',
			'user_api_key'	=> 'your bit.ly API key',
		}
	);
 
	my $bitly = WebService::Bitly->new(
		user_name			=> $config->{user_name},
		user_api_key	=> $config->{user_api_key},
	);

	my $res = $bitly->shorten($url);
	my $short_url ='';

	if ($res->is_error) {
		my $tinyurl = "http://tinyurl.com/api-create.php?url=$url";
		my $ua = LWP::UserAgent->new();
		my $req = HTTP::Request->new('GET', $tinyurl);
		my $res_tinyurl = $ua->request($req);
		return $short_url = $res_tinyurl->content;
	}else{
  return $short_url = $res->short_url;
	}
}

