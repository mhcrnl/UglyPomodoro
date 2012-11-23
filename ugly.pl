
use Tk;
use Tk::Font;
use strict;
use warnings;
use Time::HiRes;
use SDL::Audio;
use SDL::Mixer;
use SDL::Mixer::Channels;
use SDL::Mixer::Samples;
use Config::Tiny;
use Tk::Checkbox;
use Module::ScanDeps;

#hide_console;

my $Config = Config::Tiny->new;
$Config = Config::Tiny->read( 'config.ini' );



my $breaklen=$Config->{variables}->{breaklen};
my $longbreaklen=$Config->{variables}->{longbreaklen};
my $numpomsinset=$Config->{variables}->{numpomsinset};
my $origmin=$Config->{variables}->{origmin};
my $ontop=$Config->{variables}->{ontop};
my $bell=$Config->{variables}->{bell};
my $ticking=$Config->{variables}->{ticking};
my $minutes=$origmin;
my $seconds=0;
my $running=0;
my $display;
my $interval;
my $obtained;
my $break = 0;
my $numpomssincebreak = 1; #start at one cause otherwise underestimates breaks
my $longbreak=0;
my $timeentry;
my $breakentry;
my $longbreakentry;
my $numpomsentry;
my $ontopentry;
my $okbutton;
my $optionswindow;
my $startopts=1;
my @frames=();
my @Custom_Border = ();
my ($x, $y) = 0;
my $flag = 0;
my $mixer;


my $window = MainWindow->new();
#$window->overrideredirect(1); #this would get rid of bulky windows frame but prevents movement.
$window->resizable(0,0);

$mixer = SDL::Mixer::open_audio(44100, AUDIO_S16, 2, 1024) == 0;

my $ticktock = SDL::Mixer::Samples::load_WAV('ticktock.wav');
my $done = SDL::Mixer::Samples::load_WAV('done.wav');

$window->configure(-title=>'Timer', -background=>'red');
$window->geometry('+200+300');

my $time = $window->Label(-text=>"$minutes:$seconds", -background=>'white')->pack(-side=>'left', -expand=>1);
&displaytime;


my $font = $window->Font(-family=> 'Arial', -size  => 8);

my $startbutton=$window->Button(-text=>'Start', -command => sub {&start}, -font=>$font)->pack(-side=>'left', -expand=>1);
my $optionsbutton=$window->Button(-text => "Options", -command => sub{&options}, -font=>$font)->pack(-side=>'left', -expand=>1);

Time::HiRes::sleep(0.1);
if ($ontop==1){
	$window->attributes(-topmost => 1);
}
#$startbutton -> 

   
MainLoop();

######### SUBROUTINES ##########

# invocation of checkbutton causes crash when exit
sub options {
	Time::HiRes::sleep(0.1);
	if ($startopts==1){
		$startopts=0;
		$optionswindow=$window->Toplevel(-takefocus =>1);  #this line causes options window error occasionally
		#print "got here2";
		$optionswindow->protocol('WM_DELETE_WINDOW',\&getoptions);
		#$optionswindow->overrideredirect(1); 
		$optionswindow->Label(-text=>'Work Length')->pack();
		$timeentry=$optionswindow->Entry(-textvariable=>$origmin)->pack();
		$optionswindow->Label(-text=>'-------------')->pack();
		$optionswindow->Label(-text=>'Break Length')->pack();
		
		$breakentry=$optionswindow->Entry(-textvariable=>$breaklen)->pack();
		$optionswindow->Label(-text=>'-------------')->pack();
		$optionswindow->Label(-text=>'Long Break Length')->pack();
		$longbreakentry=$optionswindow->Entry(-textvariable=>$longbreaklen)->pack();
		$optionswindow->Label(-text=>'-------------')->pack();
		$optionswindow->Label(-text=>'Sets Before Long Break')->pack();
		$numpomsentry=$optionswindow->Entry(-textvariable=>$numpomsinset)->pack();
		$optionswindow->Label(-text=>'-------------')->pack();
		$optionswindow->Label(-text=>'Stay On Top')->pack();
		$ontopentry=$optionswindow->Checkbox(-variable=>\$ontop)->pack();
		$optionswindow->Label(-text=>'-------------')->pack();
		$optionswindow->Label(-text=>'Ticking Sound')->pack();
		$optionswindow->Checkbox(-variable=>\$ticking)->pack();
		$optionswindow->Label(-text=>'-------------')->pack();
		$optionswindow->Label(-text=>'End Bell')->pack();
		$optionswindow->Checkbox(-variable=>\$bell)->pack();
		$okbutton=$optionswindow->Button(-text=>'OK', -command=>sub{&getoptions})->pack();
		
	}
	#print "gothere3";
}

sub getoptions{
	$origmin=$timeentry->get();
	$breaklen=$breakentry->get();
	$longbreaklen=$longbreakentry->get();
	$numpomsinset=$numpomsentry->get();
	#Time::HiRes::sleep(0.1);
	&reset;
	$optionswindow->destroy;
	$startopts=1;
	&writeconfig;
}

sub writeconfig{
	# all section must be in single line, because will overwrite whole section.
	$Config->{variables} = { longbreaklen => $longbreaklen, numpomsinset => $numpomsinset, breaklen => $breaklen, origmin => $origmin, ontop=>$ontop, bell=>$bell, ticking=>$ticking };
	$Config->write( 'config.ini' );
}

sub reset{
	$optionsbutton->configure(-text=>'Options', -command=>sub{&options});
	$minutes=$origmin;
	$seconds=0;
	if ($ontop==1){
		$window->attributes(-topmost => 1);
	}else{
		Time::HiRes::sleep(0.3);
		$window->attributes(-topmost => 0);
	}
	&stop;
}

sub stop{
	if ($break==0){
		$window->configure(-background=>'red');
	}
	if ($break==1){
		$window->configure(-background=>'orange');
	}
	SDL::Mixer::Channels::pause( 1 );
	$startbutton-> configure(-text=>'Start', -command => sub {&start});
	$running=0;
	&displaytime;
}

sub start{
	if ($break==0){
		if ($ticking==1){
			SDL::Mixer::Channels::play_channel( 1, $ticktock, -1 );
		}
		$window->configure(-background=>'green');
	}
	else{
		if ($longbreak==1){
			$window->configure(-background=>'cyan');
		}
		else{
			$window->configure(-background=>'blue');
		}
	}
	$running=1;
	$optionsbutton->configure(-text=>'Reset', -command=>sub{&reset});
	$startbutton->configure(-text=>'Pause', -command=> sub{&stop});
	&runtimer;
}

sub displaytime{
	if ($seconds<10){
		$display = "$minutes:0$seconds";
	}else{
		$display = "$minutes:$seconds";
	}
	$time->configure (-text => "$display");
	$window->update;
}

sub runtimer{
	$interval = 5;
	while ($running==1){
		if ($interval>9){
			$seconds=$seconds-1;
			if ($seconds<0){
				if ($minutes>0){
					$seconds=59;
					$minutes=$minutes-1;
				}else{
					$seconds=0;
					$running=0;
					if ($break==0){
						$break=1;
						if ($numpomssincebreak>=$numpomsinset){
							$minutes=$longbreaklen;
							$longbreak=1;
							$numpomssincebreak=1;
						}else{
							$numpomssincebreak++;
							$minutes=$breaklen;
							$longbreak=0;
						}
					}
					else{
						$break=0;
						$minutes=$origmin;
					}
					$optionsbutton->configure(-text=>'Options', -command=>sub{&options});
					if ($bell==1){
						SDL::Mixer::Channels::play_channel( 2, $done, 0 );
					}
				}
			}
			&displaytime;
			$interval = 0;
		}
		$window->update;
		Time::HiRes::sleep(0.1);
		$interval++;
	}
	
	
	&stop;
}