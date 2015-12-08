use strict;
use warnings;

use WWW::Mechanize;

# benchmark
my $FOUND_TOTAL = 0;
my $INVALID_URL = 0;
my $COURSE_COUNT= 0;
my $DUPLICATE   = 0;

my $DEBUG    = 1;
my $ROOT_DIR = "./file";
my $MIN_YEAR = 2000;
my $MAX_YEAR = 2015; # add a check!
my $FALL     = 1;
my $WINTER   = 9;
my $mech     = WWW::Mechanize->new();
my @course_ls= qw/JRE ECE MAT CSC AER APS CHE CIV MSE MIE PHY BME STA MIN/;
#test();
main();

sub main{
    my $count = 0;
    foreach my $department (@course_ls){
        print "Parsing $department courses\n";
        for(my $course = 100; $course <= 599; $course++){
            my $course_name = "${department}${course}H1"; 
            print "Getting $course_name\n";
            $count += get_all_files($course_name);
        }

    }
    print "Total of $count files downloaded\n";
}

sub get_all_files{
    my $course_name  = shift; # ECE360H1
    my $winter_count = 0;
    my $fall_count   = 0;
    for(my $year = $MIN_YEAR; $year <= $MAX_YEAR; $year++){
        $winter_count += parse_URL($year, $course_name, $WINTER);
        $fall_count   += parse_URL($year, $course_name, $FALL  );
    }
    print "$course_name: FALL=$fall_count \b WINTER=$winter_count\n";
    return $winter_count + $fall_count;
}

sub check_and_downlaod_file{
    #check_and_downlaod_file($url_name, $year, $course, $session_code);
    my $url_name     = shift;
    my $year         = shift;
    my $course       = shift;
    my $session_code = shift;
    
    my $directory = make_directory($year, $course, $session_code);
    print "downloading $url_name\n";
    my $return_value = downlaod_file($url_name, $directory);
    if($return_value){
        print "Got $return_value from wget!\n";
        print "File: $url_name\n";
        print "YEAR: $year\n";
        print "Course: $course\n";
        print "Directory: $directory\n";
    }
}

sub downlaod_file{
    # downlaod file from url to path
    my $file_url      = shift;
    my $file_path     = shift;
    my $command       = "wget --directory-prefix=$file_path \"$file_url\"";
    my $return_code   = system($command);
    return $return_code >> 8;
}

sub parse_URL{
    my $year          = shift; #2011
    my $course        = shift; #ECE360H1
    my $session_code  = shift; #1 or 9
    my $incoming_url  = gen_URL($year, $course, $session_code);
    
    my $HTTP_response = $mech->get($incoming_url);

    if(!$HTTP_response->is_success){
        print "HTTP response unsuccessful:" . $HTTP_response->status_line . "\n";
        return 0;
    }

    my @links = $mech->links();
    my $size  = () = @links; 
    #print "Found $size files in $incoming_url\n";


    $FOUND_TOTAL = $FOUND_TOTAL + $size;
    

    for(my $i = 0; $i < $size; $i++){
        my $url_name = $links[$i]->url();
        $url_name =~ s/\r//g;
        $url_name =~ s/ /%20/g;
        if(!$url_name =~ m/\.pdf$/ or !$url_name =~ m/\.PDF$/){
            print "Found a link that is NOT a pdf: $url_name\n";
            $INVALID_URL++;
        }else{
            check_and_downlaod_file($url_name, $year, $course, $session_code);
        }
    }
    return $size;
}

sub gen_URL{
    my $year         = shift;   #2012
    my $course       = shift;   #ECE360H1
    my $session_code = shift;   #1
    my $url          = "http://courses.skule.ca/course/getYear.php?q=". "$year" ."$session_code" . "&c=" . $course; 
    return $url;
}

sub make_directory{
    my $year          = shift; #2011
    my $course        = shift; #ECE360H1
    my $session_code  = shift; #1 or 9
    
    my $directory     = synthesize_directory($course, $year, $session_code);
    if($directory eq "INVALID"){
        die "INVALID directory $directory\n";
    }

    if(-d $directory){
        return $directory;
    }else{
        my $return_code = system("mkdir -p $directory");
        if($return_code){
            $return_code = $return_code >> 8;
            die "Unable to make directory, mkdir returned $return_code\n";
        }
        return $directory;
    }

}

sub synthesize_directory{
    my $course_code  = shift; #ECE360H1
    my $year         = shift; #2011
    my $session_code = shift; #1 or 9
    my $department;
    
    if(validate_course_code($course_code)){
        ($course_code, $department) = $course_code =~ m/(([A-Z]{3})\d{3})/;
    }else{
        die "Unable to validate course code: $course_code!\n";
    }
    
    my $session = "INVALID";
    if($session_code == $WINTER){
        $session = "Winter";
    }elsif($session_code == $FALL){
        $session = "Fall";
    }else{
        return "INVALID";
    }
    
    my $synth_path  = "$ROOT_DIR/$department/$course_code/$year/$session";
    return $synth_path;
}

sub validate_course_code{
    # to be implemented
    return 1;
}

sub test{
    my $year  = 2011; 
    my $course      ;
    my $session_code = $FALL;
    for(my $i = 100; $i <= 199; $i++){
       $course = "ECE${i}H1";
       print synthesize_directory($course, $year, $session_code) . "\n";
    }

    return 1;
}

sub benchmark{
    #my $url = "http://courses.skule.ca/course/getYear.php?q=20091&c=ECE354H1";
    for(my $i = 100; $i <= 599; $i++){
        my $course_name = "ECE${i}H1";
        my $winder_match = 0;
        my $fall_match   = 0;
        for(my $j = 2013; $j <= 2015; $j++){
            $winder_match += parse_URL($j, $course_name, 1);
            $fall_match   += parse_URL($j, $course_name, 9);
        }
        if($winder_match || $fall_match){
            print "Found a course: $course_name\n";
            $COURSE_COUNT++;
        }       
        if($winder_match && $fall_match){
            print "DUPLICATE! course is $course_name\n";
            $DUPLICATE ++;
        }
    }

    print "****************************************************************************************\n";
    print "Found $FOUND_TOTAL links between (ECE100 - ECE599), of which $INVALID_URL are invalid\n";
    print "There are $COURSE_COUNT valid course codes between ECE100 and ECE599 \n";
    print "Of which $DUPLICATE courses have both fall AND winter sessions\n";
}
